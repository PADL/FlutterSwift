// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#if os(Linux)
@_implementationOnly
import CxxFlutterSwift
import Foundation

struct FlutterEngineHandlerInfo {
    let connection: FlutterBinaryMessengerConnection
    let handler: FlutterBinaryMessageHandler
    let priority: TaskPriority?
}

public actor FlutterDesktopMessenger: FlutterBinaryMessenger {
    private var messengerHandlers = [String: FlutterEngineHandlerInfo]()
    private var currentMessengerConnection: FlutterBinaryMessengerConnection = 0
    private nonisolated let messenger: FlutterDesktopMessengerRef

    // MARK: - Initializers

    init(messenger: FlutterDesktopMessengerRef) {
        self.messenger = messenger
        FlutterDesktopMessengerAddRef(messenger)
    }

    init(engine: FlutterDesktopEngineRef) {
        messenger = FlutterDesktopEngineGetMessenger(engine)
        FlutterDesktopMessengerAddRef(messenger)
    }

    deinit {
        FlutterDesktopMessengerRelease(messenger)
    }

    // MARK: - FlutterDesktopMessenger wrappers

    private nonisolated var isAvailable: Bool {
        FlutterDesktopMessengerIsAvailable(messenger)
    }

    private func withLockedMessenger<T>(_ block: (_: FlutterDesktopMessengerRef) throws -> T) throws -> T {
        FlutterDesktopMessengerLock(messenger)
        defer { FlutterDesktopMessengerUnlock(messenger) }
        guard isAvailable else {
            throw FlutterSwiftError.messengerNotAvailable
        }
        return try block(messenger)
    }

    // looking at the Darwin implementation, as long as message handlers are
    // serialized (here with an actor, in Darwin with a dispatch queue) then
    // it is safe to run handlers in any thread. However currently we must
    // *send* messages from the main thread.
    @MainActor
    private func send(
        on channel: String,
        message: Data?,
        _ block: FlutterDesktopBinaryReplyBlock?
    ) throws {
        precondition(isAvailable)

        guard withUnsafeBytes(of: message, { bytes in
            // run on main actor, so don't need to take lock
            FlutterDesktopMessengerSendWithReplyBlock(
                messenger,
                channel,
                bytes.count > 0 ? bytes.baseAddress : nil,
                bytes.count,
                block
            )
        }) == true else {
            throw FlutterSwiftError.messageSendFailure
        }
    }

    private func setCallbackBlock(
        on channel: String,
        _ block: FlutterDesktopMessageCallbackBlock?
    ) throws {
        try withLockedMessenger { messenger in
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

        try withLockedMessenger { messenger in
            withUnsafeBytes(of: response) {
                // run on main actor, so don't need to take lock
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

    private func onDesktopMessage(
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
        Task {
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
                    try? sendResponse(on: channel, handle: message.response_handle, response: nil)
                }
            }
        }
    }

    private func removeMessengerHandler(for channel: String) async throws {
        messengerHandlers.removeValue(forKey: channel)
        try setCallbackBlock(on: channel, nil)
    }

    public func setMessageHandler(
        on channel: String,
        handler: FlutterBinaryMessageHandler?,
        priority: TaskPriority?
    ) async throws -> FlutterBinaryMessengerConnection {
        guard let handler else {
            try await removeMessengerHandler(for: channel)
            return 0
        }

        currentMessengerConnection = currentMessengerConnection + 1
        let handlerInfo = FlutterEngineHandlerInfo(
            connection: currentMessengerConnection,
            handler: handler,
            priority: priority
        )
        messengerHandlers[channel] = handlerInfo
        try setCallbackBlock(on: channel, onDesktopMessage)
        return currentMessengerConnection
    }

    public func cleanUp(connection: FlutterBinaryMessengerConnection) async throws {
        guard let foundChannel = messengerHandlers.first(where: { $1.connection == connection })
        else {
            return
        }
        try await removeMessengerHandler(for: foundChannel.key)
    }
}
#endif
