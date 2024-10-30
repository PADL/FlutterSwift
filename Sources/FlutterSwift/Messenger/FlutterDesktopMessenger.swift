// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#if os(Linux)
import Atomics
@_implementationOnly
import CxxFlutterSwift
import Foundation

struct FlutterEngineHandlerInfo {
  let connection: FlutterBinaryMessengerConnection
  let handler: FlutterBinaryMessageHandler
  let priority: TaskPriority?
}

public final class FlutterDesktopMessenger: FlutterBinaryMessenger {
  private final class ManagedReference: @unchecked Sendable {
    private let messenger: FlutterDesktopMessengerRef

    init(_ messenger: FlutterDesktopMessengerRef) {
      self.messenger = messenger
      FlutterDesktopMessengerAddRef(messenger)
    }

    deinit {
      FlutterDesktopMessengerRelease(messenger)
    }

    private func withUnsafeRegion<T>(
      _ block: (_: FlutterDesktopMessengerRef) throws
        -> T
    ) throws -> T {
      guard FlutterDesktopMessengerIsAvailable(messenger) else {
        throw FlutterSwiftError.messengerNotAvailable
      }
      return try block(messenger)
    }

    func withRegion<T>(
      _ block: (_: FlutterDesktopMessengerRef) throws
        -> T
    ) throws -> T {
      FlutterDesktopMessengerLock(messenger)
      defer { FlutterDesktopMessengerUnlock(messenger) }
      return try withUnsafeRegion(block)
    }
  }

  private let messengerHandlers = ManagedCriticalState<[String: FlutterEngineHandlerInfo]>([:])
  private let currentMessengerConnection = ManagedAtomic<FlutterBinaryMessengerConnection>(0)
  private let messenger: ManagedReference

  // : - Initializers

  init(messenger: FlutterDesktopMessengerRef) {
    self.messenger = ManagedReference(messenger)
  }

  init(engine: FlutterDesktopEngineRef) {
    messenger = ManagedReference(FlutterDesktopEngineGetMessenger(engine))
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
      try messenger.withRegion { messenger in
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
    try messenger.withRegion { messenger in
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
    try messenger.withRegion { messenger in
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

  @Sendable
  private nonisolated func onDesktopMessage(
    _ messenger: FlutterDesktopMessengerRef,
    _ message: UnsafePointer<FlutterDesktopMessage>
  ) {
    let message = message.pointee
    var messageData: Data?
    let channel = String(cString: message.channel!)
    if message.message_size > 0 {
      let ptr = UnsafeRawPointer(message.message).bindMemory(
        to: UInt8.self, capacity: message.message_size
      )
      messageData = Data(bytes: ptr, count: message.message_size)
    }

    let capturedMessageData = messageData
    messengerHandlers.withCriticalRegion { messengerHandlers in
      let handlerInfo = messengerHandlers[channel]
      Task(priority: handlerInfo?.priority) {
        if let handlerInfo {
          let response = try await handlerInfo.handler(capturedMessageData)
          try? sendResponse(
            on: channel,
            handle: message.response_handle,
            response: response
          )
        } else {
          try? sendResponse(
            on: channel,
            handle: message.response_handle,
            response: nil
          )
        }
      }
    }
  }

  public func setMessageHandler(
    on channel: String,
    handler: FlutterBinaryMessageHandler?,
    priority: TaskPriority?
  ) throws -> FlutterBinaryMessengerConnection {
    var connection: FlutterBinaryMessengerConnection = 0

    try messengerHandlers.withCriticalRegion { messengerHandlers in
      if let handler {
        connection = currentMessengerConnection.wrappingIncrementThenLoad(by: 1, ordering: .relaxed)
        let handlerInfo = FlutterEngineHandlerInfo(
          connection: connection,
          handler: handler,
          priority: priority
        )
        messengerHandlers[channel] = handlerInfo
        try setCallbackBlock(on: channel, onDesktopMessage)
      } else {
        connection = 0
        messengerHandlers.removeValue(forKey: channel)
        try setCallbackBlock(on: channel, nil)
      }
    }

    return connection
  }

  public func cleanUp(connection: FlutterBinaryMessengerConnection) throws {
    messengerHandlers.withCriticalRegion { messengerHandlers in
      guard let foundChannel = messengerHandlers.first(where: { $1.connection == connection })
      else { return }
      messengerHandlers.removeValue(forKey: foundChannel.key)
    }
  }
}
#endif
