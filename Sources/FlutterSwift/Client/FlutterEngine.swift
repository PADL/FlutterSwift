//
// Copyright (c) 2023-2025 PADL Software Pty Ltd
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
import CxxStdlib
import Synchronization

public final class FlutterEngine: FlutterPluginRegistry, @unchecked Sendable {
  let pluginPublications = Mutex<[String: any Sendable]>([:])
  let project: DartProject
  weak var viewController: FlutterViewController?
  private var engine: flutter.FlutterELinuxEngine! // strong or weak ref
  private var _binaryMessenger: FlutterDesktopMessenger!
  private var ownsEngine = true
  private var hasBeenRun = false

  public init?(project: DartProject, switches: [String: Any] = [:]) {
    var properties = FlutterDesktopEngineProperties()

    debugPrint("Initializing Flutter engine with \(project)")

    self.project = project

    let assetsPath = WideCString(project.assetsPath)
    let icuDataPath = WideCString(project.icuDataPath)
    let aotLibraryPath = WideCString(project.aotLibraryPath)
    let dartEntryPointArguments = CStringArray(project.dartEntryPointArguments)

    properties.assets_path = UnsafePointer(assetsPath.pointer)
    properties.icu_data_path = UnsafePointer(icuDataPath.pointer)
    properties.aot_library_path = UnsafePointer(aotLibraryPath.pointer)
    properties.dart_entrypoint_argc = Int32(dartEntryPointArguments.count)
    properties.dart_entrypoint_argv = dartEntryPointArguments.pointer

    // FlutterDesktopEngineCreate copies every string into its FlutterProjectBundle,
    // and the noncopyable owners above live until the end of this scope.
    let engine = FlutterDesktopEngineCreate(&properties)

    self.engine = unsafeBitCast(engine, to: flutter.FlutterELinuxEngine.self)
    setSwitches(switches.map { key, value in "--\(key)=\(String(describing: value))" })
    _binaryMessenger = FlutterDesktopMessenger(engine: self.engine)
  }

  deinit {
    shutDown()
  }

  private var _handle: FlutterDesktopEngineRef {
    unsafeBitCast(engine, to: FlutterDesktopEngineRef.self)
  }

  // note we can't use public private(set) because we need the type to be FlutterDesktopMessenger!
  // in order for callbacks to work (otherwise self must be first initialized). But we want to
  // present a non-optional type to callers.
  public var binaryMessenger: FlutterBinaryMessenger {
    _binaryMessenger
  }

  public func run(entryPoint: String? = nil) -> Bool {
    guard !hasBeenRun else { return false }
    hasBeenRun = engine.RunWithEntrypoint(entryPoint)
    return hasBeenRun
  }

  public var isRunning: Bool {
    engine.running()
  }

  public func stop() -> Bool {
    guard hasBeenRun else { return false }
    defer { hasBeenRun = false }
    return engine.Stop()
  }

  public func shutDown() {
    pluginPublications.withLock { $0.removeAll() }
    if engine != nil, ownsEngine {
      FlutterDesktopEngineDestroy(_handle)
    }
    engine = nil
  }

  public func processMessages() -> UInt64 {
    precondition(engine != nil)
    return FlutterDesktopEngineProcessMessages(_handle)
  }

  public func reloadSystemFonts() {
    engine.ReloadSystemFonts()
  }

  func relinquishEngine() -> FlutterDesktopEngineRef {
    ownsEngine = false
    return _handle
  }

  public func registrar(for pluginKey: String) -> FlutterPluginRegistrar? {
    pluginPublications.withLock { $0[pluginKey] = FlutterNull() }
    return FlutterDesktopPluginRegistrar(engine: self, pluginKey)
  }

  @FlutterPlatformThreadActor
  private var _platformViewsHandler: FlutterPlatformViewsPlugin?

  /// Registered on first use rather than at startup, so that it displaces the
  /// handler the embedder's view installs in its own constructor.
  @FlutterPlatformThreadActor
  func platformViewsHandler() throws -> FlutterPlatformViewsPlugin {
    if let _platformViewsHandler { return _platformViewsHandler }
    guard let registrar = registrar(for: kPlatformViewsChannelName) else {
      throw FlutterSwiftError.viewNotFound
    }
    let handler = try FlutterPlatformViewsPlugin.register(with: registrar)
    _platformViewsHandler = handler
    return handler
  }

  public func has(plugin pluginKey: String) -> Bool {
    valuePublished(by: pluginKey) != nil
  }

  public func valuePublished(by pluginKey: String) -> (any Sendable)? {
    pluginPublications.withLock { $0[pluginKey] }
  }

  public var isImpellerEnabled: Bool {
    engine.IsImpellerEnabled()
  }

  public func setSystemSettings(textScalingFactor: Float, enableHighContrast: Bool) {
    engine.SetSystemSettings(textScalingFactor, enableHighContrast)
  }

  public func setView(_ view: FlutterView) {
    engine.SetView(view.view)
  }

  public var view: FlutterView? {
    guard let view = engine.view() else { return nil }
    return FlutterView(view)
  }

  public func setSwitches(_ switches: [String]) {
    engine.SetSwitches(switches.cxxVector)
  }

  func getRegistrar(pluginName: String) -> FlutterDesktopPluginRegistrarRef? {
    // FIXME: use GetRegistrar()
    FlutterDesktopEngineGetPluginRegistrar(_handle, pluginName)
  }

  var textureRegistrar: flutter.FlutterELinuxTextureRegistrar! {
    engine.texture_registrar()
  }

  var messenger: FlutterDesktopMessengerRef! {
    engine.messenger()
  }

  func sendWindowMetricsEvent(_ event: FlutterWindowMetricsEvent) {
    engine.SendWindowMetricsEvent(event)
  }

  func sendPointerEvent(_ event: FlutterPointerEvent) {
    engine.SendPointerEvent(event)
  }

  func sendPlatformMessageResponse(handle: OpaquePointer, data: [UInt8]) {
    engine.SendPlatformMessageResponse(handle, data, data.count)
  }

  func registerExternalTexture(id textureID: Int64) -> Bool {
    engine.RegisterExternalTexture(textureID)
  }

  func unregisterExternalTexture(id textureID: Int64) -> Bool {
    engine.UnregisterExternalTexture(textureID)
  }

  func markExternalTextureFrameAvailable(id textureID: Int64) -> Bool {
    engine.MarkExternalTextureFrameAvailable(textureID)
  }

  func onVsync(lastFrameTimeNS: UInt64, vsyncIntervalTimeNS: UInt64) {
    engine.OnVsync(lastFrameTimeNS, vsyncIntervalTimeNS)
  }

  func updateAccessibilityFeatures(flags: FlutterAccessibilityFeature) {
    engine.UpdateAccessibilityFeatures(flags)
  }

  func updateDisplayInfo(
    updateType: FlutterEngineDisplaysUpdateType,
    displays: [FlutterEngineDisplay]
  ) {
    engine.UpdateDisplayInfo(updateType, displays, displays.count)
  }
}

#endif
