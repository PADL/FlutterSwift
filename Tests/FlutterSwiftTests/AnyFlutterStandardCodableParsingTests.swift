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

/// Covers `AnyFlutterStandardCodable`'s `ExpressibleByParsing` implementation,
/// which parses the standard codec's tagged wire format directly rather than
/// through `Codable`.
final class AnyFlutterStandardCodableParsingTests: XCTestCase {
  // MARK: - wire format

  func testParsesScalars() throws {
    try assertParses([0x00], to: .nil)
    try assertParses([0x01], to: .true)
    try assertParses([0x02], to: .false)
    try assertParses([0x03, 0xDC, 0xFE, 0x00, 0x00], to: .int32(0xFEDC))
    try assertParses(
      [0x04, 0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01],
      to: .int64(0x0102_0304_0506_0708)
    )
    // float64 pads to an 8-byte boundary measured from the start of the message
    try assertParses(
      [0x06, 0, 0, 0, 0, 0, 0, 0, 0x18, 0x2D, 0x44, 0x54, 0xFB, 0x21, 0x09, 0x40],
      to: .float64(3.14159265358979311599796346854)
    )
    try assertParses([0x07, 0x05, 0x68, 0xE2, 0x98, 0xBA, 0x77], to: .string("h\u{263A}w"))
  }

  func testParsesTypedData() throws {
    try assertParses([0x08, 0x02, 0xFE, 0xFF], to: .uint8Data([0xFE, 0xFF]))
    try assertParses([0x09, 0x01, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00], to: .int32Data([1]))
    try assertParses([0x0E, 0x01, 0x00, 0x00, 0x00, 0x00, 0x80, 0x3F], to: .float32Data([1.0]))
    // the alignment padding is written even when the array is empty
    try assertParses([0x08, 0x00], to: .uint8Data([]))
    try assertParses([0x09, 0x00, 0x00, 0x00], to: .int32Data([]))
  }

  func testParsesNestedContainers() throws {
    // map(["a": int32(1)])
    try assertParses(
      [0x0D, 0x01, 0x07, 0x01, 0x61, 0x03, 0x01, 0x00, 0x00, 0x00],
      to: .map([.string("a"): .int32(1)])
    )
    // list([int32Data([1]), "z"]) — the trailing string starts at an unaligned offset
    try assertParses(
      [0x0C, 0x02, 0x09, 0x01, 0x01, 0x00, 0x00, 0x00, 0x07, 0x01, 0x7A],
      to: .list([.int32Data([1]), .string("z")])
    )
  }

  /// Sizes of 254 and above escape to a `UInt16`, and 65536 and above to a
  /// `UInt32`. Neither escape is reachable from the hand-written wire-format
  /// fixtures elsewhere in the suite.
  func testParsesEscapedSizePrefixes() throws {
    let encoder = FlutterStandardEncoder()

    let long = String(repeating: "x", count: 300)
    let encodedString = try encoder.encode(long)
    XCTAssertEqual(encodedString[encodedString.startIndex + 1], 254)
    XCTAssertEqual(try AnyFlutterStandardCodable(parsing: encodedString), .string(long))

    let big = [UInt8](repeating: 0xAB, count: 70000)
    let encodedData = try encoder.encode(big)
    XCTAssertEqual(encodedData[encodedData.startIndex + 1], 255)
    XCTAssertEqual(try AnyFlutterStandardCodable(parsing: encodedData), .uint8Data(big))
  }

  // MARK: - equivalence with the Codable path

  /// The `Decodable` conformance now delegates to the parser, so both entry
  /// points must agree — including on how far they advance the cursor, which
  /// the alignment-sensitive cases below exercise.
  func testParsingAndDecodingAgree() throws {
    let values: [AnyFlutterStandardCodable] = [
      .nil,
      .true,
      .false,
      .int32(-1),
      .int64(.min),
      .float64(-0.0),
      .string(""),
      .string("h\u{0001F602}w"),
      .uint8Data([]),
      .int32Data([1, -2, 3, -4]),
      .int64Data([.max, .min]),
      .float32Data([1.5, -2.5]),
      .float64Data([1.5, -2.5]),
      .list([]),
      .list([.true, .float64(1.0), .string("z"), .int32Data([7])]),
      .map([.int32(1): .true, .string("k"): .list([.nil, .float64(2.0)])]),
      .list([.map([.string("a"): .int32Data([1])]), .float64(3.0)]),
    ]

    let encoder = FlutterStandardEncoder()
    let decoder = FlutterStandardDecoder()

    for value in values {
      let encoded = try encoder.encode(value)
      XCTAssertEqual(try AnyFlutterStandardCodable(parsing: encoded), value)
      XCTAssertEqual(try decoder.decode(AnyFlutterStandardCodable.self, from: encoded), value)
    }
  }

