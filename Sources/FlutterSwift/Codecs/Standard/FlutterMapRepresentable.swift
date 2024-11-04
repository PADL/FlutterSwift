//
// Copyright (c) 2023-2024 PADL Software Pty Ltd
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

struct KeyValuePair<Key: Hashable & Codable & Sendable, Value: Codable & Sendable>: Codable,
  Hashable, Sendable
{
  static func == (lhs: KeyValuePair<Key, Value>, rhs: KeyValuePair<Key, Value>) -> Bool {
    guard lhs.key == rhs.key else {
      return false
    }

    return true
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(key)
  }

  var key: Key
  var value: Value
}

protocol FlutterMapRepresentable<Key, Value>: Collection, Sendable {
  associatedtype Key: Codable & Hashable & Sendable
  associatedtype Value: Codable & Sendable

  init(setOfKeyValuePairs: Set<KeyValuePair<Key, Value>>)
  init(from: FlutterStandardDecoderImpl) throws
  func forEach(_ block: (Key, Value) throws -> ()) rethrows
}

extension FlutterMapRepresentable {
  static var pairType: KeyValuePair<Key, Value>.Type {
    KeyValuePair<Key, Value>.self
  }
}

extension Dictionary: FlutterMapRepresentable where Key: Codable & Hashable, Value: Codable {
  init(setOfKeyValuePairs set: Set<KeyValuePair<Key, Value>>) {
    self = Dictionary(uniqueKeysWithValues: set.map {
      ($0.key, $0.value)
    })
  }

  init(from flutterStandardDecoder: FlutterStandardDecoderImpl) throws {
    try self
      .init(setOfKeyValuePairs: Set<KeyValuePair<Key, Value>>(from: flutterStandardDecoder))
  }

  func forEach(_ block: (Key, Value) throws -> ()) rethrows {
    for (key, value) in self {
      try block(key, value)
    }
  }
}
