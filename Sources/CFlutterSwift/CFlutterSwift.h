// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef CFlutterSwift_h
#define CFlutterSwift_h

#include "flutter_messenger.h"

#ifdef __cplusplus
extern "C" {
#endif

#include <Block.h>

typedef void (^FlutterDesktopBinaryReplyBlock)(
    const uint8_t* data,
    size_t data_size);

FLUTTER_EXPORT bool FlutterDesktopMessengerSendWithReplyBlock(
    _Nonnull FlutterDesktopMessengerRef messenger,
    const char* _Nonnull  channel,
    const uint8_t* _Nullable  message,
    const size_t message_size,
    _Nullable FlutterDesktopBinaryReplyBlock replyBlock);

typedef void (^FlutterDesktopMessageCallbackBlock)(
    FlutterDesktopMessengerRef _Nonnull,
    const FlutterDesktopMessage *_Nonnull);

FLUTTER_EXPORT void FlutterDesktopMessengerSetCallbackBlock(
    FlutterDesktopMessengerRef messenger,
    const char* _Nonnull channel,
    FlutterDesktopMessageCallbackBlock callbackBlock);

#ifdef __cplusplus
}
#endif

#endif /* CFlutterSwift_h */
