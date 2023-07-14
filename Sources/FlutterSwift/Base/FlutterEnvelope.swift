// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import AnyCodable
import Foundation

public enum FlutterEnvelope: Codable {
    case success(AnyCodable)
    case error(FlutterError)

    // FIXME: instead of treating as a special case, we could use reflection to determine discrimant and add support for enums
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        let standardContainer = container as? UnkeyedFlutterStandardEncodingContainer
        switch self {
        case let .success(value):
            try standardContainer?.state.encodeDiscriminant(0)
            try container.encode(value)
        case let .error(error):
            try standardContainer?.state.encodeDiscriminant(1)
            try container.encode(error)
        }
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        if var container = container as? UnkeyedFlutterStandardDecodingContainer {
            switch try container.state.decodeDiscriminant() {
            case 0:
                self = .success(try container.decode(AnyCodable.self))
            case 1:
                self = .error(try container.decode(FlutterError.self))
            default:
                throw FlutterChannelError.unknownDiscriminant
            }
        } else {
            switch container.count {
            case 1:
                self = .success(try container.decode(AnyCodable.self))
            case 3:
                self = .error(try container.decode(FlutterError.self))
            default:
                throw FlutterChannelError.unknownDiscriminant
            }
        }
    }
}
