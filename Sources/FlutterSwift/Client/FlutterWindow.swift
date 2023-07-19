// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#if os(Linux)
@_implementationOnly
import CxxFlutterSwift
import Foundation

// FIXME: these don't appear to be available on non-Darwin platforms
fileprivate var NSEC_PER_MSEC: UInt64 = 1_000_000
fileprivate var NSEC_PER_SEC: UInt64 = 1_000_000_000

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

    private func schedule(after nextInterval: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + nextInterval) {
            var waitDurationNS = viewController.engine.processMessages()
            let frameDurationNS = UInt64(1_000_000.0 / Float(viewController.view.frameRate)) *
                NSEC_PER_MSEC

            if frameDurationNS < waitDurationNS {
                waitDurationNS = frameDurationNS
            }

            guard viewController.view.dispatchEvent() else {
                return
            }

            // should be tail call optimised
            self.schedule(after: TimeInterval(waitDurationNS / NSEC_PER_SEC))
        }
    }

    public func run() {
        schedule(after: 0)
        RunLoop.main.run()
    }
}
#endif
