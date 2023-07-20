// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#if os(Linux)
@_implementationOnly
import CxxFlutterSwift
import Foundation

fileprivate var NanosecondsPerMillisecond: UInt64 = 1_000_000
fileprivate var NanosecondsPerSecond: UInt64 = 1_000_000_000

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

    public func run() {
        Task { @MainActor in
            repeat {
                var waitDurationNS = viewController.engine.processMessages()
                let frameDurationNS = UInt64(1_000_000.0 / Float(viewController.view.frameRate)) *
                    NanosecondsPerMillisecond

                if frameDurationNS < waitDurationNS {
                    waitDurationNS = frameDurationNS
                }

                guard viewController.view.dispatchEvent() else {
                    break
                }

                try await Task.sleep(nanoseconds: waitDurationNS)
            } while !Task.isCancelled
        }

        RunLoop.main.run()
    }
}
#endif
