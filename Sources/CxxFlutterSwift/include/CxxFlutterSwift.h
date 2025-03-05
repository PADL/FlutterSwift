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

#ifndef CxxFlutterSwift_h
#define CxxFlutterSwift_h

#include <stdbool.h>

#include <flutter_messenger.h>
#include <flutter_elinux.h>
#include <flutter_elinux_engine.h>
#include <flutter_elinux_state.h>
#include <flutter_elinux_view.h>
#include <flutter_plugin_registrar.h>
#include <flutter_platform_views.h>

#ifdef __cplusplus
#include <vector>
#include <string>

using CxxVectorOfString = std::vector<std::string, std::allocator<std::string>>;

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
