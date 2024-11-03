// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FoundationEssentials

/**
 * A codec for method calls and enveloped results.
 *
 * Method calls are encoded as binary messages with enough structure that the
 * codec can extract a method name `NSString` and an arguments `NSObject`,
 * possibly `nil`. These data items are used to populate a `FlutterMethodCall`.
 *
 * Result envelopes are encoded as binary messages with enough structure that
 * the codec can determine whether the result was successful or an error. In
 * the former case, the codec can extract the result `NSObject`, possibly `nil`.
 * In the latter case, the codec can extract an error code `NSString`, a
 * human-readable `NSString` error message (possibly `nil`), and a custom
 * error details `NSObject`, possibly `nil`. These data items are used to
 * populate a `FlutterError`.
 */
public protocol FlutterMethodCodec {
  var shared: Self { get }

  func encode<T>(method: FlutterMethodCall<T>) throws -> Data
  func decode<T>(method: Data) throws -> FlutterMethodCall<T>
  func encode<T>(envelope: FlutterEnvelope<T>) throws -> Data
  func decode<T>(envelope: Data) throws -> FlutterEnvelope<T>
}
