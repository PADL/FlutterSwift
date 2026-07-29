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
import Foundation
import XCTest

/// Covers `AnyFlutterStandardCodable.write(into:)`, which writes the standard
/// codec's tagged wire format directly rather than through `Codable`.
///
/// The load-bearing property is that it agrees with the `Codable` encoder
/// byte-for-byte: the direct path is chosen by
/// `FlutterStandardEncoder.encode`, so any divergence silently changes what
/// every event channel puts on the wire.
final class AnyFlutterStandardCodableWritingTests: XCTestCase {
  // MARK: - exact wire bytes

  func testWritesScalars() throws {
    try assertWrites(.nil, as: [0x00])
    try assertWrites(.true, as: [0x01])
    try assertWrites(.false, as: [0x02])
    try assertWrites(.int32(0xFEDC), as: [0x03, 0xDC, 0xFE, 0x00, 0x00])
    try assertWrites(
      .int64(0x0102_0304_0506_0708),
      as: [0x04, 0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01]
    )
    // float64 pads to an 8-byte boundary measured from the start of the message
    try assertWrites(
      .float64(3.14159265358979311599796346854),
      as: [0x06, 0, 0, 0, 0, 0, 0, 0, 0x18, 0x2D, 0x44, 0x54, 0xFB, 0x21, 0x09, 0x40]
    )
    try assertWrites(.string("h\u{263A}w"), as: [0x07, 0x05, 0x68, 0xE2, 0x98, 0xBA, 0x77])
  }

  func testWritesTypedData() throws {
    try assertWrites(.uint8Data([0xFE, 0xFF]), as: [0x08, 0x02, 0xFE, 0xFF])
    try assertWrites(.int32Data([1]), as: [0x09, 0x01, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00])
    try assertWrites(
      .int64Data([1]),
      as: [0x0A, 0x01, 0, 0, 0, 0, 0, 0, 0x01, 0, 0, 0, 0, 0, 0, 0]
    )
    try assertWrites(
      .float64Data([1]),
      as: [0x0B, 0x01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xF0, 0x3F]
    )
    try assertWrites(.float32Data([1]), as: [0x0E, 0x01, 0, 0, 0x00, 0x00, 0x80, 0x3F])
  }

  /// An empty typed array still carries its alignment padding — the tag and
  /// size are written first, then the buffer is padded to the element stride
  /// even though no elements follow. Dart's `WriteBuffer` does the same, and
  /// the reader consumes the padding symmetrically.
  func testWritesEmptyTypedData() throws {
    try assertWrites(.uint8Data([]), as: [0x08, 0x00])
    try assertWrites(.int32Data([]), as: [0x09, 0x00, 0, 0])
    try assertWrites(.int64Data([]), as: [0x0A, 0x00, 0, 0, 0, 0, 0, 0])
    try assertWrites(.float32Data([]), as: [0x0E, 0x00, 0, 0])
    try assertWrites(.float64Data([]), as: [0x0B, 0x00, 0, 0, 0, 0, 0, 0])
    try assertWrites(.list([]), as: [0x0C, 0x00])
    try assertWrites(.map([:]), as: [0x0D, 0x00])
  }

  func testWritesNestedContainers() throws {
    try assertWrites(
      .list([.int32(1), .string("a")]),
      as: [0x0C, 0x02, 0x03, 0x01, 0x00, 0x00, 0x00, 0x07, 0x01, 0x61]
    )
    try assertWrites(
      .list([.list([.true])]),
      as: [0x0C, 0x01, 0x0C, 0x01, 0x01]
    )
  }

  /// The size prefix escapes to a `UInt16` at 254 and a `UInt32` at 65536.
  func testWritesSizeEscapes() throws {
    let small = [UInt8](repeating: 0xAB, count: 253)
    try assertWrites(.uint8Data(small), as: [0x08, 253] + small)

    let medium = [UInt8](repeating: 0xAB, count: 254)
    try assertWrites(.uint8Data(medium), as: [0x08, 254, 0xFE, 0x00] + medium)

    // the last size the UInt16 escape can carry, and the first that needs UInt32
    let boundary = [UInt8](repeating: 0xAB, count: 0xFFFF)
    try assertWrites(.uint8Data(boundary), as: [0x08, 254, 0xFF, 0xFF] + boundary)

    let large = [UInt8](repeating: 0xAB, count: 0x10000)
    try assertWrites(.uint8Data(large), as: [0x08, 255, 0x00, 0x00, 0x01, 0x00] + large)
  }

  // MARK: - agreement with the Codable path

