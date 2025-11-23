//
// Copyright (c) 2023-2025 PADL Software Pty Ltd
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

  func resizeChannelBuffer(_ newSize: Int) async throws
  func allowChannelBufferOverflow(_ allowed: Bool) async throws
}

protocol _FlutterBinaryMessengerConnectionRepresentable: FlutterChannel {
  var connection: FlutterBinaryMessengerConnection { get set }
}

private let kControlChannelName = "dev.flutter/channel-buffers"

private func _controlChannelBuffers(
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
    on: kControlChannelName,
    message: codec.encode(methodCall)
  )
}

func _resizeChannelBuffer(
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

func _allowChannelBufferOverflow(
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

public extension FlutterChannel {
  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.name == rhs.name
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(name)
  }
}

protocol _FlutterChannelDefaultBufferControl: FlutterChannel {}

extension _FlutterChannelDefaultBufferControl {
  public func resizeChannelBuffer(_ newSize: Int) async throws {
    try await _resizeChannelBuffer(binaryMessenger: binaryMessenger, on: name, newSize: newSize)
  }

  public func allowChannelBufferOverflow(_ allowed: Bool) async throws {
    try await _allowChannelBufferOverflow(
      binaryMessenger: binaryMessenger,
      on: name,
      allowed: allowed
    )
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
  @FlutterPlatformThreadActor
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
