// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import AnyCodable
import Foundation

/**
 * Error object representing an unsuccessful outcome of invoking a method
 * on a `FlutterMethodChannel`, or an error event on a `FlutterEventChannel`.
 */
public struct FlutterError: Error, Codable {
    let code: String
    let message: String?
    let details: AnyCodable
}
