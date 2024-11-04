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
