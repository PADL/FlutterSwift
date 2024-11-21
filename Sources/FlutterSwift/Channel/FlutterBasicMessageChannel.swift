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

import Atomics
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

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

  private let _connection: ManagedAtomic<FlutterBinaryMessengerConnection>

  var connection: FlutterBinaryMessengerConnection {
    get {
      _connection.load(ordering: .acquiring)
    }
    set {
      _connection.store(newValue, ordering: .releasing)
    }
  }

  public init(
    name: String,
    binaryMessenger: FlutterBinaryMessenger,
    codec: FlutterMessageCodec = FlutterStandardMessageCodec.shared,
    priority: TaskPriority? = nil
  ) {
    _connection = ManagedAtomic(0)
    self.name = name
    self.binaryMessenger = binaryMessenger
    self.codec = codec
    self.priority = priority
  }

  deinit {
    try? removeMessageHandler()
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
    try await setMessageHandler(handler) { [weak self] unwrappedHandler in
      { message in
        let decoded: Message?

        guard let self else {
          throw FlutterSwiftError.messengerNotAvailable
        }

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
