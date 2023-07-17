// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation

public enum FlutterSwiftError: Error, Codable, Equatable {
    case eofTooEarly
    case integerOutOfRange
    case invalidAlignment
    case invalidEventError
    case messageSendFailure
    case messengerNotAvailable
    case methodNotImplemented
    case stringNotDecodable(Data)
    case stringNotEncodable(String)
    case unexpectedStandardFieldType(FlutterStandardField)
    case unknownDiscriminant
    case unknownStandardFieldType(UInt8)
    case variableSizedTypeTooBig
}
