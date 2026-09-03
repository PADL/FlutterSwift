//
// Copyright (c) 2026 PADL Software Pty Ltd
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
import Glibc
@testable import FlutterSwift
import XCTest

final class CStringOwnerTests: XCTestCase {
  // MARK: - WideCString

  func testWideCStringASCII() {
    let wide = WideCString("abc")
    XCTAssertEqual(wcslen(wide.pointer), 3)
    XCTAssertEqual(wide.pointer[0], "a")
    XCTAssertEqual(wide.pointer[1], "b")
    XCTAssertEqual(wide.pointer[2], "c")
    XCTAssertEqual(wide.pointer[3].value, 0)
  }

  func testWideCStringEmpty() {
    let wide = WideCString("")
    XCTAssertEqual(wcslen(wide.pointer), 0)
    XCTAssertEqual(wide.pointer[0].value, 0)
  }

  func testWideCStringNonBMPScalarIsOneCodeUnit() {
    // U+1F600 is two UTF-16 code units and four UTF-8 bytes, but one wchar_t.
    let wide = WideCString("/😀/é")
    XCTAssertEqual(wcslen(wide.pointer), 4)
    XCTAssertEqual(wide.pointer[0], "/")
    XCTAssertEqual(wide.pointer[1].value, 0x1F600)
    XCTAssertEqual(wide.pointer[2], "/")
    XCTAssertEqual(wide.pointer[3].value, 0xE9)
    XCTAssertEqual(wide.pointer[4].value, 0)
  }

  // MARK: - CStringArray

  func testCStringArrayEmpty() {
    let argv = CStringArray([])
    XCTAssertEqual(argv.count, 0)
    XCTAssertNil(argv.pointer[0])
  }

  func testCStringArrayContentsAndTerminator() {
    let args = ["--foo", "", "bar=baz", "ünïcödé"]
    let argv = CStringArray(args)
    XCTAssertEqual(argv.count, args.count)
    for (i, arg) in args.enumerated() {
      XCTAssertEqual(String(cString: argv.pointer[i]!), arg)
    }
    XCTAssertNil(argv.pointer[args.count])
  }

  func testCStringArrayEntriesAreContiguous() {
    let args = ["ab", "c"]
    let argv = CStringArray(args)
    // "ab\0" is three bytes, so the second entry starts three bytes in.
    XCTAssertEqual(argv.pointer[1]! - argv.pointer[0]!, 3)
  }
}
#endif
