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
}

protocol _FlutterBinaryMessengerConnectionRepresentable: FlutterChannel {
  var connection: FlutterBinaryMessengerConnection { get set }
}

private let kControlChannelName = "dev.flutter/channel-buffers"

@FlutterPlatformThreadActor
private func _controlChannelBuffers(
  binaryMessenger: FlutterBinaryMessenger,
  on channel: String,
  method: String,
  _ arg: AnyFlutterStandardCodable
) throws {
  let codec = FlutterStandardMessageCodec.shared
  let arguments: [AnyFlutterStandardCodable] = [AnyFlutterStandardCodable.string(channel), arg]
  let methodCall = FlutterMethodCall<[AnyFlutterStandardCodable]>(
    method: method,
    arguments: arguments
  )
  try binaryMessenger.send(
    on: kControlChannelName,
    message: codec.encode(methodCall)
  )
}

@FlutterPlatformThreadActor
func _resizeChannelBuffer(
  binaryMessenger: FlutterBinaryMessenger,
  on channel: String,
  newSize: Int
) throws {
  try _controlChannelBuffers(
    binaryMessenger: binaryMessenger,
    on: channel,
    method: "resize",
    AnyFlutterStandardCodable.int32(Int32(newSize))
  )
}

@FlutterPlatformThreadActor
func _allowChannelBufferOverflow(
  binaryMessenger: FlutterBinaryMessenger,
  on channel: String,
  allowed: Bool
) throws {
  try _controlChannelBuffers(
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
  @FlutterPlatformThreadActor
  public func resizeChannelBuffer(_ newSize: Int) throws {
    try _resizeChannelBuffer(binaryMessenger: binaryMessenger, on: name, newSize: newSize)
  }

  @FlutterPlatformThreadActor
  public func allowChannelBufferOverflow(_ allowed: Bool) throws {
    try _allowChannelBufferOverflow(
      binaryMessenger: binaryMessenger,
      on: name,
      allowed: allowed
    )
  }
}

@FlutterPlatformThreadActor
private func _removeMessageHandler(
  connection: FlutterBinaryMessengerConnection,
  binaryMessenger: FlutterBinaryMessenger
) {
  // Only tear down our own registration: connection IDs are positive, so 0
  // means there is nothing of ours to remove. Clearing by name would take the
  // channel from whoever holds it now — deinit schedules this on a Task, by
  // which time a newer channel of the same name may have registered.
  guard connection > 0 else { return }
  try? binaryMessenger.cleanUp(connection: connection)
}

/// `deinit` hook: schedules teardown on the platform actor, but only when there
/// is a registration to tear down. Send-only channels never register a handler,
/// so they would otherwise pay for a `Task` that does nothing.
///
/// Each name in `closing` is sent an end-of-stream first, while the handler is
/// still registered: the message is then delivered to whoever is listening
/// rather than left buffered against a name we are about to stop owning.
///
/// Known hazard: those sends are by name and run on a Task `deinit` cannot
/// await, so a channel registering the same name inside that window is handed
/// the end-of-stream. Closing it needs a connection-scoped send; retiring
/// streams via `setStreamHandler(nil)` runs synchronously and avoids the window.
func _scheduleRemoveMessageHandler(
  connection: FlutterBinaryMessengerConnection,
  binaryMessenger: FlutterBinaryMessenger,
  closing names: [String] = []
) {
  guard connection > 0 else { return }
  Task { @FlutterPlatformThreadActor in
    for name in names {
      try? binaryMessenger.send(on: name, message: nil)
    }
    _removeMessageHandler(connection: connection, binaryMessenger: binaryMessenger)
  }
}

extension _FlutterBinaryMessengerConnectionRepresentable {
  @FlutterPlatformThreadActor
  func removeMessageHandler() {
    _removeMessageHandler(connection: connection, binaryMessenger: binaryMessenger)
    connection = 0
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
      removeMessageHandler()
      return
    }
    connection = try binaryMessenger.setMessageHandler(
      on: name,
      handler: block(unwrappedHandler),
      priority: priority
    )
  }
}
