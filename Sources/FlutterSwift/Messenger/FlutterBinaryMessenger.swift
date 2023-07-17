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

/**
 * A facility for communicating with the Flutter side using asynchronous message
 * passing with binary messages.
 *
 * Implementated by:
 * - `FlutterBasicMessageChannel`, which supports communication using structured
 * messages.
 * - `FlutterMethodChannel`, which supports communication using asynchronous
 * method calls.
 * - `FlutterEventChannel`, which supports commuication using event streams.
 */
public protocol FlutterBinaryMessenger {
    func setMessageHandler(
        on channel: String,
        handler: FlutterBinaryMessageHandler?,
        priority: TaskPriority?
    ) throws -> FlutterBinaryMessengerConnection

    func send(on channel: String, message: Data?) throws
    func send(on channel: String, message: Data?, priority: TaskPriority?) async throws -> Data?
    func cleanUp(connection: FlutterBinaryMessengerConnection) throws
}
