// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation

/**
 * A message encoding/decoding mechanism.
 */
public protocol FlutterMessageCodec {
  static var shared: Self { get }

  func encode<T: Encodable>(_ message: T) throws -> Data
  func decode<T: Decodable>(_ message: Data) throws -> T
}
