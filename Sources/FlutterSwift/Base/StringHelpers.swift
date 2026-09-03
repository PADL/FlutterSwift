//
// Copyright (c) 2023-2025 PADL Software Pty Ltd
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

#if os(Linux) && canImport(Glibc)

@_implementationOnly
import CxxFlutterSwift
import CxxStdlib

/// A heap-allocated, NUL-terminated `wchar_t` copy of a string whose pointer
/// stays valid for the lifetime of the value, so it can be stored in a C struct
/// without nesting `withUnsafeBufferPointer` closures.
struct WideCString: ~Copyable {
  let pointer: UnsafeMutablePointer<CWideChar>

  init(_ string: String) {
    let scalars = string.unicodeScalars
    pointer = .allocate(capacity: scalars.count + 1)
    for (i, scalar) in scalars.enumerated() {
      pointer[i] = CWideChar(scalar)
    }
    pointer[scalars.count] = CWideChar(0 as UInt8)
  }

  deinit {
    pointer.deallocate()
  }
}

/// A NULL-terminated `char *[]` copy of an array of strings whose pointer
/// stays valid for the lifetime of the value. Two allocations: one contiguous
/// buffer for the NUL-terminated strings and one pointer table into it.
struct CStringArray: ~Copyable {
  let pointer: UnsafeMutablePointer<UnsafePointer<CChar>?>
  let count: Int
  private let buffer: UnsafeMutablePointer<CChar>

  init(_ strings: [String]) {
    count = strings.count
    pointer = .allocate(capacity: count + 1)
    buffer = .allocate(capacity: strings.reduce(0) { $0 + $1.utf8.count + 1 })

    var cursor = buffer
    for (i, string) in strings.enumerated() {
      pointer[i] = UnsafePointer(cursor)
      for byte in string.utf8 {
        cursor.pointee = CChar(bitPattern: byte)
        cursor += 1
      }
      cursor.pointee = 0
      cursor += 1
    }
    pointer[count] = nil
  }

  deinit {
    buffer.deallocate()
    pointer.deallocate()
  }
}

extension Array where Element == String {
  var cxxVector: CxxVectorOfString {
    var tmp = CxxVectorOfString()

    for element in self {
      tmp.push_back(std.string(element))
    }

    return tmp
  }
}
#endif
