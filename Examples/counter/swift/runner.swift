// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import AsyncAlgorithms
import FlutterSwift

private var NSEC_PER_SEC: UInt64 = 1_000_000_000

class ChannelManager {
    typealias Arguments = FlutterNull
    typealias Event = Int32
    typealias Stream = AsyncThrowingChannel<Event?, FlutterError>

    var flutterBasicMessageChannel: FlutterBasicMessageChannel!
    var flutterEventChannel: FlutterEventChannel!
    var flutterMethodChannel: FlutterMethodChannel!
    var task: Task<(), Error>?
    var counter: Event = 0

    let magicCookie = 0xCAFE_BABE

    var flutterEventStream = Stream()

    private func messageHandler(_ arguments: String?) async -> Int? {
        debugPrint("Received message \(String(describing: arguments))")
        return magicCookie
    }

    private func onListen(_ arguments: Arguments?) throws -> FlutterEventStream<Event> {
        flutterEventStream.eraseToAnyAsyncSequence()
    }

    private func onCancel(_ arguments: Arguments?) throws {
        cancelTask()
    }

    private func methodCallHandler(
        call: FlutterSwift
            .FlutterMethodCall<Int>
    ) async throws -> Bool {
        debugPrint("received method call \(call)")
        guard call.arguments == magicCookie else {
            throw FlutterError(code: "bad cookie")
        }
        if task == nil {
            startTask()
        } else {
            cancelTask()
        }

        return task != nil
    }

    func startTask() {
        task = Task {
            debugPrint("starting task...")
            repeat {
                counter += 1
                await flutterEventStream.send(counter)
                debugPrint("counter is now \(counter)")
                try await Task.sleep(nanoseconds: NSEC_PER_SEC)
            } while !Task.isCancelled
            debugPrint("task was cancelled")
        }
    }

    func cancelTask() {
        if let task {
            debugPrint("cancelling task...")
            task.cancel()
            self.task = nil
        }
    }

    init(_ viewController: FlutterViewController) {
        let binaryMessenger = viewController.engine.binaryMessenger

        flutterBasicMessageChannel = FlutterBasicMessageChannel(
            name: "com.padl.example",
            binaryMessenger: binaryMessenger,
            codec: FlutterJSONMessageCodec.shared
        )
        flutterEventChannel = FlutterEventChannel(
            name: "com.padl.counter",
            binaryMessenger: binaryMessenger
        )
        flutterMethodChannel = FlutterMethodChannel(
            name: "com.padl.toggleCounter",
            binaryMessenger: binaryMessenger
        )

        Task {
            try! await flutterBasicMessageChannel.setMessageHandler(messageHandler)
            try! await flutterEventChannel.setStreamHandler(onListen: onListen, onCancel: onCancel)
            try! await flutterMethodChannel.setMethodCallHandler(methodCallHandler)

            startTask()
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
