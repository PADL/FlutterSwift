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

import BinaryParsing

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// Byte-level readers for the Flutter standard message codec, as methods on
// `BinaryParsing.ParserSpan` — the span *is* the cursor, so a whole message is
// read from one borrowed view of the buffer instead of a `Data` subscript (and
// a re-derived `RawSpan`) per token.
//
// The engine puts these primitives on the reader object rather than in a
// namespace: `readSize`, `readAlignment:` and `readUTF8` are instance methods
// on `FlutterStandardReader` in FlutterCodecs.h, and `ByteStreamReader` plays
// the same role in the C++ client wrapper. `ParserSpan` is this package's
// reader, so they belong on it.
//
// Failures are raised as `ParsingError`. Codec-level failures travel in its
// `userError` payload as a `FlutterSwiftError` so that callers keep seeing this
// package's error vocabulary; `FlutterSwiftError.init(_:)` unwraps them at the
// boundary.

extension Endianness {
  /// The host's byte order.
  ///
  /// The standard codec is host-ordered rather than network-ordered: both the
  /// engine and the Dart `WriteBuffer` write scalars and typed data in the
  /// host's byte order, so that typed data can be `memcpy`d on both sides.
  static var host: Endianness {
    // constant-folds; `bigEndian` is the identity only on a big-endian host
    Endianness(isBigEndian: 1.bigEndian == 1)
  }
}

extension FlutterStandardField {
  /// Reads and validates the one-byte type tag that prefixes every value.
  init(parsing input: inout ParserSpan) throws(ParsingError) {
    let byte = try UInt8(parsing: &input)
    guard let field = Self(rawValue: byte) else {
      throw ParsingError(userError: FlutterSwiftError.unknownStandardFieldType(byte))
    }
    self = field
  }
}

extension ParserSpan {
  /// Reads a type tag and requires it to be `expected`.
  mutating func parseAssertedField(
    _ expected: FlutterStandardField
  ) throws(ParsingError) {
    let field = try FlutterStandardField(parsing: &self)
    guard field == expected else {
      throw ParsingError(userError: FlutterSwiftError.unexpectedStandardFieldType(field))
    }
  }

  /// Reads the codec's variable-length size prefix.
  ///
  /// Sizes below 254 are stored in the prefix byte itself; 254 escapes to a
  /// `UInt16` and 255 to a `UInt32`, both in host byte order.
  mutating func parseSize() throws(ParsingError) -> Int {
    let byte = try UInt8(parsing: &self)
    switch byte {
    case 254:
      return try Int(UInt16(parsing: &self, endianness: .host))
    case 255:
      let size = try UInt32(parsing: &self, endianness: .host)
      guard let size = Int(exactly: size) else {
        throw ParsingError(userError: FlutterSwiftError.variableSizedTypeTooBig)
      }
      return size
    default:
      return Int(byte)
    }
  }

  /// Consumes the padding that aligns the next read to `alignment`.
  ///
  /// Padding is measured from the start of the *message*, not from the bytes
  /// remaining, which is exactly what `ParserSpan.startPosition` reports —
  /// it stays absolute within the original region even across slicing.
  mutating func parseAlignment(
    to alignment: Int
  ) throws(ParsingError) {
    let mod = startPosition % alignment
    guard mod != 0 else { return }
    let padding = alignment - mod
    guard padding <= count else {
      throw ParsingError(userError: FlutterSwiftError.invalidAlignment)
    }
    try seek(toRelativeOffset: padding)
  }

  /// Reads a float64, including the padding that aligns it.
  mutating func parseFloat64() throws(ParsingError) -> Double {
    try parseAlignment(to: MemoryLayout<Double>.alignment)
    return try Double(bitPattern: UInt64(parsing: &self, endianness: .host))
  }

  /// Reads a length-prefixed byte blob.
  mutating func parseData() throws(ParsingError) -> Data {
    let length = try parseSize()
    return try Data(parsing: &self, byteCount: length)
  }

  /// Reads a length-prefixed UTF-8 string.
  ///
  /// `String(parsingUTF8:count:)` would repair invalid UTF-8 with U+FFFD; the
  /// codec treats malformed input as a decode failure, so validate instead.
  mutating func parseString() throws(ParsingError) -> String {
    let length = try parseSize()
    let slice = try sliceSpan(byteCount: length)
    guard let value = slice.withUnsafeBytes({ String(validating: $0, as: UTF8.self) }) else {
      let raw = slice.withUnsafeBytes { Data($0) }
      throw ParsingError(userError: FlutterSwiftError.stringNotDecodable(raw))
    }
    return value
  }

  /// Bulk-reads a typed-data array with a single `memcpy`.
  ///
  /// Mirrors `writeTypedArray`: typed data is stored in host byte order, so the
  /// wire bytes already are the elements' in-memory representation. The
  /// destination array's storage is freshly allocated and therefore correctly
  /// aligned, and `copyMemory` tolerates an unaligned source, so this is safe
  /// wherever the message happens to sit.
  mutating func parseTypedArray<T: BitwiseCopyable>(
    of type: T.Type
  ) throws(ParsingError) -> [T] {
    let count = try parseSize()
    try parseAlignment(to: MemoryLayout<T>.stride)
    let (byteCount, overflow) = count.multipliedReportingOverflow(
      by: MemoryLayout<T>.stride
    )
    guard !overflow else {
      throw ParsingError(userError: FlutterSwiftError.variableSizedTypeTooBig)
    }
    let slice = try sliceSpan(byteCount: byteCount)
    return slice.withUnsafeBytes { source in
      [T](unsafeUninitializedCapacity: count) { destination, initializedCount in
        if count > 0 {
          UnsafeMutableRawBufferPointer(destination).copyMemory(from: source)
        }
        initializedCount = count
      }
    }
  }
}

extension FlutterSwiftError {
  /// Recovers this package's error vocabulary from a `ParsingError`.
  ///
  /// Codec-level failures are carried through as `userError`; everything else
  /// is a bounds or representability failure raised by `BinaryParsing` itself.
  init(_ error: ParsingError) {
    if let error = error.userError as? FlutterSwiftError {
      self = error
    } else if error.status == .insufficientData {
      self = .eofTooEarly
    } else {
      self = .integerOutOfRange
    }
  }
}
