// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import AsyncAlgorithms
@preconcurrency
import AsyncExtensions
import Foundation

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

  private typealias EventStreamTask = Task<(), Error>

  private struct State {
    var tasks = [String: EventStreamTask]()
    var connection: FlutterBinaryMessengerConnection = 0
  }

  private let state: ManagedCriticalState<State>

  var connection: FlutterBinaryMessengerConnection {
    get {
      state.withCriticalRegion { state in
        state.connection
      }
    }
    set {
      state.withCriticalRegion { state in
        state.connection = newValue
      }
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
    state = ManagedCriticalState(State())
    self.name = name
    self.binaryMessenger = binaryMessenger
    self.codec = codec
    self.priority = priority
  }

  deinit {
    state.withCriticalRegion { state in
      state.tasks.values.forEach { $0.cancel() }
    }
    try? removeMessageHandler()
  }

  private func _removeTask(_ id: String) {
    var task: EventStreamTask?

    state.withCriticalRegion { state in
      task = state.tasks[id]
      state.tasks.removeValue(forKey: id)
    }

    task?.cancel()
  }

  private func _addTask(_ id: String, _ task: EventStreamTask) {
    state.withCriticalRegion { state in
      state.tasks[id] = task
    }
  }

  private func onMethod<Event: Codable, Arguments: Codable & Sendable>(
    call: FlutterMethodCall<Arguments>,
    onListen: @escaping ((Arguments?) async throws -> FlutterEventStream<Event>),
    onCancel: ((Arguments?) async throws -> ())?
  ) async throws -> FlutterEnvelope<Arguments>? {
    let envelope: FlutterEnvelope<Arguments>?
    let method = call.method.split(separator: "#", maxSplits: 2)
    let id: String, name: String

    if method.count > 1 {
      id = String(method[1])
      precondition(!id.isEmpty)
      name = self.name + "#" + id
    } else {
      id = ""
      name = self.name
    }

    switch method.count > 1 ? String(method[0]) : call.method {
    case "listen":
      let stream = try await onListen(call.arguments)
      let task = EventStreamTask(priority: priority) { [self] in
        do {
          for try await event in stream {
            let envelope = FlutterEnvelope.success(event)
            try await binaryMessenger.send(
              on: name,
              message: codec.encode(envelope)
            )
            if Task.isCancelled {
              break
            }
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
      _addTask(id, task)
      envelope = FlutterEnvelope.success(nil)
    case "cancel":
      _removeTask(id)
      do {
        try await onCancel?(call.arguments)
        envelope = FlutterEnvelope.success(nil)
      } catch let error as FlutterError {
        envelope = FlutterEnvelope.failure(error)
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
  public func setStreamHandler<Event: Codable, Arguments: Codable & Sendable>(
    onListen: (@Sendable (Arguments?) async throws -> FlutterEventStream<Event>)?,
    onCancel: (@Sendable (Arguments?) async throws -> ())?
  ) async throws {
    try await setMessageHandler(onListen) { [self] unwrappedHandler in
      { [self] message in
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
}
