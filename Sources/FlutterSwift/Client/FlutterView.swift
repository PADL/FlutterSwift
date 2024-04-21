// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#if os(Linux)
@_implementationOnly
import CxxFlutterSwift

let kChannelName = "flutter/platform_views"

public struct FlutterView {
  let view: FlutterDesktopViewRef
  var platformViewsPluginRegistrar: FlutterPluginRegistrar?
  var platformViewsHandler: FlutterPlatformViewsPlugin?
  var viewController: FlutterViewController? {
    didSet {
      if let viewController {
        platformViewsPluginRegistrar = viewController.engine.registrar(for: kChannelName)
        platformViewsHandler = try? FlutterPlatformViewsPlugin
          .register(with: platformViewsPluginRegistrar!)
        viewController.view = self
      } else {
        platformViewsPluginRegistrar = nil
        platformViewsHandler = nil
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
