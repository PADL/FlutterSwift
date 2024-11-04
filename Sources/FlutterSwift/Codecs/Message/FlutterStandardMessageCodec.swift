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
 * A `FlutterMessageCodec` using the Flutter standard binary encoding.
 *
 * This codec is guaranteed to be compatible with the corresponding
 * [StandardMessageCodec](https://api.flutter.dev/flutter/services/StandardMessageCodec-class.html)
 * on the Dart side. These parts of the Flutter SDK are evolved synchronously.
 *
 * Supported messages are acyclic values of these forms:
 *
 * - `nil` or `NSNull`
 * - `NSNumber` (including their representation of Boolean values)
 * - `NSString`
 * - `FlutterStandardTypedData`
 * - `NSArray` of supported values
 * - `NSDictionary` with supported keys and values
 *
 * On the Dart side, these values are represented as follows:
 *
 * - `nil` or `NSNull`: null
 * - `NSNumber`: `bool`, `int`, or `double`, depending on the contained value.
 * - `NSString`: `String`
 * - `FlutterStandardTypedData`: `Uint8List`, `Int32List`, `Int64List`, or `Float64List`
 * - `NSArray`: `List`
 * - `NSDictionary`: `Map`
 */
public final class FlutterStandardMessageCodec: FlutterMessageCodec {
  public static let shared: FlutterStandardMessageCodec = .init()

  public func encode<T>(_ message: T) throws -> Data where T: Encodable {
    try FlutterStandardEncoder().encode(message)
  }

  public func decode<T>(_ message: Data) throws -> T where T: Decodable {
    try FlutterStandardDecoder().decode(T.self, from: message)
  }
}
