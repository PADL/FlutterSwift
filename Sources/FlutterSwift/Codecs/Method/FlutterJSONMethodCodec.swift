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
  public let shared: FlutterJSONMethodCodec = .init()

  public init() {}

  public func encode<T>(method call: FlutterMethodCall<T>) throws -> Data {
    try JSONEncoder().encode(call)
  }

  public func decode<T>(method message: Data) throws -> FlutterMethodCall<T> {
    try JSONDecoder().decode(FlutterMethodCall<T>.self, from: message)
  }

  public func encode<T>(envelope: FlutterEnvelope<T>) throws -> Data {
    try JSONEncoder().encode(envelope)
  }

  public func decode<T>(envelope: Data) throws -> FlutterEnvelope<T> {
    try JSONDecoder().decode(FlutterEnvelope<T>.self, from: envelope)
  }
}
