//
// Copyright (c) 2025 PADL Software Pty Ltd
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

public struct FlutterDesktopTextureRegistrar {
  private let registrar: FlutterDesktopTextureRegistrarRef

  public init(engine: FlutterEngine) {
    registrar = FlutterDesktopEngineGetTextureRegistrar(engine.engine)
  }

  init?(plugin: FlutterDesktopPluginRegistrar) {
    guard let registrar = plugin.registrar else { return nil }
    self.registrar = FlutterDesktopRegistrarGetTextureRegistrar(registrar)
  }

  public func markExternalTextureFrameAvailable(textureID: Int64) {
    FlutterDesktopTextureRegistrarMarkExternalTextureFrameAvailable(registrar, textureID)
  }
}

#endif
