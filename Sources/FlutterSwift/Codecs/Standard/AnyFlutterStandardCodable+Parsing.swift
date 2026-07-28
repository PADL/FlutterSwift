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

import BinaryParsing

// `AnyFlutterStandardCodable` is the dynamically typed view of a standard-codec
// message: its shape is decided entirely by the type tag on the wire, so there
// is nothing for `Codable` to dispatch on. Decoding it through `Decodable`
// meant allocating a `FlutterStandardDecoderImpl` and a single-value container
// per nested value, plus a chain of existential metatype casts
// (`type as? any FlutterMapRepresentable.Type`, `type is [Int32].Type`, …) per
// element — all to rediscover what the tag byte already said.
//
// Parsing it directly is a plain recursive switch over one borrowed view of the
// buffer. The `Codable` conformance below is retained for callers that decode
// it as part of a larger `Decodable` graph (`FlutterError.details`, method-call
// arguments); it now delegates here rather than reimplementing the grammar.

extension AnyFlutterStandardCodable: ExpressibleByParsing {
  /// Parses one standard-codec value, including its type tag.
  public init(parsing input: inout ParserSpan) throws(ThrownParsingError) {
    do {
      try self.init(parsingValue: &input)
    } catch {
      throw FlutterSwiftError(error)
    }
  }

  init(parsingValue input: inout ParserSpan) throws(ParsingError) {
    switch try FlutterStandardField(parsing: &input) {
    case .nil:
      self = .nil
    case .true:
      self = .true
    case .false:
      self = .false
    case .int32:
      self = try .int32(Int32(parsing: &input, endianness: .host))
    case .int64:
      self = try .int64(Int64(parsing: &input, endianness: .host))
    case .float64:
      try input.parseAlignment(to: MemoryLayout<Double>.alignment)
      self = try .float64(Double(bitPattern: UInt64(parsing: &input, endianness: .host)))
    case .string:
      self = try .string(input.parseString())
    case .uint8Data:
      self = try .uint8Data(input.parseTypedArray(of: UInt8.self))
    case .int32Data:
      self = try .int32Data(input.parseTypedArray(of: Int32.self))
    case .int64Data:
      self = try .int64Data(input.parseTypedArray(of: Int64.self))
    case .float32Data:
      self = try .float32Data(input.parseTypedArray(of: Float.self))
    case .float64Data:
      self = try .float64Data(input.parseTypedArray(of: Double.self))
    case .list:
      let count = try input.parseSize()
      var values = [AnyFlutterStandardCodable]()
      values.reserveCapacity(count)
      for _ in 0..<count {
        try values.append(AnyFlutterStandardCodable(parsingValue: &input))
      }
      self = .list(values)
    case .map:
      let count = try input.parseSize()
      var values = [AnyFlutterStandardCodable: AnyFlutterStandardCodable](
        minimumCapacity: count
      )
      for _ in 0..<count {
        let key = try AnyFlutterStandardCodable(parsingValue: &input)
        let value = try AnyFlutterStandardCodable(parsingValue: &input)
        values[key] = value
      }
      self = .map(values)
    case .intHex:
      // written by no known encoder, and unrepresentable by this type
      throw ParsingError(userError: FlutterSwiftError.fieldNotDecodable)
    }
  }
}

extension AnyFlutterStandardCodable: Decodable {
  public init(from decoder: any Decoder) throws {
    guard let decoder = decoder as? FlutterStandardDecoderImpl else {
      throw FlutterSwiftError.fieldNotDecodable
    }
    self = try decoder.state.decodeAnyValue()
  }
}
