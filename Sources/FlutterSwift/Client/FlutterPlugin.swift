// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#if os(Linux)
@_implementationOnly
import CxxFlutterSwift
import Foundation

public typealias FlutterPluginRegistrantCallback = (FlutterPluginRegistry) -> ()

public protocol FlutterPlugin {
    associatedtype Arguments: Codable
    associatedtype Result: Codable

    static func register(with registrar: FlutterPluginRegistrar)
    static func setPluginRegistrantCallback(_ callback: FlutterPluginRegistrantCallback)

    func handleMethod(call: FlutterMethodCall<Arguments>) async throws -> Result
    func detachFromEngine(for registrar: FlutterPluginRegistrar)
}

public extension FlutterPlugin {
    func eraseToAnyFlutterPlugin() -> AnyFlutterPlugin<Arguments, Result> {
        AnyFlutterPlugin(self)
    }
}

public struct AnyFlutterPlugin<Arguments: Codable, Result: Codable>: FlutterPlugin {
    let _handleMethod: (FlutterMethodCall<Arguments>) async throws -> Result
    let _detachFromEngine: (FlutterPluginRegistrar) -> ()

    init<T: FlutterPlugin>(_ plugin: T) where T.Arguments == Arguments, T.Result == Result {
        _handleMethod = { try await plugin.handleMethod(call: $0) }
        _detachFromEngine = { plugin.detachFromEngine(for: $0) }
    }

    public static func register(with registrar: FlutterPluginRegistrar) {}

    public static func setPluginRegistrantCallback(_ callback: FlutterPluginRegistrantCallback) {}

    public func handleMethod(call: FlutterMethodCall<Arguments>) async throws -> Result {
        try await _handleMethod(call)
    }

    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        _detachFromEngine(registrar)
    }
}

public protocol FlutterPluginRegistrar {
    var messenger: FlutterBinaryMessenger? { get }
    var view: FlutterView? { get }

    func register(
        viewFactory factory: FlutterPlatformViewFactory,
        with factoryId: String
    )
    func publish(_ value: Any)
    func addMethodCallDelegate<Arguments: Codable, Result: Codable>(
        _ delegate: AnyFlutterPlugin<Arguments, Result>,
        on channel: FlutterMethodChannel
    ) async throws
    func lookupKey(for asset: String) -> String?
    func lookupKey(for asset: String, from package: String) -> String?
}

public protocol FlutterPluginRegistry {
    func registrarForPlugin(_ pluginKey: String) -> FlutterPluginRegistrar?
    func hasPlugin(_ pluginKey: String) -> Bool
    func valuePublishedByPlugin(_ pluginKey: String) -> Any?
}

public class FlutterDesktopPluginRegistrar: FlutterPluginRegistrar {
    private var engine: FlutterEngine
    private var pluginKey: String
    var registrar: FlutterDesktopPluginRegistrarRef?

    public init(
        engine: FlutterEngine,
        _ pluginName: String
    ) {
        self.engine = engine
        pluginKey = pluginName
        registrar = FlutterDesktopEngineGetPluginRegistrar(engine.engine, pluginName)
        FlutterDesktopPluginRegistrarSetDestructionHandlerBlock(registrar!) { _ in
            self.registrar = nil
        }
    }

    public var messenger: FlutterBinaryMessenger? {
        guard let registrar else { return nil }
        return FlutterDesktopMessenger(
            messenger: FlutterDesktopPluginRegistrarGetMessenger(registrar)
        )
    }

    public var view: FlutterView? {
        guard let registrar else { return nil }
        let view = FlutterDesktopPluginRegistrarGetView(registrar)
        return FlutterView(view)
    }

    public func register(
        viewFactory factory: FlutterPlatformViewFactory,
        with factoryId: String
    ) {
        fatalError("platform views not supported")
    }

    public func publish(_ value: Any) {
        engine.pluginPublications[pluginKey] = value
    }

    public func addMethodCallDelegate<Arguments: Codable, Result: Codable>(
        _ delegate: AnyFlutterPlugin<Arguments, Result>,
        on channel: FlutterMethodChannel
    ) async throws {
        try await channel.setMethodCallHandler { call in
            try await delegate.handleMethod(call: call)
        }
    }

    public func lookupKey(for asset: String) -> String? {
        guard let bundle = Bundle(path: engine.project.assetsPath) else {
            return nil
        }
        return bundle.path(forResource: asset, ofType: "")
    }

    public func lookupKey(for asset: String, from package: String) -> String? {
        lookupKey(for: "packages/\(package)/\(asset)")
    }
}

public class FlutterDesktopTextureRegistrar {
    private let registrar: FlutterDesktopTextureRegistrarRef

    public init(engine: FlutterEngine) {
        registrar = FlutterDesktopEngineGetTextureRegistrar(engine.engine)
    }

    init?(plugin: FlutterDesktopPluginRegistrar) {
        guard let registrar = plugin.registrar else { return nil }
        self.registrar = FlutterDesktopRegistrarGetTextureRegistrar(registrar)
    }
}

#endif
