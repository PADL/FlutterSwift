//
// Copyright (c) 2023-2024 PADL Software Pty Ltd
//
// Licensed under the Apache License, Version 2.0 (the License);
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an 'AS IS' BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#if os(Linux) && canImport(Glibc)
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