  /// The parser measures alignment padding from the start of the message, so a
  /// `Data` slice with a non-zero `startIndex` must be treated as starting at
  /// zero.
  func testParsesFromNonZeroStartIndexSlice() throws {
    let encoder = FlutterStandardEncoder()
    let value = AnyFlutterStandardCodable.list([.float64(1.0), .int64Data([1, 2])])

    var padded = Data([0xAA, 0xBB, 0xCC, 0xDD, 0xEE])
    padded.append(try encoder.encode(value))
    let slice = padded[5...]
    XCTAssertEqual(slice.startIndex, 5)

    XCTAssertEqual(try AnyFlutterStandardCodable(parsing: slice), value)
  }

  /// `FlutterError.details` decodes an `AnyFlutterStandardCodable` from the
  /// middle of a larger `Decodable` graph, so the parser has to resume from,
  /// and hand back, the enclosing decoder's cursor.
  func testParsesEmbeddedInDecodableGraph() throws {
    let encoder = FlutterStandardEncoder()
    let decoder = FlutterStandardDecoder()

    let error = FlutterError(
      code: "code",
      message: "message",
      details: .map([.string("k"): .list([.int32(1), .float64(2.0)])])
    )
    let envelope = FlutterEnvelope<FlutterNull>.failure(error)
    let encoded = try encoder.encode(envelope)

    let decoded = try decoder.decode(FlutterEnvelope<FlutterNull>.self, from: encoded)
    guard case let .failure(decodedError) = decoded else {
      return XCTFail("expected a failure envelope")
    }
    XCTAssertEqual(decodedError.details, error.details)
    XCTAssertEqual(decodedError.code, error.code)
  }

  // MARK: - errors

  func testRejectsUnknownFieldType() throws {
    assertParsing([0x0F], throws: .unknownStandardFieldType(0x0F))
  }

  /// `intHex` has a tag but no representation in this type.
  func testRejectsIntHex() throws {
    assertParsing([0x05], throws: .fieldNotDecodable)
  }

  func testRejectsTruncatedInput() throws {
    assertParsing([], throws: .eofTooEarly)
    assertParsing([0x03, 0x01, 0x02], throws: .eofTooEarly) // int32, 2 of 4 bytes
    assertParsing([0x07, 0x05, 0x68], throws: .eofTooEarly) // string, 1 of 5 bytes
    assertParsing([0x09, 0x02, 0x00, 0x00, 0x01], throws: .eofTooEarly) // int32Data, short
    assertParsing([0x0C, 0x02, 0x01], throws: .eofTooEarly) // list of 2, 1 element
    assertParsing([0x0D, 0x01, 0x01], throws: .eofTooEarly) // map of 1, no value
  }

  /// Unlike `String(parsingUTF8:)`, which repairs malformed input with U+FFFD,
  /// the codec treats it as a decode failure.
  func testRejectsInvalidUTF8() throws {
    assertParsing([0x07, 0x01, 0xFF], throws: .stringNotDecodable(Data([0xFF])))
  }

  // MARK: - helpers

  private func assertParses(
    _ bytes: [UInt8],
    to expected: AnyFlutterStandardCodable,
    line: UInt = #line
  ) throws {
    XCTAssertEqual(try AnyFlutterStandardCodable(parsing: Data(bytes)), expected, line: line)
    XCTAssertEqual(
      try FlutterStandardDecoder().decode(AnyFlutterStandardCodable.self, from: Data(bytes)),
      expected,
      line: line
    )
  }

  private func assertParsing(
    _ bytes: [UInt8],
    throws expected: FlutterSwiftError,
    line: UInt = #line
  ) {
    XCTAssertThrowsError(try AnyFlutterStandardCodable(parsing: Data(bytes)), line: line) { error in
      XCTAssertEqual(error as? FlutterSwiftError, expected, line: line)
    }
  }
}
