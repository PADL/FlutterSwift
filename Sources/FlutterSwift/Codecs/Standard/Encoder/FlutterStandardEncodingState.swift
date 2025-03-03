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

import Foundation

final class FlutterStandardEncodingState {
  private(set) var data: Data = .init()

  init(data: Data = .init()) {
    self.data = data
  }

  private func encodeStandardField(_ fieldType: FlutterStandardField) throws {
    withUnsafeBytes(of: fieldType) { data += $0 }
  }

  private func encodeSize(_ size: Int) throws {
    if size < 254 {
      data += [UInt8(size)]
    } else if size <= UInt16.max {
      data += [254]
      withUnsafeBytes(of: UInt16(size)) { data += $0 }
    } else if size <= UInt32.max {
      data += [255]
      withUnsafeBytes(of: UInt32(size)) { data += $0 }
    } else {
      throw FlutterSwiftError.variableSizedTypeTooBig
    }
  }

  private func encodeAlignment(_ alignment: Int) throws {
    let mod = data.count % alignment
    data += Data(repeating: 0, count: alignment - mod)
  }

  private func encode(_ value: Data) throws {
    try encodeStandardField(.uint8Data)
    try encodeSize(value.count)
    data += data
  }

  @inlinable
  func encodeDiscriminant(_ value: UInt8) throws {
    data += [value]
  }

  func encodeNil() throws {
    try encodeStandardField(.nil)
  }

  fileprivate func encodeArray(_ value: [UInt8]) throws {
    try encodeStandardField(.uint8Data)
    try encodeSize(value.count)
    data += value
  }

  fileprivate func encodeArray(_ value: [Int32]) throws {
    try encodeStandardField(.int32Data)
    try encodeSize(value.count)
    try encodeAlignment(MemoryLayout<Int32>.stride)
    try value.forEach { try encodeInteger($0) }
  }

  fileprivate func encodeArray(_ value: [Int64]) throws {
    try encodeStandardField(.int32Data)
    try encodeSize(value.count)
    try encodeAlignment(MemoryLayout<Int64>.stride)
    try value.forEach { try encodeInteger($0) }
  }

  fileprivate func encodeArray(_ value: [Double]) throws {
    try encodeStandardField(.float64Data)
    try encodeSize(value.count)
    try encodeAlignment(MemoryLayout<Double>.stride)
    try value.forEach { try encodeInteger($0.bitPattern) }
  }

  fileprivate func encodeArray(_ value: [Float]) throws {
    try encodeStandardField(.float32Data)
    try encodeSize(value.count)
    try encodeAlignment(MemoryLayout<Float>.stride)
    try value.forEach { try encodeInteger($0.bitPattern) }
  }

  fileprivate func encodeList(
    _ value: some FlutterListRepresentable,
    codingPath: [CodingKey]
  ) throws {
    try encodeStandardField(.list)
    try encodeSize(value.count)
    try value.forEach {
      try encode($0, codingPath: codingPath)
    }
  }

  fileprivate func encodeMap(
    _ value: some FlutterMapRepresentable,
    codingPath: [CodingKey]
  ) throws {
    try encodeStandardField(.map)
    try encodeSize(value.count)
    try value.forEach {
      try encode($0, codingPath: codingPath)
      try encode($1, codingPath: codingPath)
    }
  }

  private func encodeInteger<Integer>(_ value: Integer) throws where Integer: FixedWidthInteger {
    withUnsafeBytes(of: value) {
      data += $0
    }
  }

  func encode(_ value: String) throws {
    try encodeStandardField(.string)
    guard let encoded = value.data(using: .utf8) else {
      throw FlutterSwiftError.stringNotEncodable(value)
    }

    try encodeSize(encoded.count)
    data += encoded
  }

  func encode(_ value: Bool) throws {
    try encodeStandardField(value ? .true : .false)
  }

  func encode(_ value: Double) throws {
    try encodeStandardField(.float64)
    try encodeAlignment(MemoryLayout<Double>.alignment)
    try encodeInteger(value.bitPattern)
  }

  func encode(_ value: Float) throws {
    try encodeStandardField(.float64)
    try encodeAlignment(MemoryLayout<Double>.alignment)
    try encodeInteger(value.bitPattern)
  }

