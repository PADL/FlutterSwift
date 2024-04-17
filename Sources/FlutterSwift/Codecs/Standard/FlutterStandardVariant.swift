// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation

public indirect enum FlutterStandardVariant: Hashable, Sendable {
    case `nil`
    case `true`
    case `false`
    case int32(Int32)
    case int64(Int64)
    case float64(Double)
    case string(String)
    case uint8Data([UInt8])
    case int32Data([Int32])
    case int64Data([Int64])
    case float64Data([Double])
    case list([FlutterStandardVariant])
    case map([FlutterStandardVariant: FlutterStandardVariant])
    case float32Data([Float])

    public static func isValidVariantType(_ type: Any.Type) -> Bool {
        if type is ExpressibleByNilLiteral.Type {
            return true
        } else if type is Int32.Type {
            return true
        } else if type is Int64.Type {
            return true
        } else if type is Float.Type {
            return true
        } else if type is Double.Type {
            return true
        } else if type is String.Type {
            return true
        } else if type is [UInt8].Type {
            return true
        } else if type is [Int32].Type {
            return true
        } else if type is [Int64].Type {
            return true
        } else if type is [Float].Type {
            return true
        } else if type is [Double].Type {
            return true
        } else if type is any FlutterListRepresentable.Type {
            return true
        } else if type is any FlutterMapRepresentable.Type {
            return true
        } else {
            return false
        }
    }

    public init(_ any: Any?) throws {
        guard let any else {
            self = .nil
            return
        }

        // expand smaller and unsigned integer types on input

        if let bool = any as? Bool {
            self = bool ? .true : .false
        } else if let int8 = any as? Int8 {
            self = .int32(Int32(int8))
        } else if let int16 = any as? Int16 {
            self = .int32(Int32(int16))
        } else if let int32 = any as? Int32 {
            self = .int32(int32)
        } else if let int64 = any as? Int64 {
            self = .int64(int64)
        } else if let uint8 = any as? UInt8 {
            self = .int32(Int32(uint8))
        } else if let uint16 = any as? UInt16 {
            self = .int32(Int32(uint16))
        } else if let uint32 = any as? UInt32 {
            self = .int32(Int32(bitPattern: uint32))
        } else if let uint64 = any as? UInt64 {
            self = .int64(Int64(bitPattern: uint64))
        } else if let float32 = any as? Float {
            self = .float64(Double(float32))
        } else if let float64 = any as? Double {
            self = .float64(float64)
        } else if let string = any as? String {
            self = .string(string)
        } else if let data = any as? Data {
            self = .uint8Data([UInt8](data))
        } else if let uint8Data = any as? [UInt8] {
            self = .uint8Data(uint8Data)
        } else if let int32Data = any as? [Int32] {
            self = .int32Data(int32Data)
        } else if let int64Data = any as? [Int64] {
            self = .int64Data(int64Data)
        } else if let uint32Data = any as? [UInt32] {
            self = .int32Data(uint32Data.map { Int32(bitPattern: $0) })
        } else if let uint64Data = any as? [UInt64] {
            self = .int64Data(uint64Data.map { Int64(bitPattern: $0) })
        } else if let float32Data = any as? [Float] {
            self = .float32Data(float32Data)
        } else if let float64Data = any as? [Double] {
            self = .float64Data(float64Data)
        } else if let list = any as? [Any] {
            self = .list(try list.map { try FlutterStandardVariant($0) })
        } else if let map = any as? [AnyHashable: Any] {
            self = .map(try map.reduce([:]) {
                var result = $0
                try result[FlutterStandardVariant($1.key)] = FlutterStandardVariant(
                    $1
                        .value
                )
                return result
            })
        } else {
            throw FlutterSwiftError.notRepresentableAsVariant
        }
    }

    public var value: Any? {
        switch self {
        case .nil:
            return nil
        case .true:
            return true
        case .false:
            return false
        case let .int32(int32):
            return int32
        case let .int64(int64):
            return int64
        case let .float64(float64):
            return float64
        case let .string(string):
            return string
        case let .uint8Data(uint8Data):
            return uint8Data
        case let .int32Data(int32Data):
            return int32Data
        case let .int64Data(int64Data):
            return int64Data
        case let .float64Data(float64Data):
            return float64Data
        case let .list(list):
            return list.map(\.value)
        case let .map(map):
            return map.reduce([:]) {
                var result = $0
                if let key = $1.key.value as? any Hashable {
                    result[AnyHashable(key)] = $1.value.value
                }
                return result
            }
        case let .float32Data(float32Data):
            return float32Data
        }
    }

    public func value<T>(_ type: T.Type) throws -> T? {
        switch self {
        case .nil:
            return nil
        case .true:
            guard type is Bool.Type else { throw FlutterSwiftError.variantNotDecodable }
            return true as? T
        case .false:
            guard type is Bool.Type else { throw FlutterSwiftError.variantNotDecodable }
            return false as? T
        case let .int32(int32):
            guard type is Int32.Type else { throw FlutterSwiftError.variantNotDecodable }
            return int32 as? T
        case let .int64(int64):
            guard type is Int64.Type else { throw FlutterSwiftError.variantNotDecodable }
            return int64 as? T
        case let .float64(float64):
            if type is Double.Type {
                return float64 as? T
            } else if type is Float.Type {
                return Float(float64) as? T
            } else {
                throw FlutterSwiftError.variantNotDecodable
            }
        case let .string(string):
            guard type is String.Type else { throw FlutterSwiftError.variantNotDecodable }
            return string as? T
        case let .uint8Data(uint8Data):
            if type is [UInt8].Type {
                return uint8Data as? T
            } else if type is Data.Type {
                return Data(uint8Data) as? T
            } else {
                throw FlutterSwiftError.variantNotDecodable
            }
        case let .int32Data(int32Data):
            if type is [Int32].Type {
                return int32Data as? T
            } else if type is [UInt32].Type {
                return int32Data.map { UInt32(bitPattern: $0) } as? T
            } else {
                throw FlutterSwiftError.variantNotDecodable
            }
        case let .int64Data(int64Data):
            if type is [Int64].Type {
                return int64Data as? T
            } else if type is [UInt64].Type {
                return int64Data.map { UInt64(bitPattern: $0) } as? T
            } else {
                throw FlutterSwiftError.variantNotDecodable
            }
        case let .float64Data(float64Data):
            guard type is [Double].Type else { throw FlutterSwiftError.variantNotDecodable }
            return float64Data as? T
        case let .list(list):
            guard type is any FlutterListRepresentable.Type
            else { throw FlutterSwiftError.variantNotDecodable }
            return list.map(\.value) as? T
        case let .map(map):
            guard type is any FlutterMapRepresentable.Type
            else { throw FlutterSwiftError.variantNotDecodable }
            return map.reduce([:]) {
                var result = $0
                if let key = $1.key.value as? any Hashable {
                    result[AnyHashable(key)] = $1.value.value
                }
                return result
            } as? T
        case let .float32Data(float32Data):
            guard type is [Float].Type else { throw FlutterSwiftError.variantNotDecodable }
            return float32Data as? T
        }
    }

    public var field: FlutterStandardField {
        switch self {
        case .nil:
            return .nil
        case .true:
            return .true
        case .false:
            return .false
        case .int32:
            return .int32
        case .int64:
            return .int64
        case .float64:
            return .float64
        case .string:
            return .string
        case .uint8Data:
            return .uint8Data
        case .int32Data:
            return .int32Data
        case .int64Data:
            return .int64Data
        case .float64Data:
            return .float64Data
        case .list:
            return .list
        case .map:
            return .map
        case .float32Data:
            return .float32Data
        }
    }
}
