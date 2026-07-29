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

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// The mirror of `AnyFlutterStandardCodable+Parsing.swift`. Its case *is* the
// wire tag, so — exactly as when reading — there is nothing for `Codable` to
// dispatch on, and routing it through `Encodable` costs a great deal to
// rediscover what the case already said:
//
//   - `FlutterStandardEncodingState.encode(_:codingPath:)` runs a chain of
//     existential casts (`as? Data`, `as? [UInt8]` plus a `type(of:)` check,
//     … `as? any FlutterMapRepresentable`) before falling through to
//     `Encodable`;
//   - each value then allocates a `FlutterStandardEncoderImpl` and a container;
//   - and `.list`/`.map` recurse back out through that same cast chain once per
//     element, allocating an encoder and container for each.
//
// Writing directly is a plain recursive switch over the case, appending to one
// buffer: ~8x faster for a `.float64` event envelope, ~15x for an `.int32` one.
// `AnyFlutterStandardCodableWritingTests` pins the output byte-for-byte against
// the `Codable` encoder.
//
// The `Encodable` conformance is retained for callers that encode this type as
// part of a larger graph (`FlutterError.details`, method-call arguments); it
// delegates here rather than reimplementing the grammar.

extension AnyFlutterStandardCodable {
  /// Writes this value, including its type tag, to `buffer`.
  ///
  /// `buffer` must start at message offset zero: alignment padding for
  /// `float64` and typed data is measured from the start of the message.
  func write(
    into buffer: inout some FlutterStandardByteStreamWriter
  ) throws(FlutterSwiftError) {
    switch self {
    case .nil:
      buffer.writeField(.nil)
    case .true:
      buffer.writeField(.true)
    case .false:
      buffer.writeField(.false)
    case let .int32(int32):
      buffer.writeInt32(int32)
    case let .int64(int64):
      buffer.writeInt64(int64)
    case let .float64(float64):
      buffer.writeFloat64(float64)
    case let .string(string):
      try buffer.writeString(string)
    case let .uint8Data(uint8Data):
      try buffer.writeTypedArray(.uint8Data, uint8Data)
    case let .int32Data(int32Data):
      try buffer.writeTypedArray(.int32Data, int32Data)
    case let .int64Data(int64Data):
      try buffer.writeTypedArray(.int64Data, int64Data)
    case let .float32Data(float32Data):
      try buffer.writeTypedArray(.float32Data, float32Data)
    case let .float64Data(float64Data):
      try buffer.writeTypedArray(.float64Data, float64Data)
    case let .list(list):
      buffer.writeField(.list)
      try buffer.writeSize(list.count)
      for element in list {
        try element.write(into: &buffer)
      }
    case let .map(map):
      buffer.writeField(.map)
      try buffer.writeSize(map.count)
      for (key, value) in map {
        try key.write(into: &buffer)
        try value.write(into: &buffer)
      }
    }
  }

  /// A cheap, O(1) lower bound on the encoded size, used to size the buffer.
  ///
  /// Deliberately not recursive: walking a nested value to size its buffer
  /// would cost more than the reallocations it saves. Nested containers fall
  /// back to a small default and let geometric growth take over.
  ///
  /// Only ever a hint, so an unrepresentable size falls back to the default
  /// rather than trapping: `count * stride` can overflow a 32-bit `Int`. It
  /// must not saturate to `.max` either — this feeds `reserveCapacity`, so a
  /// saturated hint would turn an overflow into a doomed allocation.
  var _encodedSizeHint: Int {
    func hint(_ count: Int, stride: Int, overhead: Int) -> Int {
      let (bytes, overflowed) = count.multipliedReportingOverflow(by: stride)
      guard !overflowed else { return Self._defaultSizeHint }
      let (total, carried) = bytes.addingReportingOverflow(overhead)
      return carried ? Self._defaultSizeHint : total
    }

    return switch self {
    case .nil, .true, .false: 1
    case .int32: 5
    case .int64: 9
    case .float64: 16
    case let .string(string): hint(string.utf8.count, stride: 1, overhead: 6)
    case let .uint8Data(value): hint(value.count, stride: 1, overhead: 6)
    case let .int32Data(value): hint(value.count, stride: 4, overhead: 10)
    case let .int64Data(value): hint(value.count, stride: 8, overhead: 14)
    case let .float32Data(value): hint(value.count, stride: 4, overhead: 10)
    case let .float64Data(value): hint(value.count, stride: 8, overhead: 14)
    case .list, .map: Self._defaultSizeHint
    }
  }

  /// Buffer size assumed for nested containers, and for the sizes `hint`
  /// cannot represent. Geometric growth takes over from here.
  static let _defaultSizeHint = 64
}

// MARK: - direct encoding entry points

/// A value that can produce a whole standard-codec message without `Codable`.
///
/// `FlutterStandardEncoder.encode` checks for this before building an encoding
/// state. Returning `nil` means "no direct path for this value" and falls back
/// to the `Codable` encoder, so a conformance only has to cover the shapes it
/// actually benefits from.
protocol FlutterStandardDirectlyEncodable {
  func _directlyEncoded() throws(FlutterSwiftError) -> Data?
}

/// `[UInt8]` rather than `Data` as the scratch buffer: its appends are 3-8x
/// cheaper on the small, token-heavy payloads that dominate event traffic. The
/// trailing `Data(_:)` copy only starts to outweigh that past ~32KB, where the
/// direct path is a wash with the `Codable` one either way, so there is nothing
/// to be gained by picking a buffer per payload size.
extension AnyFlutterStandardCodable: FlutterStandardDirectlyEncodable {
  func _directlyEncoded() throws(FlutterSwiftError) -> Data? {
    var buffer = [UInt8]()
    buffer.reserveCapacity(_encodedSizeHint)
    try write(into: &buffer)
    return Data(buffer)
  }
}

/// The shape every event channel encodes, and the reason this exists: property
/// and metering events are `FlutterEnvelope<AnyFlutterStandardCodable>`, one per
/// event, each currently rebuilt through the full `Codable` machinery.
///
/// Failures keep the `Codable` path: `FlutterError` is a plain struct that
/// encodes fine that way, and errors are not on any hot path.
extension FlutterEnvelope: FlutterStandardDirectlyEncodable
  where Success == AnyFlutterStandardCodable
{
  func _directlyEncoded() throws(FlutterSwiftError) -> Data? {
    guard case let .success(value) = self else { return nil }
    var buffer = [UInt8]()
    buffer.reserveCapacity((value?._encodedSizeHint ?? 1) + 1)
    buffer.writeByte(0) // success discriminant
    if let value {
      try value.write(into: &buffer)
    } else {
      buffer.writeField(.nil)
    }
    return Data(buffer)
  }
}
