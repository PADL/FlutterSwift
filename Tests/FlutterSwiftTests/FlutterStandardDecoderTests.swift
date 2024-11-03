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

// MIT License
//
// Portions Copyright (c) 2022 fwcd
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

@testable import FlutterSwift
import XCTest

final class FlutterStandardDecoderTests: XCTestCase {
  func testDefaultStandardDecoder() throws {
    let decoder = FlutterStandardDecoder()

    try assertThat(decoder, decodes: [], to: FlutterNull?.none)
    try assertThat(decoder, decodes: [0x00], to: FlutterNull?.none)
    try assertThat(decoder, decodes: [0x01], to: true)
    try assertThat(decoder, decodes: [0x02], to: false)

    try assertThat(decoder, decodes: [0x03, 0xFE, 0x00, 0x00, 0x00], to: UInt8(0xFE))
    try assertThat(decoder, decodes: [0x03, 0xDC, 0xFE, 0x00, 0x00], to: UInt16(0xFEDC))
    try assertThat(
      decoder,
      decodes: [0x04, 0x09, 0xBA, 0xDC, 0xFE, 0x00, 0x00, 0x00, 0x00],
      to: UInt64(0xFEDC_BA09)
    )
    try assertThat(
      decoder,
      decodes: [0x04, 0xFA, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF],
      to: UInt64(0xFFFF_FFFF_FFFF_FFFA)
    )
    try assertThat(decoder, decodes: [0x03, 0xFE, 0xFF, 0xFF, 0xFF], to: Int8(-2))
    try assertThat(
      decoder,
      decodes: [0x03, 0xDC, 0xFE, 0xFF, 0xFF],
      to: Int16(bitPattern: 0xFEDC)
    )
    try assertThat(
      decoder,
      decodes: [0x03, 0x78, 0x56, 0x34, 0x12],
      to: Int32(bitPattern: 0x1234_5678)
    )
    try assertThat(
      decoder,
      decodes: [0x04, 0xEF, 0xCD, 0xAB, 0x90, 0x78, 0x56, 0x34, 0x12],
      to: Int64(bitPattern: 0x1234_5678_90AB_CDEF)
    )
    try assertThat(decoder, decodes: [
      0x06,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x60,
      0xFB,
      0x21,
      0x09,
      0x40,
    ], to: Float(3.1415927))
    try assertThat(decoder, decodes: [
      0x06,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x18,
      0x2D,
      0x44,
      0x54,
      0xFB,
      0x21,
      0x09,
      0x40,
    ], to: Double(3.14159265358979311599796346854))
    try assertThat(decoder, decodes: [0x07, 0x0B, 0x68, 0x65, 0x6C, 0x6C, 0x6F,
                                      0x20, 0x77, 0x6F, 0x72, 0x6C, 0x64], to: "hello world")
    try assertThat(
      decoder,
      decodes: [0x07, 0x05, 0x68, 0xE2, 0x98, 0xBA, 0x77],
      to: "h\u{263A}w"
    )
    try assertThat(
      decoder,
      decodes: [0x07, 0x06, 0x68, 0xF0, 0x9F, 0x98, 0x82, 0x77],
      to: "h\u{0001F602}w"
    )
  }

  func testDefaultStandardVariantDecoder() throws {
    let decoder = FlutterStandardDecoder()

    try assertThat(decoder, decodes: [0x01], to: AnyFlutterStandardCodable.true)
    try assertThat(decoder, decodes: [0x02], to: AnyFlutterStandardCodable.false)
  }

  private func assertThat<Value>(
    _ decoder: FlutterStandardDecoder,
    decodes array: [UInt8],
    to expectedValue: Value,
    line: UInt = #line
  ) throws where Value: Decodable & Equatable {
    XCTAssertEqual(try decoder.decode(Value.self, from: Data(array)), expectedValue, line: line)
  }

  private func assertThat<Value>(
    _ decoder: FlutterStandardDecoder,
    whileDecoding type: Value.Type,
    from array: [UInt8],
    throws expectedError: FlutterSwiftError,
    line: UInt = #line
  ) throws where Value: Decodable {
    XCTAssertThrowsError(
      try decoder.decode(Value.self, from: Data(array)),
      line: line
    ) { error in
      XCTAssertEqual(error as! FlutterSwiftError, expectedError, line: line)
    }
  }
}
