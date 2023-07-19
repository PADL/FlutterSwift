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

    init()

    func handleMethod(call: FlutterMethodCall<Arguments>) async throws -> Result
    func detachFromEngine(for registrar: FlutterPluginRegistrar)
}

public extension FlutterPlugin {
    static func register(with registrar: FlutterPluginRegistrar) async throws {
        let plugin = Self()
        let channel = FlutterMethodChannel(
            name: registrar.pluginKey,
            binaryMessenger: registrar.binaryMessenger!
        )
        try await registrar.addMethodCallDelegate(plugin.eraseToAnyFlutterPlugin(), on: channel)
    }
}

public extension FlutterPlugin {
    func eraseToAnyFlutterPlugin() -> AnyFlutterPlugin<Arguments, Result> {
        AnyFlutterPlugin(self)
    }
}

public struct AnyFlutterPlugin<Arguments: Codable, Result: Codable>: FlutterPlugin {
    let _handleMethod: (FlutterMethodCall<Arguments>) async throws -> Result
    let _detachFromEngine: (FlutterPluginRegistrar) -> ()

    public init() {
        _handleMethod = { _ in fatalError() }
        _detachFromEngine = { _ in }
    }

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
    var pluginKey: String { get }
    var binaryMessenger: FlutterBinaryMessenger? { get }
    var view: FlutterView? { get }

    func register(
        viewFactory factory: FlutterPlatformViewFactory,
        with factoryId: String
    ) throws
    func publish(_ value: Any)
    func addMethodCallDelegate<Arguments: Codable, Result: Codable>(
        _ delegate: AnyFlutterPlugin<Arguments, Result>,
        on channel: FlutterMethodChannel
    ) async throws
    func lookupKey(for asset: String) -> String?
    func lookupKey(for asset: String, from package: String) -> String?
}

public protocol FlutterPluginRegistry {
    func registrar(for pluginKey: String) -> FlutterPluginRegistrar?
    func has(plugin pluginKey: String) -> Bool
    func valuePublished(by pluginKey: String) -> Any?
}

public class FlutterDesktopPluginRegistrar: FlutterPluginRegistrar {
    public let pluginKey: String
    var registrar: FlutterDesktopPluginRegistrarRef?
    var detachFromEngine: ((FlutterPluginRegistrar) -> ())?
    private var engine: FlutterEngine

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

    public var binaryMessenger: FlutterBinaryMessenger? {
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
    ) throws {
        guard let view, let platformViewsHandler = view.platformViewsHandler else {
            throw FlutterSwiftError.viewNotFound
        }
        platformViewsHandler.register(viewType: factoryId, factory: factory)
    }

    public func publish(_ value: Any) {
        engine.pluginPublications[pluginKey] = value
    }

    public func addMethodCallDelegate<Arguments: Codable, Result: Codable>(
        _ delegate: AnyFlutterPlugin<Arguments, Result>,
        on channel: FlutterMethodChannel
    ) async throws {
        self.detachFromEngine = delegate._detachFromEngine
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
