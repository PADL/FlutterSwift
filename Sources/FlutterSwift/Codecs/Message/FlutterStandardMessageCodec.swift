// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation

/**
 * Type of numeric data items encoded in a `FlutterStandardDataType`.
 *
 * - FlutterStandardDataTypeUInt8: plain bytes
 * - FlutterStandardDataTypeInt32: 32-bit signed integers
 * - FlutterStandardDataTypeInt64: 64-bit signed integers
 * - FlutterStandardDataTypeFloat64: 64-bit floats
 */
public enum FlutterStandardDataType {
    case uint8
    case int32
    case int64
    case float32
    case float64
}

/**
 * A byte buffer holding `UInt8`, `SInt32`, `SInt64`, or `Float64` values, used
 * with `FlutterStandardMessageCodec` and `FlutterStandardMethodCodec`.
 *
 * Two's complement encoding is used for signed integers. IEEE754
 * double-precision representation is used for floats. The platform's native
 * endianness is assumed.
 */
public struct FlutterStandardTypedData {
    let data: Data
    let type: FlutterStandardDataType
    let elementCount: UInt32
    let elementSize: UInt8
}

/**
 * A `FlutterMessageCodec` using the Flutter standard binary encoding.
 *
 * This codec is guaranteed to be compatible with the corresponding
 * [StandardMessageCodec](https://api.flutter.dev/flutter/services/StandardMessageCodec-class.html)
 * on the Dart side. These parts of the Flutter SDK are evolved synchronously.
 *
 * Supported messages are acyclic values of these forms:
 *
 * - `nil` or `NSNull`
 * - `NSNumber` (including their representation of Boolean values)
 * - `NSString`
 * - `FlutterStandardTypedData`
 * - `NSArray` of supported values
 * - `NSDictionary` with supported keys and values
 *
 * On the Dart side, these values are represented as follows:
 *
 * - `nil` or `NSNull`: null
 * - `NSNumber`: `bool`, `int`, or `double`, depending on the contained value.
 * - `NSString`: `String`
 * - `FlutterStandardTypedData`: `Uint8List`, `Int32List`, `Int64List`, or `Float64List`
 * - `NSArray`: `List`
 * - `NSDictionary`: `Map`
 */
public final class FlutterStandardMessageCodec: FlutterMessageCodec {
    public static var shared: FlutterStandardMessageCodec = .init()

    public func encode<Value>(_ message: Value) throws -> Data where Value: Encodable {
        try FlutterStandardEncoder().encode(message)
    }

    public func decode<Value>(_ message: Data) throws -> Value where Value: Decodable {
        fatalError("unimplemented")
    }
}
