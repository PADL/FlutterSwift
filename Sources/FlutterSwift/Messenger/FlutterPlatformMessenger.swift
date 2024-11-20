//
// Copyright (c) 2023-2024 PADL Software Pty Ltd
//
// Licensed under the Apache License, Version 2.0 (the License);
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an 'AS IS' BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#if canImport(Flutter) || canImport(FlutterMacOS) || canImport(FlutterAndroid)
import AsyncAlgorithms
#if canImport(Flutter)
import Flutter
import UIKit
#elseif canImport(FlutterMacOS)
import AppKit
import FlutterMacOS
#elseif canImport(Android) || canImport(FlutterAndroid)
import AndroidLooper
import FlutterAndroid
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
#endif

public final class FlutterPlatformMessenger: FlutterBinaryMessenger {
  #if canImport(Flutter)
  public typealias PlatformFlutterBinaryMessenger = Flutter.FlutterBinaryMessenger
  public typealias PlatformFlutterBinaryMessageHandler = Flutter.FlutterBinaryMessageHandler
  #elseif canImport(FlutterMacOS)
  public typealias PlatformFlutterBinaryMessenger = FlutterMacOS.FlutterBinaryMessenger
  public typealias PlatformFlutterBinaryMessageHandler = FlutterMacOS.FlutterBinaryMessageHandler
  #elseif canImport(Android)
  public typealias PlatformFlutterBinaryMessenger = FlutterAndroid.FlutterBinaryMessenger
  public typealias PlatformFlutterBinaryMessageHandler = FlutterAndroid.FlutterBinaryMessageHandler
  #endif

  private let _wrappedMessenger: PlatformFlutterBinaryMessenger

  // MARK: - Initializers

  public init(wrapping _wrappedMessenger: PlatformFlutterBinaryMessenger) {
    self._wrappedMessenger = _wrappedMessenger
  }

  // MARK: - FlutterDesktopMessenger wrappers

  private func _setMessageHandler(
    on channel: String,
    _ binaryMessageHandler: PlatformFlutterBinaryMessageHandler?
  ) -> FlutterBinaryMessengerConnection {
    #if !canImport(Android)
    precondition(Thread.isMainThread)
    #endif
    return _wrappedMessenger.setMessageHandlerOnChannel(
      channel,
      binaryMessageHandler: binaryMessageHandler
    )
  }

  private func _cleanUp(connection: FlutterBinaryMessengerConnection) {
    #if !canImport(Android)
    precondition(Thread.isMainThread)
    #endif
    _wrappedMessenger.cleanUpConnection(connection)
  }

  public func _send(
    on channel: String,
    message: Data?,
    _ binaryReply: FlutterBinaryReply?
  ) {
    #if canImport(Android)
    Task { @UIThreadActor [weak self] in
      self?._wrappedMessenger.send(
        onChannel: channel,
        message: message,
        binaryReply: binaryReply
      )
    }
    #else
    Task { @MainActor [weak self] in
      self?._wrappedMessenger.send(
        onChannel: channel,
        message: message,
        binaryReply: binaryReply
      )
    }
    #endif
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
