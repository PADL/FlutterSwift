# FlutterSwift

FlutterSwift is designed to help you write your UI in Dart, and your business logic in Swift.

It consists of three components:

* An idiomatic, [Codable](https://developer.apple.com/documentation/foundation/archives_and_serialization/encoding_and_decoding_custom_types), [asynchronous](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/) Swift implementation of Flutter [platform channels](https://docs.flutter.dev/platform-integration/platform-channels)
* Wrappers to integrate with the platform event loop and Flutter embedding's runner
* On [eLinux](https://github.com/sony/flutter-embedded-linux), a pure Swift runner that hosts your application

The end-goal is to allow Flutter to be used for the UI, and Swift the business logic, in a cross-platform manner. Currently supported targets are macOS, iOS, Android and eLinux.

The following assumes a reasonable degree of familiarity both with Flutter (specifically platform channels) as well as the Swift language.

## Architecture

### Mobile and desktop platforms

On mobile and desktop platforms such as macOS, iOS and Android, the `FlutterPlatformMessenger` class wraps the platform's existing [binary messenger](https://api.flutter.dev/flutter/services/BinaryMessenger-class.html). This is due to the platform binary messenger not being replaceable, as it is used by host platform plugins.

On Darwin platforms (that is, iOS and macOS), you can simply add FlutterSwift as a Swift package dependency from Xcode. On Android, you will need to link FlutterSwift into a Java Native Interface (JNI) library that is bundled with your APK (more of which below).

### Embedded platforms

The `FlutterDesktopMessenger` actor wraps the API in `flutter_messenger.h`. This package will build the Sony eLinux Flutter fork as a submodule, using the Flutter engine included in the artifact bundle in this repository.

Please note the distinction between Flutter _embeddings_ or _embedders_, which are the platform-specific integration of the Flutter framework with an application, and the _embedded_ use case.

## Examples

### iOS and macOS

Example Xcode projects are included in the standard places in the [Examples/counter](Examples/counter) directory. You may need to tweak the bundle identifier to match your developer ID.

### Android

Android builds are currently only supported on macOS, and require the following dependencies to be installed:

* The [Swift Android SDK](https://github.com/finagolfin/swift-android-sdk)
* A [Swift toolchain](https://www.swift.org/install/macos/) that matches exactly the version of the Swift Android SDK
* [Android Studio](https://developer.android.com/studio)
* A [native JDK](https://www.oracle.com/au/java/technologies/downloads/)

You'll then need to edit the [`build-android.sh`](build-android.sh) script and change, if necessary, the following environment variables:

* `NDK_VERS`: the version of the Android NDK
* `SWIFT_VERS`: the version of the Swift SDK and toolchain downloaded above
* `TARGET_JAVA_HOME`: the path to the JDK for the target machine (within the Android Studio app)
* `HOST_JAVA_HOME`: the path to the JDK for the build (host) machine (typically within `/Library/Java/JavaVirtualMachines`)

Android-specific source for the example is in [Examples/counter/android/app/src/main](Examples/counter/android/app/src/main).

That the tooling here is somewhat inconvenient is a known issue and we plan to [improve it](https://github.com/PADL/FlutterSwift/issues/8) in the future.

Note that `@MainActor` is unavailable on Android; use `@UIThreadActor` instead.

### Embedded Linux

Assuming the Flutter SDK is installed in `/opt/flutter-elinux/flutter`, you can just run `./build-counter-linux.sh` in the top-level directory, followed by `./run-counter-linux.sh`. This will build the Flutter AOT object, followed by the Swift runner.

The environment variable `FLUTTER_SWIFT_BACKEND` can be set to one of `gbm`, `eglstream`, or `wayland`, as appropriate. This should be set both for building and running. You will probably want to set it to `wayland` unless you are actually testing on an embedded system.

## Usage

This section provides a brief overview of the APIs provided by FlutterSwift.

### Initialization

#### macOS

```swift
import FlutterMacOS.FlutterBinaryMessenger
import FlutterSwift

override func awakeFromNib() {
  let flutterViewController = FlutterViewController() // from platform embedding
  let binaryMessenger = FlutterSwift
        .FlutterPlatformMessenger(wrapping: flutterViewController.engine.binaryMessenger)
  ...
}
```

#### Android

Android requires that your application's `configureFlutterEngine()` method call a native function you define to initialize your platform channels, such as the following:

```java
package com.example.counter;

import io.flutter.plugin.common.BinaryMessenger;

public final class ChannelManager {
  public final BinaryMessenger binaryMessenger;

  public ChannelManager(BinaryMessenger binaryMessenger) {
    System.loadLibrary("counter");
    this.binaryMessenger = binaryMessenger;
  }

  public native void initChannelManager();
}
```

In your Swift code (here, `initChannelManager()`), you can then register your platform channel implementations:

```swift
import FlutterAndroid
import JavaKit
import JavaRuntime

@JavaClass("com.example.counter.ChannelManager")
open class _ChannelManager: JavaObject {
  @JavaField(isFinal: true)
  public var binaryMessenger: FlutterAndroid.FlutterBinaryMessenger!

  @JavaMethod
  @_nonoverride
  public convenience init(
    _ binaryMessenger: FlutterAndroid.FlutterBinaryMessenger?,
    environment: JNIEnvironment? = nil
  )
}

protocol _ChannelManagerNativeMethods {
  func initChannelManager()
}

@JavaImplementation("com.example.counter.ChannelManager")
extension _ChannelManager: _ChannelManagerNativeMethods {
  @JavaMethod
  public func initChannelManager() {
    let wrappedMessenger = FlutterPlatformMessenger(wrapping: binaryMessenger!)
    // initialize your channels, remembering to take a strong reference to them
  }
}
```

#### eLinux

On Linux, using the native Swift [client wrapper](Sources/FlutterSwift/Client/):

```swift
@main
enum SomeApp {
  static func main() {
    guard CommandLine.arguments.count > 1 else {
      print("usage: SomeApp [flutter_path]")
      exit(1)
    }
    let dartProject = DartProject(path: CommandLine.arguments[1])
    let viewProperties = FlutterViewController.ViewProperties(
            width: 640,
            height: 480,
            title: "SomeApp",
            appId: "com.example.SomeApp"
    )
    let window = FlutterWindow(properties: viewProperties, project: dartProject)
    guard let window else {
      debugPrint("failed to initialize window!")
      exit(2)
    }
    let binaryMessenger = viewController.engine.binaryMessenger
    ...
    window.run()
  }
}
```

### Channels

#### Message channel

This shows a basic message channel handler using the JSON message codec. On eLinux, instead of registering the channels in `awakeFromNib()`, call this from the `main()` function (perhaps indirected by a manager class).

```swift
private func messageHandler(_ arguments: String?) async -> Int? {
  debugPrint("Received message \(String(describing: arguments))")
  return 0xCAFE_BABE
}

override func awakeFromNib() {
...
  flutterBasicMessageChannel = FlutterBasicMessageChannel(
    name: "com.example.SomeApp.basic",
    binaryMessenger: binaryMessenger,
    codec: FlutterJSONMessageCodec.shared
  )

  task = Task {
    try! await flutterBasicMessageChannel.setMessageHandler(messageHandler)
    ...
  }
}
```

#### Method channel

```swift
var isRunning = true

private func methodCallHandler(
  call: FlutterSwift.FlutterMethodCall<Bool>
) async throws -> Bool {
  isRunning.toggle()
  return isRunning
}

override func awakeFromNib() {
...
  let flutterMethodChannel = FlutterMethodChannel(
    name: "com.example.SomeApp.toggle",
        binaryMessenger: binaryMessenger
    )
    task = Task {
      try! await flutterMethodChannel.setMethodCallHandler(methodCallHandler)
  }
}

```

#### Event channel

Here is an example of an event channel, lifted from the [counter](Examples/counter/swift/runner.swift) example.

```swift
import AsyncAlgorithms
import AsyncExtensions
import FlutterSwift
...

typealias Arguments = FlutterNull
typealias Event = Int32
typealias Stream = AsyncThrowingChannel<Event?, FlutterError>

var flutterEventStream = Stream()
var task: Task<(), Error>?
var counter: Event = 0

private func onListen(_ arguments: Arguments?) throws -> FlutterEventStream<Event> {
  flutterEventStream.eraseToAnyAsyncSequence()
}

private func onCancel(_ arguments: Arguments?) throws {
  task?.cancel()
  task = nil
}

override func awakeFromNib() {
...
  let flutterEventChannel = FlutterEventChannel(
    name: "com.example.SomeApp.counterEvents",
    binaryMessenger: binaryMessenger
  )
  task = Task {
    try! await flutterEventChannel.setStreamHandler(onListen: onListen, onCancel: onCancel)
    repeat {
      await flutterEventStream.send(counter)
      count += 1
      try await Task.sleep(nanoseconds: NSEC_PER_SEC)
    } while !Task.isCancelled
  }
}
```
