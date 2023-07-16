FlutterSwift
============

FlutterSwift is a Swift-native implementation of Flutter platform channels. It is a work in progress, which is to say, it is not debugged yet.

It's intended to be used on platforms where Swift is available but Objective-C and AppKit/UIKit are not, for example the [Sony Flutter embedder](https://github.com/sony/flutter-embedded-linux). It also provides an `async/await` API rather than using callbacks and dispatch queues.

 `FlutterDesktopMessenger` wraps the API in `flutter_messenger.h`. To allow development on Darwin platforms, `FlutterPlatformMessenger` is also provided which uses the existing platform binary messenger.

Some examples follow.

Initialization
--------------

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

On Linux, you will use `FlutterDesktopMessenger`, however this code hasn't been built or tested yet.

Event channel
-------------

Event channels are initialized with the binary messenger created in the previous example.

```swift
import AsyncAlgorithms
...

/// this should go inside MainFlutterWindow
typealias Arguments = FlutterEmptyArguments
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

    letflutterMethodChannel = FlutterMethodChannel(
        name: "com.padl.toggleCounter",
        binaryMessenger: platformBinaryMessenger
    )
    task = Task { @MainActor in
        try await flutterEventChannel!.setStreamHandler(onListen: onListen, onCancel: onCancel)
    }
}
```
