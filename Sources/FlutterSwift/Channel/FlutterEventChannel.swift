// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import AsyncAlgorithms
import Foundation

/**
 * An asynchronous event stream.
 */
public typealias FlutterEventStream<Event: Codable> = AsyncThrowingChannel<Event?, Error>

/**
 * A channel for communicating with the Flutter side using event streams.
 */
public actor FlutterEventChannel: FlutterChannel {
    let name: String
    let binaryMessenger: FlutterBinaryMessenger
    let codec: FlutterMessageCodec
    var task: Task<(), Error>?
    let priority: TaskPriority?
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
    }

    private func withOptionalCallback<Arguments: Codable>(
        arguments: Arguments?,
        callback: ((Arguments?) throws -> ())?
    )
        throws -> FlutterEnvelope<Arguments>?
    {
        let envelope: FlutterEnvelope<Arguments>?

        if let callback {
            do {
                try callback(arguments)
                envelope = .success(nil)
            } catch let error as FlutterError {
                envelope = .failure(error)
            }
        } else {
            envelope = .success(nil)
        }

        return envelope
    }

    private func onMethod<Event: Codable, Arguments: Codable>(
        call: FlutterMethodCall<Arguments>,
        stream: FlutterEventStream<Event>,
        onListen: ((Arguments?) throws -> ())?,
        onCancel: ((Arguments?) throws -> ())?
    ) throws -> FlutterEnvelope<Arguments>? {
        let envelope: FlutterEnvelope<Arguments>?

        switch call.method {
        case "listen":
            if let task {
                task.cancel()
                self.task = nil
            }
            envelope = try withOptionalCallback(arguments: call.arguments, callback: onListen)
            task = Task<(), Error>(priority: priority) { @MainActor in
                do {
                    for try await event in stream {
                        let envelope = FlutterEnvelope.success(event)
                        try binaryMessenger.send(on: name, message: try codec.encode(envelope))
                        try Task.checkCancellation()
                    }
                    try binaryMessenger.send(on: name, message: nil)
                } catch let error as FlutterError {
                    let envelope = FlutterEnvelope<Event>.failure(error)
                    try binaryMessenger.send(on: name, message: try codec.encode(envelope))
                } catch is CancellationError {
                    // FIXME: send finish even when task cancelled?
                } catch {
                    throw FlutterSwiftError.invalidEventError
                }
            }
        case "cancel":
            if let task {
                task.cancel()
                self.task = nil
            }
            envelope = try withOptionalCallback(arguments: call.arguments, callback: onCancel)
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
    public func setEventStream<Event: Codable, Arguments: Codable>(
        _ stream: FlutterEventStream<Event>?,
        onListen: ((Arguments?) throws -> ())? = nil,
        onCancel: ((Arguments?) throws -> ())? = nil
    ) async throws {
        try await setMessageHandler(stream) { [self] unwrappedStream in
            { [self] message in
                guard let message else {
                    throw FlutterSwiftError.methodNotImplemented
                }

                let call: FlutterMethodCall<Arguments> = try self.codec.decode(message)
                let envelope: FlutterEnvelope<Arguments>? = try onMethod(
                    call: call,
                    stream: unwrappedStream,
                    onListen: onListen,
                    onCancel: onCancel
                )
                guard let envelope else { return nil }
                return try codec.encode(envelope)
            }
        }
    }
}

public struct FlutterEmptyArguments: Codable, Equatable {}
