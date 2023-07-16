// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation

/**
 * A strategy for handling incoming messages from Flutter and to send
 * asynchronous replies back to Flutter.
 *
 * @param message The message.
 */
public typealias FlutterMessageHandler<Message: Decodable, Reply: Encodable> = (Message?) async
    -> Reply?

private let kControlChannelName = "dev.flutter/channel-buffers"

/**
 * A channel for communicating with the Flutter side using basic, asynchronous
 * message passing.
 */
public actor FlutterBasicMessageChannel: FlutterChannel {
    let name: String
    let binaryMessenger: FlutterBinaryMessenger
    let codec: FlutterMessageCodec
    let priority: TaskPriority?
    var connection: FlutterBinaryMessengerConnection = 0

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

    public func send<Message: Encodable>(message: Message) throws {
        try binaryMessenger.send(on: name, message: codec.encode(message))
    }

    public func send<Message: Encodable, Reply: Decodable>(
        message: Message,
        reply type: Reply.Type
    ) async throws -> Reply? {
        let reply = try await binaryMessenger.send(
            on: name,
            message: codec.encode(message),
            priority: priority
        )
        guard let reply else { return nil }
        return try codec.decode(reply)
    }

    public func setMessageHandler<
        Message: Decodable,
        Reply: Encodable
    >(_ handler: FlutterMessageHandler<Message, Reply>?) async throws {
        try setMessageHandler(handler) { [self] unwrappedHandler in
            { message in
                let decoded: Message?

                if let message {
                    decoded = try self.codec.decode(message)
                } else {
                    decoded = nil
                }
                let reply = await unwrappedHandler(decoded)
                return try self.codec.encode(reply)
            }
        }
    }

    public func resizeChannelBuffer(_ newSize: Int) throws {
        let messageString = "resize\r\(name)\r\(newSize)"
        let message = messageString.data(using: .utf8)!
        try binaryMessenger.send(on: kControlChannelName, message: message)
    }
}
