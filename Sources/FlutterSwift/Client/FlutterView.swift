// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#if os(Linux)
@_implementationOnly
import CxxFlutterSwift

public final class FlutterView {
    let view: FlutterDesktopViewRef

    init(_ view: FlutterDesktopViewRef) {
        self.view = view
    }

    public func dispatchEvent() -> Bool {
        FlutterDesktopViewDispatchEvent(view)
    }

    public var frameRate: Int32 {
        FlutterDesktopViewGetFrameRate(view)
    }
}
#endif
