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
