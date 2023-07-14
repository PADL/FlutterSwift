// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation

public enum FlutterChannelError: Error, Codable, Equatable {
    case messageSendFailure
    case methodNotImplemented
    case endOfEventStream
    case stringNotDecodable(Data)
    case stringNotEncodable(String)
    case variableSizedTypeTooBig
    case eofTooEarly
    case unknownStandardFieldType
    case unexpectedStandardFieldType
    case invalidAlignment
    case integerOutOfRange
    case unknownDiscriminant
}
