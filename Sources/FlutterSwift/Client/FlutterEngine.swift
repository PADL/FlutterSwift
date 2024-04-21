// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#if os(Linux)
@_implementationOnly
import CxxFlutterSwift

public final class FlutterEngine: FlutterPluginRegistry, @unchecked Sendable {
  var engine: FlutterDesktopEngineRef! // strong or weak ref
  var pluginPublications = [String: Any]()
  let project: DartProject
  weak var viewController: FlutterViewController?
  private var _binaryMessenger: FlutterDesktopMessenger!
  private var ownsEngine = true
  private var hasBeenRun = false

  public init?(project: DartProject) {
    var properties = FlutterDesktopEngineProperties()

    debugPrint("Initializing Flutter engine with \(project)")

    self.project = project

    self.project.assetsPath.withWideChars { assetsPath in
      properties.assets_path = assetsPath
      self.project.icuDataPath.withWideChars { icuDataPath in
        properties.icu_data_path = icuDataPath
        self.project.aotLibraryPath.withWideChars { aotLibraryPath in
          properties.aot_library_path = aotLibraryPath
          withArrayOfCStrings(self.project.dartEntryPointArguments) { cStrings in
            properties
              .dart_entrypoint_argc = Int32(
                self.project.dartEntryPointArguments
                  .count
              )
            cStrings.withUnsafeMutableBufferPointer { pointer in
              properties.dart_entrypoint_argv = pointer.baseAddress
              self.engine = FlutterDesktopEngineCreate(&properties)
              self._binaryMessenger = FlutterDesktopMessenger(engine: self.engine)
            }
          }
        }
      }
    }
  }

  deinit {
    shutDown()
  }

  // note we can't use public private(set) because we need the type to be FlutterDesktopMessenger!
  // in order for callbacks to work (otherwise self must be first initialized). But we want to
  // present a non-optional type to callers.
  public var binaryMessenger: FlutterBinaryMessenger {
    _binaryMessenger
  }

  public func run(entryPoint: String? = nil) -> Bool {
    if hasBeenRun {
      debugPrint("Cannot run an engine more than once.")
      return false
    }
    let runSucceeded = FlutterDesktopEngineRun(engine, entryPoint)
    if !runSucceeded {
      debugPrint("Failed to start engine.")
    }
    hasBeenRun = true
    return runSucceeded
  }

  public func shutDown() {
    pluginPublications.removeAll()
    if let engine, ownsEngine {
      FlutterDesktopEngineDestroy(engine)
    }
    engine = nil
  }

  public func processMessages() -> UInt64 {
    precondition(engine != nil)
    return FlutterDesktopEngineProcessMessages(engine)
  }

  public func reloadSystemFonts() {
    precondition(engine != nil)
    FlutterDesktopEngineReloadSystemFonts(engine)
  }

  func relinquishEngine() -> FlutterDesktopEngineRef {
    ownsEngine = false
    return engine
  }

  public func registrar(for pluginKey: String) -> FlutterPluginRegistrar? {
    pluginPublications[pluginKey] = FlutterNull()
    return FlutterDesktopPluginRegistrar(engine: self, pluginKey)
  }

  public func has(plugin pluginKey: String) -> Bool {
    valuePublished(by: pluginKey) != nil
  }

  public func valuePublished(by pluginKey: String) -> Any? {
    pluginPublications[pluginKey]
  }
}
#endif
