// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation

/**
 * An event sink callback.
 *
 * @param event The event.
 */
public typealias FlutterEventSink<Event: Codable> = (Result<Event?, Error>) throws -> ()

/**
 * A strategy for exposing an event stream to the Flutter side.
 */
public protocol FlutterStreamHandler {
    associatedtype Arguments: Codable
    associatedtype Event: Codable

    /**
     * Sets up an event stream and begin emitting events.
     *
     * Invoked when the first listener is registered with the Stream associated to
     * this channel on the Flutter side.
     *
     * @param arguments Arguments for the stream.
     * @param events A callback to asynchronously emit events. Invoke the
     *     callback with a `FlutterError` to emit an error event. Invoke the
     *     callback with `FlutterEndOfEventStream` to indicate that no more
     *     events will be emitted. Any other value, including `nil` are emitted as
     *     successful events.
     * @return A FlutterError instance, if setup fails.
     */
    func onListen(
        with arguments: Arguments?,
        eventSink: FlutterEventSink<Event>
    ) throws

    /**
     * Tears down an event stream.
     *
     * Invoked when the last listener is deregistered from the Stream associated to
     * this channel on the Flutter side.
     *
     * The channel implementation may call this method with `nil` arguments
     * to separate a pair of two consecutive set up requests. Such request pairs
     * may occur during Flutter hot restart.
     *
     * @param arguments Arguments for the stream.
     * @return A FlutterError instance, if teardown fails.
     */
    func onCancel(with arguments: Arguments?) throws
}

/**
 * A channel for communicating with the Flutter side using event streams.
 */
public actor FlutterEventChannel: FlutterChannel {
    let name: String
    let binaryMessenger: FlutterBinaryMessenger
    let codec: FlutterMessageCodec
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

    private func onMethod<Result: Codable, Handler: FlutterStreamHandler>(
        call: FlutterMethodCall<Handler.Arguments>,
        handler: Handler
    ) throws -> FlutterEnvelope<Result>? {
        let envelope: FlutterEnvelope<Result>?
        var currentSink: FlutterEventSink<Handler.Event>?

        switch call.method {
        case "listen":
            if currentSink != nil {
                try handler.onCancel(with: nil)
            }
            currentSink = { [self] event in
                switch event {
                case let .success(success):
                    let envelope = FlutterEnvelope<Handler.Event>.success(success)
                    try binaryMessenger.send(on: name, message: try codec.encode(envelope))
                case let .failure(error):
                    if let error = error as? FlutterSwiftError, error == .endOfEventStream {
                        try binaryMessenger.send(on: name, message: nil)
                    } else if let error = error as? FlutterError {
                        let envelope = FlutterEnvelope<Result>.failure(error)
                        try binaryMessenger.send(on: name, message: try codec.encode(envelope))
                    } else {
                        throw FlutterSwiftError.invalidEvent
                    }
                }
            }
            do {
                try handler.onListen(
                    with: call.arguments,
                    eventSink: currentSink!
                )
                envelope = .success(nil)
            } catch let error as FlutterError {
                envelope = .failure(error)
            }
        case "cancel":
            if currentSink == nil {
                envelope = .failure(FlutterError(
                    code: "error",
                    message: "No active stream to cancel",
                    details: nil
                ))
            } else {
                currentSink = nil
                do {
                    try handler.onCancel(with: call.arguments)
                    envelope = .success(nil)
                } catch let error as FlutterError {
                    envelope = .failure(error)
                }
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
    public func setStreamHandler<Handler: FlutterStreamHandler>(_ handler: Handler?) async throws {
        try await setMessageHandler(handler) { [self] unwrappedHandler in
            { [self] message in
                guard let message else {
                    throw FlutterSwiftError.methodNotImplemented
                }

                let call: FlutterMethodCall<Handler.Arguments> = try self.codec.decode(message)
                let envelope: FlutterEnvelope<Handler.Arguments>? = try onMethod(
                    call: call,
                    handler: unwrappedHandler
                )
                guard let envelope else { return nil }
                return try codec.encode(envelope)
            }
        }
    }
}
