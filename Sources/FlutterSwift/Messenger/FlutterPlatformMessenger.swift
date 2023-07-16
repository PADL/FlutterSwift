// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#if canImport(Flutter) || canImport(FlutterMacOS)
import AppKit
import AsyncAlgorithms
#if canImport(Flutter)
import Flutter
#elseif canImport(FlutterMacOS)
import FlutterMacOS
#endif

public final class FlutterPlatformMessenger: FlutterBinaryMessenger {
    #if canImport(Flutter)
    public typealias PlatformFlutterBinaryMessenger = Flutter.FlutterBinaryMessenger
    #elseif canImport(FlutterMacOS)
    public typealias PlatformFlutterBinaryMessenger = FlutterMacOS.FlutterBinaryMessenger
    #endif

    private let platformBinaryMessenger: FlutterMacOS.FlutterBinaryMessenger

    public init(wrapping platformBinaryMessenger: PlatformFlutterBinaryMessenger) {
        self.platformBinaryMessenger = platformBinaryMessenger
    }

    public func setMessageHandler(
        on channel: String,
        handler: FlutterBinaryMessageHandler?,
        priority: TaskPriority?
    ) -> FlutterBinaryMessengerConnection {
        guard let handler else {
            return platformBinaryMessenger.setMessageHandlerOnChannel(
                channel,
                binaryMessageHandler: nil
            )
        }
        return platformBinaryMessenger.setMessageHandlerOnChannel(channel) { message, callback in
            Task(priority: priority) { @MainActor in
                callback(try await handler(message!))
            }
        }
    }

    public func send(on channel: String, message: Data?) {
        platformBinaryMessenger.send(onChannel: channel, message: message)
    }

    public func send(
        on channel: String,
        message: Data?,
        priority: TaskPriority?
    ) async throws -> Data? {
        let asyncChannel = AsyncChannel<Data?>()

        platformBinaryMessenger.send(onChannel: channel, message: message) { reply in
            Task(priority: priority) {
                await asyncChannel.send(reply)
                asyncChannel.finish()
            }
        }
        var iterator = asyncChannel.makeAsyncIterator()
        return await iterator.next()!
    }

    public func cleanUp(connection: FlutterBinaryMessengerConnection) {
        platformBinaryMessenger.cleanUpConnection(connection)
    }
}
#endif