  /// NOTE ON WHAT THIS DOES AND DOESN'T PROVE.
  ///
  /// It is tempting to read this as pinning the direct writer against an
  /// independent `Codable` encoder. It isn't, and can't be:
  /// `AnyFlutterStandardCodable` is an enum, so it matches none of the
  /// `as? Data` / `[UInt8]` / `FlutterListRepresentable` /
  /// `FlutterMapRepresentable` arms in
  /// `FlutterStandardEncodingState.encode(_:codingPath:)` — `Array` and
  /// `Dictionary` are the only conformers — and always falls through to
  /// `encode(to: FlutterStandardEncoderImpl)`, which delegates straight back to
  /// `write(into:)`. Both sides of this comparison are the same writer.
  ///
  /// What it *does* cover is that the two ways of reaching the writer agree —
  /// the standalone buffer in `_directlyEncoded()` and the shared buffer the
  /// encoding state owns — which is where the message-relative alignment rule
  /// could diverge.
  ///
  /// The bytes themselves are pinned by the literal vectors above, and against
  /// an independent implementation by the round trips through the parser.
  ///
  /// Maps are excluded: `Dictionary` iteration order is unspecified, so neither
  /// side produces deterministic bytes for them.
  func testDirectAndStatefulBuffersAgree() throws {
    for value in Self.everyShapeExceptMaps {
      let direct = try XCTUnwrap(value._directlyEncoded())
      let viaState = try encodedViaCodable(value)
      XCTAssertEqual(
        [UInt8](direct),
        [UInt8](viaState),
        "standalone and state-owned buffers diverged for \(value)"
      )
    }
  }

  /// The envelope case does exercise the `Codable` machinery for the framing —
  /// unkeyed container, discriminant — even though the payload bytes still come
  /// from the writer.
  func testEnvelopeFramingAgrees() throws {
    for value in Self.everyShapeExceptMaps {
      let envelope = FlutterEnvelope.success(value)
      let direct = try XCTUnwrap(envelope._directlyEncoded())
      let viaState = try encodedViaCodable(envelope)
      XCTAssertEqual(
        [UInt8](direct),
        [UInt8](viaState),
        "direct envelope framing diverged from the Codable framing for \(value)"
      )
    }
  }

  /// The fast path has to actually be *selected*: losing the conformance would
  /// silently revert every event channel to the `Codable` encoder, at roughly
  /// 8-15x the cost per event.
  ///
  /// This has to assert on the conformance rather than on bytes. Both paths
  /// produce identical output by construction — the `Codable` path delegates to
  /// the same writer — so comparing `FlutterStandardEncoder().encode(x)` against
  /// `x._directlyEncoded()` passes even with the fast path deleted outright
  /// (verified). Byte equality cannot observe routing; only the conformance
  /// `FlutterStandardEncoder.encode` dispatches on can.
  func testDirectlyEncodableConformancesArePresent() throws {
    XCTAssertTrue(
      AnyFlutterStandardCodable.int32(1) is any FlutterStandardDirectlyEncodable,
      "AnyFlutterStandardCodable lost its direct-encoding conformance"
    )
    XCTAssertTrue(
      FlutterEnvelope.success(AnyFlutterStandardCodable.int32(1))
        is any FlutterStandardDirectlyEncodable,
      "FlutterEnvelope lost its direct-encoding conformance; every event " +
        "channel would silently fall back to the Codable encoder"
    )
    // and the conformance has to accept, not decline, the shapes it covers
    for value in Self.everyShapeExceptMaps + Self.maps {
      XCTAssertNotNil(try value._directlyEncoded())
      XCTAssertNotNil(try FlutterEnvelope.success(value)._directlyEncoded())
    }
  }

  /// A nil success payload is a discriminant followed by a bare `nil` tag.
  func testEnvelopeWritesNilPayload() throws {
    let envelope = FlutterEnvelope<AnyFlutterStandardCodable>.success(nil)
    let direct = try XCTUnwrap(envelope._directlyEncoded())
    XCTAssertEqual([UInt8](direct), [0x00, 0x00])
    XCTAssertEqual([UInt8](direct), try [UInt8](encodedViaCodable(envelope)))
  }

  /// Failures decline the direct path and fall back to `Codable`, so the error
  /// envelope's bytes must be unaffected by any of this.
  func testFailureEnvelopeDeclinesDirectPath() throws {
    let envelope = FlutterEnvelope<AnyFlutterStandardCodable>.failure(
      FlutterError(code: "oops", message: "bad", stacktrace: nil)
    )
    XCTAssertNil(try envelope._directlyEncoded())
    let encoded = try FlutterStandardMessageCodec.shared.encode(envelope)
    let decoded: FlutterEnvelope<AnyFlutterStandardCodable> =
      try FlutterStandardMessageCodec.shared.decode(encoded)
    guard case let .failure(error) = decoded else {
      return XCTFail("expected a failure envelope")
    }
    XCTAssertEqual(error.code, "oops")
  }

  // MARK: - round trips

  /// Maps included: compares values rather than bytes, so dictionary ordering
  /// doesn't matter.
  func testRoundTripsEveryShape() throws {
    for value in Self.everyShapeExceptMaps + Self.maps {
      let encoded = try FlutterStandardMessageCodec.shared.encode(value)
      let decoded: AnyFlutterStandardCodable =
        try FlutterStandardMessageCodec.shared.decode(encoded)
      XCTAssertEqual(decoded, value)
    }
  }

