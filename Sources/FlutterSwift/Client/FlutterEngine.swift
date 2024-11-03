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
