// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation

/// protocol to allow third-party classes to opt into being represented as
/// `AnyFlutterStandardCodable`
public protocol FlutterStandardCodable {
  init(any: AnyFlutterStandardCodable) throws
  func bridgeToAnyFlutterStandardCodable() throws -> AnyFlutterStandardCodable
}

/// extension for initializing a type from a type-erased value
public extension AnyFlutterStandardCodable {
  init(_ any: Any) throws {
    if isNil(any) {
      self = .nil
    } else if let bool = any as? Bool {
      self = bool ? .true : .false
    } else if let int32 = any as? Int32 {
      self = .int32(int32)
    } else if let int64 = any as? Int64 {
      self = .int64(int64)
    } else if let float64 = any as? Double {
      self = .float64(float64)
    } else if let string = any as? String {
      self = .string(string)
    } else if let uint8Data = any as? [UInt8] {
      self = .uint8Data(uint8Data)
    } else if let int32Data = any as? [Int32] {
      self = .int32Data(int32Data)
    } else if let int64Data = any as? [Int64] {
      self = .int64Data(int64Data)
    } else if let float32Data = any as? [Float] {
      self = .float32Data(float32Data)
    } else if let float64Data = any as? [Double] {
      self = .float64Data(float64Data)
    } else if let list = any as? [Any] {
      self = try .list(list.map { try AnyFlutterStandardCodable($0) })
    } else if let map = any as? [AnyHashable: Any] {
      self = try .map(map.reduce([:]) {
        var result = $0
        try result[AnyFlutterStandardCodable($1.key)] = AnyFlutterStandardCodable(
          $1
            .value
        )
        return result
      })
    } else if let any = any as? FlutterStandardCodable {
      self = try any.bridgeToAnyFlutterStandardCodable()
    } else if let raw = any as? (any RawRepresentable) {
      self = try raw.bridgeToAnyFlutterStandardCodable()
    } else if let encodable = any as? Encodable {
      self = try encodable.bridgeToAnyFlutterStandardCodable()
    } else {
      throw FlutterSwiftError.notRepresentableAsStandardField
    }
  }
}

/// extensions to allow smaller and unsigned integral types to be represented as variants
extension Int8: FlutterStandardCodable {
  public init(any: AnyFlutterStandardCodable) throws {
    guard case let .int32(int32) = any else {
      throw FlutterSwiftError.fieldNotDecodable
    }
    guard let int8 = Int8(exactly: int32) else {
      throw FlutterSwiftError.notRepresentableAsStandardField
    }
    self = int8
  }

  public func bridgeToAnyFlutterStandardCodable() throws -> AnyFlutterStandardCodable {
    .int32(Int32(self))
  }
}

extension Int16: FlutterStandardCodable {
  public init(any: AnyFlutterStandardCodable) throws {
    guard case let .int32(int32) = any else {
      throw FlutterSwiftError.fieldNotDecodable
    }
    guard let int16 = Int16(exactly: int32) else {
      throw FlutterSwiftError.notRepresentableAsStandardField
    }
    self = int16
  }

  public func bridgeToAnyFlutterStandardCodable() throws -> AnyFlutterStandardCodable {
    .int32(Int32(self))
  }
}

extension UInt8: FlutterStandardCodable {
  public init(any: AnyFlutterStandardCodable) throws {
    guard case let .int32(int32) = any else {
      throw FlutterSwiftError.fieldNotDecodable
    }
    guard let uint8 = UInt8(exactly: int32) else {
      throw FlutterSwiftError.notRepresentableAsStandardField
    }
    self = uint8
  }

  public func bridgeToAnyFlutterStandardCodable() throws -> AnyFlutterStandardCodable {
    .int32(Int32(self))
  }
}

extension UInt16: FlutterStandardCodable {
  public init(any: AnyFlutterStandardCodable) throws {
    guard case let .int32(int32) = any else {
      throw FlutterSwiftError.fieldNotDecodable
    }
    guard let uint16 = UInt16(exactly: int32) else {
      throw FlutterSwiftError.notRepresentableAsStandardField
    }
    self = uint16
  }

  public func bridgeToAnyFlutterStandardCodable() throws -> AnyFlutterStandardCodable {
    .int32(Int32(self))
  }
}

extension UInt32: FlutterStandardCodable {
  public init(any: AnyFlutterStandardCodable) throws {
    guard case let .int64(int64) = any else {
      throw FlutterSwiftError.fieldNotDecodable
    }
    guard let uint32 = UInt32(exactly: int64) else {
      throw FlutterSwiftError.notRepresentableAsStandardField
    }
    self = uint32
  }

  public func bridgeToAnyFlutterStandardCodable() throws -> AnyFlutterStandardCodable {
    .int64(Int64(self))
  }
}

extension Float: FlutterStandardCodable {
  public init(any: AnyFlutterStandardCodable) throws {
    guard case let .float64(float64) = any else {
      throw FlutterSwiftError.fieldNotDecodable
    }
    self = Float(float64)
  }

