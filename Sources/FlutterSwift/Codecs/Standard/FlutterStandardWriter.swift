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

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// Byte-level writers for the Flutter standard message codec: the mirror image
// of `FlutterStandardReader.swift`, so the grammar — sizes, alignment, strings,
// typed data — has exactly one implementation on each side of the wire.
//
// `FlutterStandardEncodingState` drives these for the `Codable` path and
// `AnyFlutterStandardCodable.write(into:)` drives them directly.

/// A byte sink the standard-codec writers write to.
///
/// The write-side counterpart of `BinaryParsing.ParserSpan`, and the analogue
/// of the engine's own `ByteStreamWriter` (`byte_streams.h` in the C++ client
/// wrapper), whose `WriteByte`/`WriteBytes` this mirrors.
///
/// Alignment padding is measured from the start of the *message*, so a
/// conforming writer must begin at message offset zero: `writtenByteCount` is
/// taken to be the number of bytes written so far in the current message, the
/// way the readers key off `ParserSpan.startPosition`.
protocol FlutterStandardByteStreamWriter {
  var writtenByteCount: Int { get }
  mutating func writeByte(_ byte: UInt8)
  mutating func writeBytes(_ bytes: UnsafeRawBufferPointer)
  mutating func writeZeros(count: Int)
  mutating func reserveCapacity(_ capacity: Int)
}

extension Array: FlutterStandardByteStreamWriter where Element == UInt8 {
  var writtenByteCount: Int {
    count
  }

  mutating func writeByte(_ byte: UInt8) {
    append(byte)
  }

  mutating func writeBytes(_ bytes: UnsafeRawBufferPointer) {
    append(contentsOf: bytes)
  }

  mutating func writeZeros(count: Int) {
    append(contentsOf: repeatElement(0, count: count))
  }
}

extension Data: FlutterStandardByteStreamWriter {
  var writtenByteCount: Int {
    count
  }

  mutating func writeByte(_ byte: UInt8) {
    append(byte)
  }

  mutating func writeBytes(_ bytes: UnsafeRawBufferPointer) {
    append(contentsOf: bytes)
  }

  mutating func writeZeros(count: Int) {
    append(Data(repeating: 0, count: count))
  }
}

/// The codec's grammar, as methods on the writer itself.
///
/// This follows the engine, where the primitives belong to the byte sink rather
/// than to a free-floating namespace: `ByteStreamWriter` declares `WriteByte`,
/// `WriteBytes` and `WriteAlignment` in the C++ client wrapper, and
/// `FlutterStandardWriter` carries `writeByte:`/`writeSize:`/`writeAlignment:`
/// in FlutterCodecs.h.
extension FlutterStandardByteStreamWriter {
  /// Writes the one-byte type tag that prefixes every value.
  mutating func writeField(_ field: FlutterStandardField) {
    writeByte(field.rawValue)
  }

  /// Writes the codec's variable-length size prefix.
  ///
  /// Sizes below 254 are stored in the prefix byte itself; 254 escapes to a
  /// `UInt16` and 255 to a `UInt32`, both in host byte order.
  ///
  /// The bounds are compared heterogeneously rather than converted to `Int`:
  /// `Int(UInt32.max)` does not fit a 32-bit `Int`, so converting would trap on
  /// armv7. Comparing directly also makes the final branch correctly
  /// unreachable there, where `size` cannot exceed `UInt32.max` to begin with.
  mutating func writeSize(_ size: Int) throws(FlutterSwiftError) {
    if size < 254 {
      writeByte(UInt8(size))
    } else if size <= UInt16.max {
      writeByte(254)
      withUnsafeBytes(of: UInt16(size)) { writeBytes($0) }
    } else if size <= UInt32.max {
      writeByte(255)
      withUnsafeBytes(of: UInt32(size)) { writeBytes($0) }
    } else {
      throw FlutterSwiftError.variableSizedTypeTooBig
    }
  }

  /// Writes the padding that aligns the next write to `alignment`.
  mutating func writeAlignment(_ alignment: Int) {
    let mod = writtenByteCount % alignment
    // no padding when already aligned: `alignment - mod` would be a whole block
    if mod != 0 {
      writeZeros(count: alignment - mod)
    }
  }

  mutating func writeInt32(_ value: Int32) {
    writeField(.int32)
    withUnsafeBytes(of: value) { writeBytes($0) }
  }

  mutating func writeInt64(_ value: Int64) {
    writeField(.int64)
    withUnsafeBytes(of: value) { writeBytes($0) }
  }

  /// Writes a float64, including the padding that aligns it.
  mutating func writeFloat64(_ value: Double) {
    writeField(.float64)
    writeAlignment(MemoryLayout<Double>.alignment)
    withUnsafeBytes(of: value.bitPattern) { writeBytes($0) }
  }

  /// Writes a length-prefixed UTF-8 string.
  ///
  /// `withUTF8` yields the string's own storage for native strings, so this
  /// avoids the intermediate `Data` that `String.data(using:)` allocates.
  mutating func writeString(_ value: String) throws(FlutterSwiftError) {
    writeField(.string)
    try writeSize(value.utf8.count)
    var value = value
    value.withUTF8 { writeBytes(UnsafeRawBufferPointer($0)) }
  }

  /// Writes a length-prefixed byte blob, tagged as `uint8Data`.
  mutating func writeData(_ value: Data) throws(FlutterSwiftError) {
    writeField(.uint8Data)
    try writeSize(value.count)
    value.withUnsafeBytes { writeBytes($0) }
  }

  /// Bulk-writes a typed-data array in a single buffer append.
  ///
  /// The Flutter standard codec stores typed data (`Uint8List`, `Int32List`,
  /// `Int64List`, `Float32List`, `Float64List`) in host byte order — the engine
  /// `memcpy`s the backing store on its side too — so an element's in-memory
  /// representation is exactly its wire representation. Copying the array's raw
  /// storage once is therefore equivalent to writing each element via
  /// `withUnsafeBytes(of:)`, but performs O(1) buffer operations instead of
  /// O(n) appends (each of which re-checks bounds and copy-on-write ownership).
  mutating func writeTypedArray<T>(
    _ field: FlutterStandardField,
    _ value: [T]
  ) throws(FlutterSwiftError) {
    writeField(field)
    try writeSize(value.count)
    writeAlignment(MemoryLayout<T>.stride)
    value.withUnsafeBytes { writeBytes($0) }
  }
}
