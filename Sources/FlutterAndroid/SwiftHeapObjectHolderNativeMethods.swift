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
import JavaKit
import JavaRuntime

public extension SwiftHeapObjectHolder {
  convenience init(swiftObject: some AnyObject, environment: JNIEnvironment?) {
    let swiftObject = Unmanaged.passRetained(swiftObject)
    let swiftObjectIntPtr = unsafeBitCast(swiftObject, to: Int.self) // Int32 on 32-bit platforms
    self.init(Int64(swiftObjectIntPtr), environment: environment)
  }

  var swiftObject: AnyObject? {
    guard _swiftObject != 0 else { return nil }
    let unmanagedSwiftObject = unsafeBitCast(Int(_swiftObject), to: Unmanaged<AnyObject>.self)
    return unmanagedSwiftObject.takeUnretainedValue()
  }
}

extension SwiftHeapObjectHolder: CustomJavaClassLoader {
  public static func getJavaClassLoader(in environment: JNIEnvironment) throws -> JavaClassLoader! {
    _getFlutterSwiftClassLoader()
  }
}

@JavaImplementation("com.padl.FlutterAndroid.SwiftHeapObjectHolder")
extension JavaClass<SwiftHeapObjectHolder> {
  @JavaMethod
  public static func _1releaseSwiftObject(_ swiftObject: Int64, environment: JNIEnvironment? = nil) {
    guard swiftObject != 0 else { return }
    let swiftObjectIntPtr = Int(swiftObject)
    unsafeBitCast(Int(swiftObjectIntPtr), to: Unmanaged<AnyObject>.self).release()
  }
}
