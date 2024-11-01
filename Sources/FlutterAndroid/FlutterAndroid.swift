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

import Android
import Atomics
import FoundationEssentials
import JavaKit
import JavaRuntime

// this API is designed to mimic the iOS/macOS APIs, hence lack of Swiftiness

private let currentMessengerConnection = ManagedAtomic<Int64>(0)

public typealias FlutterBinaryReply = (Data?) -> ()
public typealias FlutterBinaryMessageHandler = _FlutterSwiftBinaryMessageHandler.MessageHandler

extension FlutterBinaryMessenger: @unchecked Sendable {}

extension FlutterBinaryMessenger: CustomJavaClassLoader {
  public static func getJavaClassLoader(in environment: JNIEnvironment) throws -> JavaClassLoader! {
    _getFlutterClassLoader()
  }
}

public extension FlutterBinaryMessenger {
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
      let typeErasedBinaryMessageHandler = FlutterBinaryMessenger
        .BinaryMessageHandler(javaHolder: binaryMessageHandler.javaHolder)

      setMessageHandler(channel, typeErasedBinaryMessageHandler)
      return currentMessengerConnection.wrappingIncrementThenLoad(by: 1, ordering: .relaxed)
    } else {
      setMessageHandler(channel, nil)
      return 0
    }
  }
}
