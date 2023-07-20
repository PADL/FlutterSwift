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

    // any calls to FlutterDesktopMessenger...() must be performed by the main actor,
    // otherwise we would need to take a lock (and it is not recommended anyway)
    // The channel handlers, however, are free to run on the local actor
    @MainActor
    private func send(
        on channel: String,
        message: Data?,
        _ block: FlutterDesktopBinaryReplyBlock?
    ) throws {
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

    @MainActor
    private func setCallbackBlock(
        on channel: String,
        _ block: FlutterDesktopMessageCallbackBlock?) {
        FlutterDesktopMessengerSetCallbackBlock(messenger, channel, block)
    }

    @MainActor
    private func sendResponse(
        on channel: String,
        handle: OpaquePointer?,
        response: Data?
    ) {
        guard let handle else {
            debugPrint(
                "Error: Message responses can be sent only once. Ignoring duplicate response " +
                    "on channel '\(channel)'"
            )
            return
        }

        withUnsafeBytes(of: response) {
            // run on main actor, so don't need to take lock
            FlutterDesktopMessengerSendResponse(
                self.messenger,
                handle,
                $0.baseAddress,
                response?.count ?? 0
            )
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

                precondition(self.isAvailable) // should always be available from main thread

                Task {
                    // FIXME: errors are ignored
                    try? await self.send(on: channel, message: message, replyThunk)
                }
            }
        }
    }

    public func send(on channel: String, message: Data?) async throws {
        precondition(isAvailable) // should always be available from main thread
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
                    precondition(isAvailable) // should always be available from main actor
                    let response = try await handlerInfo.handler(capturedMessageData)
                    await sendResponse(on: channel, handle: message.response_handle, response: response)
                } else {
                    await sendResponse(on: channel, handle: message.response_handle, response: nil)
                }
            }
        }
    }

    private func removeMessengerHandler(for channel: String) async {
        precondition(isAvailable) // should always be available with locked messenger
        messengerHandlers.removeValue(forKey: channel)
        await setCallbackBlock(on: channel, nil)
    }

    public func setMessageHandler(
        on channel: String,
        handler: FlutterBinaryMessageHandler?,
        priority: TaskPriority?
    ) async throws -> FlutterBinaryMessengerConnection {
        guard let handler else {
            await removeMessengerHandler(for: channel)
            return 0
        }

        currentMessengerConnection = currentMessengerConnection + 1
        let handlerInfo = FlutterEngineHandlerInfo(
            connection: currentMessengerConnection,
            handler: handler,
            priority: priority
        )
        messengerHandlers[channel] = handlerInfo
        precondition(isAvailable) // should always be available with locked messenger
        await setCallbackBlock(on: channel, onDesktopMessage)
        return currentMessengerConnection
    }

    public func cleanUp(connection: FlutterBinaryMessengerConnection) async throws {
        guard let foundChannel = messengerHandlers.first(where: { $1.connection == connection })
        else {
            return
        }
        await removeMessengerHandler(for: foundChannel.key)
    }
}
#endif
