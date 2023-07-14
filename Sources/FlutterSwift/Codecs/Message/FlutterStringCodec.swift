// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation

/**
 * A `FlutterMessageCodec` using UTF-8 encoded `NSString` messages.
 *
 * This codec is guaranteed to be compatible with the corresponding
 * [StringCodec](https://api.flutter.dev/flutter/services/StringCodec-class.html)
 * on the Dart side. These parts of the Flutter SDK are evolved synchronously.
 */
public final class FlutterStringCodec: FlutterMessageCodec {
    public static var shared: FlutterStringCodec = .init()

    public func encode<T>(_ message: T) throws -> Data where T: Encodable {
        let string = message as! String
        guard let data = string.data(using: .utf8) else {
            let context = EncodingError.Context(
                codingPath: [],
                debugDescription: "Invalid UTF8 string"
            )
            throw EncodingError.invalidValue(string, context)
        }
        return data
    }

    public func decode<T>(_ message: Data) throws -> T where T: Decodable {
        guard let string = String(data: message, encoding: .utf8) else {
            let context = DecodingError.Context(
                codingPath: [],
                debugDescription: "Invalid UTF8 string"
            )
            throw DecodingError.dataCorrupted(context)
        }
        return string as! T
    }
}
