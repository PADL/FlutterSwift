//
// Copyright (c) 2026 PADL Software Pty Ltd
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

@testable import FlutterSwift
import XCTest

final class FlutterMethodCodecTests: XCTestCase {
  // MARK: - FlutterStandardMethodCodec

  func testStandardMethodCodecMethodCall() throws {
    let codec = FlutterStandardMethodCodec()
    let call = FlutterMethodCall<[String]>(method: "greet", arguments: ["hello", "world"])
    let encoded = try codec.encode(method: call)
    let decoded: FlutterMethodCall<[String]> = try codec.decode(method: encoded)
    XCTAssertEqual(decoded, call)
  }

  func testStandardMethodCodecMethodCallNilArguments() throws {
    let codec = FlutterStandardMethodCodec()
    let call = FlutterMethodCall<String>(method: "ping", arguments: nil)
    let encoded = try codec.encode(method: call)
    let decoded: FlutterMethodCall<String> = try codec.decode(method: encoded)
    XCTAssertEqual(decoded, call)
  }

  func testStandardMethodCodecSuccessEnvelope() throws {
    let codec = FlutterStandardMethodCodec()
    let envelope = FlutterEnvelope<String>("success result")
    let encoded = try codec.encode(envelope: envelope)
    let decoded: FlutterEnvelope<String> = try codec.decode(envelope: encoded)
    XCTAssertEqual(decoded, envelope)
  }

  func testStandardMethodCodecErrorEnvelope() throws {
    let codec = FlutterStandardMethodCodec()
    let error = FlutterError(
      code: "ERR_001",
      message: "something went wrong",
      details: AnyFlutterStandardCodable.string("detail")
    )
    let envelope = FlutterEnvelope<String>(error)
    let encoded = try codec.encode(envelope: envelope)
    let decoded: FlutterEnvelope<String> = try codec.decode(envelope: encoded)
    XCTAssertEqual(decoded, envelope)
  }

  func testStandardMethodCodecNilSuccessEnvelope() throws {
    let codec = FlutterStandardMethodCodec()
    let envelope = FlutterEnvelope<String>(nil)
    let encoded = try codec.encode(envelope: envelope)
    let decoded: FlutterEnvelope<String> = try codec.decode(envelope: encoded)
    XCTAssertEqual(decoded, envelope)
  }
}