  func testEnvelopeRoundTripsEveryShape() throws {
    for value in Self.everyShapeExceptMaps + Self.maps {
      let encoded = try FlutterStandardMessageCodec.shared.encode(
        FlutterEnvelope.success(value)
      )
      let decoded: FlutterEnvelope<AnyFlutterStandardCodable> =
        try FlutterStandardMessageCodec.shared.decode(encoded)
      guard case let .success(payload) = decoded else {
        return XCTFail("expected a success envelope for \(value)")
      }
      // `.success(nil)` and `.success(.nil)` are the same two bytes on the
      // wire, so the decoder can only ever produce the former. Pre-existing
      // and inherent to the format, not affected by how the bytes are written.
      if value == .nil {
        XCTAssertNil(payload)
      } else {
        XCTAssertEqual(payload, value)
      }
    }
  }

  // MARK: - alignment

  /// The trap this file exists to catch.
  ///
  /// Alignment padding is measured from the start of the *message*, not from
  /// the start of whatever buffer the writer happens to be filling. A writer
  /// that measures locally still passes every scalar test above — the
  /// divergence only appears once an aligned value follows other bytes at a
  /// non-8-aligned offset, which is exactly what the envelope discriminant
  /// creates.
  func testAlignmentIsMeasuredFromStartOfMessage() throws {
    // discriminant (1 byte) + float64 tag (1 byte) => 6 bytes of padding
    let envelope = FlutterEnvelope.success(AnyFlutterStandardCodable.float64(1))
    let direct = try XCTUnwrap(envelope._directlyEncoded())
    XCTAssertEqual(
      [UInt8](direct),
      [0x00, 0x06, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xF0, 0x3F]
    )
    XCTAssertEqual([UInt8](direct), try [UInt8](encodedViaCodable(envelope)))

    // and inside a list, where the preceding element leaves an odd offset
    let list = AnyFlutterStandardCodable.list([.int32(1), .float64(1)])
    XCTAssertEqual(
      try [UInt8](XCTUnwrap(list._directlyEncoded())),
      try [UInt8](encodedViaCodable(list))
    )
  }

  /// Typed data aligns to its element stride, on the same message-relative rule.
  func testTypedDataAlignmentInsideEnvelope() throws {
    for value: AnyFlutterStandardCodable in [
      .int32Data([1, 2]),
      .int64Data([1, 2]),
      .float32Data([1, 2]),
      .float64Data([1, 2]),
    ] {
      let envelope = FlutterEnvelope.success(value)
      let direct = try XCTUnwrap(envelope._directlyEncoded())
      XCTAssertEqual(
        [UInt8](direct),
        try [UInt8](encodedViaCodable(envelope)),
        "alignment diverged for \(value) at a non-zero message offset"
      )
    }
  }

  // MARK: - helpers

  /// Encodes via the `Codable` path, bypassing the direct-writer fast path so
  /// the two can be compared.
  private func encodedViaCodable(_ value: some Encodable) throws -> Data {
    let state = FlutterStandardEncodingState()
    try state.encode(value, codingPath: [])
    return state.data
  }

  private func assertWrites(
    _ value: AnyFlutterStandardCodable,
    as expected: [UInt8],
    file: StaticString = #filePath,
    line: UInt = #line
  ) throws {
    var buffer = [UInt8]()
    try value.write(into: &buffer)
    XCTAssertEqual(buffer, expected, file: file, line: line)

    // and the same bytes when the buffer is a `Data` rather than an array
    var data = Data()
    try value.write(into: &data)
    XCTAssertEqual([UInt8](data), expected, file: file, line: line)
  }

  private static let everyShapeExceptMaps: [AnyFlutterStandardCodable] = [
    .nil,
    .true,
    .false,
    .int32(0),
    .int32(.min),
    .int32(.max),
    .int64(0),
    .int64(.min),
    .int64(.max),
    .float64(0),
    .float64(-42.5),
    .float64(.pi),
    .string(""),
    .string("plain"),
    .string("\u{263A} unicode \u{1F600}"),
    .string(String(repeating: "x", count: 300)), // size escape
    .uint8Data([]),
    .uint8Data([1, 2, 3]),
    .int32Data([]),
    .int32Data([1, -1]),
    .int64Data([]),
    .int64Data([1, -1]),
    .float32Data([]),
    .float32Data([1.5, -1.5]),
    .float64Data([]),
    .float64Data([1.5, -1.5]),
    .list([]),
    .list([.int32(1), .string("a"), .float64(2)]),
    .list([.list([.list([.true])])]),
    .list([.uint8Data([1, 2]), .float64Data([1])]),
  ]

  private static let maps: [AnyFlutterStandardCodable] = [
    .map([:]),
    .map([.string("a"): .int32(1)]),
    .map([.int32(1): .list([.true, .nil])]),
  ]
}
