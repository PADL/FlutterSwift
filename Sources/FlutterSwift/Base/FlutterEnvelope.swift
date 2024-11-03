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

public enum FlutterEnvelope<Success: Codable>: Codable {
  case success(Success?)
  case failure(FlutterError)

  public init(_ value: Success?) {
    self = .success(value)
  }

  public init(_ error: FlutterError) {
    self = .failure(error)
  }

  public init(from decoder: Decoder) throws {
    var container = try decoder.unkeyedContainer()
    if var container = container as? UnkeyedFlutterStandardDecodingContainer {
      switch try container.state.decodeDiscriminant() {
      case 0:
        self = try .success(container.decodeIfPresent(Success.self))
      case 1:
        self = try .failure(container.decode(FlutterError.self))
      default:
        throw FlutterSwiftError.unknownDiscriminant
      }
    } else {
      switch container.count {
      case 1:
        self = try .success(container.decodeIfPresent(Success.self))
      case 3:
        fallthrough
      case 4: // contains stacktrace
        self = try .failure(container.decode(FlutterError.self))
      default:
        throw FlutterSwiftError.unknownDiscriminant
      }
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.unkeyedContainer()
    let standardContainer = container as? UnkeyedFlutterStandardEncodingContainer
    switch self {
    case let .success(value):
      try standardContainer?.state.encodeDiscriminant(0)
      if let value {
        try container.encode(value)
      } else {
        try container.encodeNil()
      }
    case let .failure(error):
      try standardContainer?.state.encodeDiscriminant(1)
      try container.encode(error)
    }
  }
}
