// MIT License
//
// Copyright (c) 2023 PADL Software Pty Ltd dba Lukktone
// Portions Copyright (c) 2023 fwcd
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

class FlutterStandardEncodingState {
    private(set) var data: Data = .init()

    init(data: Data = .init()) {
        self.data = data
    }

    func encodeStandardField(_ fieldType: FlutterStandardField) throws {
        withUnsafeBytes(of: fieldType) { data += $0 }
    }

    func encodeSize(_ size: Int) throws {
        if size < 254 {
            data += [UInt8(size)]
        } else if size <= UInt16.max {
            data += [254]
            withUnsafeBytes(of: UInt16(size)) { data += $0 }
        } else if size <= UInt32.max {
            data += [255]
            withUnsafeBytes(of: UInt32(size)) { data += $0 }
        } else {
            throw FlutterSwiftError.variableSizedTypeTooBig
        }
    }

    private func encodeAlignment(_ alignment: Int) throws {
        let mod = data.count % alignment
        data += Data(repeating: 0, count: alignment - mod)
    }

    private func encode(_ value: Data) throws {
        try encodeStandardField(.uint8Data)
        try encodeSize(value.count)
        try encodeAlignment(1)
        data += data
    }

    func encodeDiscriminant(_ value: UInt8) throws {
        data += [value]
    }

    func encodeNil() throws {
        try encodeStandardField(.nil)
    }

    private func encodeArray(_ value: [UInt8]) throws {
        try encodeStandardField(.uint8Data)
        try encodeSize(value.count)
        try encodeAlignment(1)
        data += value
    }

    private func encodeArray(_ value: [Int32]) throws {
        try encodeStandardField(.int32Data)
        try encodeSize(value.count)
        try encodeAlignment(MemoryLayout<Int32>.alignment)
        try value.forEach { try encodeInteger($0) }
    }

    private func encodeArray(_ value: [Int64]) throws {
        try encodeStandardField(.int32Data)
        try encodeSize(value.count)
        try encodeAlignment(MemoryLayout<Int64>.alignment)
        try value.forEach { try encodeInteger($0) }
    }

    private func encodeArray(_ value: [Double]) throws {
        try encodeStandardField(.float64Data)
        try encodeSize(value.count)
        try encodeAlignment(MemoryLayout<Double>.alignment)
        try value.forEach { try encodeInteger($0.bitPattern) }
    }

    private func encodeArray(_ value: [Float]) throws {
        try encodeStandardField(.float32Data)
        try encodeSize(value.count)
        try encodeAlignment(MemoryLayout<Float>.alignment)
        try value.forEach { try encodeInteger($0.bitPattern) }
    }

    private func encodeList(
        _ value: some FlutterListRepresentable,
        codingPath: [CodingKey]
    ) throws {
        try encodeStandardField(.list)
        try encodeSize(value.count)
        try value.forEach {
            try $0
                .encode(to: FlutterStandardEncoderImpl(state: self, codingPath: codingPath))
        }
    }

    private func encodeMap(_ value: some FlutterMapRepresentable, codingPath: [CodingKey]) throws {
        let map = value.map

        try encodeStandardField(.map)
        try encodeSize(map.count)
        try map.forEach {
            try $0.key
                .encode(to: FlutterStandardEncoderImpl(state: self, codingPath: codingPath))
            try $0.value
                .encode(to: FlutterStandardEncoderImpl(state: self, codingPath: codingPath))
        }
    }

    private func encodeInteger<Integer>(_ value: Integer) throws where Integer: FixedWidthInteger {
        withUnsafeBytes(of: value) {
            data += $0
        }
    }

    func encode(_ value: String) throws {
        try encodeStandardField(.string)
        guard let encoded = value.data(using: .utf8) else {
            throw FlutterSwiftError.stringNotEncodable(value)
        }

        try encodeSize(encoded.count)
        data += encoded
    }

    func encode(_ value: Bool) throws {
        try encodeStandardField(value ? .true : .false)
    }

    func encode(_ value: Double) throws {
        try encodeStandardField(.float64)
        try encodeAlignment(MemoryLayout<Double>.alignment)
        try encodeInteger(value.bitPattern)
    }

    func encode(_ value: Float) throws {
        try encodeStandardField(.float64)
        try encodeAlignment(MemoryLayout<Double>.alignment)
        try encodeInteger(value.bitPattern)
    }

    func encode(_ value: Int) throws {
        if Int.bitWidth == 64 {
            try encode(Int64(value))
        } else if Int.bitWidth == 32 {
            try encode(Int32(value))
        } else {
            fatalError("unsupporterd Int.bitWidth")
        }
    }

    func encode(_ value: Int8) throws {
        try encode(Int32(value))
    }

    func encode(_ value: Int16) throws {
        try encode(Int32(value))
    }

    func encode(_ value: Int32) throws {
        try encodeStandardField(.int32)
        try encodeAlignment(MemoryLayout<Int32>.alignment)
        try encodeInteger(value)
    }

    func encode(_ value: Int64) throws {
        try encodeStandardField(.int64)
        try encodeAlignment(MemoryLayout<Int64>.alignment)
        try encodeInteger(value)
    }

    func encode(_ value: UInt) throws {
        try encode(Int(value))
    }

    func encode(_ value: UInt8) throws {
        try encode(Int32(value))
    }

    func encode(_ value: UInt16) throws {
        try encode(Int32(value))
    }

    func encode(_ value: UInt32) throws {
        try encode(Int32(bitPattern: value))
    }

    func encode(_ value: UInt64) throws {
        try encode(Int64(bitPattern: value))
    }

    func encode<T>(_ value: T, codingPath: [any CodingKey]) throws where T: Encodable {
        switch value {
        case let value as Data:
            try encode(value)
        case let value as [UInt8]:
            try encodeArray(value)
        case let value as [Int32]:
            try encodeArray(value)
        case let value as [Int64]:
            try encodeArray(value)
        case let value as [Float]:
            try encodeArray(value)
        case let value as [Double]:
            try encodeArray(value)
        case let value as any FlutterListRepresentable:
            try encodeList(value, codingPath: codingPath)
        case let value as any FlutterMapRepresentable:
            try encodeMap(value, codingPath: codingPath)
        #if canImport(Foundation)
        case is NSNull:
            try encodeNil()
        #endif
        default:
            try value
                .encode(to: FlutterStandardEncoderImpl(state: self, codingPath: codingPath))
        }
    }
}
