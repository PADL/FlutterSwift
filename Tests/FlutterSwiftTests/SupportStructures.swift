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

struct Simple: Codable, Hashable {
  let x: UInt8
  let y: UInt16
  let z: Int8
}

struct Composite: Codable, Hashable {
  let before: Int32
  let inner: Inner
  let after: Int64

  struct Inner: Codable, Hashable {
    let value: Int8
  }
}

struct VariablePrefix: Codable, Hashable {
  let prefix: [UInt8]
  let value: UInt8
}

struct VariableSuffix: Codable, Hashable {
  let value: UInt8
  let suffix: [UInt8]
}

struct Generic<Value> {
  let value: Value
  let additional: UInt8
}

extension Generic: Equatable where Value: Equatable {}
extension Generic: Hashable where Value: Hashable {}
extension Generic: Encodable where Value: Encodable {}
extension Generic: Decodable where Value: Decodable {}


