// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

public indirect enum AnyFlutterStandardCodable: Hashable, Sendable {
  case `nil`
  case `true`
  case `false`
  case int32(Int32)
  case int64(Int64)
  case float64(Double)
  case string(String)
  case uint8Data([UInt8])
  case int32Data([Int32])
  case int64Data([Int64])
  case float64Data([Double])
  case list([AnyFlutterStandardCodable])
  case map([AnyFlutterStandardCodable: AnyFlutterStandardCodable])
  case float32Data([Float])
}
