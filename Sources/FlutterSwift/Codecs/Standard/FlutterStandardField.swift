// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

public enum FlutterStandardField: UInt8, Codable, Sendable {
    case `nil`
    case `true`
    case `false`
    case int32
    case int64
    case intHex
    case float64
    case string
    case uint8Data
    case int32Data
    case int64Data
    case float64Data
    case list
    case map
    case float32Data
}
