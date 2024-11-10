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
  fileprivate static func _getUnmanagedSwiftHeapObject(_ heapObjectInt64Ptr: Int64)
    -> Unmanaged<AnyObject>?
  {
    guard heapObjectInt64Ptr != 0 else { return nil }
    let heapObjectIntPtr = Int(heapObjectInt64Ptr)
    return unsafeBitCast(Int(heapObjectIntPtr), to: Unmanaged<AnyObject>.self)
  }

  convenience init(swiftObject: some AnyObject, environment: JNIEnvironment?) {
    let heapObjectIntPtr = unsafeBitCast(swiftObject, to: Int.self) // Int32 on 32-bit platforms
    self.init(Int64(heapObjectIntPtr), environment: environment) // will call retain()
  }

  var swiftObject: AnyObject? {
    let unmanagedSwiftHeapObject = SwiftHeapObjectHolder
      ._getUnmanagedSwiftHeapObject(_swiftHeapObject)
    return unmanagedSwiftHeapObject?.takeUnretainedValue()
  }
}

extension SwiftHeapObjectHolder: CustomJavaClassLoader {
  public static func getJavaClassLoader(in environment: JNIEnvironment) throws -> JavaClassLoader! {
    _getFlutterSwiftClassLoader()
  }
}

@JavaImplementation("com.padl.FlutterAndroid.SwiftHeapObjectHolder")
public extension JavaClass<SwiftHeapObjectHolder> {
  @JavaMethod
  static func _1retainSwiftHeapObject(
    _ heapObjectInt64Ptr: Int64,
    environment: JNIEnvironment? = nil
  ) {
    _ = SwiftHeapObjectHolder._getUnmanagedSwiftHeapObject(heapObjectInt64Ptr)?.retain()
  }

  @JavaMethod
  static func _1releaseSwiftHeapObject(
    _ heapObjectInt64Ptr: Int64,
    environment: JNIEnvironment? = nil
  ) {
    SwiftHeapObjectHolder._getUnmanagedSwiftHeapObject(heapObjectInt64Ptr)?.release()
  }
}
