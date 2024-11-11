//
// Copyright (c) 2023-2024 PADL Software Pty Ltd
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

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import JavaKit
import JavaRuntime

extension _FlutterSwiftBinaryMessageHandler {
  public typealias MessageHandler = @Sendable (Data?, @Sendable @escaping (Data?) -> ()) -> ()

  fileprivate final class MessageHandlerHolder {
    let _callback: MessageHandler

    init(_ wrapped: @escaping MessageHandler) {
      _callback = wrapped
    }

    func onMessage(
      _ message: JavaNIOByteBuffer?,
      _ binaryReply: FlutterBinaryMessenger.BinaryReply?
    ) {
      _callback(try! message?.asData()) { data in
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

  private var messageHandlerHolder: MessageHandlerHolder {
    swiftObject as! MessageHandlerHolder
  }

  package convenience init(_ messageHandler: @escaping MessageHandler) {
    self.init(messageHandlerHolder: MessageHandlerHolder(messageHandler))
  }

  private convenience init(
    messageHandlerHolder: MessageHandlerHolder,
    environment: JNIEnvironment? = nil
  ) {
    self.init(swiftObject: messageHandlerHolder, environment: environment)
  }
}

@JavaImplementation("com.padl.FlutterAndroid.FlutterSwiftBinaryMessageHandler")
extension _FlutterSwiftBinaryMessageHandler: _FlutterSwiftBinaryMessageHandlerNativeMethods {
  @JavaMethod
  public func onMessage(
    _ message: JavaNIOByteBuffer?,
    _ binaryReply: FlutterBinaryMessenger.BinaryReply?
  ) {
    messageHandlerHolder.onMessage(message, binaryReply)
  }
}
