// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef CxxFlutterSwift_h
#define CxxFlutterSwift_h

#ifndef __APPLE__

#include <stdbool.h>

#include <flutter_messenger.h>
#include <flutter_elinux.h>
#include <flutter_plugin_registrar.h>

// FIXME: when C++17 support is working, import this to get native ++ reference counting
// #include <flutter_elinux_state.h>
// #include <flutter_platform_views.h>

// FIXME: why is there no header for this? (note it has C++ linkage because no C header)
FLUTTER_EXPORT FlutterDesktopViewRef _Nonnull
FlutterDesktopPluginRegistrarGetView(_Nonnull FlutterDesktopPluginRegistrarRef registrar);

#ifdef __cplusplus
extern "C" {
#endif

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

typedef void (^FlutterDesktopMessageCallbackBlock)(
    _Nonnull FlutterDesktopMessengerRef,
    const FlutterDesktopMessage *_Nonnull);

typedef void (^FlutterDesktopOnPluginRegistrarDestroyedBlock)(
    _Nonnull FlutterDesktopPluginRegistrarRef);

FLUTTER_EXPORT void FlutterDesktopPluginRegistrarSetDestructionHandlerBlock(
    _Nonnull FlutterDesktopPluginRegistrarRef registrar,
    _Nonnull FlutterDesktopOnPluginRegistrarDestroyedBlock callbackBlock);

FLUTTER_EXPORT void FlutterDesktopEngineSetView(
    _Nonnull FlutterDesktopEngineRef engineRef,
    _Nonnull FlutterDesktopViewRef viewRef);
 
#ifdef __cplusplus
}
#endif

#endif /* !__APPLE__ */

#endif /* CxxFlutterSwift_h */
