//
// Copyright (c) 2023-2024 PADL Software Pty Ltd
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

/**
 * An asynchronous event stream.
 */
public typealias FlutterEventStream<Event: Codable> = AnyAsyncSequence<Event?>

/**
 * A channel for communicating with the Flutter side using event streams.
 */
public final class FlutterEventChannel: _FlutterBinaryMessengerConnectionRepresentable, Sendable {
  public let name: String
  public let binaryMessenger: FlutterBinaryMessenger
  public let codec: FlutterMessageCodec
  public let priority: TaskPriority?

  private typealias EventStreamTask = Task<(), Never>

  private let _connection: ManagedAtomic<FlutterBinaryMessengerConnection>
  private let tasks: ManagedCriticalState<[String: EventStreamTask]>

  var connection: FlutterBinaryMessengerConnection {
    get {
      _connection.load(ordering: .acquiring)
    }
    set {
      _connection.store(newValue, ordering: .releasing)
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
   * @param taskQueue The FlutterTaskQueue that executes the handler (see
   -[FlutterBinaryMessenger makeBackgroundTaskQueue]).
   */
  public init(
    name: String,
    binaryMessenger: FlutterBinaryMessenger,
    codec: FlutterMessageCodec = FlutterStandardMessageCodec.shared,
    priority: TaskPriority? = nil
  ) {
    _connection = ManagedAtomic(0)
    tasks = ManagedCriticalState([:])
    self.name = name
    self.binaryMessenger = binaryMessenger
    self.codec = codec
    self.priority = priority
  }

  deinit {
    tasks.withCriticalRegion { tasks in
      tasks.values.forEach { $0.cancel() }
    }
    try? removeMessageHandler()
  }

  private func _cancelTask(_ id: String) {
    var task: EventStreamTask?

    tasks.withCriticalRegion { tasks in
      task = tasks[id]
      tasks.removeValue(forKey: id) // shouldn't be necessary
    }

    task?.cancel()
  }

  private func _removeTask(_ id: String) {
    tasks.withCriticalRegion { tasks in
      tasks.removeValue(forKey: id)
    }
  }

  private func _addTask(_ id: String, _ task: EventStreamTask) {
    var oldTask: EventStreamTask?

    tasks.withCriticalRegion { tasks in
      oldTask = tasks[id]
      tasks[id] = task
    }

    oldTask?.cancel()
  }

  private func _run<Event: Codable>(
    for stream: FlutterEventStream<Event>,
    name: String
  ) async throws {
    do {
      for try await event in stream {
        let envelope = FlutterEnvelope.success(event)
        try await binaryMessenger.send(
          on: name,
          message: codec.encode(envelope)
        )
        try Task.checkCancellation()
      }
      try await binaryMessenger.send(on: name, message: nil)
    } catch let error as FlutterError {
      let envelope = FlutterEnvelope<Event>.failure(error)
      try await binaryMessenger.send(on: name, message: codec.encode(envelope))
    } catch is CancellationError {
      try await binaryMessenger.send(on: name, message: nil)
    } catch {
      throw FlutterSwiftError.invalidEventError
    }
  }

  private func onMethod<Event: Codable, Arguments: Codable & Sendable>(
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
      let stream = try await onListen(call.arguments)
      let task = EventStreamTask(priority: priority) {
        try? await self._run(for: stream, name: name)
        self._removeTask(invocationID)
      }
      _addTask(invocationID, task)
      envelope = FlutterEnvelope.success(nil)
    case "cancel":
      do {
        try await onCancel?(call.arguments)
        envelope = FlutterEnvelope.success(nil)
      } catch let error as FlutterError {
        envelope = FlutterEnvelope.failure(error)
      }
      _cancelTask(invocationID)
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
  public func setStreamHandler<Event: Codable, Arguments: Codable & Sendable>(
    onListen: (@Sendable (Arguments?) async throws -> FlutterEventStream<Event>)?,
    onCancel: (@Sendable (Arguments?) async throws -> ())?
  ) async throws {
    try await setMessageHandler(onListen) { [weak self] unwrappedHandler in
      { [weak self] message in
        guard let self else {
          throw FlutterSwiftError.messengerNotAvailable
        }
        guard let message else {
          throw FlutterSwiftError.methodNotImplemented
        }

        let call: FlutterMethodCall<Arguments> = try codec.decode(message)
        let envelope: FlutterEnvelope<Arguments>? = try await onMethod(
          call: call,
          onListen: unwrappedHandler,
          onCancel: onCancel
        )
        guard let envelope else { return nil }
        return try codec.encode(envelope)
      }
    }
  }

  @_spi(FlutterSwiftPrivate)
  public var tasksCount: Int {
    tasks.withCriticalRegion { $0.count }
  }
}
