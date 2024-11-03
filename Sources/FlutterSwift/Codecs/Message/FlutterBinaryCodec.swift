// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FoundationEssentials

/**
 * A `FlutterMessageCodec` using unencoded binary messages, represented as
 * `NSData` instances.
 *
 * This codec is guaranteed to be compatible with the corresponding
 * [BinaryCodec](https://api.flutter.dev/flutter/services/BinaryCodec-class.html)
 * on the Dart side. These parts of the Flutter SDK are evolved synchronously.
 *
 * On the Dart side, messages are represented using `ByteData`.
 */
public final class FlutterBinaryCodec: FlutterMessageCodec {
  public static let shared: FlutterBinaryCodec = .init()

  public func encode<T>(_ message: T) throws -> Data where T: Encodable {
    let message = message as! Data
    return message
  }

  public func decode<T>(_ message: Data) throws -> T where T: Decodable {
    message as! T
  }
}
