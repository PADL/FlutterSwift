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

package extension _FlutterSwiftBinaryReply {
  // note: block convention necessary to allow casting to AnyObject
  typealias Block = @convention(block) (Data?) -> ()

  internal var block: Block {
    swiftObject as! Block
  }

  convenience init(block: @escaping Block, environment: JNIEnvironment? = nil) {
    self.init(swiftObject: block as AnyObject, environment: environment)
  }
}

@JavaImplementation("com.padl.FlutterAndroid.FlutterSwiftBinaryReply")
extension _FlutterSwiftBinaryReply: _FlutterSwiftBinaryReplyNativeMethods {
  @JavaMethod
  public func reply(_ replyBuffer: JavaNIOByteBuffer?) {
    try! block(replyBuffer?.asData())
  }
}

extension _FlutterSwiftBinaryReply {
  func reply(_ replyBuffer: Data?) {
    block(replyBuffer)
  }
}