  public func bridgeToAnyFlutterStandardCodable() throws -> AnyFlutterStandardCodable {
    .float64(Double(self))
  }
}

extension Data: FlutterStandardCodable {
  public init(any: AnyFlutterStandardCodable) throws {
    guard case let .uint8Data(uint8Data) = any else {
      throw FlutterSwiftError.fieldNotDecodable
    }
    self.init(uint8Data)
  }

  public func bridgeToAnyFlutterStandardCodable() throws -> AnyFlutterStandardCodable {
    .uint8Data([UInt8](self))
  }
}

private extension FixedWidthInteger {
  var _int32Value: Int32? {
    Int32(exactly: self)
  }
}

extension RawRepresentable {
  func bridgeToAnyFlutterStandardCodable() throws -> AnyFlutterStandardCodable {
    guard let rawValue = rawValue as? (any FixedWidthInteger),
          let rawValue = rawValue._int32Value
    else {
      throw FlutterSwiftError.notRepresentableAsStandardField
    }
    return .int32(rawValue)
  }
}

private extension CaseIterable {
  static func value(for aRawValue: Int32) -> Any? {
    guard self is any RawRepresentable.Type else {
      return nil
    }

    for aCase in allCases {
      let rawValue = (aCase as! any RawRepresentable).rawValue
      guard let rawValue = rawValue as? any FixedWidthInteger else {
        return nil
      }
      guard let rawValue = Int32(exactly: rawValue) else {
        continue
      }
      if rawValue == aRawValue {
        return aCase
      }
    }
    return nil
  }
}

private func isNil(_ value: Any) -> Bool {
  if let value = value as? ExpressibleByNilLiteral {
    let value = value as Any?
    if case .none = value {
      return true
    }
  }
  return false
}

public extension AnyFlutterStandardCodable {
  func value(as type: Any.Type? = nil) throws -> Any {
    if let type = type as? FlutterStandardCodable.Type {
      do {
        return try type.init(any: self)
      } catch {}
    }

    switch self {
    case .nil:
      if type is ExpressibleByNilLiteral.Type {
        let vnil: Any! = nil
        return vnil as Any
      }
    case .true:
      fallthrough
    case .false:
      guard type is Bool.Type else { throw FlutterSwiftError.fieldNotDecodable }
      return self == .true
    case let .int32(int32):
      if let type = type as? any CaseIterable.Type {
        return try type.bridgeFromAnyFlutterStandardCodable(self) as Any
      } else if type is Int32.Type {
        return int32
      }
    case let .int64(int64):
      if type is Int64.Type { return int64 }
    case let .float64(float64):
      if type is Double.Type { return float64 }
    case let .string(string):
      if type is String.Type { return string }
    case let .uint8Data(uint8Data):
      if type is [UInt8].Type { return uint8Data }
    case let .int32Data(int32Data):
      if type is [Int32].Type { return int32Data }
    case let .int64Data(int64Data):
      if type is [Int64].Type { return int64Data }
    case let .float32Data(float32Data):
      if type is [Float].Type { return float32Data }
    case let .float64Data(float64Data):
      if type is [Double].Type { return float64Data }
    case let .list(list):
      if type is any FlutterListRepresentable.Type {
        return try list.map { try $0.value() }
      } else if let type = type as? Decodable.Type {
        return try bridgeFromAnyFlutterStandardCodable(to: type)
      }
    case let .map(map):
      if type is any FlutterMapRepresentable.Type {
        return try map.reduce([:]) {
          var result = $0
          if let key = try $1.key.value() as? any Hashable {
            result[AnyHashable(key)] = try? $1.value.value()
          }
          return result
        }
      } else if let type = type as? Decodable.Type {
        return try bridgeFromAnyFlutterStandardCodable(to: type)
      }
    }

    throw FlutterSwiftError.fieldNotDecodable
  }
}

private extension CaseIterable {
  static func bridgeFromAnyFlutterStandardCodable(_ any: AnyFlutterStandardCodable) throws
    -> Self
  {
    guard case let .int32(int32) = any else {
      throw FlutterSwiftError.notRepresentableAsStandardField
    }
    return Self.value(for: int32) as! Self
  }
}

extension AnyFlutterStandardCodable {
  func bridgeFromAnyFlutterStandardCodable<T: Decodable>(to type: T.Type) throws -> T {
    let jsonEncodedValue = try JSONEncoder().encode(self)
    return try JSONDecoder().decode(type, from: jsonEncodedValue)
  }
}

extension Encodable {
  func bridgeToAnyFlutterStandardCodable() throws -> AnyFlutterStandardCodable {
    let jsonEncodedValue = try JSONEncoder().encode(self)
    let jsonDecodedValue = try JSONSerialization.jsonObject(with: jsonEncodedValue)
    return try AnyFlutterStandardCodable(jsonDecodedValue)
  }
}
