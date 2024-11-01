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
public struct DartProject: Sendable {
  let assetsPath: String
  let icuDataPath: String
  let aotLibraryPath: String
  let dartEntryPointArguments: [String]

  public init(path: String, arguments: [String] = []) {
    assetsPath = path + "/data/flutter_assets"
    icuDataPath = path + "/data/icudtl.dat"
    aotLibraryPath = path + "/lib/libapp.so"
    dartEntryPointArguments = arguments
  }
}
#endif
