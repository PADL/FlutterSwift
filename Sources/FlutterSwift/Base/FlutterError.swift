// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation

/**
 * Error object representing an unsuccessful outcome of invoking a method
 * on a `FlutterMethodChannel`, or an error event on a `FlutterEventChannel`.
 */
public struct FlutterError: Error, Codable, @unchecked Sendable {
    let code: String
    let message: String?
    let details: FlutterStandardVariant?
    let stacktrace: String?

    public init(
        code: String,
        message: String? = nil,
        details: FlutterStandardVariant? = nil,
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
        details = try container.decodeIfPresent(FlutterStandardVariant.self)
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
