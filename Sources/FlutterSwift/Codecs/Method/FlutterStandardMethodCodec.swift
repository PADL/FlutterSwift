// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation

/**
 * A `FlutterMethodCodec` using the Flutter standard binary encoding.
 *
 * This codec is guaranteed to be compatible with the corresponding
 * [StandardMethodCodec](https://api.flutter.dev/flutter/services/StandardMethodCodec-class.html)
 * on the Dart side. These parts of the Flutter SDK are evolved synchronously.
 *
 * Values supported as method arguments and result payloads are those supported by
 * `FlutterStandardMessageCodec`.
 */
public final class FlutterStandardMethodCodec: FlutterMethodCodec {
    public var shared: FlutterStandardMethodCodec = .init()

    public func encode(method call: FlutterMethodCall) throws -> Data {
        fatalError("unimplemented")
    }

    public func decode(method call: Data) throws -> FlutterMethodCall {
        fatalError("unimplemented")
    }

    public func encode(envelope: FlutterEnvelope) -> Data {
        fatalError("unimplemented")
    }

    public func decode(envelope: Data) -> FlutterEnvelope {
        fatalError("unimplemented")
    }
}
