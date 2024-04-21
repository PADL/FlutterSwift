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

struct SingleValueFlutterStandardEncodingContainer: SingleValueEncodingContainer {
  let state: FlutterStandardEncodingState

  let codingPath: [any CodingKey]

  init(state: FlutterStandardEncodingState, codingPath: [any CodingKey]) {
    self.state = state
    self.codingPath = codingPath
  }

  mutating func encodeNil() throws { try state.encodeNil() }

  mutating func encode(_ value: Bool) throws { try state.encode(value) }

  mutating func encode(_ value: String) throws { try state.encode(value) }

  mutating func encode(_ value: Double) throws { try state.encode(value) }

  mutating func encode(_ value: Float) throws { try state.encode(value) }

  mutating func encode(_ value: Int) throws { try state.encode(value) }

  mutating func encode(_ value: Int8) throws { try state.encode(value) }

  mutating func encode(_ value: Int16) throws { try state.encode(value) }

  mutating func encode(_ value: Int32) throws { try state.encode(value) }

  mutating func encode(_ value: Int64) throws { try state.encode(value) }

  mutating func encode(_ value: UInt) throws { try state.encode(value) }

  mutating func encode(_ value: UInt8) throws { try state.encode(value) }

  mutating func encode(_ value: UInt16) throws { try state.encode(value) }

  mutating func encode(_ value: UInt32) throws { try state.encode(value) }

  mutating func encode(_ value: UInt64) throws { try state.encode(value) }

  mutating func encode<T>(_ value: T) throws
    where T: Encodable { try state.encode(value, codingPath: codingPath) }
}
