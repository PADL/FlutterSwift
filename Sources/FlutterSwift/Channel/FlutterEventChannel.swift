//
// Copyright (c) 2023-2025 PADL Software Pty Ltd
//
// Licensed under the Apache License, Version 2.0 (the License);
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an 'AS IS' BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import AsyncAlgorithms
@preconcurrency
import AsyncExtensions
import Atomics
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Synchronization

/**
 * An asynchronous event stream.
 */
public typealias FlutterEventStream<Event: Codable & Sendable> = AnyAsyncSequence<Event?>

/**
 * A channel for communicating with the Flutter side using event streams.
 */
public final class FlutterEventChannel: _FlutterBinaryMessengerConnectionRepresentable,
  Sendable
{
  public let name: String
  public let binaryMessenger: FlutterBinaryMessenger
  public let codec: FlutterMessageCodec
  public let priority: TaskPriority?

  private typealias EventStreamTask = Task<(), Never>

  /// A single `listen` invocation. `generation` distinguishes successive
  /// invocations sharing an invocation ID, so a superseded task cannot disturb
  /// the entry its replacement now owns; `name` is where its events go, kept so
  /// the teardown paths can close the stream without the originating call.
  private struct EventStreamEntry {
    let generation: UInt64
    let name: String
    let task: EventStreamTask
  }

  private let _connection = ManagedAtomic<FlutterBinaryMessengerConnection>(0)
  private let _channelBufferSize = ManagedAtomic<Int>(1)
  private let _channelBufferOverflowAllowed = ManagedAtomic<Bool>(false)
  private let _nextGeneration = ManagedAtomic<UInt64>(0)
  private let tasks: Mutex<[String: EventStreamEntry]>

  var connection: FlutterBinaryMessengerConnection {
    get {
      _connection.load(ordering: .acquiring)
    }
    set {
      _connection.store(newValue, ordering: .releasing)
    }
  }

  private var channelBufferSize: Int {
    get {
      _channelBufferSize.load(ordering: .acquiring)
    }
    set {
      _channelBufferSize.store(newValue, ordering: .releasing)
    }
  }

  private var channelBufferOverflowAllowed: Bool {
    get {
      _channelBufferOverflowAllowed.load(ordering: .acquiring)
    }
    set {
      _channelBufferOverflowAllowed.store(newValue, ordering: .releasing)
    }
  }

  /**
   * Initializes a `FlutterEventChannel` with the specified name, binary messenger,
   * method codec and task queue.
   *
   * The channel name logically identifies the channel; identically named channels
   * interfere with each other's communication.
   *
   * The binary messenger is a facility for sending raw, binary messages to the
   * Flutter side. This protocol is implemented by `FlutterEngine` and `FlutterViewController`.
   *
   * @param name The channel name.
   * @param binaryMessenger The binary messenger.
   * @param codec The method codec.
   * @param taskQueue The FlutterTaskQueue that executes the handler
   */
  public init(
    name: String,
    binaryMessenger: FlutterBinaryMessenger,
    codec: FlutterMessageCodec = FlutterStandardMessageCodec.shared,
    priority: TaskPriority? = nil
  ) {
    tasks = Mutex([:])
    self.name = name
    self.binaryMessenger = binaryMessenger
    self.codec = codec
    self.priority = priority
  }

  deinit {
    // subscribers may still be attached, and cancelled tasks stay silent (see
    // `_run`), so their streams are closed as part of teardown
    _scheduleRemoveMessageHandler(
      connection: connection,
      binaryMessenger: binaryMessenger,
      closing: _retireAllTasks().map(\.name)
    )
  }

  /// Cancels and forgets every stream task, returning what was retired so the
  /// caller can close the corresponding subscriptions.
  private func _retireAllTasks() -> [EventStreamEntry] {
    let retired = tasks.withLock { tasks -> [EventStreamEntry] in
      let retired = Array(tasks.values)
      tasks.removeAll()
      return retired
    }
    retired.forEach { $0.task.cancel() }
    return retired
  }

  private func _cancelTask(_ id: String) {
    var task: EventStreamTask?

    tasks.withLock { tasks in
      task = tasks[id]?.task
      tasks.removeValue(forKey: id) // shouldn't be necessary
    }

    task?.cancel()
  }

  /// Removes the entry only if it is still the one this generation installed: a
  /// re-`listen` on the same invocation ID replaces it, and the superseded task
  /// finishing must not delete its successor.
  private func _removeTask(_ id: String, generation: UInt64) {
    tasks.withLock { tasks in
      guard tasks[id]?.generation == generation else { return }
      tasks.removeValue(forKey: id)
    }
  }

  private func _addTask(_ id: String, _ entry: EventStreamEntry) {
    var oldTask: EventStreamTask?

    tasks.withLock { tasks in
      oldTask = tasks[id]?.task
      tasks[id] = entry
    }

    oldTask?.cancel()
  }

  /// Sends only while the channel still has a handler: otherwise the message is
  /// buffered and handed to the next subscriber to this name. The test and the
  /// send share one hop on the platform actor, where `removeMessageHandler()`
  /// also runs, so the handler cannot be retired between them.
  @FlutterPlatformThreadActor
  private func _send(on name: String, message: Data?) throws {
    guard connection > 0 else { return }
    try binaryMessenger.send(on: name, message: message)
  }

  private func _run<Event: Codable & Sendable>(
    for stream: FlutterEventStream<Event>,
    name: String
  ) async throws {
    do {
      for try await event in stream {
        let envelope = FlutterEnvelope.success(event)
        try await _send(on: name, message: codec.encode(envelope))
        try Task.checkCancellation()
      }
      try await _send(on: name, message: nil)
    } catch let error as FlutterError {
      let envelope = FlutterEnvelope<Event>.failure(error)
      try await _send(on: name, message: codec.encode(envelope))
    } catch is CancellationError {
      // No end-of-stream from here: cancellation means either the subscriber
      // asked to stop, or the channel is being retired — and the retirement
      // paths close the stream themselves, while the handler is still live.
    } catch {
      let envelope = FlutterEnvelope<Event>.failure(error.flutterError)
      try await _send(on: name, message: codec.encode(envelope))
    }
  }

  private func onMethod<Event: Codable & Sendable, Arguments: Codable & Sendable>(
    call: FlutterMethodCall<Arguments>,
    onListen: @escaping ((Arguments?) async throws -> FlutterEventStream<Event>),
    onCancel: ((Arguments?) async throws -> ())?
  ) async throws -> FlutterEnvelope<Arguments>? {
    let envelope: FlutterEnvelope<Arguments>?
    let method = call.method.split(separator: "#", maxSplits: 2)
    let invocationID: String, name: String

    if method.count > 1 {
      invocationID = String(method[1])
      precondition(!invocationID.isEmpty)
      name = self.name + "#" + invocationID
    } else {
      invocationID = ""
      name = self.name
    }

    switch method.count > 1 ? String(method[0]) : call.method {
    case "listen":
      if !invocationID.isEmpty {
        // Drain before arming, since a client that restarts invocation IDs
        // reuses this name. This cannot rescue the current subscriber — the
        // engine flushes the buffer when Dart registers its handler, before
        // `listen` reaches us — it only cleans up for the next invocation.
        try await _resizeChannelBuffer(
          binaryMessenger: binaryMessenger,
          on: name,
          newSize: 0
        )
        try await _resizeChannelBuffer(
          binaryMessenger: binaryMessenger,
          on: name,
          newSize: channelBufferSize
        )
        try await _allowChannelBufferOverflow(
          binaryMessenger: binaryMessenger,
          on: name,
          allowed: channelBufferOverflowAllowed
        )
      }

      let generation = _nextGeneration.wrappingIncrementThenLoad(by: 1, ordering: .relaxed)
      let stream = try await onListen(call.arguments)
      let task = EventStreamTask(priority: priority) { [weak self] in
        try? await self?._run(for: stream, name: name)
        self?._removeTask(invocationID, generation: generation)
      }
      _addTask(invocationID, EventStreamEntry(generation: generation, name: name, task: task))
      envelope = FlutterEnvelope.success(nil)
    case "cancel":
      do {
        try await onCancel?(call.arguments)
        envelope = FlutterEnvelope.success(nil)
      } catch let error as FlutterError {
        envelope = FlutterEnvelope.failure(error)
      } catch {
        envelope = FlutterEnvelope.failure(error.flutterError)
      }
      _cancelTask(invocationID)
      // Nothing still queued under this name will ever be consumed. Not gated on
      // the invocation ID: a stock Dart EventChannel sends a bare `cancel`, and
      // those channels carry their events on the channel's own name.
      try? await _resizeChannelBuffer(
        binaryMessenger: binaryMessenger,
        on: name,
        newSize: 0
      )
      if invocationID.isEmpty {
        // that name outlives the invocation, so restore it for the next listen
        try? await _resizeChannelBuffer(
          binaryMessenger: binaryMessenger,
          on: name,
          newSize: channelBufferSize
        )
      }
    default:
      envelope = nil
    }

    return envelope
  }

  /**
   * Registers a handler for stream setup requests from the Flutter side.
   *
   * Replaces any existing handler. Use a `nil` handler for unregistering the
   * existing handler.
   *
   * @param handler The stream handler.
   */
  @FlutterPlatformThreadActor
  public func setStreamHandler<Event: Codable & Sendable, Arguments: Codable & Sendable>(
    onListen: (@Sendable (Arguments?) async throws -> FlutterEventStream<Event>)?,
    onCancel: (@Sendable (Arguments?) async throws -> ())?
  ) throws {
    // Any re-registration retires the previous incarnation: its streams belong
    // to the handler that is going away, whether or not one replaces it. Left
    // running, they would interleave into the new subscriber's stream and close
    // it when they exhausted.
    let wasRegistered = connection > 0
    let retired = _retireAllTasks()

    if wasRegistered {
      for entry in retired {
        // The subscriber is still attached and still waiting for end-of-stream;
        // the handler is not unregistered until setMessageHandler() below, so
        // this is delivered rather than buffered. Cancelled tasks stay silent.
        try? binaryMessenger.send(on: entry.name, message: nil)
      }
    }

    if onListen != nil {
      // A new incarnation must not inherit the previous one's buffered messages;
      // a retained end-of-stream would close it at once. Not gated on
      // `connection > 0`: that is per object, and the case that matters is a new
      // object taking over a name whose previous owner is already deallocated.
      try? _resizeChannelBuffer(binaryMessenger: binaryMessenger, on: name, newSize: 0)
      try? _resizeChannelBuffer(
        binaryMessenger: binaryMessenger,
        on: name,
        newSize: channelBufferSize
      )
    }

    try setMessageHandler(onListen) { [weak self] unwrappedHandler in
      { [weak self] message in
        guard let self else {
          throw FlutterSwiftError.messengerNotAvailable
        }
        guard let message else {
          throw FlutterSwiftError.methodNotImplemented
        }

        let call: FlutterMethodCall<Arguments> = try self.codec.decode(message)
        let envelope: FlutterEnvelope<Arguments>? = try await self.onMethod(
          call: call,
          onListen: unwrappedHandler,
          onCancel: onCancel
        )
        guard let envelope else { return nil }
        return try self.codec.encode(envelope)
      }
    }
  }

  @_spi(FlutterSwiftPrivate)
  public var tasksCount: Int {
    tasks.withLock { $0.count }
  }

  @FlutterPlatformThreadActor
  public func resizeChannelBuffer(_ newSize: Int) throws {
    try _resizeChannelBuffer(binaryMessenger: binaryMessenger, on: name, newSize: newSize)
    channelBufferSize = newSize
  }

  @FlutterPlatformThreadActor
  public func allowChannelBufferOverflow(_ allowed: Bool) throws {
    try _allowChannelBufferOverflow(
      binaryMessenger: binaryMessenger,
      on: name,
      allowed: allowed
    )
    channelBufferOverflowAllowed = allowed
  }
}
