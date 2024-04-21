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

/// A (stateful) binary decoder.
struct FlutterStandardDecoderImpl: Decoder {
  let state: FlutterStandardDecodingState
  let codingPath: [any CodingKey]
  var userInfo: [CodingUserInfoKey: Any] { [:] }
  let count: Int?

  init(state: FlutterStandardDecodingState, codingPath: [any CodingKey], count: Int? = nil) {
    self.state = state
    self.codingPath = codingPath
    self.count = count
  }

  func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key>
    where Key: CodingKey
  {
    .init(KeyedFlutterStandardDecodingContainer(state: state, codingPath: codingPath))
  }

  func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
    UnkeyedFlutterStandardDecodingContainer(state: state, codingPath: codingPath, count: count)
  }

  func singleValueContainer() throws -> any SingleValueDecodingContainer {
    SingleValueFlutterStandardDecodingContainer(state: state, codingPath: codingPath)
  }
}
