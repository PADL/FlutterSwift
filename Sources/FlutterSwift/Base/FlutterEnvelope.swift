// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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
                self = .success(try container.decodeIfPresent(Success.self))
            case 1:
                self = .failure(try container.decode(FlutterError.self))
            default:
                throw FlutterSwiftError.unknownDiscriminant
            }
        } else {
            switch container.count {
            case 1:
                self = .success(try container.decodeIfPresent(Success.self))
            case 3:
                fallthrough
            case 4: // contains stacktrace
                self = .failure(try container.decode(FlutterError.self))
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
