//
// Copyright (c) 2023-2024 PADL Software Pty Ltd
//
// Licensed under the Apache License, Version 2.0 (the License);
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an 'AS IS' BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import AsyncAlgorithms
import FlutterSwift
import Foundation
import Logging
#if canImport(AndroidLogging)
import AndroidLogging
#endif

final class ChannelManager: @unchecked Sendable {
  fileprivate static var shared: ChannelManager!

  typealias Arguments = FlutterNull
  typealias Event = Int32
  typealias Stream = AsyncThrowingChannel<Event?, FlutterSwift.FlutterError>

  var flutterBasicMessageChannel: FlutterSwift.FlutterBasicMessageChannel!
  var flutterEventChannel: FlutterSwift.FlutterEventChannel!
  var flutterMethodChannel: FlutterSwift.FlutterMethodChannel!
  var task: Task<(), Error>?
  var counter: Event = 0
  var logger: Logger

  let magicCookie = 0xCAFE_BABE

  var flutterEventStream = Stream()

  private func messageHandler(_ arguments: String?) async -> Int? {
    logger.debug("received message \(String(describing: arguments))")
    return magicCookie
  }

  @Sendable
  private func onListen(_ arguments: Arguments?) throws -> FlutterEventStream<Event> {
    flutterEventStream.eraseToAnyAsyncSequence()
  }

  @Sendable
  private func onCancel(_ arguments: Arguments?) throws {
    stop()
  }

  private func methodCallHandler(
    call: FlutterSwift
      .FlutterMethodCall<Int>
  ) async throws -> Bool {
    logger.debug("received method call \(call)")
    guard call.arguments == magicCookie else {
      throw FlutterError(code: "bad cookie")
    }
    if task == nil {
      run()
    } else {
      stop()
    }

    return task != nil
  }

  func run() {
    task = Task {
      repeat {
        counter += 1
        await flutterEventStream.send(counter)
        logger.trace("counter is now \(counter)")
        try await Task.sleep(for: .seconds(1))
      } while !Task.isCancelled
      logger.info("task was cancelled")
    }
  }

  func stop() {
    if let task {
      logger.info("cancelling task...")
      task.cancel()
      self.task = nil
    }
  }

  init(binaryMessenger: FlutterSwift.FlutterBinaryMessenger) {
    #if canImport(Android)
    LoggingSystem.bootstrap(AndroidLogHandler.taggedBySource)
    #else
    LoggingSystem.bootstrap(StreamLogHandler.standardError)
    #endif
    logger = Logger(label: "com.example.counter")

    flutterBasicMessageChannel = FlutterBasicMessageChannel(
      name: "com.example.counter.basic",
      binaryMessenger: binaryMessenger,
      codec: FlutterJSONMessageCodec.shared
    )
    flutterEventChannel = FlutterEventChannel(
      name: "com.example.counter.events",
      binaryMessenger: binaryMessenger
    )
    flutterMethodChannel = FlutterMethodChannel(
      name: "com.example.counter.toggle",
      binaryMessenger: binaryMessenger
    )
    Task {
      try! await flutterBasicMessageChannel.setMessageHandler(messageHandler)
      try! await flutterEventChannel.setStreamHandler(onListen: onListen, onCancel: onCancel)
      try! await flutterMethodChannel.setMethodCallHandler(methodCallHandler)

      run()
    }
  }
}

#if os(Linux) && canImport(Glibc)
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
      appId: "com.example.counter"
    )
    let window = FlutterWindow(
      properties: viewProperties,
      project: dartProject
    )
    guard let window else {
      exit(2)
    }
    ChannelManager.shared = ChannelManager(viewController: window.viewController)
    window.run()
  }
}

#elseif canImport(Android)
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
    ChannelManager.shared = ChannelManager(binaryMessenger: wrappedMessenger)
  }
}
#endif
