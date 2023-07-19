// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#if os(Linux)
@_implementationOnly
import CxxFlutterSwift

// FIXME: what should this be?
let kPlatformViewsPlugin = "dev.flutter.elinux.platformViewsPlugin"

public final class FlutterView {
    let view: FlutterDesktopViewRef
    var internalPluginRegistrar: FlutterPluginRegistrar?
    var platformViewsHandler: FlutterPlatformViewsPlugin?
    var viewController: FlutterViewController? {
        didSet {
            if let viewController {
                internalPluginRegistrar = viewController.engine.registrar(for: kPlatformViewsPlugin)
                platformViewsHandler = FlutterPlatformViewsPlugin(
                    binaryMessenger: viewController
                        .binaryMessenger
                )
                viewController.view = self
            } else {
                internalPluginRegistrar = nil
                platformViewsHandler = nil
                // FIXME: what to do with old view controller?
            }
        }
    }

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
