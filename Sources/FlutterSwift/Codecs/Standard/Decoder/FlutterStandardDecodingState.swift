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
///
/// Holds a *borrowed* view of the message rather than its own `Data`. The
/// buffer belongs to `FlutterStandardDecoder.decode`, which keeps it alive
/// across the whole decode; this is what lets the codec read a message without
/// first copying it, and without a `Data` subscript per token.
///
/// Byte-level reads go through `withParser`, which lends the cursor to
/// `BinaryParsing` and takes back wherever the parse finished. The grammar
/// itself lives on `ParserSpan` (`FlutterStandardReader.swift`) and is shared with
/// `AnyFlutterStandardCodable`'s direct (non-`Codable`) parser, so there is one
/// implementation of sizes, alignment, strings and typed data rather than two.
///
/// - Important: decoding containers must not outlive the `decode` call that
///   created them — the same constraint `JSONDecoder` places on its own buffer
///   view. Nothing in `Codable`'s API encourages that, but a `Decodable`
///   implementation that stored its `Decoder` away for later would be reading
///   freed memory.
final class FlutterStandardDecodingState {
  private let bytes: UnsafeRawBufferPointer
  private var offset: Int

  var isAtEnd: Bool {
    offset >= bytes.count
  }

  init(bytes: UnsafeRawBufferPointer) {
    self.bytes = bytes
    offset = 0
  }

  /// Runs `body` against a parser positioned at the cursor, then adopts the
  /// cursor the parse left behind.
  ///
  /// Rebuilding the span per call costs a few integer operations, which is the
  /// price of `ParserSpan` being non-escapable: it cannot be stored here, nor
  /// handed to the escapable `Decoder` and container types. It is still far
  /// cheaper than the `Data` subscripting it replaces, and a whole nested
  /// value — a list, a map, an `AnyFlutterStandardCodable` — is parsed inside
  /// a single call.
  private func withParser<T>(
    _ body: (inout ParserSpan) throws(ParsingError) -> T
  ) throws(FlutterSwiftError) -> T {
    let bytes = bytes
    do {
      var span = ParserSpan(_unsafeBytes: bytes)
      try span.seek(toAbsoluteOffset: offset)
      let value = try body(&span)
      offset = span.startPosition
      return value
    } catch {
      throw FlutterSwiftError(error)
    }
  }

  private func peekStandardField() throws(FlutterSwiftError) -> FlutterStandardField {
    guard offset < bytes.count else {
      throw FlutterSwiftError.eofTooEarly
    }
    let byte = bytes[offset]
    guard let fieldType = FlutterStandardField(rawValue: byte) else {
      throw FlutterSwiftError.unknownStandardFieldType(byte)
    }
    return fieldType
  }

  func assertStandardField(_ assertedFieldType: FlutterStandardField) throws(FlutterSwiftError) {
    try withParser { span throws(ParsingError) in
      try parseAssertedField(&span, assertedFieldType)
    }
  }

  private func decodeSize() throws(FlutterSwiftError) -> Int {
    try withParser { span throws(ParsingError) in
      try parseSize(&span)
    }
  }

  func decodeData() throws(FlutterSwiftError) -> Data {
    try withParser { span throws(ParsingError) in
      try parseAssertedField(&span, .uint8Data)
      return try parseData(&span)
    }
  }

  func decodeDiscriminant() throws(FlutterSwiftError) -> UInt8 {
    guard offset < bytes.count else {
      throw FlutterSwiftError.eofTooEarly
    }
    let byte = bytes[offset]
    offset += 1
    return byte
  }

  func decodeNil() throws(FlutterSwiftError) -> Bool {
    guard try peekStandardField() == .nil else {
      return false
    }
    offset += 1
    return true
  }

  private func decodeTypedArray<T: BitwiseCopyable>(
    _ fieldType: FlutterStandardField,
    _ type: T.Type
  ) throws(FlutterSwiftError) -> [T] {
    try withParser { span throws(ParsingError) in
      try parseAssertedField(&span, fieldType)
      return try parseTypedArray(&span, of: type)
    }
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

  private func decodeMap<Key: Hashable & Codable, Value: Codable>(
    _ type: KeyValuePair<Key, Value>.Type,
    codingPath: [CodingKey]
  ) throws -> [Key: Value] {
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

  func decode(_ type: Bool.Type) throws(FlutterSwiftError) -> Bool {
    try withParser { span throws(ParsingError) in
      let fieldType = try FlutterStandardField(parsing: &span)
      switch fieldType {
      case .true:
        return true
      case .false:
        return false
      default:
        throw ParsingError(userError: FlutterSwiftError.unexpectedStandardFieldType(fieldType))
      }
    }
  }

  func decode(_ type: String.Type) throws(FlutterSwiftError) -> String {
    try withParser { span throws(ParsingError) in
      try parseAssertedField(&span, .string)
      return try parseString(&span)
    }
  }

  func decode(_ type: Double.Type) throws(FlutterSwiftError) -> Double {
    try withParser { span throws(ParsingError) in
      try parseAssertedField(&span, .float64)
      return try parseFloat64(&span)
    }
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
    try withParser { span throws(ParsingError) in
      try parseAssertedField(&span, .int32)
      return try Int32(parsing: &span, endianness: .host)
    }
  }

  func decode(_ type: Int64.Type) throws(FlutterSwiftError) -> Int64 {
    try withParser { span throws(ParsingError) in
      try parseAssertedField(&span, .int64)
      return try Int64(parsing: &span, endianness: .host)
    }
  }

  func decode(_ type: UInt.Type) throws(FlutterSwiftError) -> UInt {
    // `encode(UInt)` widens to `Int`, so read back the same way — reading a
    // bare platform-width integer here would consume the type tag as data.
    guard let value = try UInt(exactly: decode(Int.self)) else {
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

  func decode<T: Decodable>(_ type: T.Type, codingPath: [any CodingKey]) throws -> T {
    try FlutterStandardDecodingState.decode(type, state: self, codingPath: [])
  }

  /// Parse a dynamically typed value at the current position.
  ///
  /// Nested values are parsed within this one span, so an arbitrarily deep
  /// value costs a single `withParser` call — no decoder, no containers.
  func decodeAnyValue() throws(FlutterSwiftError) -> AnyFlutterStandardCodable {
    try withParser { span throws(ParsingError) in
      try AnyFlutterStandardCodable(parsingValue: &span)
    }
  }

  static func decode<T: Decodable>(
    _ type: T.Type,
    state: FlutterStandardDecodingState,
    codingPath: [any CodingKey]
  ) throws -> T {
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
