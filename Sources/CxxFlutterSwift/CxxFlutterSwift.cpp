//
// Copyright (c) 2023-2024 PADL Software Pty Ltd
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

#include <stdlib.h>

#include <map>
#include <mutex>
#include <string>
#include <thread>

// FIXME: how can we include <Block/Block.h>
extern "C" {
extern void *_Block_copy(const void *aBlock);
extern void _Block_release(const void *aBlock);
};

#include "CxxFlutterSwift.h"

#include <flutter_elinux_engine.h>
#include <flutter_elinux_view.h>

// +1 on block because it goes out of scope and is only called once

static void FlutterDesktopMessengerBinaryReplyThunk(const uint8_t *data,
                                                    size_t data_size,
                                                    void *user_data) {
  auto replyBlock = (FlutterDesktopBinaryReplyBlock)user_data;
  replyBlock(data, data_size);
}

static void FlutterDesktopMessengerBinaryCleanupThunk(void *captures_data) {
  auto replyBlock = (FlutterDesktopBinaryReplyBlock)captures_data;
  _Block_release(replyBlock);
}

bool FlutterDesktopMessengerSendWithReplyBlock(
    FlutterDesktopMessengerRef messenger,
    const char *channel,
    const uint8_t *message,
    const size_t message_size,
    FlutterDesktopBinaryReplyBlock replyBlock) {
  return FlutterDesktopMessengerSendWithReply(
      messenger, channel, message, message_size,
      replyBlock ? FlutterDesktopMessengerBinaryReplyThunk : nullptr,
      replyBlock ? _Block_copy(replyBlock) : nullptr,
      replyBlock ? FlutterDesktopMessengerBinaryCleanupThunk : nullptr);
}

static std::map<std::string, const void *> flutterSwiftCallbacks{};
static std::mutex flutterSwiftCallbacksMutex;

static void
FlutterDesktopMessageCallbackThunk(FlutterDesktopMessengerRef messenger,
                                   const FlutterDesktopMessage *message,
                                   void *user_data) {
  auto callbackBlock = (FlutterDesktopMessageCallbackBlock)user_data;
  callbackBlock(messenger, message);
}

void FlutterDesktopMessengerSetCallbackBlock(
    FlutterDesktopMessengerRef messenger,
    const char *_Nonnull channel,
    FlutterDesktopMessageCallbackBlock callbackBlock) {
  std::lock_guard<std::mutex> guard(flutterSwiftCallbacksMutex);
  if (callbackBlock != nullptr) {
    flutterSwiftCallbacks[channel] = _Block_copy(callbackBlock);
    messenger->GetEngine()->message_dispatcher()->SetMessageCallback(
        channel, FlutterDesktopMessageCallbackThunk, callbackBlock);
  } else {
    auto savedCallbackBlock = flutterSwiftCallbacks[channel];
    flutterSwiftCallbacks.erase(channel);
    _Block_release(savedCallbackBlock);
    messenger->GetEngine()->message_dispatcher()->SetMessageCallback(
        channel, nullptr, nullptr);
  }
}

static std::map<FlutterDesktopPluginRegistrarRef, const void *>
    flutterSwiftRegistrarCallbacks{};
static std::mutex flutterSwiftRegistrarCallbacksMutex;

static void FlutterDesktopOnPluginRegistrarDestroyedBlockThunk(
    FlutterDesktopPluginRegistrarRef registrar) {
  std::lock_guard<std::mutex> guard(flutterSwiftRegistrarCallbacksMutex);
  auto callbackBlock = (FlutterDesktopOnPluginRegistrarDestroyedBlock)
      flutterSwiftRegistrarCallbacks[registrar];
  flutterSwiftRegistrarCallbacks.erase(registrar);
  callbackBlock(registrar);
  _Block_release(callbackBlock);
}

void FlutterDesktopPluginRegistrarSetDestructionHandlerBlock(
    FlutterDesktopPluginRegistrarRef registrar,
    FlutterDesktopOnPluginRegistrarDestroyedBlock callbackBlock) {
  std::lock_guard<std::mutex> guard(flutterSwiftRegistrarCallbacksMutex);
  flutterSwiftRegistrarCallbacks[registrar] = _Block_copy(callbackBlock);
  registrar->engine->SetPluginRegistrarDestructionCallback(
      FlutterDesktopOnPluginRegistrarDestroyedBlockThunk);
}

void FlutterDesktopEngineSetView(FlutterDesktopEngineRef engineRef,
                                 FlutterDesktopViewRef viewRef) {
  auto engine = reinterpret_cast<flutter::FlutterELinuxEngine *>(engineRef);
  engine->SetView(reinterpret_cast<flutter::FlutterELinuxView *>(viewRef));
}
