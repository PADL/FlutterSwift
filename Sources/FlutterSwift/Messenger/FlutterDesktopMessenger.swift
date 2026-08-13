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
import Synchronization
@_implementationOnly
import CxxFlutterSwift
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

typealias FlutterDesktopBinaryReplyHandler = @Sendable (UnsafePointer<UInt8>?, Int) -> ()

typealias FlutterDesktopMessageCallbackHandler = @Sendable (
  FlutterDesktopMessengerRef,
  UnsafePointer<FlutterDesktopMessage>
) -> ()

private final class ReplyBox: Sendable {
  let handler: FlutterDesktopBinaryReplyHandler

  init(_ handler: @escaping FlutterDesktopBinaryReplyHandler) {
    self.handler = handler
  }
}

private final class MessageCallbackBox: Sendable {
  let handler: FlutterDesktopMessageCallbackHandler

  init(_ handler: @escaping FlutterDesktopMessageCallbackHandler) {
    self.handler = handler
  }
}

public final class FlutterDesktopMessenger: FlutterBinaryMessenger, @unchecked Sendable {
  private let currentMessengerConnection = ManagedAtomic<FlutterBinaryMessengerConnection>(0)
  // connection -> channel, so cleanUp(connection:) can unregister the callback
  private let handlerChannels = Mutex<[FlutterBinaryMessengerConnection: String]>([:])
  private let messageCallbackBoxes = Mutex<[String: MessageCallbackBox]>([:])
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
  @FlutterPlatformThreadActor
  private func send(
    on channel: String,
    message: Data?,
    _ handler: FlutterDesktopBinaryReplyHandler?
  ) throws {
    guard try (message ?? Data()).withUnsafeBytes({ bytes in
      try withMessenger { messenger in
        // consumed by the reply thunk, or by the cleanup thunk if the engine
        // fails to send; still outstanding if the engine is torn down first
        let userData = handler.map { Unmanaged.passRetained(ReplyBox($0)).toOpaque() }
        return FlutterDesktopMessengerSendWithReply(
          messenger,
          channel,
          bytes.count > 0 ? bytes.bindMemory(to: UInt8.self).baseAddress : nil,
          bytes.count,
          userData == nil ? nil : { data, dataSize, userData in
            guard let userData else { return }
            Unmanaged<ReplyBox>.fromOpaque(userData).takeRetainedValue().handler(data, dataSize)
          },
          userData,
          userData == nil ? nil : { userData in
            guard let userData else { return }
            Unmanaged<ReplyBox>.fromOpaque(userData).release()
          }
        )
      }
    }) == true else {
      throw FlutterSwiftError.messageSendFailure
    }
  }

  private func setMessageCallback(
    on channel: String,
    _ handler: FlutterDesktopMessageCallbackHandler?
  ) throws {
    try withMessenger { messenger in
      let box = handler.map { MessageCallbackBox($0) }
      let previous = messageCallbackBoxes.withLock { boxes -> MessageCallbackBox? in
        let previous = boxes[channel]
        boxes[channel] = box
        return previous
      }
      let callback: FlutterDesktopMessageCallback? = box == nil ? nil :
        { messenger, message, userData in
          guard let messenger, let message, let userData else { return }
          Unmanaged<MessageCallbackBox>.fromOpaque(userData).takeUnretainedValue()
            .handler(messenger, message)
        }
      FlutterDesktopMessengerSetCallback(
        messenger,
        channel,
        callback,
        box.map { Unmanaged.passUnretained($0).toOpaque() }
      )
      withExtendedLifetime(previous) {}
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

  @FlutterPlatformThreadActor
  public func send(
    on channel: String,
    message: Data?,
    priority: TaskPriority?
  ) async throws -> Data? {
    try await withPriority(priority) {
      try await withUnsafeThrowingContinuation { continuation in
        let replyThunk: FlutterDesktopBinaryReplyHandler?

        replyThunk = { bytes, count in
          let data: Data?

          if let bytes, count > 0 {
            // copy: the engine-owned reply buffer is freed after this callback
            data = Data(bytes: bytes, count: count)
          } else {
            data = nil
          }
          continuation.resume(returning: data)
        }

        Task {
          do {
            try await self.send(on: channel, message: message, replyThunk)
          } catch {
            // send() threw before the reply block registered; it will never fire
            continuation.resume(throwing: error)
          }
        }
      }
    }
  }

  @FlutterPlatformThreadActor
  public func send(on channel: String, message: Data?) throws {
    try send(on: channel, message: message, nil)
  }

  public func setMessageHandler(
    on channel: String,
    handler: FlutterBinaryMessageHandler?,
    priority: TaskPriority?
  ) throws -> FlutterBinaryMessengerConnection {
    var connection: FlutterBinaryMessengerConnection = 0

    if let handler {
      connection = currentMessengerConnection.wrappingIncrementThenLoad(by: 1, ordering: .relaxed)
      handlerChannels.withLock { registry in
        // drop any stale mapping for this channel from a prior registration
        for (staleConnection, staleChannel) in registry where staleChannel == channel {
          registry[staleConnection] = nil
        }
        registry[connection] = channel
      }

      try setMessageCallback(on: channel) { [weak self] _, message in
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

        nonisolated(unsafe) let responseHandle = message.response_handle
        let _ = Task(priority: priority) { @Sendable [self, handler, channel, messageData] in
          do {
            let response = try await handler(messageData)
            try? self.sendResponse(
              on: channel,
              handle: responseHandle,
              response: response
            )
          } catch {
            // Always send a response even on error so the Flutter engine
            // can release the MallocMapping-owned message buffer (flutter/flutter#159363).
            try? self.sendResponse(on: channel, handle: responseHandle, response: nil)
          }
        }
      }

    } else {
      connection = 0
      handlerChannels.withLock { registry in
        for (staleConnection, staleChannel) in registry where staleChannel == channel {
          registry[staleConnection] = nil
        }
      }
      try setMessageCallback(on: channel, nil)
    }

    return connection
  }

  public func cleanUp(connection: FlutterBinaryMessengerConnection) throws {
    guard let channel = handlerChannels.withLock({ $0.removeValue(forKey: connection) })
    else {
      return
    }
    try setMessageCallback(on: channel, nil)
  }
}
#endif
