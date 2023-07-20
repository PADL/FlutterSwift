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

public actor FlutterPlatformMessenger: FlutterBinaryMessenger {
    #if canImport(Flutter)
    public typealias PlatformFlutterBinaryMessenger = Flutter.FlutterBinaryMessenger
    public typealias PlatformFlutterBinaryMessageHandler = Flutter.FlutterBinaryMessengerHandler
    #elseif canImport(FlutterMacOS)
    public typealias PlatformFlutterBinaryMessenger = FlutterMacOS.FlutterBinaryMessenger
    public typealias PlatformFlutterBinaryMessageHandler = FlutterMacOS.FlutterBinaryMessageHandler
    #endif

    private let platformBinaryMessenger: FlutterMacOS.FlutterBinaryMessenger

    // MARK: - Initializers

    public init(wrapping platformBinaryMessenger: PlatformFlutterBinaryMessenger) {
        self.platformBinaryMessenger = platformBinaryMessenger
    }

    // MARK: - FlutterDesktopMessenger wrappers

    @MainActor
    private func _setMessageHandler(
        on channel: String,
        _ binaryMessageHandler: PlatformFlutterBinaryMessageHandler?
    ) -> FlutterBinaryMessengerConnection {
        platformBinaryMessenger.setMessageHandlerOnChannel(
            channel,
            binaryMessageHandler: binaryMessageHandler
        )
    }

    @MainActor
    private func _cleanup(connection: FlutterBinaryMessengerConnection) {
        platformBinaryMessenger.cleanUpConnection(connection)
    }

    @MainActor
    public func _send(
        on channel: String,
        message: Data?,
        _ binaryReply: FlutterBinaryReply?
    ) {
        platformBinaryMessenger.send(onChannel: channel, message: message, binaryReply: binaryReply)
    }

    // MARK: - public API

    public func send(on channel: String, message: Data?) async throws {
        await _send(on: channel, message: message, nil)
    }

    public func send(
        on channel: String,
        message: Data?,
        priority: TaskPriority?
    ) async throws -> Data? {
        try await withPriority(priority) {
            await withCheckedContinuation { continuation in
                Task {
                    await self._send(on: channel, message: message) { binaryReply in
                        continuation.resume(returning: binaryReply)
                    }
                }
            }
        }
    }

    public func setMessageHandler(
        on channel: String,
        handler: FlutterBinaryMessageHandler?,
        priority: TaskPriority?
    ) async throws -> FlutterBinaryMessengerConnection {
        guard let handler else {
            return await _setMessageHandler(on: channel, nil)
        }
        return await _setMessageHandler(on: channel) { message, callback in
            Task {
                let response = try await handler(message)
                DispatchQueue.main.async {
                    callback(response)
                }
            }
        }
    }

    public func cleanUp(connection: FlutterBinaryMessengerConnection) async throws {
        await _cleanup(connection: connection)
    }
}
#endif
