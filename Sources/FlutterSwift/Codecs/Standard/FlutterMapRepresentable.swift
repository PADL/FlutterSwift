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
