// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#if os(Linux)
public struct DartProject {
  let assetsPath: String
  let icuDataPath: String
  let aotLibraryPath: String
  var dartEntryPointArguments = [String]()

  public init(path: String) {
    assetsPath = path + "/data/flutter_assets"
    icuDataPath = path + "/data/icudtl.dat"
    aotLibraryPath = path + "/lib/libapp.so"
  }
}
#endif
