// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "CFlutterMessenger.h"

#include <stdlib.h>
#include <memory.h>

// +1 on block because it goes out of scope and is only called once

static void FlutterDesktopMessengerBinaryReplyThunk(const uint8_t* data,
                                                    size_t data_size,
                                                    void* user_data) {
    auto replyBlock = (FlutterDesktopBinaryReplyBlock)user_data;
    replyBlock(data, data_size);
    _Block_release(replyBlock);
}

bool FlutterDesktopMessengerSendWithReplyBlock(FlutterDesktopMessengerRef messenger,
                                               const char* channel,
                                               const uint8_t* message,
                                               const size_t message_size,
                                               FlutterDesktopBinaryReplyBlock replyBlock) {
    return FlutterDesktopMessengerSendWithReply(messenger,
                                                channel,
                                                message,
                                                message_size,
                                                replyBlock ? FlutterDesktopMessengerBinaryReplyThunk : nullptr,
                                                replyBlock ? _Block_retain(replyBlock) : nullptr);
}

// +0 on block because it is called multiple times and we assume it is long-lived

static void FlutterDesktopMessageCallbackThunk(FlutterDesktopMessengerRef messenger,
                                               const FlutterDesktopMessage *message,
                                               void *user_data) {
    auto block = (FlutterDesktopMessageCallbackBlock)user_data;
    block(messenger, message);
}

void FlutterDesktopMessengerSetCallbackBlock(FlutterDesktopMessengerRef messenger,
                                             const char* _Nonnull channel,
                                             FlutterDesktopMessageCallbackBlock callbackBlock) {

    return FlutterDesktopMessengerSetCallback(messenger,
                                              channel,
                                              callbackBlock ? FlutterDesktopMessageCallbackThunk : nullptr,
                                              callbackBlock);
}
