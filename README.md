FlutterSwift
============

FlutterSwift is a Swift-native implementation of Flutter platform channels.

It's intended to be used on platforms where Swift is available but Objective-C and AppKit/UIKit are not, for example the [Sony Flutter embedder](https://github.com/sony/flutter-embedded-linux). It also provides an `async/await` API rather than using callbacks and dispatch queues.

 `FlutterDesktopMessenger` wraps the API in `flutter_messenger.h`. To allow development on Darwin platforms, `FlutterPlatformMessenger` is also provided which uses the existing platform binary messenger.

Some examples follow.

Note that building a Swift package currently requires Swift 5.9 as some limited use is made of C++ interoperability. If this proves to be a blocking issue, it shouldn't be too difficult to fix.

To build the embedded Linux eaxmples, you'll need a version of the Sony embedder at least at revision 5c86492. I'm yet to implement a proper embedder wrapper, this will require some CMake wizardy to integrate with the Swift Package Manager. In the interim see `Examples/counter/swift/README.md` for some testing notes.

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

