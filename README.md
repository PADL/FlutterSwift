FlutterSwift
============

FlutterSwift is a Swift-native implementation of Flutter platform channels.

It's intended to be used on platforms where Swift is available but Objective-C and AppKit/UIKit are not, for example the [Sony Flutter embedder](https://github.com/sony/flutter-embedded-linux). It also provides an `async/await` API rather than using callbacks and dispatch queues.

 `FlutterDesktopMessenger` wraps the API in `flutter_messenger.h`. To allow development on Darwin platforms, `FlutterPlatformMessenger` is also provided which uses the existing platform binary messenger.

This repository will build the Sony embedded Linux Wayland engine as a submodule, but it doesn't at this time build the Flutter engine itself (this is assumed to be in `/opt/flutter-elinux/lib` or a downloaded build artifact) or a runner. In lieu of a runner, see [README.md](Examples/counter/swift/README.md) for some testing notes.

Some examples follow.

Initialization
--------------

macOS:

```swift
import FlutterMacOS.FlutterBinaryMessenger
import FlutterSwift

override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let platformBinaryMessenger = FlutterSwift
        FlutterPlatformMessenger(wrapping: flutterViewController.engine.binaryMessenger)
    ...
}
```

Linux:

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


```swift
private func messageHandler(_ arguments: String?) async -> Int? {
    debugPrint("Received message \(arguments)")
    return 12345
}       

override func awakeFromNib() {
...
    flutterBasicMessageChannel = FlutterBasicMessageChannel(
        name: "com.padl.example",
        binaryMessenger: platformBinaryMessenger,
        codec: FlutterJSONMessageCodec.shared
    )

    task = Task { @MainActor in
        try! await flutterBasicMessageChannel!.setMessageHandler(messageHandler)
        ...
    }
}
```

Method channel
--------------

```swift

var isRunning = true

@MainActor
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
        binaryMessenger: platformBinaryMessenger
    )
    task = Task { @MainActor in
        try await flutterMethodChannel!.setMethodCallHandler(methodCallHandler)
    }
}

```
Event channel
-------------

Event channels are initialized with the binary messenger created in the previous example.

```swift
import AsyncAlgorithms
...

/// this should go inside MainFlutterWindow
typealias Arguments = FlutterNull
typealias Event = Int32

var flutterEventStream = FlutterEventStream<Event>()
var task: Task<(), Error>?
var counter: Event = 0

@MainActor
private func onListen(_ arguments: Arguments?) throws -> FlutterEventStream<Event> {
    flutterEventStream
}

@MainActor
private func onCancel(_ arguments: Arguments?) throws {
    task?.cancel()
}

override func awakeFromNib() {
...
    let flutterEventChannel = FlutterEventChannel(
        name: "com.padl.counter",
        binaryMessenger: platformBinaryMessenger
    )
    task = Task { @MainActor in
        try await flutterEventChannel!.setStreamHandler(onListen: onListen, onCancel: onCancel)
        repeat {
            await flutterEventStream.send(counter)
            try await Task.sleep(nanoseconds: NSEC_PER_SEC)
        } while !Task.isCancelled
    }
}
```

