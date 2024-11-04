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
 * A `FlutterMessageCodec` using UTF-8 encoded `NSString` messages.
 *
 * This codec is guaranteed to be compatible with the corresponding
 * [StringCodec](https://api.flutter.dev/flutter/services/StringCodec-class.html)
 * on the Dart side. These parts of the Flutter SDK are evolved synchronously.
 */
public final class FlutterStringCodec: FlutterMessageCodec {
  public static let shared: FlutterStringCodec = .init()

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
