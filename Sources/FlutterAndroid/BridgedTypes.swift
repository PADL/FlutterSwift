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

private func getDirectBufferAddress(_ byteBuffer: ByteBuffer) -> UnsafeMutableRawPointer? {
  let env = byteBuffer.javaEnvironment
  guard let jniEnv = env.pointee else { return nil }
  return jniEnv.pointee.GetDirectBufferAddress(env, byteBuffer.javaThis)
}

extension Data {
  func asByteBuffer() -> ByteBuffer {
    let byteBuffer = _byteBufferClass.allocateDirect(Int32(count))!

    guard count > 0 else { return byteBuffer }

    if let dst = getDirectBufferAddress(byteBuffer) {
      withUnsafeBytes { src in
        dst.copyMemory(from: src.baseAddress!, byteCount: count)
      }
      // advance position to match put() semantics so flip() works correctly
      let buffer = JavaNIOBuffer(javaHolder: byteBuffer.javaHolder)
      buffer.position(Int32(count))
    } else {
      byteBuffer.put(map { Int8(bitPattern: $0) }, 0, Int32(count))
    }

    return byteBuffer
  }
}

extension ByteBuffer {
  func asData() throws -> Data {
    let buffer = JavaNIOBuffer(javaHolder: self.javaHolder)
    let position = Int(buffer.position()), limit = Int(buffer.limit())
    let remaining = limit - position

    guard remaining > 0 else { return Data() }

    if let src = getDirectBufferAddress(self) {
      return Data(bytes: src.advanced(by: position), count: remaining)
    }

    if hasArray() {
      let offset = Int(arrayOffset()) + position
      let array = self.array()
      return array.withUnsafeBufferPointer { buf in
        Data(bytes: buf.baseAddress! + offset, count: remaining)
      }
    }

    let array = _byteBufferHelperClass.getByteBufferContents(self)
    return array.withUnsafeBufferPointer { buf in
      Data(bytes: buf.baseAddress!, count: buf.count)
    }
  }
}
