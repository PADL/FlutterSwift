// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import AnyCodable
import Foundation

/**
 * A `FlutterMethodCodec` using UTF-8 encoded JSON method calls and result
 * envelopes.
 *
 * This codec is guaranteed to be compatible with the corresponding
 * [JSONMethodCodec](https://api.flutter.dev/flutter/services/JSONMethodCodec-class.html)
 * on the Dart side. These parts of the Flutter SDK are evolved synchronously.
 *
 * Values supported as methods arguments and result payloads are
 * those supported as top-level or leaf values by `FlutterJSONMessageCodec`.
 */
public final class FlutterJSONMethodCodec: FlutterMethodCodec {
    public var shared: FlutterJSONMethodCodec = .init()

    public func encode(method call: FlutterMethodCall) throws -> Data {
        try JSONEncoder().encode(call)
    }

    public func decode(method message: Data) throws -> FlutterMethodCall {
        try JSONDecoder().decode(FlutterMethodCall.self, from: message)
    }

    public func encode(envelope: FlutterEnvelope) throws -> Data {
        try JSONEncoder().encode(envelope)
    }

    public func decode(envelope: Data) throws -> FlutterEnvelope {
        try JSONDecoder().decode(FlutterEnvelope.self, from: envelope)
    }
}
