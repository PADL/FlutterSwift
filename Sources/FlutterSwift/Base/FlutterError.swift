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

/**
 * Error object representing an unsuccessful outcome of invoking a method
 * on a `FlutterMethodChannel`, or an error event on a `FlutterEventChannel`.
 */
public struct FlutterError: Error, Codable, Sendable {
  let code: String
  let message: String?
  let details: AnyFlutterStandardCodable?
  let stacktrace: String?

  public init(
    code: String,
    message: String? = nil,
    details: AnyFlutterStandardCodable? = nil,
    stacktrace: String? = nil
  ) {
    self.code = code
    self.message = message
    self.details = details
    self.stacktrace = stacktrace
  }

  // according to FlutterCodecs.mm, errors are encoded as unkeyed arrays
  public init(from decoder: Decoder) throws {
    var container = try decoder.unkeyedContainer()
    code = try container.decode(String.self)
    message = try container.decodeIfPresent(String.self)
    details = try container.decodeIfPresent(AnyFlutterStandardCodable.self)
    if container.count ?? 0 > 3 {
      stacktrace = try container.decode(String.self)
    } else {
      stacktrace = nil
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.unkeyedContainer()
    try container.encode(code)
    if let message {
      try container.encode(message)
    } else {
      try container.encodeNil()
    }
    if let details {
      try container.encode(details)
    } else {
      try container.encodeNil()
    }
    if let stacktrace {
      try container.encode(stacktrace)
    }
  }
}
