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
public final class FlutterEventChannel: FlutterChannel, @unchecked Sendable {
    let name: String
    let binaryMessenger: FlutterBinaryMessenger
    let codec: FlutterMessageCodec
    let priority: TaskPriority?
    var task: Task<(), Error>?
    var connection: FlutterBinaryMessengerConnection = 0

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
        self.name = name
        self.binaryMessenger = binaryMessenger
        self.codec = codec
        self.priority = priority
    }

    deinit {
        task?.cancel()
        Task {
            try? await removeMessageHandler()
        }
    }

    private func onMethod<Event: Codable, Arguments: Codable>(
        call: FlutterMethodCall<Arguments>,
        onListen: @escaping ((Arguments?) async throws -> FlutterEventStream<Event>),
        onCancel: ((Arguments?) async throws -> ())?
    ) async throws -> FlutterEnvelope<Arguments>? {
        let envelope: FlutterEnvelope<Arguments>?

        switch call.method {
        case "listen":
            if let task {
                task.cancel()
                self.task = nil
            }
            let stream = try await onListen(call.arguments)
            task = Task<(), Error>(priority: priority) { [self] in
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
                    // FIXME: should we ignore this or send the finish message?
                } catch {
                    throw FlutterSwiftError.invalidEventError
                }
            }
            envelope = FlutterEnvelope.success(nil)
        case "cancel":
            if let task {
                task.cancel()
                self.task = nil
            }
            do {
                if let onCancel {
                    try await onCancel(call.arguments)
                }
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
    public func setStreamHandler<Event: Codable, Arguments: Codable>(
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
