# FlutterSwift

FlutterSwift is designed to help you write your UI in Dart, and your business logic in Swift.

It consists of three components:

* An idiomatic, [Codable](https://developer.apple.com/documentation/foundation/archives_and_serialization/encoding_and_decoding_custom_types), [asynchronous](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/) Swift implementation of Flutter [platform channels](https://docs.flutter.dev/platform-integration/platform-channels)
* Wrappers to integrate with the platform event loop and Flutter embedding's runner
* On [eLinux](https://github.com/flutter-elinux/flutter-embedded-linux), a pure Swift runner that hosts your application

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

Install [Flutter](https://docs.flutter.dev/get-started/install) and [Xcode](https://developer.apple.com/xcode/) on your development machine. Add FlutterSwift as a Swift package dependency from Xcode (see [Architecture](#mobile-and-desktop-platforms) above).

Example Xcode projects are included in the [Examples/counter](Examples/counter) directory under `ios/` and `macos/`. You may need to tweak the bundle identifier to match your developer ID. The shared Swift runner code is in [Examples/counter/swift/](Examples/counter/swift/).

### Android

#### Prerequisites

- [Android Studio](https://developer.android.com/studio) with the Android SDK and NDK installed
- [swiftly](https://swiftlang.github.io/swiftly/) with Swift 6.3 installed (`swiftly install 6.3`)
- The Swift Android SDK installed (`swift sdk install swift-6.3-RELEASE_android`)
- Flutter SDK (set `flutter.sdk` in `android/local.properties`)

#### Environment

The build must use Android Studio's bundled JDK (JBR), not a system-installed JDK, because the Kotlin Gradle plugin may not support newer JDK versions. Set `JAVA_HOME` accordingly:

```sh
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
```

The following environment variables are used by `Package.swift` and the Gradle integration:

| Variable | Purpose | Set by |
|---|---|---|
| `JAVA_HOME` | JDK for Gradle and `Package.swift`'s `findJavaHome()` | You (see above) |
| `FLUTTER_SWIFT_JVM` | Enables Android/JVM targets in `Package.swift` | Gradle script |
| `CLASSPATH` | Path to `flutter.jar` for SwiftJava code generation | Gradle script |

You only need to set `JAVA_HOME` yourself; the other variables are set automatically by the Gradle integration.

#### Building

From the `Examples/counter/android/` directory:

```sh
JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :app:assembleDebug
```

Or for a release build:

```sh
JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :app:assembleRelease
```

#### How the Gradle build works

The [`swift-android.gradle.kts`](Examples/counter/android/swift-android.gradle.kts) script is applied from `app/build.gradle.kts` and integrates the Swift cross-compilation into the Android build pipeline. It registers four tasks per architecture (currently arm64-v8a only):

1. **`swiftWriteClasspath`** — Writes a `.swift-java.classpath` file pointing to `flutter.jar` so the SwiftJava plugin can find Flutter's Java classes during code generation.

2. **`swiftBuild`** — Cross-compiles the Swift product (`counter`) using `swiftly run swift build --swift-sdk <target>`. This produces `libcounter.so` and its dependencies (e.g. `libSwiftJava.so`). The working directory is the FlutterSwift root (where `Package.swift` lives). The `FLUTTER_SWIFT_JVM=true` environment variable activates the Android target configuration in `Package.swift`.

3. **`packageSwiftJar`** — Packages the Java bridge classes generated by SwiftJava's `JavaCompilerPlugin` into `libs/flutterswift.jar`. These are the Java-side stubs for `@JavaImplementation` and `@JavaClass` annotated Swift types.

4. **`copySwiftLibraries`** — Copies all `.so` files into `src/{debug,release}/jniLibs/arm64-v8a/`:
   - Built product and dependency `.so` files from `.build/<triple>/{debug,release}/`
   - Swift runtime libraries from the Swift Android SDK's `swift-resources/` directory
   - `libc++_shared.so` from the NDK sysroot

These tasks are wired into the Android build so they run before `mergeJniLibFolders`, ensuring all native libraries are included in the APK.

#### Configuration

The `swift-android.gradle.kts` script can be configured by setting properties on the `swiftConfig` extension before the script is applied. The defaults are:

```kotlin
swiftConfig.apiLevel = 28
swiftConfig.debugAbiFilters = setOf("arm64-v8a")
swiftConfig.releaseAbiFilters = setOf("arm64-v8a")
swiftConfig.swiftVersion = "6.3"
swiftConfig.swiftProduct = "counter"
```

Android-specific source for the example is in [Examples/counter/android/app/src/main](Examples/counter/android/app/src/main).

Note that `@MainActor` is unavailable on Android; use `@UIThreadActor` instead.

### Embedded Linux

Ensure [swiftly](https://swiftlang.github.io/swiftly/) and [Flutter eLinux](https://github.com/flutter-elinux/flutter-elinux) are installed. Flutter eLinux should be in `/opt/flutter-elinux`; Swift is expected at `~/.local/share/swiftly/bin` (the default swiftly location).

To build and run the counter example:

```sh
export FLUTTER_SWIFT_BACKEND=wayland
./build-elinux.sh
./run-elinux.sh
```

This builds the Flutter assets and AOT object, cross-compiles the Swift runner, and copies the Flutter engine into the bundle.

The environment variable `FLUTTER_SWIFT_BACKEND` can be set to one of `gbm`, `eglstream`, or `wayland`, as appropriate. This should be set both for building and running. You will probably want to set it to `wayland` unless you are actually testing on an embedded system. Set `FLUTTER_SWIFT_BUILD_CONFIG` to `release` for a release build (defaults to `debug`).

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
    UIThreadActor.assumeIsolated {
      // initialize your channels, remembering to take a strong reference to them
    }
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
