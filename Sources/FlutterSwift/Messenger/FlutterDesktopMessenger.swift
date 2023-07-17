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
    private var messengerRef: FlutterDesktopMessengerRef

    init(engine: FlutterDesktopEngineRef) {
        messengerRef = FlutterDesktopEngineGetMessenger(engine)
        FlutterDesktopMessengerAddRef(messengerRef)
    }

    deinit {
        FlutterDesktopMessengerRelease(messengerRef)
    }

    private var isAvailable: Bool {
        FlutterDesktopMessengerIsAvailable(messengerRef)
    }

    private func withLockedMessenger<T>(_ block: () throws -> T) throws -> T {
        guard isAvailable else {
            throw FlutterSwiftError.messengerNotAvailable
        }
        FlutterDesktopMessengerLock(messengerRef)
        defer { FlutterDesktopMessengerUnlock(messengerRef) }
        return try block()
    }

    private func withPriority<Value>(
        _ priority: TaskPriority?,
        _ block: @escaping () async throws -> Value
    ) async throws -> Value {
        if let priority {
            let task = Task<Value, Error>(priority: priority) { @MainActor in
                try await block()
            }
            switch await task.result {
            case let .success(value):
                return value
            case let .failure(error):
                throw error
            }
        } else {
            return try await block()
        }
    }

    private func send(
        on channel: String,
        message: Data?,
        replyBlock: ((Data?) -> ())?
    ) throws {
        try withLockedMessenger {
            let replyThunk: FlutterDesktopBinaryReplyBlock?

            if let replyBlock {
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
                    replyBlock(data)
                }
            } else {
                replyThunk = nil
            }

            guard withUnsafeBytes(of: message, { bytes in
                FlutterDesktopMessengerSendWithReplyBlock(
                    messengerRef,
                    channel,
                    bytes.count > 0 ? bytes.baseAddress : nil,
                    bytes.count,
                    replyThunk
                )
            }) == true else {
                throw FlutterSwiftError.messageSendFailure
            }
        }
    }

    public func send(on channel: String, message: Data?) throws {
        try send(on: channel, message: message, replyBlock: nil)
    }

    public func send(
        on channel: String,
        message: Data?,
        priority: TaskPriority?
    ) async throws -> Data? {
        try await withPriority(priority) {
            try await withCheckedThrowingContinuation { continuation in
                do {
                    try self.send(on: channel, message: message) { reply in
                        continuation.resume(returning: reply)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func onDesktopMessage(
        _ messengerRef: FlutterDesktopMessengerRef,
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
                    FlutterDesktopMessengerSendResponse(
                        self.messengerRef,
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
                let reply = try await handlerInfo.handler(capturedMessageData)
                binaryResponseHandler(reply)
            }
        } else {
            binaryResponseHandler(nil)
        }
    }

    private func removeMessengerHandler(for channel: String) {
        messengerHandlers.removeValue(forKey: channel)
        FlutterDesktopMessengerSetCallbackBlock(messengerRef, channel, nil)
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
            FlutterDesktopMessengerSetCallbackBlock(messengerRef, channel, onDesktopMessage)
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
