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

  @MainActor
  public func run() async throws {
    repeat {
      var waitDurationNS = viewController.engine.processMessages()
      if waitDurationNS == UInt64(Int64.max) {
        waitDurationNS = UInt64(Float(NanosecondsPerSecond) / Float(viewController.view.frameRate))
      }

      guard viewController.view.dispatchEvent() else {
        break
      }

      try await Task.sleep(for: .nanoseconds(waitDurationNS))
    } while !Task.isCancelled
  }

  public func run() {
    Task { try await run() }
    RunLoop.main.run()
  }
}
#endif
