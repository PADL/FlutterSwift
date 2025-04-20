//
// Copyright (c) 2023-2025 PADL Software Pty Ltd
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

#if os(Linux) && canImport(Glibc)
@_implementationOnly
import CxxFlutterSwift
import Foundation

fileprivate let NanosecondsPerMillisecond: UInt64 = 1_000_000
fileprivate let NanosecondsPerSecond: UInt64 = 1_000_000_000

public struct FlutterWindow {
  public let viewController: FlutterViewController

  public init?(
    properties viewProperties: FlutterViewController.ViewProperties,
    project: DartProject,
    enableImpeller: Bool = false
  ) {
    var switches = [String: Any]()
    if enableImpeller {
      switches["enable-impeller"] = true
    }
    guard let viewController = FlutterViewController(
      properties: viewProperties,
      project: project,
      switches: switches
    ) else {
      return nil
    }
    self.viewController = viewController
    // caller should register plugins before calling run()
  }

  // MARK: - CFRunLoop API

  private func _allocTimer() -> Timer {
    // note: frame rate is not in Hz, rather it's 1000*Hz (i.e. 60000 for 60Hz)
    Timer(
      timeInterval: TimeInterval(1000.0) / TimeInterval(viewController.view.frameRate),
      repeats: true
    ) { [self] timer in
      let waitDurationNS = viewController.engine.processMessages()
      if waitDurationNS != Int64.max {
        timer.fireDate = Date.now
          .addingTimeInterval(TimeInterval(waitDurationNS) / TimeInterval(NanosecondsPerSecond))
      }
      guard viewController.view.dispatchEvent() else {
        timer.invalidate()
        return
      }
    }
  }

  public func schedule(in aRunLoop: RunLoop, forMode mode: RunLoop.Mode) {
    aRunLoop.add(_allocTimer(), forMode: mode)
  }

  public func run() {
    let runLoop = RunLoop.main
    schedule(in: runLoop, forMode: .common)
    runLoop.run()
  }

  // MARK: - Async API

  // note: this still needs to run within a CFRunLoop as it appears Dispatch
  // does not guarantee @MainActor runs on the main thread otherwise.

  @MainActor
  public func run() async throws {
    let framePeriodNS =
      Int(Double(NanosecondsPerSecond) / (Double(viewController.view.frameRate) / 1000.0))

    repeat {
      var deadline: ContinuousClock.Instant = .now
      let waitDurationNS = viewController.engine.processMessages()
      if waitDurationNS != Int64.max {
        deadline += .nanoseconds(waitDurationNS)
      } else {
        deadline += .nanoseconds(framePeriodNS)
      }
      try await Task.sleep(until: deadline)
    } while viewController.view.dispatchEvent()
  }
}

#endif
