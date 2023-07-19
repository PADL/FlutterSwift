// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#if os(Linux)
@_implementationOnly
import CxxFlutterSwift
import Foundation

public protocol FlutterPlatformView {
    var registrar: FlutterPluginRegistrar { get }
    var viewId: CInt { get }
    var textureId: CInt { get set }
    var isFocused: Bool { get set }
}

public protocol FlutterPlatformViewFactory {
    var registrar: FlutterPluginRegistrar { get }

    func create(viewId: CInt, width: Double, height: Double, params: [UInt8])
        -> FlutterPlatformView?
}

public struct FlutterDesktopPlatformView: FlutterPlatformView {
    public let registrar: FlutterPluginRegistrar
    public let viewId: CInt
    public var textureId: CInt = -1
    public var isFocused: Bool = false

    public init(registrar: FlutterPluginRegistrar, viewId: CInt) {
        self.registrar = registrar
        self.viewId = viewId
    }
}

#endif
