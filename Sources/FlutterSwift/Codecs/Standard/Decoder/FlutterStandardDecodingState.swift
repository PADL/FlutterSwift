// MIT License
//
// Copyright (c) 2023-2025 PADL Software Pty Ltd
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

import BinaryParsing

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The internal state used by the decoders.
final class FlutterStandardDecodingState {
  private let data: Data
  private var offset: Int

  var isAtEnd: Bool { offset >= data.count }

  init(data: Data) {
    self.data = data
    offset = 0
  }

  private var remaining: Int { data.count - offset }

  fileprivate func peekStandardField() throws(FlutterSwiftError) -> FlutterStandardField {
    guard offset < data.count else {
      throw FlutterSwiftError.eofTooEarly
    }
    let byte = data[data.startIndex + offset]
    guard let fieldType = FlutterStandardField(rawValue: byte) else {
      throw FlutterSwiftError.unknownStandardFieldType(byte)
    }
    return fieldType
  }

  private func decodeStandardField() throws(FlutterSwiftError) -> FlutterStandardField {
    guard offset < data.count else {
      throw FlutterSwiftError.eofTooEarly
    }
    let byte = data[data.startIndex + offset]
    offset += 1
    guard let fieldType = FlutterStandardField(rawValue: byte) else {
      throw FlutterSwiftError.unknownStandardFieldType(byte)
    }
    return fieldType
  }

  @inlinable
  func assertStandardField(_ assertedFieldType: FlutterStandardField) throws(FlutterSwiftError) {
    let fieldType = try decodeStandardField()
    guard fieldType == assertedFieldType else {
      throw FlutterSwiftError.unexpectedStandardFieldType(fieldType)
    }
  }

  private func decodeSize() throws(FlutterSwiftError) -> Int {
    guard offset < data.count else {
      throw FlutterSwiftError.eofTooEarly
    }
    let byte = data[data.startIndex + offset]
    offset += 1
    if byte < 254 {
      return Int(byte)
    } else if byte == 254 {
      return try Int(decodeInteger(UInt16.self))
    } else if byte == 255 {
      return try Int(decodeInteger(UInt32.self))
    } else {
      fatalError("notreached")
    }
  }

  private func assertAlignment(_ alignment: Int) throws(FlutterSwiftError) {
    // padding is relative to the read position, not the bytes remaining
    let mod = offset % alignment
    guard mod == 0 || remaining >= alignment - mod else {
      throw FlutterSwiftError.invalidAlignment
    }
    if mod != 0 {
      offset += alignment - mod
    }
  }

  func decodeData() throws(FlutterSwiftError) -> Data {
    try assertStandardField(.uint8Data)
    let length = try decodeSize()
    let start = data.startIndex + offset
    guard remaining >= length else {
      throw FlutterSwiftError.eofTooEarly
    }
    let raw = data[start..<(start + length)]
    offset += length
    return Data(raw)
  }

  @inlinable
  func decodeDiscriminant() throws(FlutterSwiftError) -> UInt8 {
    guard offset < data.count else {
      throw FlutterSwiftError.eofTooEarly
    }
    let byte = data[data.startIndex + offset]
    offset += 1
    return byte
  }

  func decodeNil() throws(FlutterSwiftError) -> Bool {
    let fieldType = try peekStandardField()
    if fieldType == .nil {
      offset += 1
      return true
    } else {
      return false
    }
  }

  /// Bulk-decode a typed-data array with a single `memcpy`.
  ///
  /// Mirrors `FlutterStandardEncodingState.encodeTypedArray`: the standard codec
  /// stores typed data in host byte order, so the wire bytes are the elements'
  /// in-memory representation. We copy the whole region into a freshly allocated
  /// (and therefore correctly aligned) array buffer in one operation instead of
  /// reconstructing each element with a separate unaligned load. `copyBytes`
  /// tolerates an unaligned source, so this is safe regardless of where the
  /// message buffer happens to sit in memory.
  private func decodeTypedArray<T: BitwiseCopyable>(
    _ fieldType: FlutterStandardField,
    _ type: T.Type
  ) throws(FlutterSwiftError) -> [T] {
    try assertStandardField(fieldType)
    let count = try decodeSize()
    try assertAlignment(MemoryLayout<T>.stride)
    let byteCount = count * MemoryLayout<T>.stride
    guard remaining >= byteCount else {
      throw FlutterSwiftError.eofTooEarly
    }
    let start = data.startIndex + offset
    let values = [T](unsafeUninitializedCapacity: count) { buffer, initializedCount in
      if count > 0 {
        data.copyBytes(
          to: UnsafeMutableRawBufferPointer(buffer),
          from: start..<(start + byteCount)
        )
      }
      initializedCount = count
    }
    offset += byteCount
    return values
  }

