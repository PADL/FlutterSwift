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

public final class FlutterDesktopMessenger: FlutterBinaryMessenger {
    private var messengerHandlers = [String: FlutterEngineHandlerInfo]()
    private var currentMessengerConnection: FlutterBinaryMessengerConnection = 0
    private var messenger: FlutterDesktopMessengerRef

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

    private var isAvailable: Bool {
        FlutterDesktopMessengerIsAvailable(messenger)
    }

    private func withLockedMessenger<T>(_ block: () throws -> T) throws -> T {
        guard isAvailable else {
            throw FlutterSwiftError.messengerNotAvailable
        }
        FlutterDesktopMessengerLock(messenger)
        defer { FlutterDesktopMessengerUnlock(messenger) }
        return try block()
    }

    private func send(
        on channel: String,
        message: Data?,
        _ replyBlock: FlutterDesktopBinaryReplyBlock?
    ) throws {
        guard withUnsafeBytes(of: message, { bytes in
            // run on main actor, so don't need to take lock
            FlutterDesktopMessengerSendWithReplyBlock(
                messenger,
                channel,
                bytes.count > 0 ? bytes.baseAddress : nil,
                bytes.count,
                replyBlock
            )
        }) == true else {
            throw FlutterSwiftError.messageSendFailure
        }
    }

    @MainActor
    public func send(
        on channel: String,
        message: Data?,
        priority: TaskPriority?
    ) async throws -> Data? {
        try await withPriority(priority) {
            try await withCheckedThrowingContinuation { continuation in
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

                do {
                    try self.send(on: channel, message: message, replyThunk)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    @MainActor
    public func send(on channel: String, message: Data?) async throws {
        precondition(isAvailable) // should always be available from main thread
        try send(on: channel, message: message, nil)
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

        let binaryResponseHandler: (Data?) -> () = { response in
            if message.response_handle != nil {
                withUnsafeBytes(of: response) {
                    // run on main actor, so don't need to take lock
                    FlutterDesktopMessengerSendResponse(
                        self.messenger,
                        message.response_handle,
                        $0.baseAddress,
                        response?.count ?? 0
                    )
                }
            } else {
                debugPrint(
                    "Error: Message responses can be sent only once. Ignoring duplicate response " +
                        "on channel '\(channel)'"
                )
            }
        }

        if let handlerInfo = messengerHandlers[channel] {
            let capturedMessageData = messageData
            Task(priority: handlerInfo.priority) { @MainActor in
                precondition(isAvailable) // should always be available from main thread
                let reply = try await handlerInfo.handler(capturedMessageData)
                binaryResponseHandler(reply)
            }
        } else {
            binaryResponseHandler(nil)
        }
    }

    private func removeMessengerHandler(for channel: String) {
        precondition(isAvailable) // should always be available with locked messenger
        messengerHandlers.removeValue(forKey: channel)
        FlutterDesktopMessengerSetCallbackBlock(messenger, channel, nil)
    }

    public func setMessageHandler(
        on channel: String,
        handler: FlutterBinaryMessageHandler?,
        priority: TaskPriority?
    ) throws -> FlutterBinaryMessengerConnection {
        try withLockedMessenger {
            guard let handler else {
                removeMessengerHandler(for: channel)
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
            FlutterDesktopMessengerSetCallbackBlock(messenger, channel, onDesktopMessage)
            return currentMessengerConnection
        }
    }

    public func cleanUp(connection: FlutterBinaryMessengerConnection) throws {
        try withLockedMessenger {
            guard let foundChannel = messengerHandlers.first(where: { $1.connection == connection })
            else {
                return
            }
            removeMessengerHandler(for: foundChannel.key)
        }
    }
}
#endif
