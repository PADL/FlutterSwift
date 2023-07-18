// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#if os(Linux)
@_implementationOnly
import CxxFlutterSwift

public final class FlutterEngine {
    private var engine: FlutterDesktopEngineRef! // strong or weak ref
    private var messenger_: FlutterDesktopMessenger!
    private var ownsEngine = true
    private var hasBeenRun = false

    public init?(project: DartProject) {
        var properties = FlutterDesktopEngineProperties()

        debugPrint("Initializing Flutter engine with path '\(project)'")

        project.assetsPath.withWideChars { assetsPath in
            properties.assets_path = assetsPath
            project.icuDataPath.withWideChars { icuDataPath in
                properties.icu_data_path = icuDataPath
                project.aotLibraryPath.withWideChars { aotLibraryPath in
                    properties.aot_library_path = aotLibraryPath
                    withArrayOfCStrings(project.dartEntryPointArguments) { cStrings in
                        properties
                            .dart_entrypoint_argc = Int32(project.dartEntryPointArguments.count)
                        cStrings.withUnsafeMutableBufferPointer { pointer in
                            properties.dart_entrypoint_argv = pointer.baseAddress
                            self.engine = FlutterDesktopEngineCreate(&properties)
                            self.messenger_ = FlutterDesktopMessenger(engine: self.engine)
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
    public var messenger: FlutterDesktopMessenger {
        messenger_
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

    func getRegistrarForPlugin(_ pluginName: String) -> FlutterDesktopPluginRegistrarRef? {
        guard let engine else { return nil }
        return FlutterDesktopEngineGetPluginRegistrar(engine, pluginName)
    }

    func relinquishEngine() -> FlutterDesktopEngineRef {
        ownsEngine = false
        return engine
    }
}
#endif
