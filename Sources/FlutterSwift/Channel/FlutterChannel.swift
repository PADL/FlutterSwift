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
public protocol FlutterChannel: AnyObject, Hashable, Equatable {
  var name: String { get }
  var binaryMessenger: FlutterBinaryMessenger { get }
  var codec: FlutterMessageCodec { get }
  var priority: TaskPriority? { get }
}

protocol _FlutterBinaryMessengerConnectionRepresentable: FlutterChannel {
  var connection: FlutterBinaryMessengerConnection { get set }
}

private let kFlutterChannelBuffersChannel = "dev.flutter/channel-buffers"

public extension FlutterChannel {
  private static func resizeChannelBuffer(
    binaryMessenger: FlutterBinaryMessenger,
    on channel: String,
    method: String,
    _ arg: AnyFlutterStandardCodable
  ) async throws {
    let codec = FlutterStandardMessageCodec.shared
    let arguments: [AnyFlutterStandardCodable] = [AnyFlutterStandardCodable.string(channel), arg]
    let methodCall = FlutterMethodCall<[AnyFlutterStandardCodable]>(
      method: method,
      arguments: arguments
    )
    try await binaryMessenger.send(
      on: kFlutterChannelBuffersChannel,
      message: codec.encode(methodCall)
    )
  }

  private static func resizeChannelBuffer(
    binaryMessenger: FlutterBinaryMessenger,
    on channel: String,
    newSize: Int
  ) async throws {
    try await resizeChannelBuffer(
      binaryMessenger: binaryMessenger,
      on: channel,
      method: "resize",
      AnyFlutterStandardCodable.int32(Int32(newSize))
    )
  }

  func resizeChannelBuffer(_ newSize: Int) async throws {
    try await Self.resizeChannelBuffer(binaryMessenger: binaryMessenger, on: name, newSize: newSize)
  }

  private static func allowChannelBufferOverflow(
    binaryMessenger: FlutterBinaryMessenger,
    on channel: String,
    allowed: Bool
  ) async throws {
    try await resizeChannelBuffer(
      binaryMessenger: binaryMessenger,
      on: channel,
      method: "overflow",
      allowed ? AnyFlutterStandardCodable.true : AnyFlutterStandardCodable.false
    )
  }

  func allowChannelBufferOverflow(_ allowed: Bool) async throws {
    try await Self.allowChannelBufferOverflow(
      binaryMessenger: binaryMessenger,
      on: name,
      allowed: allowed
    )
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.name == rhs.name
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(name)
  }
}

extension _FlutterBinaryMessengerConnectionRepresentable {
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
}
