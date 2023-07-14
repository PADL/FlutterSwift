// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import AnyCodable
import Foundation

/**
 * A strategy for handling method calls.
 *
 * @param call The incoming method call.
 * @param result A callback to asynchronously submit the result of the call.
 *     Invoke the callback with a `FlutterError` to indicate that the call failed.
 *     Invoke the callback with `FlutterMethodNotImplemented` to indicate that the
 *     method was unknown. Any other values, including `nil`, are interpreted as
 *     successful results.  This can be invoked from any thread.
 */
public typealias FlutterMethodCallHandler = (FlutterMethodCall) async throws -> (any Codable)?

/**
 * Creates a method call for invoking the specified named method with the
 * specified arguments.
 *
 * @param method the name of the method to call.
 * @param arguments the arguments value.
 */
public struct FlutterMethodCall: Codable {
    let method: String
    let arguments: AnyCodable
}

/**
 * A channel for communicating with the Flutter side using invocation of
 * asynchronous methods.
 */
public actor FlutterMethodChannel: FlutterChannel {
    let name: String
    let messenger: FlutterBinaryMessenger
    let codec: FlutterMessageCodec
    let priority: TaskPriority?
    var connection: FlutterBinaryMessengerConnection = 0

    init(
        name: String,
        messenger: FlutterBinaryMessenger,
        codec: FlutterMessageCodec = FlutterStandardMessageCodec.shared,
        priority: TaskPriority? = nil
    ) {
        self.name = name
        self.messenger = messenger
        self.codec = codec
        self.priority = priority
    }

    func invoke(method: String, arguments: Any?) throws {
        let methodCall = FlutterMethodCall(method: method, arguments: AnyCodable(arguments))
        try messenger.send(on: name, message: codec.encode(methodCall))
    }

    func invoke(method: String, arguments: Any?) async throws -> Any? {
        let methodCall = FlutterMethodCall(method: method, arguments: AnyCodable(arguments))
        let reply = try await messenger.send(
            on: name,
            message: codec.encode(methodCall),
            priority: priority
        )
        guard let reply else { throw FlutterChannelError.methodNotImplemented }
        let envelope: FlutterEnvelope = try codec.decode(reply)
        switch envelope {
        case let .success(value):
            return value.value
        case let .error(error):
            throw error
        }
    }

    func setMethodCallHandler(handler: FlutterMethodCallHandler?) async throws {
        try await setMessageHandler(handler) { [self] unwrappedHandler in
            { message in
                guard let message else {
                    // FIXME: should we return an error here
                    throw FlutterChannelError.methodNotImplemented
                }
                let call: FlutterMethodCall = try self.codec.decode(message)
                let envelope: FlutterEnvelope
                do {
                    envelope =
                        .success(AnyCodable(try await unwrappedHandler(call)))
                } catch let error as FlutterError {
                    envelope = .error(error)
                }
                return try self.codec.encode(envelope)
            }
        }
    }
}
