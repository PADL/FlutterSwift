// MIT License
//
// Copyright (c) 2022 fwcd
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation

/// A decoder that decodes Swift structures from a flat binary representation.
public struct FlutterStandardDecoder {
    /// Decodes a value from a flat binary representation.
    public func decode<Value>(_ type: Value.Type, from data: Data) throws -> Value
        where Value: Decodable
    {
        if Value.self is ExpressibleByNilLiteral.Type, data.count == 0 {
            // FIXME: abstraction violation
            return Any?.none as! Value
        }
        let state = FlutterStandardDecodingState(data: data)
        var count: Int? = nil
        let value: Value

        // FIXME: DRY
        switch type {
        case is Data.Type:
            value = try state.decodeData() as! Value
        case is [UInt8].Type:
            value = try state.decodeArray(UInt8.self) as! Value
        case is [Int32].Type:
            value = try state.decodeArray(Int32.self) as! Value
        case is [Int64].Type:
            value = try state.decodeArray(Int64.self) as! Value
        case is [Float].Type:
            value = try state.decodeArray(Float.self) as! Value
        case is [Double].Type:
            value = try state.decodeArray(Double.self) as! Value
        case is any FlutterListRepresentable.Type:
            try state.assertStandardField(.list)
            count = try state.decodeSize()
            fallthrough
        default:
            value = try Value(from: FlutterStandardDecoderImpl(
                state: state,
                codingPath: [],
                count: count
            ))
        }
        return value
    }
}
