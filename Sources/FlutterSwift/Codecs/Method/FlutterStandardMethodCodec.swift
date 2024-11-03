// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FoundationEssentials

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
  public let shared: FlutterStandardMethodCodec = .init()

  public init() {}

  public func encode<T>(method call: FlutterMethodCall<T>) throws -> Data {
    try FlutterStandardEncoder().encode(call)
  }

  public func decode<T>(method message: Data) throws -> FlutterMethodCall<T> {
    try FlutterStandardDecoder().decode(FlutterMethodCall<T>.self, from: message)
  }

  public func encode<T>(envelope: FlutterEnvelope<T>) throws -> Data {
    try FlutterStandardEncoder().encode(envelope)
  }

  public func decode<T>(envelope: Data) throws -> FlutterEnvelope<T> {
    try FlutterStandardDecoder().decode(FlutterEnvelope<T>.self, from: envelope)
  }
}
