//
// Copyright (c) 2023-2024 PADL Software Pty Ltd
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

import Atomics
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/**
 * A strategy for handling method calls.
 *
 * @param call The incoming method call.
 * @param result A callback to asynchronously submit the result of the call.
 *     Invoke the callback with a `FlutterError` to indicate that the call failed.
 *     Invoke the callback with `FlutterMethodNotImplemented` to indicate that the
 *     method was unknown. Any other values, including `nil`, are interpreted as
 *     successful results.  This can be invoked from any thread.
 */
public typealias FlutterMethodCallHandler<
  Arguments: Codable & Sendable,
  Result: Codable & Sendable
> =
  (FlutterMethodCall<Arguments>) async throws -> Result?

/**
 * Creates a method call for invoking the specified named method with the
 * specified arguments.
 *
 * @param method the name of the method to call.
 * @param arguments the arguments value.
 */
public struct FlutterMethodCall<Arguments: Codable & Sendable>: Codable, Sendable {
  enum CodingKeys: String, CodingKey {
    case method
    case arguments = "args"
  }

  public let method: String
  public let arguments: Arguments?
}

extension FlutterMethodCall: Equatable where Arguments: Codable & Equatable {
  public static func == (
    lhs: FlutterMethodCall<Arguments>,
    rhs: FlutterMethodCall<Arguments>
  ) -> Bool {
    lhs.method == rhs.method && lhs.arguments == rhs.arguments
  }
}

extension FlutterMethodCall: Hashable where Arguments: Codable & Hashable {
  public func hash(into hasher: inout Hasher) {
    method.hash(into: &hasher)
    arguments?.hash(into: &hasher)
  }
}

/**
 * A channel for communicating with the Flutter side using invocation of
 * asynchronous methods.
 */
public final class FlutterMethodChannel: _FlutterBinaryMessengerConnectionRepresentable, Sendable {
  public let name: String
  public let binaryMessenger: FlutterBinaryMessenger
  public let codec: FlutterMessageCodec
  public let priority: TaskPriority?

  private let _connection: ManagedAtomic<FlutterBinaryMessengerConnection>

  var connection: FlutterBinaryMessengerConnection {
    get {
      _connection.load(ordering: .acquiring)
    }
    set {
      _connection.store(newValue, ordering: .releasing)
    }
  }

  public init(
    name: String,
    binaryMessenger: FlutterBinaryMessenger,
    codec: FlutterMessageCodec = FlutterStandardMessageCodec.shared,
    priority: TaskPriority? = nil
  ) {
    _connection = ManagedAtomic(0)
    self.name = name
    self.binaryMessenger = binaryMessenger
    self.codec = codec
    self.priority = priority
  }

  deinit {
    try? removeMessageHandler()
  }

  public func invoke<Arguments: Codable & Sendable>(
    method: String,
    arguments: Arguments?
  ) async throws {
    let methodCall = FlutterMethodCall<Arguments>(method: method, arguments: arguments)
    try await binaryMessenger.send(on: name, message: codec.encode(methodCall))
  }

  public func invoke<Arguments: Codable & Sendable, Result: Codable>(
    method: String,
    arguments: Arguments?
  ) async throws -> Result? {
    let methodCall = FlutterMethodCall<Arguments>(
      method: method,
      arguments: arguments
    )
    let reply = try await binaryMessenger.send(
      on: name,
      message: codec.encode(methodCall),
      priority: priority
    )
    guard let reply else { throw FlutterSwiftError.methodNotImplemented }
    let envelope: FlutterEnvelope<Result> = try codec.decode(reply)
    switch envelope {
    case let .success(value):
      return value
    case let .failure(error):
      throw error
    }
  }

  public func setMethodCallHandler<
    Arguments: Codable & Sendable,
    Result: Codable
  >(_ handler: FlutterMethodCallHandler<Arguments, Result>?) async throws {
    try await setMessageHandler(handler) { [weak self] unwrappedHandler in
      { message in
        guard let self else {
          throw FlutterSwiftError.messengerNotAvailable
        }
        guard let message else {
          throw FlutterSwiftError.methodNotImplemented
        }

        let call: FlutterMethodCall<Arguments> = try self.codec.decode(message)
        let envelope: FlutterEnvelope<Result>
        do {
          envelope = try await .success(unwrappedHandler(call))
        } catch let error as FlutterError {
          envelope = .failure(error)
        }
        return try self.codec.encode(envelope)
      }
    }
  }
}
