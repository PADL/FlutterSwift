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
import SwiftJava

public extension SwiftHeapObjectHolder {
  fileprivate static func _getUnmanagedSwiftHeapObject(_ heapObjectInt64Ptr: Int64)
    -> Unmanaged<AnyObject>?
  {
    guard heapObjectInt64Ptr != 0 else { return nil }
    let heapObjectIntPtr = Int(heapObjectInt64Ptr)
    return unsafeBitCast(Int(heapObjectIntPtr), to: Unmanaged<AnyObject>.self)
  }

  convenience init(swiftObject: some AnyObject, environment: JNIEnvironment?) {
    let heapObjectPtr = Unmanaged.passUnretained(swiftObject).toOpaque()
    let heapObjectInt64 = Int64(Int(bitPattern: heapObjectPtr))
    self.init(heapObjectInt64, environment: environment) // will call retain()
  }

  var swiftObject: AnyObject? {
    let unmanagedSwiftHeapObject = SwiftHeapObjectHolder
      ._getUnmanagedSwiftHeapObject(_swiftHeapObject)
    return unmanagedSwiftHeapObject?.takeUnretainedValue()
  }
}

extension SwiftHeapObjectHolder: AnyJavaObjectWithCustomClassLoader {
  public static func getJavaClassLoader(in environment: JNIEnvironment) throws -> JavaClassLoader! {
    _getFlutterSwiftClassLoader()
  }
}

// Use @_cdecl directly rather than @JavaImplementation on JavaClass<T>, since
// swift-java's @JavaImplementation macro produces malformed expansions for generic
// class specializations (swiftlang/swift-java#674 regression).
@_cdecl("Java_com_padl_FlutterAndroid_SwiftHeapObjectHolder__1retainSwiftHeapObject")
public func Java_com_padl_FlutterAndroid_SwiftHeapObjectHolder__1retainSwiftHeapObject(
  _ environment: JNIEnvironment?,
  _ clazz: JavaObject?,
  _ heapObjectInt64Ptr: Int64
) {
  _ = SwiftHeapObjectHolder._getUnmanagedSwiftHeapObject(heapObjectInt64Ptr)?.retain()
}

@_cdecl("Java_com_padl_FlutterAndroid_SwiftHeapObjectHolder__1releaseSwiftHeapObject")
public func Java_com_padl_FlutterAndroid_SwiftHeapObjectHolder__1releaseSwiftHeapObject(
  _ environment: JNIEnvironment?,
  _ clazz: JavaObject?,
  _ heapObjectInt64Ptr: Int64
) {
  SwiftHeapObjectHolder._getUnmanagedSwiftHeapObject(heapObjectInt64Ptr)?.release()
}
