// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import AnyCodable
import Foundation

/**
 * A strategy for handling incoming messages from Flutter and to send
 * asynchronous replies back to Flutter.
 *
 * @param message The message.
 */
public typealias FlutterMessageHandler = (any Decodable) async -> any Encodable

private let kFlutterChannelBuffersChannel = "dev.flutter/channel-buffers"

/**
 * A channel for communicating with the Flutter side using basic, asynchronous
 * message passing.
 */
public actor FlutterBasicMessageChannel: FlutterChannel {
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

    func send<Message: Encodable>(message: Message) throws {
        try messenger.send(on: name, message: codec.encode(message))
    }

    func send<Message: Encodable, Reply: Decodable>(
        message: Message,
        reply type: Reply.Type
    ) async throws -> Reply? {
        let reply = try await messenger.send(
            on: name,
            message: codec.encode(message),
            priority: priority
        )
        guard let reply else { return nil }
        return try codec.decode(reply)
    }

    func setMessageHandler(handler: FlutterMessageHandler?) async throws {
        try await setMessageHandler(handler) { [self] unwrappedHandler in
            { message in
                let decoded: AnyDecodable
                if let message {
                    decoded = try self.codec.decode(message)
                } else {
                    decoded = AnyDecodable(())
                }
                let reply = await unwrappedHandler(decoded)
                return try self.codec.encode(AnyCodable(reply))
            }
        }
    }

    func resizeChannelBuffer(_ newSize: Int) throws {
        let messageString = "resize\r\(name)\r\(newSize)"
        let message = messageString.data(using: .utf8)!
        try messenger.send(on: kFlutterChannelBuffersChannel, message: message)
    }
}
