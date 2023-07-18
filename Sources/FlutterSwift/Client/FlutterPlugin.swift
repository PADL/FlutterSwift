// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#if os(Linux)
@_implementationOnly
import CxxFlutterSwift

// TODO: finish implementing Swift plugins

public protocol FlutterTextureRegistry {}

public protocol FlutterPlatformViewFactory {}

public typealias FlutterPluginRegistrantCallback = (FlutterPluginRegistry) -> ()

public protocol FlutterPlugin {
    static func register(with registrar: FlutterPluginRegistrar)
    static func setPluginRegistrantCallback(_ callback: FlutterPluginRegistrantCallback)

    func handleMethod<
        Arguments: Codable,
        Result: Codable
    >(call: FlutterMethodCall<Arguments>) async throws -> Result
    func detachFromEngine(for registrar: FlutterPluginRegistrar)
}

public protocol FlutterPluginRegistrar {
    var messenger: FlutterBinaryMessenger { get }
    var textures: FlutterTextureRegistry { get }

    func register(
        viewFactory factory: FlutterPlatformViewFactory,
        with factoryId: String
    )
    func publish(_ value: Any)
    func addMethodCallDelegate(
        _ delegate: FlutterPlugin,
        on channel: FlutterMethodChannel
    )
    func addApplicationDelegate(_ delegate: FlutterPlugin)
    func lookupKey(for asset: String) -> String?
    func lookupKey(for asset: String, from package: String) -> String?
}

public protocol FlutterPluginRegistry {
    func registrarForPlugin(_ pluginKey: String) -> FlutterPluginRegistrar?
    func pluginKey(_ pluginKey: String) -> Bool
    func valuePublishedByPlugin(_ pluginKey: String) -> Any?
}

public class FlutterDesktopPluginRegistrar {
    private var registrar: FlutterDesktopPluginRegistrarRef!

    public init(
        engine: FlutterEngine,
        _ pluginName: String
    ) {
        self.registrar = FlutterDesktopEngineGetPluginRegistrar(engine.engine, pluginName)
        FlutterDesktopPluginRegistrarSetDestructionHandlerBlock(self.registrar, { _ in
            self.registrar = nil
        })
    }

/*
    public var view: FlutterView {
        let view = FlutterDesktopPluginRegistrarGetView(registrar)
        return FlutterView(view)
    }
*/
}

public class FlutterDesktopTextureRegistrar {
    private let registrar: FlutterDesktopTextureRegistrarRef

    public init(
        engine: FlutterEngine
    ) {
        self.registrar = FlutterDesktopEngineGetTextureRegistrar(engine.engine)
    }

}

#endif
