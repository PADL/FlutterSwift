// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation

/**
 * A facility for communicating with the Flutter side using asynchronous message
 * passing with binary messages.
 *
 * Implemented by:
 * - `FlutterBasicMessageChannel`, which supports communication using structured
 * messages.
 * - `FlutterMethodChannel`, which supports communication using asynchronous
 * method calls.
 * - `FlutterEventChannel`, which supports commuication using event streams.
 */
protocol FlutterChannel: AnyObject, Hashable, Equatable {
  var name: String { get }
  var binaryMessenger: FlutterBinaryMessenger { get }
  var codec: FlutterMessageCodec { get }
  var priority: TaskPriority? { get }
  var connection: FlutterBinaryMessengerConnection { get set }
}

private let kFlutterChannelBuffersChannel = "dev.flutter/channel-buffers"

extension FlutterChannel {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.name == rhs.name
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(name)
  }

  @MainActor
  func removeMessageHandler() async throws {
    if connection > 0 {
      try await binaryMessenger.cleanUp(connection: connection)
      connection = 0
    } else {
      _ = try await binaryMessenger.setMessageHandler(
        on: name,
        handler: nil,
        priority: priority
      )
    }
  }

  @MainActor
  func setMessageHandler<Handler>(
    _ optionalHandler: Handler?,
    _ block: @Sendable (Handler) -> FlutterBinaryMessageHandler
  ) async throws {
    guard let unwrappedHandler = optionalHandler else {
      try await removeMessageHandler()
      return
    }
    connection = try await binaryMessenger.setMessageHandler(
      on: name,
      handler: block(unwrappedHandler),
      priority: priority
    )
  }

  public func resizeChannelBuffer(_ newSize: Int) async throws {
    let messageString = "resize\r\(name)\r\(newSize)"
    let message = messageString.data(using: .utf8)!
    try await binaryMessenger.send(on: kFlutterChannelBuffersChannel, message: message)
  }
}
