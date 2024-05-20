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

/**
 * A channel for communicating with the Flutter side using basic, asynchronous
 * message passing.
 */
public final class FlutterBasicMessageChannel: _FlutterBinaryMessengerConnectionRepresentable,
  Sendable
{
  public let name: String
  public let binaryMessenger: FlutterBinaryMessenger
  public let codec: FlutterMessageCodec
  public let priority: TaskPriority?

  private struct State {
    var connection: FlutterBinaryMessengerConnection = 0
  }

  private let state: ManagedCriticalState<State>

  var connection: FlutterBinaryMessengerConnection {
    get {
      state.withCriticalRegion { state in
        state.connection
      }
    }
    set {
      state.withCriticalRegion { state in
        state.connection = newValue
      }
    }
  }

  public init(
    name: String,
    binaryMessenger: FlutterBinaryMessenger,
    codec: FlutterMessageCodec = FlutterStandardMessageCodec.shared,
    priority: TaskPriority? = nil
  ) {
    state = ManagedCriticalState(State())
    self.name = name
    self.binaryMessenger = binaryMessenger
    self.codec = codec
    self.priority = priority
  }

  deinit {
    Task {
      try? await removeMessageHandler()
    }
  }

  public func send<Message: Encodable>(message: Message) async throws {
    try await binaryMessenger.send(on: name, message: codec.encode(message))
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
    try await setMessageHandler(handler) { [self] unwrappedHandler in
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
}
