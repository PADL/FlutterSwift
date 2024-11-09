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

import Android
import AndroidLogging
import AndroidLooper
import Atomics
import FoundationEssentials
import JavaKit
import JavaRuntime
import Logging

private var _flutterSwiftClassLoader: JavaClassLoader!
private var _flutterClassLoader: JavaClassLoader!

private var _logger: Logger!

@_cdecl("JNI_OnLoad")
public func JNI_OnLoad(
  _ jvm: UnsafeMutablePointer<JavaVM?>,
  _ reserved: UnsafeMutableRawPointer
) -> jint {
  _logger = Logger(label: "FlutterAndroid")

  do {
    AndroidLooper_initialize(nil)

    let jvm = JavaVirtualMachine(adoptingJVM: jvm)
    let environment = try jvm.environment()

    _logger.debug("JNI_OnLoad: adopted JVM \(jvm) with environment \(environment)")

    let aClass = try JavaClass<SwiftObjectHolder>(environment: environment)
    let anInterface = try JavaClass<FlutterBinaryMessenger>(environment: environment)

    _flutterSwiftClassLoader = try aClass.getClassLoader()
    _flutterClassLoader = try anInterface.getClassLoader()

    _logger.debug("JNI_OnLoad: registered class loaders")
    return JNI_VERSION_1_6
  } catch {
    _logger.debug("JNI_OnLoad: exception raised: \(error)")
    return JNI_ERR
  }
}

@_cdecl("JNI_OnUnLoad")
public func JNI_OnUnload(
  _ jvm: UnsafeMutablePointer<JavaVM?>,
  _ reserved: UnsafeMutableRawPointer
) {
  _flutterSwiftClassLoader = nil
  _flutterClassLoader = nil

  AndroidLooper_deinitialize(nil)

  _logger.debug("JNI_OnUnload: unload complete")
}

func _getFlutterSwiftClassLoader() -> JavaClassLoader! {
  _flutterSwiftClassLoader
}

func _getFlutterClassLoader() -> JavaClassLoader! {
  _flutterClassLoader
}
