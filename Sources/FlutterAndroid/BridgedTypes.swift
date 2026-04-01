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

import FoundationEssentials
import SwiftJava

extension Data {
  func asByteBuffer() -> ByteBuffer {
    let byteBuffer = _byteBufferClass.allocateDirect(Int32(count))!

    return byteBuffer.put(map { Int8(bitPattern: $0) }, 0, Int32(count))
  }
}

extension ByteBuffer {
  func asData() throws -> Data {
    let array: [Int8]

    if hasArray() {
      let buffer = JavaNIOBuffer(javaHolder: self.javaHolder)
      let position = Int(buffer.position()), limit = Int(buffer.limit())
      let offset = Int(arrayOffset()) + position

      array = Array(self.array()[offset..<(offset + limit)])
    } else {
      array = _byteBufferHelperClass.getByteBufferContents(self)
    }

    return Data(array.map { UInt8(bitPattern: $0) })
  }
}
