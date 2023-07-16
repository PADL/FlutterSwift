// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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

@testable import FlutterSwift
import XCTest

extension FlutterError: Equatable {
    public static func == (lhs: FlutterError, rhs: FlutterError) -> Bool {
        guard lhs.code == rhs.code && lhs.message == rhs.message else {
            return false
        }
        // FIXME: don't care about details
        return true
    }
}

extension FlutterEnvelope: Equatable where Success: Codable & Equatable {
    public static func == (lhs: FlutterEnvelope<Success>, rhs: FlutterEnvelope<Success>) -> Bool {
        if case let .success(lhs) = lhs, case let .success(rhs) = rhs {
            return lhs == rhs
        } else if case let .failure(lhs) = lhs, case let .failure(rhs) = rhs {
            return lhs == rhs
        } else {
            return false
        }
    }
}

final class FlutterStandardEncoderTests: XCTestCase {
    func testDefaultStandardEncoder() throws {
        let encoder = FlutterStandardEncoder()

        try assertThat(encoder, encodes: FlutterNull?.none, to: [0x00])
        try assertThat(encoder, encodes: true, to: [0x01])
        try assertThat(encoder, encodes: false, to: [0x02])
        try assertThat(encoder, encodes: UInt8(0xFE), to: [0x03, 0xFE, 0x00, 0x00, 0x00])
        try assertThat(encoder, encodes: UInt16(0xFEDC), to: [0x03, 0xDC, 0xFE, 0x00, 0x00])
        try assertThat(
            encoder,
            encodes: UInt64(0xFEDC_BA09),
            to: [0x04, 0x09, 0xBA, 0xDC, 0xFE, 0x00, 0x00, 0x00, 0x00]
        )
        try assertThat(
            encoder,
            encodes: UInt64(0xFFFF_FFFF_FFFF_FFFA),
            to: [0x04, 0xFA, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
        )
        try assertThat(encoder, encodes: Int8(-2), to: [0x03, 0xFE, 0xFF, 0xFF, 0xFF])
        try assertThat(
            encoder,
            encodes: Int16(bitPattern: 0xFEDC),
            to: [0x03, 0xDC, 0xFE, 0xFF, 0xFF]
        )
        try assertThat(
            encoder,
            encodes: Int32(bitPattern: 0x1234_5678),
            to: [0x03, 0x78, 0x56, 0x34, 0x12]
        )
        try assertThat(
            encoder,
            encodes: Int64(bitPattern: 0x1234_5678_90AB_CDEF),
            to: [0x04, 0xEF, 0xCD, 0xAB, 0x90, 0x78, 0x56, 0x34, 0x12]
        )
        try assertThat(
            encoder,
            encodes: Double(3.14159265358979311599796346854),
            to: [
                0x06,
                0x00,
                0x00,
                0x00,
                0x00,
                0x00,
                0x00,
                0x00,
                0x18,
                0x2D,
                0x44,
                0x54,
                0xFB,
                0x21,
                0x09,
                0x40,
            ]
        )
        try assertThat(
            encoder,
            encodes: "hello world",
            to: [0x07, 0x0B, 0x68, 0x65, 0x6C, 0x6C, 0x6F,
                 0x20, 0x77, 0x6F, 0x72, 0x6C, 0x64]
        )
        try assertThat(
            encoder,
            encodes: "h\u{263A}w",
            to: [0x07, 0x05, 0x68, 0xE2, 0x98, 0xBA, 0x77]
        )
        try assertThat(
            encoder,
            encodes: "h\u{0001F602}w",
            to: [0x07, 0x06, 0x68, 0xF0, 0x9F, 0x98, 0x82, 0x77]
        )
    }

    func testDefaultStandardEncoderDecoder() throws {
        let decoder = FlutterStandardDecoder()
        let encoder = FlutterStandardEncoder()

        try assertThat(encoder: encoder, decoder: decoder, canEncodeDecode: "hello, world")
        try assertThat(encoder: encoder, decoder: decoder, canEncodeDecode: UInt8(123))
        try assertThat(encoder: encoder, decoder: decoder, canEncodeDecode: UInt16(12343))
        try assertThat(encoder: encoder, decoder: decoder, canEncodeDecode: UInt32(13_423_433))
        try assertThat(encoder: encoder, decoder: decoder, canEncodeDecode: UInt64(1_214_423_123))
        try assertThat(encoder: encoder, decoder: decoder, canEncodeDecode: Int8(123))
        try assertThat(encoder: encoder, decoder: decoder, canEncodeDecode: Int16(12343))
        try assertThat(encoder: encoder, decoder: decoder, canEncodeDecode: Int32(13_423_433))
        try assertThat(encoder: encoder, decoder: decoder, canEncodeDecode: Int64(-1_214_423_123))

        try assertThat(encoder: encoder, decoder: decoder, canEncodeDecode: 12345)
        try assertThat(encoder: encoder, decoder: decoder, canEncodeDecode: [1, 2, 3, 4, 5])
        try assertThat(
            encoder: encoder,
            decoder: decoder,
            canEncodeDecode: [Float(1.9), Float(2.0234)]
        )
        try assertThat(encoder: encoder, decoder: decoder, canEncodeDecode: ["foo", "bar", "baz"])

        let error = FlutterError(code: "1234", message: "hello", details: "something")
        try assertThat(encoder: encoder, decoder: decoder, canEncodeDecode: error)

        let method = FlutterMethodCall<[String]>(method: "hello", arguments: ["world", "moon"])
        try assertThat(encoder: encoder, decoder: decoder, canEncodeDecode: method)
    }

    func testConstructedStandardEncoderDecoder() throws {
        let decoder = FlutterStandardDecoder()
        let encoder = FlutterStandardEncoder()

        let error = FlutterError(code: "1231231", message: "hello", details: "something")
        let envelope = FlutterEnvelope<String>("hello")
        try assertThat(encoder: encoder, decoder: decoder, canEncodeDecode: envelope)

        let envelope2 = FlutterEnvelope<String>(error)
        try assertThat(encoder: encoder, decoder: decoder, canEncodeDecode: envelope2)

        let simple = Simple(x: 1, y: 2, z: 3)
        try assertThat(encoder: encoder, decoder: decoder, canEncodeDecode: simple)

        let composite = Composite(before: 1, inner: Composite.Inner(value: 99), after: 7_834_868)
        try assertThat(encoder: encoder, decoder: decoder, canEncodeDecode: composite)

        let variablePrefix = VariablePrefix(prefix: [2, 23], value: 99)
        try assertThat(encoder: encoder, decoder: decoder, canEncodeDecode: variablePrefix)

        let variableSuffix = VariableSuffix(value: 78, suffix: [99, 11])
        try assertThat(encoder: encoder, decoder: decoder, canEncodeDecode: variableSuffix)

        let generic = Generic<String>(value: "Hello, world", additional: 255)
        try assertThat(encoder: encoder, decoder: decoder, canEncodeDecode: generic)

        // FIXME: Either -- enums are not supported, we need to interrogate metadata to determine number of keys, this is possible but probably useless because there is no direct equivalent on the Flutter side
    }

    private func assertThat<Value>(
        encoder: FlutterStandardEncoder,
        decoder: FlutterStandardDecoder,
        canEncodeDecode value: Value,
        line: UInt = #line
    ) throws where Value: Codable & Equatable {
        let encoded = try encoder.encode(value)
        // debugPrint("encoded to \(encoded.hexEncodedString())")
        let decoded = try decoder.decode(Value.self, from: encoded)
        XCTAssertEqual(value, decoded, line: line)
    }

    private func assertThat<Value>(
        _ encoder: FlutterStandardEncoder,
        encodes value: Value,
        to expectedArray: [UInt8],
        line: UInt = #line
    ) throws where Value: Encodable {
        XCTAssertEqual(Array(try encoder.encode(value)), expectedArray, line: line)
    }

    private func assertThat<Value>(
        _ encoder: FlutterStandardEncoder,
        whileEncoding value: Value,
        throws expectedError: FlutterSwiftError,
        line: UInt = #line
    ) throws where Value: Encodable {
        XCTAssertThrowsError(try encoder.encode(value), line: line) { error in
            XCTAssertEqual(error as! FlutterSwiftError, expectedError, line: line)
        }
    }
}
