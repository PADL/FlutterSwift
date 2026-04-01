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

final class FlutterStandardDecoderErrorTests: XCTestCase {
  func testDecodeTruncatedInt32() throws {
    let decoder = FlutterStandardDecoder()
    // Int32 field (0x03) followed by only 2 bytes instead of 4
    XCTAssertThrowsError(try decoder.decode(Int32.self, from: Data([0x03, 0x01, 0x02])))
  }

  func testDecodeTruncatedInt64() throws {
    let decoder = FlutterStandardDecoder()
    // Int64 field (0x04) followed by only 4 bytes instead of 8
    XCTAssertThrowsError(
      try decoder.decode(Int64.self, from: Data([0x04, 0x01, 0x02, 0x03, 0x04]))
    )
  }

  func testDecodeTruncatedFloat64() throws {
    let decoder = FlutterStandardDecoder()
    // Float64 field (0x06) followed by only 3 bytes (needs 7 alignment + 8 data)
    XCTAssertThrowsError(
      try decoder.decode(Double.self, from: Data([0x06, 0x00, 0x00, 0x01]))
    )
  }

  func testDecodeEmptyData() throws {
    let decoder = FlutterStandardDecoder()
    // Empty data should decode to nil optional
    let result = try decoder.decode(FlutterNull?.self, from: Data())
    XCTAssertNil(result)
  }

  func testDecodeUnknownFieldType() throws {
    let decoder = FlutterStandardDecoder()
    // 0xFF is not a valid FlutterStandardField type
    XCTAssertThrowsError(
      try decoder.decode(AnyFlutterStandardCodable.self, from: Data([0xFF]))
    )
  }
}
