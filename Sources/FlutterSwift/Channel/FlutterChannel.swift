// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation

protocol FlutterChannel: AnyObject {
    var name: String { get }
    var binaryMessenger: FlutterBinaryMessenger { get }
    var codec: FlutterMessageCodec { get }
    var priority: TaskPriority? { get }
    var connection: FlutterBinaryMessengerConnection { get set }
}

extension FlutterChannel {
    func setMessageHandler<Handler>(
        _ optionalHandler: Handler?,
        _ block: (Handler) -> FlutterBinaryMessageHandler
    ) throws {
        guard let unwrappedHandler = optionalHandler else {
            if connection > 0 {
                binaryMessenger.cleanUp(connection: connection)
                connection = 0
            } else {
                _ = try binaryMessenger.setMessageHandler(
                    on: name,
                    handler: nil,
                    priority: priority
                )
            }
            return
        }
        connection = try binaryMessenger.setMessageHandler(
            on: name,
            handler: block(unwrappedHandler),
            priority: priority
        )
    }
}
