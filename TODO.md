- remove checked in Wayland sources, write a SwiftPM extension to generate them
- fix `libflutter_engine.so` binary artifact
- [build steps](https://github.com/sony/flutter-embedded-linux/wiki/Building-Flutter-apps#cross-build-for-arm64-targets-on-x64-hosts)

- warnings
  * FlutterSwift/Client/FlutterEngine.swift:40:77: warning: passing argument of non-sendable type 'FlutterDesktopEngineRef' (aka 'OpaquePointer') into actor-isolated context may introduce data races
  * FlutterSwift/Client/FlutterPlugin.swift:115:13: warning: passing argument of non-sendable type 'FlutterDesktopMessengerRef' (aka 'OpaquePointer') into actor-isolated context may introduce data races
  * FlutterSwift/Messenger/FlutterDesktopMessenger.swift:174:25: warning: passing argument of non-sendable type 'OpaquePointer?' into actor-isolated context may introduce data races
  * FlutterSwift/Messenger/FlutterDesktopMessenger.swift:180:25: warning: passing argument of non-sendable type 'OpaquePointer?' into actor-isolated context may introduce data races

