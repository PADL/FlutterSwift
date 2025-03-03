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

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The internal state used by the decoders.
final class FlutterStandardDecodingState {
  private var data: Data

  var isAtEnd: Bool { data.isEmpty }

  init(data: Data) {
    self.data = data
  }

  fileprivate func peekStandardField() throws -> FlutterStandardField {
    guard let byte = data.first else {
      throw FlutterSwiftError.eofTooEarly
    }
    guard let fieldType = FlutterStandardField(rawValue: byte) else {
      throw FlutterSwiftError.unknownStandardFieldType(byte)
    }
    return fieldType
  }

  private func decodeStandardField() throws -> FlutterStandardField {
    guard let byte = data.popFirst() else {
      throw FlutterSwiftError.eofTooEarly
    }
    guard let fieldType = FlutterStandardField(rawValue: byte) else {
      throw FlutterSwiftError.unknownStandardFieldType(byte)
    }
    return fieldType
  }

  @inlinable
  func assertStandardField(_ assertedFieldType: FlutterStandardField) throws {
    let fieldType = try decodeStandardField()
    guard fieldType == assertedFieldType else {
      throw FlutterSwiftError.unexpectedStandardFieldType(fieldType)
    }
  }

  private func decodeSize() throws -> Int {
    guard let byte = data.popFirst() else {
      throw FlutterSwiftError.eofTooEarly
    }
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

  private func assertAlignment(_ alignment: Int) throws {
    let mod = data.count % alignment
    guard data.count >= mod else {
      throw FlutterSwiftError.invalidAlignment
    }
    data.removeFirst(mod)
  }

  func decodeData() throws -> Data {
    try assertStandardField(.uint8Data)
    let length = try decodeSize()
    let raw = data.prefix(length)
    guard raw.count == length else {
      throw FlutterSwiftError.eofTooEarly
    }
    data.removeFirst(length)
    return Data(raw)
  }

  @inlinable
  func decodeDiscriminant() throws -> UInt8 {
    guard let byte = data.popFirst() else {
      throw FlutterSwiftError.eofTooEarly
    }
    return byte
  }

  func decodeNil() throws -> Bool {
    let fieldType = try peekStandardField()
    if fieldType == .nil {
      data.removeFirst()
      return true
    } else {
      return false
    }
  }

  private func decodeArray<Value>(
    _ fieldType: FlutterStandardField,
    _ block: () throws -> Value
  ) throws -> [Value] {
    try assertStandardField(fieldType)
    let count = try decodeSize()
    try assertAlignment(MemoryLayout<Value>.stride)
    var values = [Value]()
    values.reserveCapacity(count)
    for _ in 0..<count {
      try values.append(block())
    }
    return values
  }

  func decodeArray(_ type: UInt8.Type) throws -> [UInt8] {
    try decodeArray(.uint8Data) {
      try decodeInteger(type)
    }
  }

  func decodeArray(_ type: Int32.Type) throws -> [Int32] {
    try decodeArray(.int32Data) {
      try decodeInteger(type)
    }
  }

  func decodeArray(_ type: Int64.Type) throws -> [Int64] {
    try decodeArray(.int64Data) {
      try decodeInteger(type)
    }
  }

  func decodeArray(_ type: Double.Type) throws -> [Double] {
    try decodeArray(.float64Data) {
      let bitPattern = try decodeInteger(UInt64.self)
      return Double(bitPattern: bitPattern)
    }
  }

  func decodeArray(_ type: Float.Type) throws -> [Float] {
    try decodeArray(.float32Data) {
      let bitPattern = try decodeInteger(UInt32.self)
      return Float(bitPattern: bitPattern)
    }
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

  private func decodeInteger<Integer>(_ type: Integer.Type) throws -> Integer
    where Integer: FixedWidthInteger
  {
    let byteWidth = Integer.bitWidth / 8
    guard data.count >= byteWidth else {
      throw FlutterSwiftError.eofTooEarly
    }
    let value = data.withUnsafeBytes {
      $0.loadUnaligned(as: type)
    }
    data.removeFirst(byteWidth)
    return value
  }

  func decode(_ type: Bool.Type) throws -> Bool {
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

  func decode(_ type: String.Type) throws -> String {
    try assertStandardField(.string)
    let length = try decodeSize()
    let raw = data.prefix(length)
    guard raw.count == length else {
      throw FlutterSwiftError.eofTooEarly
    }
    data.removeFirst(length)
    guard let value = String(data: raw, encoding: .utf8) else {
      throw FlutterSwiftError.stringNotDecodable(raw)
    }
    return value
  }

  func decode(_ type: Double.Type) throws -> Double {
    try assertStandardField(.float64)
    try assertAlignment(MemoryLayout<Double>.alignment)
    return try Double(bitPattern: decodeInteger(UInt64.self))
  }

  func decode(_ type: Float.Type) throws -> Float {
    try Float(decode(Double.self))
  }

  func decode(_ type: Int.Type) throws -> Int {
    if MemoryLayout<Int>.size == 8 {
      return try Int(decode(Int64.self))
    } else if MemoryLayout<Int>.size == 4 {
      return try Int(decode(Int32.self))
    } else {
      fatalError("unsupporterd UInt.bitWidth")
    }
  }

  func decode(_ type: Int8.Type) throws -> Int8 {
    guard let value = try Int8(exactly: decode(Int32.self)) else {
      throw FlutterSwiftError.integerOutOfRange
    }
    return value
  }

  func decode(_ type: Int16.Type) throws -> Int16 {
    guard let value = try Int16(exactly: decode(Int32.self)) else {
      throw FlutterSwiftError.integerOutOfRange
    }
    return value
  }

  func decode(_ type: Int32.Type) throws -> Int32 {
    try assertStandardField(.int32)
    return try decodeInteger(type)
  }

  func decode(_ type: Int64.Type) throws -> Int64 {
    try assertStandardField(.int64)
    return try decodeInteger(type)
  }

  func decode(_ type: UInt.Type) throws -> UInt {
    guard let value = try UInt(exactly: decodeInteger(Int.self)) else {
      throw FlutterSwiftError.integerOutOfRange
    }
    return value
  }

  func decode(_ type: UInt8.Type) throws -> UInt8 {
    guard let value = try UInt8(exactly: decode(Int32.self)) else {
      throw FlutterSwiftError.integerOutOfRange
    }
    return value
  }

  func decode(_ type: UInt16.Type) throws -> UInt16 {
    guard let value = try UInt16(exactly: decode(Int32.self)) else {
      throw FlutterSwiftError.integerOutOfRange
    }
    return value
  }

  func decode(_ type: UInt32.Type) throws -> UInt32 {
    try UInt32(bitPattern: decode(Int32.self))
  }

  func decode(_ type: UInt64.Type) throws -> UInt64 {
    try UInt64(bitPattern: decode(Int64.self))
  }

  func decode<T>(_ type: T.Type, codingPath: [any CodingKey]) throws -> T where T: Decodable {
    try FlutterStandardDecodingState.decode(type, state: self, codingPath: [])
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

extension AnyFlutterStandardCodable: Decodable {
  public init(from decoder: any Decoder) throws {
    guard let decoder = decoder as? FlutterStandardDecoderImpl else {
      throw FlutterSwiftError.fieldNotDecodable
    }

    let container = try decoder
      .singleValueContainer() as! SingleValueFlutterStandardDecodingContainer

    switch try container.state.peekStandardField() {
    case .nil:
      try container.state.assertStandardField(.nil)
      self = .nil
    case .true:
      fallthrough
    case .false:
      let b = try container.state.decode(Bool.self)
      self = b ? .true : .false
    case .int32:
      self = try .int32(container.state.decode(Int32.self))
    case .int64:
      self = try .int64(container.state.decode(Int64.self))
    case .float64:
      self = try .float64(container.state.decode(Double.self))
    case .string:
      self = try .string(container.state.decode(String.self))
    case .uint8Data:
      self = try .uint8Data(container.state.decodeArray(UInt8.self))
    case .int32Data:
      self = try .int32Data(container.state.decodeArray(Int32.self))
    case .int64Data:
      self = try .int64Data(container.state.decodeArray(Int64.self))
    case .float32Data:
      self = try .float32Data(container.state.decodeArray(Float.self))
    case .float64Data:
      self = try .float64Data(container.state.decodeArray(Double.self))
    case .list:
      self = try .list(container.state.decode([Self].self, codingPath: []))
    case .map:
      self = try .map(container.state.decode([Self: Self].self, codingPath: []))
    default:
      throw FlutterSwiftError.fieldNotDecodable
    }
  }
}
