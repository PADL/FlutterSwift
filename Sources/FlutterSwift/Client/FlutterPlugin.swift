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
import Synchronization

public protocol FlutterPlugin: Sendable {
  associatedtype Arguments: Codable & Sendable
  associatedtype Result: Codable & Sendable

  init()

  /// Called on the platform thread, as method call handlers are on every other
  /// Flutter platform, so plugin state needs no locking of its own.
  @FlutterPlatformThreadActor
  func handleMethod(call: FlutterMethodCall<Arguments>) throws -> Result
  func detachFromEngine(for registrar: FlutterPluginRegistrar)
}

public extension FlutterPlugin {
  @FlutterPlatformThreadActor
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
  let _handleMethod: @FlutterPlatformThreadActor @Sendable (FlutterMethodCall<Arguments>) throws
    -> Result
  let _detachFromEngine: @Sendable (FlutterPluginRegistrar)
    -> ()

  init() {
    _handleMethod = { _ in fatalError() }
    _detachFromEngine = { _ in }
  }

  init<T: FlutterPlugin>(_ plugin: T) where T.Arguments == Arguments, T.Result == Result {
    _handleMethod = { try plugin.handleMethod(call: $0) }
    _detachFromEngine = { plugin.detachFromEngine(for: $0) }
  }

  @FlutterPlatformThreadActor
  func handleMethod(call: FlutterMethodCall<Arguments>) throws -> Result {
    try _handleMethod(call)
  }

  func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    _detachFromEngine(registrar)
  }
}

public protocol FlutterPluginRegistrar {
  var pluginKey: String { get }
  var binaryMessenger: FlutterBinaryMessenger? { get }
  var view: FlutterView? { get }

  @FlutterPlatformThreadActor
  func register(
    viewFactory factory: FlutterPlatformViewFactory,
    with factoryId: String
  ) throws
  func publish(_ value: any Sendable)
  func lookupKey(for asset: String) -> String?
  func lookupKey(for asset: String, from package: String) -> String?
}

public protocol FlutterPluginRegistry {
  func registrar(for pluginKey: String) -> FlutterPluginRegistrar?
  func has(plugin pluginKey: String) -> Bool
  func valuePublished(by pluginKey: String) -> (any Sendable)?
}

typealias FlutterDesktopPluginRegistrarDestructor =
  @Sendable (FlutterDesktopPluginRegistrarRef) -> ()

// the embedder's destruction callback carries no user_data, so map the
// registrar back to its destructors here. eLinux vends one registrar per engine
// however many plugins ask for one, so every plugin's destructor must be kept
private let registrarDestructors =
  Mutex<[UInt: [FlutterDesktopPluginRegistrarDestructor]]>([:])

private func addDestructor(
  for registrar: FlutterDesktopPluginRegistrarRef,
  _ destructor: @escaping FlutterDesktopPluginRegistrarDestructor
) {
  registrarDestructors.withLock { $0[UInt(bitPattern: registrar), default: []].append(destructor) }
  FlutterDesktopPluginRegistrarSetDestructionHandler(registrar) { registrar in
    guard let registrar else { return }
    let destructors = registrarDestructors
      .withLock { $0.removeValue(forKey: UInt(bitPattern: registrar)) }
    for destructor in destructors ?? [] {
      destructor(registrar)
    }
  }
}

public final class FlutterDesktopPluginRegistrar: FlutterPluginRegistrar, @unchecked Sendable {
  public let pluginKey: String
  public let engine: FlutterEngine

  var registrar: FlutterDesktopPluginRegistrarRef!
  let detachFromEngineCallbacks =
    Mutex<[FlutterMethodChannel: (FlutterPluginRegistrar) -> ()]>([:])

  public init(
    engine: FlutterEngine,
    _ pluginName: String
  ) {
    self.engine = engine
    pluginKey = pluginName
    registrar = engine.getRegistrar(pluginName: pluginName)
    addDestructor(for: registrar!) { [weak self] _ in
      guard let self else { return }
      self.detachFromEngineCallbacks.withLock { detachFromEngineCallbacks in
        for (channel, detachFromEngine) in detachFromEngineCallbacks {
          Task { await channel.removeMessageHandler() }
          detachFromEngine(self)
        }
      }
      self.registrar = nil
    }
  }

  public var binaryMessenger: FlutterBinaryMessenger? {
    guard registrar != nil else { return nil }
    // one messenger instance per engine: the connection -> channel registry
    // backing cleanUp(connection:) is per-instance, and minting a fresh
    // messenger here would let one channel's teardown unregister another's
    // handler for the same name
    return engine.binaryMessenger
  }

  public var view: FlutterView? {
    guard let registrar else { return nil }
    let view = registrar.pointee.engine.view()!
    return FlutterView(view)
  }

  @FlutterPlatformThreadActor
  public func register(
    viewFactory factory: FlutterPlatformViewFactory,
    with factoryId: String
  ) throws {
    try engine.platformViewsHandler().register(viewType: factoryId, factory: factory)
  }

  public func publish(_ value: any Sendable) {
    engine.pluginPublications.withLock { $0[pluginKey] = value }
  }

  @FlutterPlatformThreadActor
  func addMethodCallDelegate<Arguments: Codable, Result: Codable>(
    _ delegate: AnyFlutterPlugin<Arguments, Result>,
    on channel: FlutterMethodChannel
  ) throws {
    let detachCallback = delegate._detachFromEngine
    // synchronously, so registration completes before we return: a spawned task
    // would leave a window where the engine has no handler for the channel
    try channel.setMethodCallHandler { call in
      try await delegate.handleMethod(call: call)
    }
    detachFromEngineCallbacks.withLock { detachFromEngineCallbacks in
      detachFromEngineCallbacks[channel] = detachCallback
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
