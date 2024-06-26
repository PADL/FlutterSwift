// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

protocol FlutterListRepresentable: Collection, Codable where Element: Codable {
  var count: Int { get }
  func forEach(_ body: (Self.Element) throws -> ()) rethrows
}

extension Array: FlutterListRepresentable where Element: Codable {}
