// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#if os(Linux)
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
