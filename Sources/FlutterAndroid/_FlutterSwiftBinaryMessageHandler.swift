// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FoundationEssentials
import JavaKit
import JavaRuntime

protocol _FlutterSwiftBinaryMessageHandlerNativeMethods {
  func onMessage(_ message: JavaNIOByteBuffer?, _ binaryReply: BinaryMessenger.BinaryReply?)
  func finalize()
}

@JavaClass(
  "com.padl.FlutterAndroid.FlutterSwiftBinaryMessageHandler",
  extends: JavaObject.self,
  implements: BinaryMessenger.BinaryMessageHandler.self
)
public struct _FlutterSwiftBinaryMessageHandler {
  public typealias MessageHandler = @Sendable (Data?, @Sendable @escaping (Data?) -> ()) -> ()

  @JavaField(isFinal: false)
  public var _box: Int64

  @JavaMethod
  public init(environment: JNIEnvironment? = nil)

  fileprivate final class Box {
    let _callback: MessageHandler

    init(_ wrapped: @escaping MessageHandler) {
      _callback = wrapped
    }

    func onMessage(_ message: JavaNIOByteBuffer?, _ binaryReply: BinaryMessenger.BinaryReply?) {
      _callback(message?.asData()) { data in
        guard let binaryReply else { return }
        if let binaryReply = binaryReply.as(_FlutterSwiftBinaryReply.self) {
          // if binaryReply is native Swift, short-circuit to avoid redundant data conversion
          binaryReply.reply(data)
        } else {
          binaryReply.reply(data?.asJavaNIOByteBuffer())
        }
      }
    }
  }
}

extension _FlutterSwiftBinaryMessageHandler {
  private var box: Unmanaged<Box> {
    unsafeBitCast(_box, to: Unmanaged<Box>.self)
  }

  package init(_ messageHandler: MessageHandler) {
    self.init()
  }

  private init(box: Box, environment: JNIEnvironment? = nil) {
    self.init(environment: environment)
    _box = unsafeBitCast(Unmanaged.passRetained(box), to: Int64.self)
  }

  private func deallocate() {
    _ = box.takeRetainedValue()
    _box = 0
  }
}

@JavaImplementation("com.padl.FlutterAndroid.FlutterSwiftBinaryMessageHandler")
extension _FlutterSwiftBinaryMessageHandler: _FlutterSwiftBinaryMessageHandlerNativeMethods {
  func onMessage(_ message: JavaNIOByteBuffer?, _ binaryReply: BinaryMessenger.BinaryReply?) {
    box.takeUnretainedValue().onMessage(message, binaryReply)
  }

  func finalize() {
    deallocate()
  }
}
