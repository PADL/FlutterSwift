// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation

@_spi(FlutterSwiftPrivate)
public final class ManagedCriticalState<State> {
  private var buffer: State
  private let lock: NSLock

  public init(_ initial: State) {
    buffer = initial
    lock = NSLock()
  }

  public func withCriticalRegion<R>(_ critical: (inout State) throws -> R) rethrows -> R {
    lock.lock()
    defer { lock.unlock() }
    return try critical(&buffer)
  }
}

extension ManagedCriticalState: @unchecked Sendable where State: Sendable {}
