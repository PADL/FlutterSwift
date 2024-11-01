import Android
import FoundationEssentials
import JavaKit
import JavaRuntime

package extension Data {
  func asJavaNIOByteBuffer() -> JavaNIOByteBuffer {
    let clz = try! JavaClass<JavaNIOByteBuffer>()
    return clz.wrap(Array(self).map { Int8($0) })
  }

  init(_ javaNIOBytebuffer: JavaNIOByteBuffer) {
    self.init(javaNIOBytebuffer.array().map { UInt8($0) })
  }
}

/*
@JavaImplementation("com.padl.AndroidFlutter.FlutterSwiftBinaryMessageHandler")
extension _FlutterSwiftBinaryMessageHandler: _FlutterSwiftBinaryMessageHandlerNativeMethods {
  @JavaMethod
  public func onMessage(_ message: JavaNIOByteBuffer?, _ binaryReply: AndroidFlutterBinaryMessenger.BinaryReply?) {
  }
}
*/
