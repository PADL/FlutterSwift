// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#if os(Linux)
import Foundation

// doesn't seem to be in swift-corelibs-foundation we are using
@_spi(FlutterSwiftPrivate)
public extension NSLock {
  func withLock<R>(_ body: () throws -> R) rethrows -> R {
    lock()
    defer {
      self.unlock()
    }

    return try body()
  }
}
#endif
