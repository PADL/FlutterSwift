// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#if canImport(Flutter) || canImport(FlutterMacOS)
import AsyncAlgorithms
#if canImport(Flutter)
import Flutter
import UIKit
#elseif canImport(FlutterMacOS)
import AppKit
import FlutterMacOS
#endif

public final class FlutterPlatformMessenger: FlutterBinaryMessenger {
  #if canImport(Flutter)
  public typealias PlatformFlutterBinaryMessenger = Flutter.FlutterBinaryMessenger
  public typealias PlatformFlutterBinaryMessageHandler = Flutter.FlutterBinaryMessageHandler
  #elseif canImport(FlutterMacOS)
  public typealias PlatformFlutterBinaryMessenger = FlutterMacOS.FlutterBinaryMessenger
  public typealias PlatformFlutterBinaryMessageHandler = FlutterMacOS.FlutterBinaryMessageHandler
  #endif

  private let platformBinaryMessenger: PlatformFlutterBinaryMessenger

  // MARK: - Initializers

  public init(wrapping platformBinaryMessenger: PlatformFlutterBinaryMessenger) {
    self.platformBinaryMessenger = platformBinaryMessenger
  }

  // MARK: - FlutterDesktopMessenger wrappers

  private func _setMessageHandler(
    on channel: String,
    _ binaryMessageHandler: PlatformFlutterBinaryMessageHandler?
  ) -> FlutterBinaryMessengerConnection {
    precondition(Thread.isMainThread)
    return platformBinaryMessenger.setMessageHandlerOnChannel(
      channel,
      binaryMessageHandler: binaryMessageHandler
    )
  }

  private func _cleanUp(connection: FlutterBinaryMessengerConnection) {
    precondition(Thread.isMainThread)
    platformBinaryMessenger.cleanUpConnection(connection)
  }

  public func _send(
    on channel: String,
    message: Data?,
    _ binaryReply: FlutterBinaryReply?
  ) {
    DispatchQueue.main.async { [self] in
      platformBinaryMessenger.send(
        onChannel: channel,
        message: message,
        binaryReply: binaryReply
      )
    }
  }

  // MARK: - public API

  public func send(on channel: String, message: Data?) async throws {
    _send(on: channel, message: message, nil)
  }

  public func send(
    on channel: String,
    message: Data?,
    priority: TaskPriority?
  ) async throws -> Data? {
    try await withPriority(priority) {
      await withCheckedContinuation { continuation in
        self._send(on: channel, message: message) { binaryReply in
          continuation.resume(returning: binaryReply)
        }
      }
    }
  }

  public func setMessageHandler(
    on channel: String,
    handler: FlutterBinaryMessageHandler?,
    priority: TaskPriority?
  ) throws -> FlutterBinaryMessengerConnection {
    guard let handler else {
      return _setMessageHandler(on: channel, nil)
    }
    return _setMessageHandler(on: channel) { message, callback in
      Task {
        let response = try await handler(message)
        callback(response)
      }
    }
  }

  public func cleanUp(connection: FlutterBinaryMessengerConnection) throws {
    _cleanUp(connection: connection)
  }
}
#endif