  func decodeArray(_ type: UInt8.Type) throws(FlutterSwiftError) -> [UInt8] {
    try decodeTypedArray(.uint8Data, type)
  }

  func decodeArray(_ type: Int32.Type) throws(FlutterSwiftError) -> [Int32] {
    try decodeTypedArray(.int32Data, type)
  }

  func decodeArray(_ type: Int64.Type) throws(FlutterSwiftError) -> [Int64] {
    try decodeTypedArray(.int64Data, type)
  }

  func decodeArray(_ type: Double.Type) throws(FlutterSwiftError) -> [Double] {
    try decodeTypedArray(.float64Data, type)
  }

  func decodeArray(_ type: Float.Type) throws(FlutterSwiftError) -> [Float] {
    try decodeTypedArray(.float32Data, type)
  }

  func decodeList<Value: Decodable>(
    _ type: Value.Type,
    codingPath: [CodingKey]
  ) throws -> [Value] {
    try assertStandardField(.list)
    let count = try decodeSize()
    var values = [Value]()
    values.reserveCapacity(count)
    for _ in 0..<count {
      try values.append(decode(type, codingPath: codingPath))
    }
    return values
  }

  private func decodeMap<Key, Value>(
    _ type: KeyValuePair<Key, Value>.Type,
    codingPath: [CodingKey]
  ) throws -> [Key: Value] where Key: Hashable & Codable,
    Value: Codable
  {
    try assertStandardField(.map)
    let count = try decodeSize()
    var values = [Key: Value](minimumCapacity: count)
    for _ in 0..<count {
      let key = try decode(Key.self, codingPath: codingPath)
      let value = try decode(Value.self, codingPath: codingPath)
      values[key] = value
    }
    return values
  }

  private func decodeInteger<Integer>(_ type: Integer.Type) throws(FlutterSwiftError) -> Integer
    where Integer: FixedWidthInteger & BitwiseCopyable
  {
    let byteWidth = Integer.bitWidth / 8
    guard remaining >= byteWidth else {
      throw FlutterSwiftError.eofTooEarly
    }
    // Read directly from a borrowed `RawSpan` view of the message rather than
    // materialising a `Data` slice (with its retain/range bookkeeping) per
    // scalar. `offset` is measured from the logical start of the message, which
    // is exactly the span's origin.
    let value = data.bytes.unsafeLoadUnaligned(fromByteOffset: offset, as: type)
    offset += byteWidth
    return value
  }

  func decode(_ type: Bool.Type) throws(FlutterSwiftError) -> Bool {
    let fieldType = try decodeStandardField()
    switch fieldType {
    case .true:
      return true
    case .false:
      return false
    default:
      throw FlutterSwiftError.unexpectedStandardFieldType(fieldType)
    }
  }

  func decode(_ type: String.Type) throws(FlutterSwiftError) -> String {
    try assertStandardField(.string)
    let length = try decodeSize()
    let start = data.startIndex + offset
    guard remaining >= length else {
      throw FlutterSwiftError.eofTooEarly
    }
    let raw = data[start..<(start + length)]
    offset += length
    guard let value = String(data: raw, encoding: .utf8) else {
      throw FlutterSwiftError.stringNotDecodable(raw)
    }
    return value
  }

  func decode(_ type: Double.Type) throws(FlutterSwiftError) -> Double {
    try assertStandardField(.float64)
    try assertAlignment(MemoryLayout<Double>.alignment)
    return try Double(bitPattern: decodeInteger(UInt64.self))
  }

  func decode(_ type: Float.Type) throws(FlutterSwiftError) -> Float {
    try Float(decode(Double.self))
  }

  func decode(_ type: Int.Type) throws(FlutterSwiftError) -> Int {
    if MemoryLayout<Int>.size == 8 {
      return try Int(decode(Int64.self))
    } else if MemoryLayout<Int>.size == 4 {
      return try Int(decode(Int32.self))
    } else {
      fatalError("unsupporterd UInt.bitWidth")
    }
  }

