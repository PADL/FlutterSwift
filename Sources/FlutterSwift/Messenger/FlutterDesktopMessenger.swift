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

#if os(Linux) && canImport(Glibc)
import Atomics
@_implementationOnly
import CxxFlutterSwift
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public final class FlutterDesktopMessenger: FlutterBinaryMessenger, @unchecked Sendable {
  private let currentMessengerConnection = ManagedAtomic<FlutterBinaryMessengerConnection>(0)
  private let messenger: FlutterDesktopMessengerRef

  // : - Initializers

  init(messenger: FlutterDesktopMessengerRef) {
    self.messenger = messenger
  }

  convenience init(engine: flutter.FlutterELinuxEngine) {
    self.init(messenger: engine.messenger())
  }

  private func withUnsafeMessenger<T>(
    _ block: (_: FlutterDesktopMessengerRef) throws
      -> T
  ) throws -> T {
    guard messenger.GetEngine() != nil else {
      throw FlutterSwiftError.messengerNotAvailable
    }
    return try block(messenger)
  }

  private func withMessenger<T>(
    _ block: (_: FlutterDesktopMessengerRef) throws
      -> T
  ) throws -> T {
    FlutterDesktopMessengerLock(messenger)
    defer { FlutterDesktopMessengerUnlock(messenger) }
    return try withUnsafeMessenger(block)
  }

  // MARK: - FlutterDesktopMessenger wrappers

  // looking at the Darwin implementation, as long as message handlers are
  // serialized (here with an actor, in Darwin with a dispatch queue) then
  // it is safe to run handlers in any thread. However currently we must
  // *send* messages from the main thread. according to the eLinux docs,
  // we only need to acquire the lock when not on the platform thread. But
  // this doesn't really make sense.
  @MainActor
  private func send(
    on channel: String,
    message: Data?,
    _ block: FlutterDesktopBinaryReplyBlock?
  ) throws {
    guard try (message ?? Data()).withUnsafeBytes({ bytes in
      try withMessenger { messenger in
        FlutterDesktopMessengerSendWithReplyBlock(
          messenger,
          channel,
          bytes.count > 0 ? bytes.baseAddress : nil,
          bytes.count,
          block
        )
      }
    }) == true else {
      throw FlutterSwiftError.messageSendFailure
    }
  }

  private func setCallbackBlock(
    on channel: String,
    _ block: FlutterDesktopMessageCallbackBlock?
  ) throws {
    try withMessenger { messenger in
      FlutterDesktopMessengerSetCallbackBlock(messenger, channel, block)
    }
  }

  private func sendResponse(
    on channel: String,
    handle: OpaquePointer?,
    response: Data?
  ) throws {
    guard let handle else {
      debugPrint(
        "Error: Message responses can be sent only once. Ignoring duplicate response " +
          "on channel '\(channel)'"
      )
      return
    }

    // FIXME: do we need to take a lock here? doesn't look like other platforms do
    try withMessenger { messenger in
      (response ?? Data()).withUnsafeBytes {
        FlutterDesktopMessengerSendResponse(
          messenger,
          handle,
          $0.baseAddress,
          response?.count ?? 0
        )
      }
    }
  }

  // MARK: - public API

  public func send(
    on channel: String,
    message: Data?,
    priority: TaskPriority?
  ) async throws -> Data? {
    try await withPriority(priority) {
      await withCheckedContinuation { continuation in
        let replyThunk: FlutterDesktopBinaryReplyBlock?

        replyThunk = { bytes, count in
          let data: Data?

          if let bytes, count > 0 {
            data = Data(
              bytesNoCopy: UnsafeMutableRawPointer(mutating: bytes),
              count: count,
              deallocator: .none
            )
          } else {
            data = nil
          }
          continuation.resume(returning: data)
        }

        Task {
          try? await self.send(on: channel, message: message, replyThunk)
        }
      }
    }
  }

  public func send(on channel: String, message: Data?) async throws {
    try await send(on: channel, message: message, nil)
  }

  public func setMessageHandler(
    on channel: String,
    handler: FlutterBinaryMessageHandler?,
    priority: TaskPriority?
  ) throws -> FlutterBinaryMessengerConnection {
    var connection: FlutterBinaryMessengerConnection = 0

    if let handler {
      connection = currentMessengerConnection.wrappingIncrementThenLoad(by: 1, ordering: .relaxed)

      try setCallbackBlock(on: channel) { [weak self] _, message in
        let message = message.pointee
        var messageData: Data?

        guard let self else {
          return
        }

        if message.message_size > 0 {
          let ptr = UnsafeRawPointer(message.message).bindMemory(
            to: UInt8.self, capacity: message.message_size
          )
          messageData = Data(bytes: ptr, count: message.message_size)
        }

        Task(priority: priority) {
          let response = try await handler(messageData)
          try? self.sendResponse(
            on: channel,
            handle: message.response_handle,
            response: response
          )
        }
      }

    } else {
      connection = 0
      try setCallbackBlock(on: channel, nil)
    }

    return connection
  }

  public func cleanUp(connection: FlutterBinaryMessengerConnection) throws {}
}
#endif
