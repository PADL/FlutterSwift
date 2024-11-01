// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Android
import Atomics
import FoundationEssentials
import JavaKit
import JavaRuntime

extension Data {
  func asJavaNIOByteBuffer() -> JavaNIOByteBuffer {
    let clz = try! JavaClass<JavaNIOByteBuffer>()
    return clz.wrap(Array(self).map { Int8($0) })
  }
}

extension JavaNIOByteBuffer {
  func asData() -> Data {
    Data(array().map { UInt8($0) })
  }
}

// this API is designed to mimic the iOS/macOS APIs, hence lack of Swiftiness

private let currentMessengerConnection = ManagedAtomic<Int64>(0)

public typealias FlutterBinaryReply = (Data?) -> ()
public typealias BinaryMessageHandler = _FlutterSwiftBinaryMessageHandler.MessageHandler

extension BinaryMessenger: @unchecked Sendable {}

package extension BinaryMessenger {
  func send(onChannel channel: String, message: Data?, binaryReply: FlutterBinaryReply?) {
    send(channel, message?.asJavaNIOByteBuffer())
  }

  func cleanUpConnection(_ connection: Int64) {}

  func setMessageHandlerOnChannel(
    _ channel: String,
    binaryMessageHandler messageHandler: _FlutterSwiftBinaryMessageHandler.MessageHandler?
  ) -> Int64 {
    if let messageHandler {
      let binaryMessageHandler = _FlutterSwiftBinaryMessageHandler(messageHandler)
      setMessageHandler(
        channel,
        binaryMessageHandler.as(BinaryMessenger.BinaryMessageHandler.self)!
      )
      return currentMessengerConnection.wrappingIncrementThenLoad(by: 1, ordering: .relaxed)
    } else {
      setMessageHandler(channel, nil)
      return 0
    }
  }
}
