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

@testable import FlutterSwift
import XCTest

final class FlutterMessageCodecTests: XCTestCase {
  // MARK: - FlutterStringCodec

  func testStringCodecRoundTrip() throws {
    let codec = FlutterStringCodec.shared
    let encoded: Data = try codec.encode("hello world")
    let decoded: String = try codec.decode(encoded)
    XCTAssertEqual(decoded, "hello world")
  }

  func testStringCodecUnicode() throws {
    let codec = FlutterStringCodec.shared
    let value = "h\u{263A}w \u{0001F602}"
    let encoded: Data = try codec.encode(value)
    let decoded: String = try codec.decode(encoded)
    XCTAssertEqual(decoded, value)
  }

  func testStringCodecEmpty() throws {
    let codec = FlutterStringCodec.shared
    let encoded: Data = try codec.encode("")
    let decoded: String = try codec.decode(encoded)
    XCTAssertEqual(decoded, "")
  }

  // MARK: - FlutterJSONMessageCodec

  func testJSONMessageCodecString() throws {
    let codec = FlutterJSONMessageCodec.shared
    let encoded: Data = try codec.encode("hello")
    let decoded: String = try codec.decode(encoded)
    XCTAssertEqual(decoded, "hello")
  }

  func testJSONMessageCodecInt() throws {
    let codec = FlutterJSONMessageCodec.shared
    let encoded: Data = try codec.encode(42)
    let decoded: Int = try codec.decode(encoded)
    XCTAssertEqual(decoded, 42)
  }

  func testJSONMessageCodecArray() throws {
    let codec = FlutterJSONMessageCodec.shared
    let value = [1, 2, 3]
    let encoded: Data = try codec.encode(value)
    let decoded: [Int] = try codec.decode(encoded)
    XCTAssertEqual(decoded, value)
  }

  func testJSONMessageCodecDictionary() throws {
    let codec = FlutterJSONMessageCodec.shared
    let value = ["key": "value"]
    let encoded: Data = try codec.encode(value)
    let decoded: [String: String] = try codec.decode(encoded)
    XCTAssertEqual(decoded, value)
  }

  func testJSONMessageCodecStruct() throws {
    let codec = FlutterJSONMessageCodec.shared
    let value = Simple(x: 1, y: 2, z: 3)
    let encoded: Data = try codec.encode(value)
    let decoded: Simple = try codec.decode(encoded)
    XCTAssertEqual(decoded, value)
  }

  // MARK: - FlutterStandardMessageCodec

  func testStandardMessageCodecRoundTrip() throws {
    let codec = FlutterStandardMessageCodec.shared
    let value = "hello world"
    let encoded: Data = try codec.encode(value)
    let decoded: String = try codec.decode(encoded)
    XCTAssertEqual(decoded, value)
  }

  func testStandardMessageCodecInt() throws {
    let codec = FlutterStandardMessageCodec.shared
    let value = Int32(12345)
    let encoded: Data = try codec.encode(value)
    let decoded: Int32 = try codec.decode(encoded)
    XCTAssertEqual(decoded, value)
  }

  func testStandardMessageCodecStruct() throws {
    let codec = FlutterStandardMessageCodec.shared
    let value = Composite(before: 1, inner: Composite.Inner(value: 99), after: 7_834_868)
    let encoded: Data = try codec.encode(value)
    let decoded: Composite = try codec.decode(encoded)
    XCTAssertEqual(decoded, value)
  }
}
