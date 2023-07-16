// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef CFlutterSwift_h
#define CFlutterSwift_h

#include <stdbool.h>

#include <flutter_messenger.h>

#ifdef __cplusplus
extern "C" {
#endif

// flutter_elinux.h can't be imported into C code because it uses ref params
struct FlutterDesktopEngine;
typedef struct FlutterDesktopEngine* FlutterDesktopEngineRef;

// Returns the messenger associated with the engine.
FLUTTER_EXPORT FlutterDesktopMessengerRef _Nonnull
FlutterDesktopEngineGetMessenger(_Nonnull FlutterDesktopEngineRef engine);

typedef void (^FlutterDesktopBinaryReplyBlock)(
    const uint8_t* _Nullable data,
    size_t data_size);

FLUTTER_EXPORT bool FlutterDesktopMessengerSendWithReplyBlock(
    _Nonnull FlutterDesktopMessengerRef messenger,
    const char* _Nonnull  channel,
    const uint8_t* _Nullable  message,
    const size_t message_size,
    _Nullable FlutterDesktopBinaryReplyBlock replyBlock);

typedef void (^FlutterDesktopMessageCallbackBlock)(
    _Nonnull FlutterDesktopMessengerRef,
    const FlutterDesktopMessage *_Nonnull);

FLUTTER_EXPORT void FlutterDesktopMessengerSetCallbackBlock(
    _Nonnull FlutterDesktopMessengerRef messenger,
    const char* _Nonnull channel,
    _Nullable FlutterDesktopMessageCallbackBlock callbackBlock);

#ifdef __cplusplus
}
#endif

#endif /* CFlutterSwift_h */
