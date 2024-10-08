FlutterSwift
============

FlutterSwift is a native Swift Flutter client wrapper and platform channel implementation.

The end-goal is to allow Flutter to be used for the UI, and Swift the business logic, in a cross-platform manner. Currently this is achieved for macOS, iOS and [embedded Linux](https://github.com/sony/flutter-embedded-linux), but Android is an obvious future target. It also provides a more idiomatic structured concurrency API which would not be possible in Objective-C.

Architecture
------------

The `FlutterDesktopMessenger` actor wraps the API in `flutter_messenger.h`. To permit development on Darwin platforms, FlutterSwift also provides `FlutterPlatformMessenger` which wraps the existing platform binary messenger. Thus, you can develop on macOS and deploy on embedded Linux from a single codebase.

This repository will build the Sony eLinux Wayland engine as a submodule, but it doesn't at this time build the Flutter engine itself: this is assumed to be in `/opt/flutter-elinux/lib` or a build artifact downloaded by [download-engine.sh](download-engine.sh).

Some examples follow.

Counter Demo
------------

Assuming the Flutter SDK is installed in `/opt/flutter-elinux/flutter`, you can just run `./build-counter-linux.sh` in the top-level directory, followed by `./run-counter-linux.sh`. This will build the Flutter AOT object followed by the Swift runner.

Initialization
--------------

macOS:

```swift
import FlutterMacOS.FlutterBinaryMessenger
import FlutterSwift

override func awakeFromNib() {
    let flutterViewController = FlutterViewController() // from ObjC implementation
    let binaryMessenger = FlutterSwift
        .FlutterPlatformMessenger(wrapping: flutterViewController.engine.binaryMessenger)
    ...
}
```

Linux, using the native Swift [client wrapper](Sources/FlutterSwift/Client/):

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
            appId: "com.example.some-app"
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

Message channel
---------------

This shows a basic message channel handler using the JSON message codec. Note that because the binary messenger is an actors, `setMessageHandler()` needs to be called in an asynchronous context. On eLinux, instead of registering the channels in `awakeFromNib()`, call this from the `main()` function (perhaps indirected by a manager class).

```swift
private func messageHandler(_ arguments: String?) async -> Int? {
    debugPrint("Received message \(arguments)")
    return 12345
}       

override func awakeFromNib() {
...
    flutterBasicMessageChannel = FlutterBasicMessageChannel(
        name: "com.padl.example",
        binaryMessenger: binaryMessenger,
        codec: FlutterJSONMessageCodec.shared
    )

    task = Task {
        try! await flutterBasicMessageChannel.setMessageHandler(messageHandler)
        ...
    }
}
```

Method channel
--------------

```swift
var isRunning = true

private func methodCallHandler(
    call: FlutterSwift
        .FlutterMethodCall<Bool>
) async throws -> Bool {
    isRunning.toggle()
    return isRunning
}

override func awakeFromNib() {
...

    let flutterMethodChannel = FlutterMethodChannel(
        name: "com.padl.toggleCounter",
        binaryMessenger: binaryMessenger
    )
    task = Task {
        try! await flutterMethodChannel.setMethodCallHandler(methodCallHandler)
    }
}

```
Event channel
-------------

```swift
import AsyncAlgorithms
import AsyncExtensions
import FlutterSwift
...

/// this should go inside MainFlutterWindow
typealias Arguments = FlutterNull
typealias Event = Int32
typealias Stream = AsyncThrowingChannel<Event?, FlutterError>

var flutterEventStream = Stream()
var task: Task<(), Error>?
var counter: Event = 0

private func onListen(_ arguments: Arguments?) throws -> FlutterEventStream<Event> {
    // a FlutterEventStream is an AsyncSequence
    flutterEventStream.eraseToAnyAsyncSequence()
}

private func onCancel(_ arguments: Arguments?) throws {
    task?.cancel()
    task = nil
}

override func awakeFromNib() {
...
    let flutterEventChannel = FlutterEventChannel(
        name: "com.padl.counter",
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
