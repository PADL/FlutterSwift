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

#if canImport(Android)
import AndroidLooper
#endif
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

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
  private static func _controlChannelBuffers(
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
    try await _controlChannelBuffers(
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
    try await _controlChannelBuffers(
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
  func removeMessageHandler() throws {
    if connection > 0 {
      try? binaryMessenger.cleanUp(connection: connection)
      connection = 0
    } else {
      _ = try? binaryMessenger.setMessageHandler(
        on: name,
        handler: nil,
        priority: priority
      )
    }
  }

  /// helper function to set the message handler for a channel.
  /// `optionalHandler` is the handler function; if `nil`, then the message
  /// handler will be removed (as if `removeMessageHandler()` was called`.
  /// Otherwise, `block` is called to wrap the handler into a
  /// `FlutterBinaryMessageHandler`.
  #if canImport(Android)
  @UIThreadActor
  #else
  @MainActor
  #endif
  func setMessageHandler<Handler>(
    _ optionalHandler: Handler?,
    _ block: @Sendable (Handler) -> FlutterBinaryMessageHandler
  ) throws {
    guard let unwrappedHandler = optionalHandler else {
      try removeMessageHandler()
      return
    }
    connection = try binaryMessenger.setMessageHandler(
      on: name,
      handler: block(unwrappedHandler),
      priority: priority
    )
  }
}
