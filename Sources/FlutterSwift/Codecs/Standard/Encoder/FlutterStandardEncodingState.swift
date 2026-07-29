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

  private func encodeStandardField(_ fieldType: FlutterStandardField) throws(FlutterSwiftError) {
    data.writeField(fieldType)
  }

  private func encodeSize(_ size: Int) throws(FlutterSwiftError) {
    try data.writeSize(size)
  }

  private func encodeAlignment(_ alignment: Int) throws(FlutterSwiftError) {
    data.writeAlignment(alignment)
  }

  private func encode(_ value: Data) throws(FlutterSwiftError) {
    try data.writeData(value)
  }

  /// Writes an `AnyFlutterStandardCodable` straight into the buffer, bypassing
  /// the encoder and container allocation the `Codable` path would need.
  func write(_ value: AnyFlutterStandardCodable) throws(FlutterSwiftError) {
    try value.write(into: &data)
  }

  @inlinable
  func encodeDiscriminant(_ value: UInt8) throws(FlutterSwiftError) {
    data.append(value)
  }

  func encodeNil() throws(FlutterSwiftError) {
    try encodeStandardField(.nil)
  }

  /// Bulk-encode a typed-data array in a single buffer append.
  ///
  /// The Flutter standard codec stores typed data (`Uint8List`, `Int32List`,
  /// `Int64List`, `Float32List`, `Float64List`) in host byte order — the engine
  /// `memcpy`s the backing store on its side too — so an element's in-memory
  /// representation is exactly its wire representation. Copying the array's raw
  /// storage once is therefore equivalent to encoding each element via
  /// `withUnsafeBytes(of:)`, but performs O(1) buffer operations instead of O(n)
  /// appends (each of which re-checks bounds and copy-on-write ownership).
  private func encodeTypedArray<T>(
    _ fieldType: FlutterStandardField,
    _ value: [T]
  ) throws(FlutterSwiftError) {
    try data.writeTypedArray(fieldType, value)
  }

  private func encodeArray(_ value: [UInt8]) throws(FlutterSwiftError) {
    try encodeTypedArray(.uint8Data, value)
  }

  private func encodeArray(_ value: [Int32]) throws(FlutterSwiftError) {
    try encodeTypedArray(.int32Data, value)
  }

  private func encodeArray(_ value: [Int64]) throws(FlutterSwiftError) {
    try encodeTypedArray(.int64Data, value)
  }

  private func encodeArray(_ value: [Double]) throws(FlutterSwiftError) {
    try encodeTypedArray(.float64Data, value)
  }

  private func encodeArray(_ value: [Float]) throws(FlutterSwiftError) {
    try encodeTypedArray(.float32Data, value)
  }

  private func encodeList(
    _ value: some FlutterListRepresentable,
    codingPath: [CodingKey]
  ) throws {
    try encodeStandardField(.list)
    try encodeSize(value.count)
    try value.forEach {
      try encode($0, codingPath: codingPath)
    }
  }

  private func encodeMap(
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

  private func encodeInteger<Integer>(_ value: Integer) throws(FlutterSwiftError)
    where Integer: FixedWidthInteger
  {
    withUnsafeBytes(of: value) {
      data += $0
    }
  }

  func encode(_ value: String) throws(FlutterSwiftError) {
    try data.writeString(value)
  }

  func encode(_ value: Bool) throws(FlutterSwiftError) {
    try encodeStandardField(value ? .true : .false)
  }

  func encode(_ value: Double) throws(FlutterSwiftError) {
    try encodeStandardField(.float64)
    try encodeAlignment(MemoryLayout<Double>.alignment)
    try encodeInteger(value.bitPattern)
  }

  func encode(_ value: Float) throws(FlutterSwiftError) {
    // no float32 scalar in the standard codec; promote to float64
    try encode(Double(value))
  }

  func encode(_ value: Int) throws(FlutterSwiftError) {
    if MemoryLayout<Int>.size == 8 {
      try encode(Int64(value))
    } else if MemoryLayout<Int>.size == 4 {
      try encode(Int32(value))
    } else {
      fatalError("unsupporterd Int.bitWidth")
    }
  }

  func encode(_ value: Int8) throws(FlutterSwiftError) {
    try encode(Int32(value))
  }

  func encode(_ value: Int16) throws(FlutterSwiftError) {
    try encode(Int32(value))
  }

  func encode(_ value: Int32) throws(FlutterSwiftError) {
    try encodeStandardField(.int32)
    try encodeInteger(value)
  }

  func encode(_ value: Int64) throws(FlutterSwiftError) {
    try encodeStandardField(.int64)
    try encodeInteger(value)
  }

  func encode(_ value: UInt) throws(FlutterSwiftError) {
    try encode(Int(value))
  }

  func encode(_ value: UInt8) throws(FlutterSwiftError) {
    try encode(Int32(value))
  }

  func encode(_ value: UInt16) throws(FlutterSwiftError) {
    try encode(Int32(value))
  }

  func encode(_ value: UInt32) throws(FlutterSwiftError) {
    try encode(Int32(bitPattern: value))
  }

  func encode(_ value: UInt64) throws(FlutterSwiftError) {
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
    // The typed-data array cases are guarded on the value's *exact* dynamic
    // type rather than dispatching on the `as?` cast alone. An empty array
    // bridges to any element type — `[Int32]() as? [UInt8]` succeeds and
    // produces a fresh empty `[UInt8]` — so without the guard an empty
    // `[Int32]`/`[Int64]`/`[Float]`/`[Double]` (indeed any empty non-UInt8
    // array) would fall into the first `[UInt8]` case and be mis-tagged as
    // uint8Data. `type(of: value)` inspects the original value before the cast.
    switch value {
    case let value as Data:
      try state.encode(value)
    case let array as [UInt8] where type(of: value) == [UInt8].self:
      try state.encodeArray(array)
    case let array as [Int32] where type(of: value) == [Int32].self:
      try state.encodeArray(array)
    case let array as [Int64] where type(of: value) == [Int64].self:
      try state.encodeArray(array)
    case let array as [Float] where type(of: value) == [Float].self:
      try state.encodeArray(array)
    case let array as [Double] where type(of: value) == [Double].self:
      try state.encodeArray(array)
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
      // the grammar lives in `write(into:)`; don't reimplement it here, and
      // don't pay for a container we would only read `state` back out of
      try encoder.state.write(self)
    } else {
      var container = encoder.singleValueContainer()

      switch self {
      case .nil:
        try container.encodeNil()
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
      }
    }
  }
}
