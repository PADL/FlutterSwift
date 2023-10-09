// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation

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

protocol FlutterMapRepresentable<Key, Value>: Sendable {
    associatedtype Key: Codable & Hashable & Sendable
    associatedtype Value: Codable & Sendable

    init(map: Set<KeyValuePair<Key, Value>>)
    var map: Set<KeyValuePair<Key, Value>> { get }
}

extension FlutterMapRepresentable {
    static var pairType: KeyValuePair<Key, Value>.Type {
        KeyValuePair<Key, Value>.self
    }
}

extension Dictionary: FlutterMapRepresentable where Key: Codable, Value: Codable {
    init(map: Set<KeyValuePair<Key, Value>>) {
        self = Dictionary(uniqueKeysWithValues: map.map {
            ($0.key, $0.value)
        })
    }

    var map: Set<KeyValuePair<Key, Value>> {
        Set(self.map { KeyValuePair(key: $0, value: $1) })
    }
}
