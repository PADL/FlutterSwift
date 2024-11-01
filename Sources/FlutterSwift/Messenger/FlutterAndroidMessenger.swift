#if canImport(Android)

import Android
import AndroidFlutter
import FoundationEssentials
import JavaKit
import JavaRuntime

public final class FlutterAndroidMessenger: FlutterBinaryMessenger, @unchecked Sendable {
  private let _wrappedMessenger: AndroidFlutterBinaryMessenger

  public init(wrapping binaryMessenger: AndroidFlutterBinaryMessenger) {
    self._wrappedMessenger = binaryMessenger
  }

  private func _send(
    on channel: String,
    message: Data?,
    _ binaryReply: (Data?) -> ()
  ) {
  }

  public func send(on channel: String, message: Data?) async throws {
    _wrappedMessenger.send(channel, message?.asJavaNIOByteBuffer())
  }

  public func send(on channel: String, message: Data?, priority: TaskPriority?) async throws -> Data? {
    try await withPriority(priority) {
      await withCheckedContinuation { continuation in
        self._send(on: channel, message: message) { binaryReply in
          continuation.resume(returning: binaryReply)
        }
      }
    }
  }

  public func setMessageHandler(
    on channel: String,
    handler: FlutterBinaryMessageHandler?,
    priority: TaskPriority?
  ) throws -> FlutterBinaryMessengerConnection {
    0
  }

  public func cleanUp(connection: FlutterBinaryMessengerConnection) throws {
  }
}

/*
@JavaImplementation("com.padl.flutterswift.FlutterSwiftBinaryReply")
extension AndroidFlutterSwiftBinaryReply: AndroidFlutterSwiftBinaryReplyNativeMethods {
  @JavaMethod
  func reply(_ buffer: JavaNIOByteBuffer?) {
  }
}

@JavaImplementation("com.padl.flutterswift.FlutterSwiftBinaryMessageHandler")
extension AndroidFlutterSwiftBinaryMessageHandler: AndroidFlutterSwiftBinaryMessageHandlerNativeMethods {
  @JavaMethod
  func onMessage(_ message: JavaNIOByteBuffer?, _ binaryReply: AndroidFlutterSwiftBinaryReply) {
  }
}
*/

#endif
