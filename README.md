FlutterSwift
------------

FlutterSwift is a Swift-native implementation of Flutter platform channels. It is a work in progress, which is to say, it is not debugged yet.

It's intended to be used on platforms where Swift is available but Objective-C and AppKit/UIKit are not, for example the [Sony Flutter embedder](https://github.com/sony/flutter-embedded-linux). It also provides an `async/await` API rather than using callbacks and dispatch queues.

 `FlutterDesktopMessenger` wraps the API in `flutter_messenger.h`. To allow development on Darwin platforms, `FlutterPlatformMessenger` is also provided which uses the existing platform binary messenger.
