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
    project: DartProject
  ) {
    guard let viewController = FlutterViewController(
      properties: viewProperties,
      project: project
    ) else {
      return nil
    }
    self.viewController = viewController
    // caller should register plugins before calling run()
  }

  private var _timer: Timer?

  private func _allocTimer() -> Timer {
    Timer(
      timeInterval: TimeInterval(1.0) / TimeInterval(viewController.view.frameRate),
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

  // run in an existing run loop, at expense of increased CPU overhead
  public func schedule(in aRunLoop: RunLoop, forMode mode: RunLoop.Mode) {
    aRunLoop.add(_allocTimer(), forMode: mode)
  }

  // poll at Flutter frame rate (typically 60Hz)
  public func run() {
    viewController._run()
  }
}

#endif
