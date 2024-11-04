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

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/**
 * A strategy for handling incoming binary messages from Flutter and to send
 * asynchronous replies back to Flutter.
 *
 * @param message The message.
 * @result reply A callback for submitting an asynchronous reply to the sender.
 */
public typealias FlutterBinaryMessageHandler = (Data?) async throws -> Data?

public typealias FlutterBinaryMessengerConnection = Int64

public protocol FlutterBinaryMessenger: Sendable {
  func send(on channel: String, message: Data?) async throws
  func send(on channel: String, message: Data?, priority: TaskPriority?) async throws -> Data?

  func setMessageHandler(
    on channel: String,
    handler: FlutterBinaryMessageHandler?,
    priority: TaskPriority?
  ) throws -> FlutterBinaryMessengerConnection

  func cleanUp(connection: FlutterBinaryMessengerConnection) throws
}

extension FlutterBinaryMessenger {
  func withPriority<Value: Sendable>(
    _ priority: TaskPriority?,
    _ block: @Sendable @escaping () async throws -> Value
  ) async throws -> Value {
    try await Task<Value, Error>(priority: priority) {
      try await block()
    }.value
  }
}