  func encode(_ value: Int) throws {
    if MemoryLayout<Int>.size == 8 {
      try encode(Int64(value))
    } else if MemoryLayout<Int>.size == 4 {
      try encode(Int32(value))
    } else {
      fatalError("unsupporterd Int.bitWidth")
    }
  }

  func encode(_ value: Int8) throws {
    try encode(Int32(value))
  }

  func encode(_ value: Int16) throws {
    try encode(Int32(value))
  }

  func encode(_ value: Int32) throws {
    try encodeStandardField(.int32)
    try encodeInteger(value)
  }

  func encode(_ value: Int64) throws {
    try encodeStandardField(.int64)
    try encodeInteger(value)
  }

  func encode(_ value: UInt) throws {
    try encode(Int(value))
  }

  func encode(_ value: UInt8) throws {
    try encode(Int32(value))
  }

  func encode(_ value: UInt16) throws {
    try encode(Int32(value))
  }

  func encode(_ value: UInt32) throws {
    try encode(Int32(bitPattern: value))
  }

  func encode(_ value: UInt64) throws {
    try encode(Int64(bitPattern: value))
  }

  func encode<T>(_ value: T, codingPath: [any CodingKey]) throws where T: Encodable {
    try Self.encode(value, state: self, codingPath: codingPath)
  }

  static func encode<T>(
    _ value: T,
    state: FlutterStandardEncodingState,
    codingPath: [any CodingKey]
  ) throws where T: Encodable {
    switch value {
    case let value as Data:
      try state.encode(value)
    case let value as [UInt8]:
      try state.encodeArray(value)
    case let value as [Int32]:
      try state.encodeArray(value)
    case let value as [Int64]:
      try state.encodeArray(value)
    case let value as [Float]:
      try state.encodeArray(value)
    case let value as [Double]:
      try state.encodeArray(value)
    case let value as any FlutterListRepresentable:
      try state.encodeList(value, codingPath: codingPath)
    case let value as any FlutterMapRepresentable:
      try state.encodeMap(value, codingPath: codingPath)
    #if canImport(Foundation)
    case is NSNull:
      try state.encodeNil()
    #endif
    default:
      try value
        .encode(to: FlutterStandardEncoderImpl(state: state, codingPath: codingPath))
    }
  }
}

extension AnyFlutterStandardCodable: Encodable {
  public func encode(to encoder: any Encoder) throws {
    if let encoder = encoder as? FlutterStandardEncoderImpl {
      let container = encoder
        .singleValueContainer() as! SingleValueFlutterStandardEncodingContainer

      switch self {
      case .true:
        try container.state.encode(true)
      case .false:
        try container.state.encode(false)
      case let .int32(int32):
        try container.state.encode(int32)
      case let .int64(int64):
        try container.state.encode(int64)
      case let .float64(float64):
        try container.state.encode(float64)
      case let .string(string):
        try container.state.encode(string)
      case let .uint8Data(uint8Data):
        try container.state.encodeArray(uint8Data)
      case let .int32Data(int32Data):
        try container.state.encodeArray(int32Data)
      case let .int64Data(int64Data):
        try container.state.encodeArray(int64Data)
      case let .float32Data(float32Data):
        try container.state.encodeArray(float32Data)
      case let .float64Data(float64Data):
        try container.state.encodeArray(float64Data)
      case let .list(list):
        try container.state.encodeList(list, codingPath: container.codingPath)
      case let .map(map):
        try container.state.encodeMap(map, codingPath: container.codingPath)
      default:
        throw FlutterSwiftError.fieldNotEncodable
      }
    } else {
      var container = encoder.singleValueContainer()

      switch self {
      case .true:
        try container.encode(true)
      case .false:
        try container.encode(false)
      case let .int32(int32):
        try container.encode(int32)
      case let .int64(int64):
        try container.encode(int64)
      case let .float64(float64):
        try container.encode(float64)
      case let .string(string):
        try container.encode(string)
      case let .uint8Data(uint8Data):
        try container.encode(uint8Data)
      case let .int32Data(int32Data):
        try container.encode(int32Data)
      case let .int64Data(int64Data):
        try container.encode(int64Data)
      case let .float32Data(float32Data):
        try container.encode(float32Data)
      case let .float64Data(float64Data):
        try container.encode(float64Data)
      case let .list(list):
        try container.encode(list)
      case let .map(map):
        try container.encode(map)
      default:
        throw FlutterSwiftError.fieldNotEncodable
      }
    }
  }
}
