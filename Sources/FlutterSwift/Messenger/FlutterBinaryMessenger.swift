// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation

/**
 * A strategy for handling incoming binary messages from Flutter and to send
 * asynchronous replies back to Flutter.
 *
 * @param message The message.
 * @result reply A callback for submitting an asynchronous reply to the sender.
 */
public typealias FlutterBinaryMessageHandler = (Data?) async throws -> Data?

public typealias FlutterBinaryMessengerConnection = Int64

public protocol FlutterBinaryMessenger: Actor {
  func send(on channel: String, message: Data?) async throws
  func send(on channel: String, message: Data?, priority: TaskPriority?) async throws -> Data?

  func setMessageHandler(
    on channel: String,
    handler: FlutterBinaryMessageHandler?,
    priority: TaskPriority?
  ) async throws -> FlutterBinaryMessengerConnection

  func cleanUp(connection: FlutterBinaryMessengerConnection) async throws
}

extension FlutterBinaryMessenger {
  func withPriority<Value: Sendable>(
    _ priority: TaskPriority?,
    _ block: @escaping () async throws -> Value
  ) async throws -> Value {
    try await Task<Value, Error>(priority: priority) {
      try await block()
    }.value
  }
}
