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

public final class FlutterViewController {
  private let controller: FlutterDesktopViewControllerRef
  public let engine: FlutterEngine

  public enum ViewMode: Int {
    case kNormal = 0
    case kFullscreen = 1
  }

  public enum ViewRotation: Int {
    case kRotation_0 = 0
    case kRotation_90 = 1
    case kRotation_180 = 2
    case kRotation_270 = 3
  }

  public struct ViewProperties {
    let width: Int32
    let height: Int32
    let viewRotation: ViewRotation
    let viewMode: ViewMode
    let title: String?
    let appId: String?
    let useMouseCursor: Bool
    let useOnscreenKeyboard: Bool
    let useWindowDecoration: Bool
    let textScaleFactor: Double
    let enableHighContrast: Bool
    let forceScaleFactor: Bool
    let scaleFactor: Double
    let enableVSync: Bool

    #if FLUTTER_TARGET_BACKEND_GBM || FLUTTER_TARGET_BACKEND_EGLSTREAM
    public static let ViewModeDefault = ViewMode.kFullscreen
    public static let UseWindowDecorationDefault = false
    #else
    public static let ViewModeDefault = ViewMode.kNormal
    public static let UseWindowDecorationDefault = true
    #endif

    public init(
      width: Int32,
      height: Int32,
      viewRotation: ViewRotation = .kRotation_0,
      viewMode: ViewMode = ViewProperties.ViewModeDefault,
      title: String? = nil,
      appId: String? = nil,
      useMouseCursor: Bool = true,
      useOnscreenKeyboard: Bool = false,
      useWindowDecoration: Bool = ViewProperties.UseWindowDecorationDefault,
      textScaleFactor: Double = 1.0,
      enableHighContrast: Bool = false,
      forceScaleFactor: Bool = false,
      scaleFactor: Double = 1.0,
      enableVSync: Bool = true
    ) {
      self.width = width
      self.height = height
      self.viewRotation = viewRotation
      self.viewMode = viewMode
      self.title = title
      self.appId = appId
      self.useMouseCursor = useMouseCursor
      self.useOnscreenKeyboard = useOnscreenKeyboard
      self.useWindowDecoration = useWindowDecoration
      self.textScaleFactor = textScaleFactor
      self.enableHighContrast = enableHighContrast
      self.forceScaleFactor = forceScaleFactor
      self.scaleFactor = scaleFactor
      self.enableVSync = enableVSync
    }
  }

  public init?(
    properties viewProperties: ViewProperties,
    project: DartProject,
    switches: [String: Any] = [:]
  ) {
    var cViewProperties = FlutterDesktopViewProperties()
    var controller: FlutterDesktopViewControllerRef?

    guard let engine = FlutterEngine(project: project, switches: switches)
    else { return nil }
    self.engine = engine

    cViewProperties.width = viewProperties.width
    cViewProperties.height = viewProperties.height
    switch viewProperties.viewRotation {
    case .kRotation_0:
      cViewProperties.view_rotation = kRotation_0
    case .kRotation_90:
      cViewProperties.view_rotation = kRotation_90
    case .kRotation_180:
      cViewProperties.view_rotation = kRotation_180
    case .kRotation_270:
      cViewProperties.view_rotation = kRotation_270
    }
    switch viewProperties.viewMode {
    case .kNormal:
      cViewProperties.view_mode = kNormalscreen
    case .kFullscreen:
      cViewProperties.view_mode = kFullscreen
    }
    cViewProperties.use_mouse_cursor = viewProperties.useMouseCursor
    cViewProperties.use_onscreen_keyboard = viewProperties.useOnscreenKeyboard
    cViewProperties.use_window_decoration = viewProperties.useWindowDecoration
    cViewProperties.text_scale_factor = viewProperties.textScaleFactor
    cViewProperties.enable_high_contrast = viewProperties.enableHighContrast
    cViewProperties.force_scale_factor = viewProperties.forceScaleFactor
    cViewProperties.scale_factor = viewProperties.scaleFactor
    cViewProperties.enable_vsync = viewProperties.enableVSync
    viewProperties.title?.withCString { title in
      cViewProperties.title = title
      viewProperties.appId?.withCString { appId in
        cViewProperties.app_id = appId
        controller = FlutterDesktopViewControllerCreate(
          &cViewProperties,
          engine.relinquishEngine()
        )
      }
    }
    guard let controller else {
      debugPrint("Failed to create view controller.")
      return nil
    }
    self.controller = controller
    view = FlutterView(FlutterDesktopViewControllerGetView(self.controller))
    self.engine.viewController = self // weak reference
  }

  public var view: FlutterView {
    didSet {
      engine.setView(view)
    }
  }

  var binaryMessenger: FlutterBinaryMessenger {
    engine.binaryMessenger
  }

  deinit {
    self.engine.viewController = nil
    FlutterDesktopViewControllerDestroy(controller)
  }
}
#endif
