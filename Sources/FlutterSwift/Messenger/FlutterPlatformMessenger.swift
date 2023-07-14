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
    private let wrapped = (
        NSApplication.shared.mainWindow!.contentViewController as! FlutterMacOS
            .FlutterViewController
    )

    private var binaryMessenger: FlutterMacOS.FlutterBinaryMessenger {
        wrapped.engine.binaryMessenger
    }

    public func setMessageHandler(
        on channel: String,
        handler: FlutterBinaryMessageHandler?,
        priority: TaskPriority?
    ) async -> FlutterBinaryMessengerConnection {
        guard let handler else {
            return binaryMessenger.setMessageHandlerOnChannel(channel, binaryMessageHandler: nil)
        }
        return binaryMessenger.setMessageHandlerOnChannel(channel) { message, callback in
            Task(priority: priority) { @MainActor in
                callback(try await handler(message!))
            }
        }
    }

    public func send(on channel: String, message: Data?) {
        binaryMessenger.send(onChannel: channel, message: message)
    }

    public func send(
        on channel: String,
        message: Data?,
        priority: TaskPriority?
    ) async throws -> Data? {
        let asyncChannel = AsyncChannel<Data?>()

        binaryMessenger.send(onChannel: channel, message: message) { reply in
            Task(priority: priority) {
                await asyncChannel.send(reply)
                asyncChannel.finish()
            }
        }
        var iterator = asyncChannel.makeAsyncIterator()
        return await iterator.next()!
    }

    public func cleanUp(connection: FlutterBinaryMessengerConnection) {
        binaryMessenger.cleanUpConnection(connection)
    }
}
#endif
