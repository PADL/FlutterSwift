// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef CxxFlutterSwift_h
#define CxxFlutterSwift_h

#include <stdbool.h>

#include <flutter_messenger.h>
#include <flutter_elinux.h>
#include <flutter_plugin_registrar.h>
#include <flutter_elinux_state.h>
#include <flutter_platform_views.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef __attribute__((__swift_attr__("@Sendable"))) void (
    ^FlutterDesktopBinaryReplyBlock)(const uint8_t *_Nullable data,
                                     size_t data_size);

FLUTTER_EXPORT bool FlutterDesktopMessengerSendWithReplyBlock(
    _Nonnull FlutterDesktopMessengerRef messenger,
    const char *_Nonnull channel,
    const uint8_t *_Nullable message,
    const size_t message_size,
    _Nullable FlutterDesktopBinaryReplyBlock replyBlock);

typedef __attribute__((__swift_attr__("@Sendable"))) void (
    ^FlutterDesktopMessageCallbackBlock)(_Nonnull FlutterDesktopMessengerRef,
                                         const FlutterDesktopMessage *_Nonnull);

FLUTTER_EXPORT void FlutterDesktopMessengerSetCallbackBlock(
    _Nonnull FlutterDesktopMessengerRef messenger,
    const char *_Nonnull channel,
    _Nullable FlutterDesktopMessageCallbackBlock callbackBlock);

typedef __attribute__((__swift_attr__("@Sendable"))) void (
    ^FlutterDesktopMessageCallbackBlock)(_Nonnull FlutterDesktopMessengerRef,
                                         const FlutterDesktopMessage *_Nonnull);

typedef __attribute__((__swift_attr__("@Sendable"))) void (
    ^FlutterDesktopOnPluginRegistrarDestroyedBlock)(
    _Nonnull FlutterDesktopPluginRegistrarRef);

FLUTTER_EXPORT void FlutterDesktopPluginRegistrarSetDestructionHandlerBlock(
    _Nonnull FlutterDesktopPluginRegistrarRef registrar,
    _Nonnull FlutterDesktopOnPluginRegistrarDestroyedBlock callbackBlock);

FLUTTER_EXPORT void
FlutterDesktopEngineSetView(_Nonnull FlutterDesktopEngineRef engineRef,
                            _Nonnull FlutterDesktopViewRef viewRef);

#ifdef __cplusplus
}
#endif

#endif /* CxxFlutterSwift_h */
