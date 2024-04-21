// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation

/**
 * A `FlutterMessageCodec` using UTF-8 encoded JSON messages.
 *
 * This codec is guaranteed to be compatible with the corresponding
 * [JSONMessageCodec](https://api.flutter.dev/flutter/services/JSONMessageCodec-class.html)
 * on the Dart side. These parts of the Flutter SDK are evolved synchronously.
 *
 * Supports values accepted by `NSJSONSerialization` plus top-level
 * `nil`, `NSNumber`, and `NSString`.
 *
 * On the Dart side, JSON messages are handled by the JSON facilities of the
 * [`dart:convert`](https://api.dartlang.org/stable/dart-convert/JSON-constant.html)
 * package.
 */
public final class FlutterJSONMessageCodec: FlutterMessageCodec {
  public static let shared: FlutterJSONMessageCodec = .init()

  public func encode<T>(_ message: T) throws -> Data where T: Encodable {
    try JSONEncoder().encode(message)
  }

  public func decode<T>(_ message: Data) throws -> T where T: Decodable {
    try JSONDecoder().decode(T.self, from: message)
  }
}
