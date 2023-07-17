import FlutterSwift

private var NSEC_PER_SEC: UInt64 = 1_000_000_000

class ChannelManager {
    typealias Arguments = FlutterNull
    typealias Event = Int32

    var flutterBasicMessageChannel: FlutterBasicMessageChannel?
    var flutterEventChannel: FlutterEventChannel?
    var flutterMethodChannel: FlutterMethodChannel?
    var task: Task<(), Error>?
    var isRunning = true
    var counter: Event = 0

    let magicCookie = 0xCAFE_BABE

    var flutterEventStream = FlutterEventStream<Event>()

    private func messageHandler(_ arguments: String?) async -> Int? {
        debugPrint("Received message \(String(describing: arguments))")
        return magicCookie
    }

    @MainActor
    private func onListen(_ arguments: Arguments?) throws -> FlutterEventStream<Event> {
        flutterEventStream
    }

    @MainActor
    private func onCancel(_ arguments: Arguments?) throws {
        task?.cancel()
    }

    @MainActor
    private func methodCallHandler(
        call: FlutterSwift
            .FlutterMethodCall<Int>
    ) async throws -> Bool {
        debugPrint("received method call \(call)")
        guard call.arguments == magicCookie else {
            throw FlutterError(code: "bad cookie")
        }
        isRunning.toggle()
        return isRunning
    }

    init(_ viewController: FlutterViewController) {
        let messenger = viewController.engine.messenger!

        flutterBasicMessageChannel = FlutterBasicMessageChannel(
            name: "com.padl.example",
            binaryMessenger: messenger,
            codec: FlutterJSONMessageCodec.shared
        )
        flutterEventChannel = FlutterEventChannel(
            name: "com.padl.counter",
            binaryMessenger: messenger
        )
        flutterMethodChannel = FlutterMethodChannel(
            name: "com.padl.toggleCounter",
            binaryMessenger: messenger
        )

        task = Task { @MainActor in
            try! await flutterBasicMessageChannel!.setMessageHandler(messageHandler)
            try! await flutterEventChannel!.setStreamHandler(onListen: onListen, onCancel: onCancel)
            try! await flutterMethodChannel!.setMethodCallHandler(methodCallHandler)

            repeat {
                debugPrint("starting task...")
                await flutterEventStream.send(counter)
                if isRunning {
                    counter += 1
                    debugPrint("counter is now \(counter)")
                }
                try await Task.sleep(nanoseconds: NSEC_PER_SEC)
            } while !Task.isCancelled
            debugPrint("ending task")
        }
    }
}

@main
enum Counter {
    static func main() {
        guard CommandLine.arguments.count > 1 else {
            print("usage: Counter [flutter_path]")
            exit(1)
        }
        let dartProject = DartProject(path: CommandLine.arguments[1])
        let viewProperties = FlutterViewController.ViewProperties(
            width: 640,
            height: 480,
            title: "Counter",
            appId: "com.padl.counter"
        )
        let window = FlutterWindow(properties: viewProperties, project: dartProject)
        guard let window else {
            debugPrint("failed to initialize window!")
            exit(2)
        }
        let _ = ChannelManager(window.viewController)
        window.run()
    }
}
