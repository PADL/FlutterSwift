// MIT License
//
// Copyright (c) 2022 fwcd
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

struct UnkeyedFlutterStandardDecodingContainer: UnkeyedDecodingContainer {
  let state: FlutterStandardDecodingState
  let codingPath: [any CodingKey]

  private(set) var currentIndex: Int = 0

  var isAtEnd: Bool {
    if let count {
      return currentIndex == count
    } else {
      return state.isAtEnd
    }
  }

  var count: Int?

  init(state: FlutterStandardDecodingState, codingPath: [any CodingKey], count: Int?) {
    self.state = state
    self.codingPath = codingPath
    self.count = count
  }

  mutating func nestedContainer<NestedKey>(
    keyedBy type: NestedKey
      .Type
  ) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
    .init(KeyedFlutterStandardDecodingContainer<NestedKey>(
      state: state,
      codingPath: codingPath
    ))
  }

  mutating func nestedUnkeyedContainer() throws -> any UnkeyedDecodingContainer {
    UnkeyedFlutterStandardDecodingContainer(state: state, codingPath: codingPath, count: nil)
  }

  mutating func superDecoder() throws -> any Decoder {
    FlutterStandardDecoderImpl(state: state, codingPath: codingPath)
  }

  mutating func decodeNil() throws -> Bool {
    let isNil = try state.decodeNil()
    currentIndex += 1
    return isNil
  }

  mutating func decode(_ type: Bool.Type) throws -> Bool {
    let value = try state.decode(type)
    currentIndex += 1
    return value
  }

  mutating func decode(_ type: String.Type) throws -> String {
    let value = try state.decode(type)
    currentIndex += 1
    return value
  }

  mutating func decode(_ type: Double.Type) throws -> Double {
    let value = try state.decode(type)
    currentIndex += 1
    return value
  }

  mutating func decode(_ type: Float.Type) throws -> Float {
    let value = try state.decode(type)
    currentIndex += 1
    return value
  }

  mutating func decode(_ type: Int.Type) throws -> Int {
    let value = try state.decode(type)
    currentIndex += 1
    return value
  }

  mutating func decode(_ type: Int8.Type) throws -> Int8 {
    let value = try state.decode(type)
    currentIndex += 1
    return value
  }

  mutating func decode(_ type: Int16.Type) throws -> Int16 {
    let value = try state.decode(type)
    currentIndex += 1
    return value
  }

  mutating func decode(_ type: Int32.Type) throws -> Int32 {
    let value = try state.decode(type)
    currentIndex += 1
    return value
  }

  mutating func decode(_ type: Int64.Type) throws -> Int64 {
    let value = try state.decode(type)
    currentIndex += 1
    return value
  }

  mutating func decode(_ type: UInt.Type) throws -> UInt {
    let value = try state.decode(type)
    currentIndex += 1
    return value
  }

  mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
    let value = try state.decode(type)
    currentIndex += 1
    return value
  }

  mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
    let value = try state.decode(type)
    currentIndex += 1
    return value
  }

  mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
    let value = try state.decode(type)
    currentIndex += 1
    return value
  }

  mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
    let value = try state.decode(type)
    currentIndex += 1
    return value
  }

  mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
    let value = try state.decode(type, codingPath: codingPath)
    currentIndex += 1
    return value
  }
}
