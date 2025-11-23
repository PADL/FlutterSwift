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

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/**
 * A strategy for handling incoming binary messages from Flutter and to send
 * asynchronous replies back to Flutter.
 *
 * @param message The message.
 * @result reply A callback for submitting an asynchronous reply to the sender.
 */
public typealias FlutterBinaryMessageHandler = @Sendable (Data?) async throws -> Data?

public typealias FlutterBinaryMessengerConnection = Int64

#if canImport(Android)
public typealias FlutterPlatformThreadActor = UIThreadActor
#else
public typealias FlutterPlatformThreadActor = MainActor
#endif

//
// https://docs.flutter.dev/platform-integration/platform-channels#channels-and-platform-threading
//
//   "When invoking channels on the platform side destined for Flutter,
//    invoke them on the platform's main thread."
//
// Hence the send() methods in the protocol are annotated with
// @FlutterPlatformThreadActor which will ensure they run on @MainActor on
// Darwin, and @UIThreadActor on Android. This/ annotation ensures that the
// caller doesn't need to be aware of the platform thread requirement.
//
// setMessageHandler() and cleanUp() are not annotated as such as they need
// to be called from deinitializers, however setMessageHandler() is always
// run on the platform thread at registration time because its only consumer
// is a wrapper which is marked @FlutterPlatformThreadActor. This enables
// channels to be registered in awakeFromNib() without needing to spawn a
// task, which eliminates some race conditions.
//
// The basic, method and event channels themselves do not have actor
// annotations. They are classes which are thread-safe (they use mutexes
// and/or atomics). Their methods will switch to the platform actor when they
// call into the common messenger implementation. The basic and method channels
// are completely synchronous except for this call to send(). An analysis of
// event channels is not provided here.
//

public protocol FlutterBinaryMessenger: Sendable {
  @FlutterPlatformThreadActor
  func send(on channel: String, message: Data?) throws

  @FlutterPlatformThreadActor
  func send(on channel: String, message: Data?, priority: TaskPriority?) async throws -> Data?

  func setMessageHandler(
    on channel: String,
    handler: FlutterBinaryMessageHandler?,
    priority: TaskPriority?
  ) throws -> FlutterBinaryMessengerConnection

  func cleanUp(connection: FlutterBinaryMessengerConnection) throws
}

extension FlutterBinaryMessenger {
  func withPriority<Value: Sendable>(
    _ priority: TaskPriority?,
    _ block: @Sendable @escaping () async throws -> Value
  ) async throws -> Value {
    try await Task<Value, Error>(priority: priority) {
      try await block()
    }.value
  }
}
