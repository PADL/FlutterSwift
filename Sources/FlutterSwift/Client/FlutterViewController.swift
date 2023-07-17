// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#if os(Linux)
@_implementationOnly
import CxxFlutterSwift

public final class FlutterViewController {
    private let controller: FlutterDesktopViewControllerRef
    public let engine: FlutterEngine
    public let view: FlutterView

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
        let width: CInt
        let height: CInt
        let viewRotation: ViewRotation
        let viewMode: ViewMode
        let title: String?
        let appId: String?
        let useMouseCursor: Bool
        let useOnscreenKeyboard: Bool
        let useWindowDecoration: Bool
        let forceScaleFactor: Bool
        let scaleFactor: Double

        public init(
            width: CInt,
            height: CInt,
            viewRotation: ViewRotation = .kRotation_0,
            viewMode: ViewMode = .kNormal,
            title: String? = nil,
            appId: String? = nil,
            useMouseCursor: Bool = true,
            useOnscreenKeyboard: Bool = false,
            useWindowDecoration: Bool = true,
            forceScaleFactor: Bool = false,
            scaleFactor: Double = 1.0
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
            self.forceScaleFactor = forceScaleFactor
            self.scaleFactor = scaleFactor
        }
    }

    public init?(properties viewProperties: ViewProperties, project: DartProject) {
        var cViewProperties = FlutterDesktopViewProperties()
        var controller: FlutterDesktopViewControllerRef?
        var view: FlutterView?

        guard let engine = FlutterEngine(project: project) else { return nil }
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
        cViewProperties.force_scale_factor = viewProperties.forceScaleFactor
        cViewProperties.scale_factor = viewProperties.scaleFactor
        viewProperties.title?.withCString { title in
            cViewProperties.title = title
            viewProperties.appId?.withCString { appId in
                cViewProperties.app_id = appId
                controller = FlutterDesktopViewControllerCreate(
                    &cViewProperties,
                    engine.relinquishEngine()
                )
                if let controller {
                    view = FlutterView(FlutterDesktopViewControllerGetView(controller))
                }
            }
        }
        guard let controller, let view else {
            debugPrint("Failed to create view controller.")
            return nil
        }
        self.controller = controller
        self.view = view
    }

    deinit {
        FlutterDesktopViewControllerDestroy(controller)
    }
}
#endif
