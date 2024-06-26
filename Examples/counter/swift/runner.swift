// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import AsyncAlgorithms
import FlutterSwift
import Foundation

private var NSEC_PER_SEC: UInt64 = 1_000_000_000

final class ChannelManager: @unchecked Sendable {
  typealias Arguments = FlutterNull
  typealias Event = Int32
  typealias Stream = AsyncThrowingChannel<Event?, FlutterSwift.FlutterError>

  var flutterBasicMessageChannel: FlutterSwift.FlutterBasicMessageChannel!
  var flutterEventChannel: FlutterSwift.FlutterEventChannel!
  var flutterMethodChannel: FlutterSwift.FlutterMethodChannel!
  var task: Task<(), Error>?
  var counter: Event = 0

  let magicCookie = 0xCAFE_BABE

  var flutterEventStream = Stream()

  private func messageHandler(_ arguments: String?) async -> Int? {
    debugPrint("Received message \(String(describing: arguments))")
    return magicCookie
  }

  @Sendable
  private func onListen(_ arguments: Arguments?) throws -> FlutterEventStream<Event> {
    flutterEventStream.eraseToAnyAsyncSequence()
  }

  @Sendable
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

  init(binaryMessenger: FlutterSwift.FlutterBinaryMessenger) {
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

#if os(Linux)
extension ChannelManager {
  convenience init(viewController: FlutterViewController) {
    self.init(binaryMessenger: viewController.engine.binaryMessenger)
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
      width: 800,
      height: 480,
      title: "Counter",
      appId: "com.padl.counter"
    )
    let window = FlutterWindow(properties: viewProperties, project: dartProject)
    guard let window else {
      exit(2)
    }
    _ = ChannelManager(viewController: window.viewController)
    Task { @MainActor in
      try await window.run()
    }
    RunLoop.main.run()
  }
}
#endif
