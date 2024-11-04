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
