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
import Foundation

public protocol FlutterPlugin {
  associatedtype Arguments: Codable & Sendable
  associatedtype Result: Codable & Sendable

  init()

  func handleMethod(call: FlutterMethodCall<Arguments>) throws -> Result
  func detachFromEngine(for registrar: FlutterPluginRegistrar)
}

public extension FlutterPlugin {
  static func register(
    with registrar: FlutterPluginRegistrar,
    on channel: FlutterMethodChannel? = nil
  ) throws -> Self {
    let plugin = Self()
    let _channel: FlutterMethodChannel

    if let channel {
      _channel = channel
    } else {
      _channel = FlutterMethodChannel(
        name: registrar.pluginKey,
        binaryMessenger: registrar.binaryMessenger!
      )
    }

    try (registrar as! FlutterDesktopPluginRegistrar)
      .addMethodCallDelegate(plugin.eraseToAnyFlutterPlugin(), on: _channel)

    return plugin
  }
}

extension FlutterPlugin {
  func eraseToAnyFlutterPlugin() -> AnyFlutterPlugin<Arguments, Result> {
    AnyFlutterPlugin(self)
  }
}

struct AnyFlutterPlugin<Arguments: Codable & Sendable, Result: Codable & Sendable>: FlutterPlugin {
  let _handleMethod: @Sendable (FlutterMethodCall<Arguments>) throws -> Result
  let _detachFromEngine: @Sendable (FlutterPluginRegistrar)
    -> ()

  public init() {
    _handleMethod = { _ in fatalError() }
    _detachFromEngine = { _ in }
  }

  init<T: FlutterPlugin>(_ plugin: T) where T.Arguments == Arguments, T.Result == Result {
    _handleMethod = { try plugin.handleMethod(call: $0) }
    _detachFromEngine = { plugin.detachFromEngine(for: $0) }
  }

  public func handleMethod(call: FlutterMethodCall<Arguments>) throws -> Result {
    try _handleMethod(call)
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
  func lookupKey(for asset: String) -> String?
  func lookupKey(for asset: String, from package: String) -> String?
}

public protocol FlutterPluginRegistry {
  func registrar(for pluginKey: String) -> FlutterPluginRegistrar?
  func has(plugin pluginKey: String) -> Bool
  func valuePublished(by pluginKey: String) -> Any?
}

public final class FlutterDesktopPluginRegistrar: FlutterPluginRegistrar {
  public let pluginKey: String
  public let engine: FlutterEngine

  var registrar: FlutterDesktopPluginRegistrarRef?
  var detachFromEngineCallbacks = [FlutterMethodChannel: (FlutterPluginRegistrar) -> ()]()

  public init(
    engine: FlutterEngine,
    _ pluginName: String
  ) {
    self.engine = engine
    pluginKey = pluginName
    registrar = engine.getRegistrar(pluginName: pluginName)
    // FIXME: use std::function
    FlutterDesktopPluginRegistrarSetDestructionHandlerBlock(registrar!) { [self] _ in
      for (channel, detachFromEngine) in detachFromEngineCallbacks {
        try? channel.removeMessageHandler()
        detachFromEngine(self)
      }
      registrar = nil
    }
  }

  public var binaryMessenger: FlutterBinaryMessenger? {
    guard let registrar else { return nil }
    return FlutterDesktopMessenger(messenger: registrar.pointee.engine.messenger())
  }

  public var view: FlutterView? {
    guard let registrar else { return nil }
    let view = registrar.pointee.engine.view()!
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

  func addMethodCallDelegate<Arguments: Codable, Result: Codable>(
    _ delegate: AnyFlutterPlugin<Arguments, Result>,
    on channel: FlutterMethodChannel
  ) throws {
    Task {
      try await channel.setMethodCallHandler { call in
        try delegate.handleMethod(call: call)
      }
      detachFromEngineCallbacks[channel] = delegate._detachFromEngine
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

#endif
