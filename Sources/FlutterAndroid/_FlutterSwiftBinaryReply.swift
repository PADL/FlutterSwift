// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FoundationEssentials
import JavaKit
import JavaRuntime

protocol _FlutterSwiftBinaryReplyNativeMethods {
  func reply(_ replyBuffer: JavaNIOByteBuffer?)
}

@JavaClass(
  "com.padl.FlutterAndroid.FlutterSwiftBinaryReply",
  extends: JavaObject.self,
  implements: BinaryMessenger.BinaryReply.self
)
public struct _FlutterSwiftBinaryReply {
  // note: block convention necessary to allow casting to AnyObject
  package typealias Block = @convention(block) (Data?) -> ()

  @JavaField(isFinal: false)
  public var _block: Int64

  @JavaMethod
  public init(environment: JNIEnvironment? = nil)
}

extension _FlutterSwiftBinaryReply {
  var block: Block {
    unsafeBitCast(_block, to: Block.self)
  }

  package init(block: @escaping Block, environment: JNIEnvironment? = nil) {
    self.init(environment: environment)
    let blockObject = Unmanaged.passRetained(unsafeBitCast(
      block,
      to: AnyObject.self
    )) // increment refcount on block
    _block = unsafeBitCast(blockObject, to: Int64.self)
  }

  private func deallocate() {
    _ = unsafeBitCast(_block, to: Unmanaged<AnyObject>.self).takeRetainedValue()
    _block = 0
  }
}

@JavaImplementation("com.padl.FlutterAndroid.FlutterSwiftBinaryReply")
extension _FlutterSwiftBinaryReply: _FlutterSwiftBinaryReplyNativeMethods {
  @JavaMethod
  public func reply(_ replyBuffer: JavaNIOByteBuffer?) {
    block(replyBuffer?.asData())
    deallocate()
  }

  func reply(_ replyBuffer: Data?) {
    block(replyBuffer)
    deallocate()
  }

//  @JavaMethod
//  public func finalize() {
//    _ = unsafeBitCast(_block, to: Unmanaged<AnyObject>.self).takeRetainedValue()
//  }
}