  func decode(_ type: Int8.Type) throws(FlutterSwiftError) -> Int8 {
    guard let value = try Int8(exactly: decode(Int32.self)) else {
      throw FlutterSwiftError.integerOutOfRange
    }
    return value
  }

  func decode(_ type: Int16.Type) throws(FlutterSwiftError) -> Int16 {
    guard let value = try Int16(exactly: decode(Int32.self)) else {
      throw FlutterSwiftError.integerOutOfRange
    }
    return value
  }

  func decode(_ type: Int32.Type) throws(FlutterSwiftError) -> Int32 {
    try assertStandardField(.int32)
    return try decodeInteger(type)
  }

  func decode(_ type: Int64.Type) throws(FlutterSwiftError) -> Int64 {
    try assertStandardField(.int64)
    return try decodeInteger(type)
  }

  func decode(_ type: UInt.Type) throws(FlutterSwiftError) -> UInt {
    guard let value = try UInt(exactly: decodeInteger(Int.self)) else {
      throw FlutterSwiftError.integerOutOfRange
    }
    return value
  }

  func decode(_ type: UInt8.Type) throws(FlutterSwiftError) -> UInt8 {
    guard let value = try UInt8(exactly: decode(Int32.self)) else {
      throw FlutterSwiftError.integerOutOfRange
    }
    return value
  }

  func decode(_ type: UInt16.Type) throws(FlutterSwiftError) -> UInt16 {
    guard let value = try UInt16(exactly: decode(Int32.self)) else {
      throw FlutterSwiftError.integerOutOfRange
    }
    return value
  }

  func decode(_ type: UInt32.Type) throws(FlutterSwiftError) -> UInt32 {
    try UInt32(bitPattern: decode(Int32.self))
  }

  func decode(_ type: UInt64.Type) throws(FlutterSwiftError) -> UInt64 {
    try UInt64(bitPattern: decode(Int64.self))
  }

  func decode<T>(_ type: T.Type, codingPath: [any CodingKey]) throws -> T where T: Decodable {
    try FlutterStandardDecodingState.decode(type, state: self, codingPath: [])
  }

  /// Parse a dynamically typed value at the current position.
  ///
  /// Bridges the `Codable` path onto `AnyFlutterStandardCodable`'s
  /// `ParserSpan` parser. The span is taken over the whole message so that
  /// `startPosition` is measured from the same origin as `offset` — which the
  /// codec's alignment rules depend on — and the cursor is written back on the
  /// way out. Nested values are parsed within this one span, so an arbitrarily
  /// deep value costs a single borrow of the buffer.
  func decodeAnyValue() throws(FlutterSwiftError) -> AnyFlutterStandardCodable {
    do {
      return try data.withParserSpan { (span) throws(ParsingError) in
        try span.seek(toAbsoluteOffset: offset)
        let value = try AnyFlutterStandardCodable(parsingValue: &span)
        offset = span.startPosition
        return value
      }
    } catch {
      throw FlutterSwiftError(error)
    }
  }

  static func decode<T>(
    _ type: T.Type,
    state: FlutterStandardDecodingState,
    codingPath: [any CodingKey]
  ) throws -> T where T: Decodable {
    var count: Int?
    if let type = type as? any FlutterMapRepresentable.Type {
      try state.assertStandardField(.map)
      count = try state.decodeSize()
      let decoder = FlutterStandardDecoderImpl(
        state: state,
        codingPath: [],
        count: count
      )
      return try type.init(from: decoder) as! T
    } else {
      let value: T
      switch type {
      case is AnyFlutterStandardCodable.Type:
        // parsed directly, without a decoder or container
        value = try state.decodeAnyValue() as! T
      case is Data.Type:
        value = try state.decodeData() as! T
      case is [UInt8].Type:
        value = try state.decodeArray(UInt8.self) as! T
      case is [Int32].Type:
        value = try state.decodeArray(Int32.self) as! T
      case is [Int64].Type:
        value = try state.decodeArray(Int64.self) as! T
      case is [Float].Type:
        value = try state.decodeArray(Float.self) as! T
      case is [Double].Type:
        value = try state.decodeArray(Double.self) as! T
      case is any FlutterListRepresentable.Type:
        try state.assertStandardField(.list)
        count = try state.decodeSize()
        fallthrough
      default:
        value = try T(from: FlutterStandardDecoderImpl(
          state: state,
          codingPath: codingPath,
          count: count
        ))
      }
      return value
    }
  }
}
