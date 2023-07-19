// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#if os(Linux)
import AnyCodable
@_implementationOnly
import CxxFlutterSwift

public protocol FlutterPlatformView {
    var registrar: FlutterPluginRegistrar { get }
    var viewId: Int { get }
    var textureId: Int { get set }
    var isFocused: Bool { get set }

    func dispose() -> ()
}

public protocol FlutterPlatformViewFactory {
    var registrar: FlutterPluginRegistrar { get }

    func create(viewId: Int, width: Double, height: Double, params: [UInt8])
        -> FlutterPlatformView?
}

let kChannelName = "flutter/platform_views"

enum FlutterPlatformViewMethod: String {
    case create
    case dispose
    case resize
    case setDirection
    case clearFocus
    case touchMethod
    case acceptGesture
    case rejectGesture
    case enter
    case exit
}

enum FlutterPlatformViewKey: String, CaseIterable {
    case viewType
    case id
    case width
    case height
    case params
}

public class FlutterPlatformViewsPlugin {
    let channel: FlutterMethodChannel
    var viewFactories = [String: FlutterPlatformViewFactory]()
    var platformViews = [Int: FlutterPlatformView]()
    var currentViewId: Int = -1

    public init(binaryMessenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: kChannelName, binaryMessenger: binaryMessenger)
        Task {
            // FIXME: what if this fails?
            try? await self.channel.setMethodCallHandler(handleMethodCall)
        }
    }

    func handleMethodCall(call: FlutterMethodCall<AnyCodable>) async throws -> AnyCodable? {
        guard let methodName = FlutterPlatformViewMethod(rawValue: call.method) else {
            throw FlutterSwiftError.methodNotImplemented
        }

        switch methodName {
        case .create:
            return try await create(call.arguments)
        case .dispose:
            return try await dispose(call.arguments)
        default:
            throw FlutterSwiftError.methodNotImplemented
        }
    }

    public func register(viewType: String, factory: FlutterPlatformViewFactory) {
        guard !viewFactories.keys.contains(viewType) else {
            debugPrint("Platform view factory for \(viewType) is already registered")
            return
        }
        viewFactories[viewType] = factory
    }

    func create(_ arguments: AnyCodable?) async throws -> AnyCodable? {
        guard let arguments = arguments?.value as? [String: Any] else {
            throw FlutterError(code: "Couldn't parse arguments")
        }

        guard let viewType = arguments[FlutterPlatformViewKey.viewType.rawValue] as? String else {
            throw FlutterError(code: "Couldn't find the view type in the arguments")
        }

        guard let viewId = arguments[FlutterPlatformViewKey.id.rawValue] as? Int else {
            throw FlutterError(code: "Couldn't find the view id in the arguments")
        }

        guard let width = arguments[FlutterPlatformViewKey.width.rawValue] as? Double else {
            throw FlutterError(code: "Couldn't find the width in the arguments")
        }

        guard let height = arguments[FlutterPlatformViewKey.height.rawValue] as? Double else {
            throw FlutterError(code: "Couldn't find the height in the arguments")
        }

        guard let factory = viewFactories[viewType] else {
            throw FlutterError(code: "Couldn't find the view type")
        }

        let params = arguments[FlutterPlatformViewKey.params.rawValue] as? [UInt8]
        guard let view = factory.create(
            viewId: viewId,
            width: width,
            height: height,
            params: params ?? []
        ) else {
            throw FlutterError(code: "Failed to create a platform view")
        }

        platformViews[viewId] = view
        if var currentView = platformViews[currentViewId] {
            currentView.isFocused = false
        }
        currentViewId = viewId
        return nil
    }

    func dispose(_ arguments: AnyCodable?) async throws -> AnyCodable? {
        guard let arguments = arguments?.value as? [String: Any] else {
            throw FlutterError(code: "Couldn't parse arguments")
        }

        guard let viewId = arguments[FlutterPlatformViewKey.id.rawValue] as? Int else {
            throw FlutterError(code: "Couldn't find the view id in the arguments")
        }

        guard let platformView = platformViews[viewId] else {
            throw FlutterError(code: "Couldn't find the view id in the arguments")
        }

        platformView.dispose()
        return nil
    }
}

#endif
