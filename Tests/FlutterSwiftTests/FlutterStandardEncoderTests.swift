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

        let envelope = FlutterEnvelope<String>("hello")
        try assertThat(encoder: encoder, decoder: decoder, canEncodeDecode: envelope)
        let envelope2 = FlutterEnvelope<String>(error)
        try assertThat(encoder: encoder, decoder: decoder, canEncodeDecode: envelope2)
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
