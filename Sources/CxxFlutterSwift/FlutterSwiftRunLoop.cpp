//
// Copyright (c) 2025 PADL Software Pty Ltd
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

#include "CxxFlutterSwift.h"

#include <chrono>
#include <cmath>

#include <flutter_elinux_engine.h>
#include <flutter_elinux_view.h>

extern "C" {
void _dispatch_main_queue_callback_4CF(void *);
}

void _FlutterSwiftRunLoopRun(FlutterDesktopEngineRef engineRef,
                             FlutterDesktopViewRef viewRef) {
  auto nextFlutterEventTime =
      std::chrono::steady_clock::time_point::clock::now();

  while (FlutterDesktopViewDispatchEvent(viewRef)) {
    auto waitDurationMS =
        std::max(std::chrono::nanoseconds(0),
                 nextFlutterEventTime -
                     std::chrono::steady_clock::time_point::clock::now());

    std::this_thread::sleep_for(
        std::chrono::duration_cast<std::chrono::milliseconds>(waitDurationMS));

    auto waitDurationNS = std::chrono::nanoseconds(
        FlutterDesktopEngineProcessMessages(engineRef));
    auto nextEventTime = std::chrono::steady_clock::time_point::max();

    if (waitDurationNS != std::chrono::nanoseconds::max()) {
      nextEventTime = std::min(
          nextEventTime,
          std::chrono::steady_clock::time_point::clock::now() + waitDurationNS);
    } else {
      auto frameRate = FlutterDesktopViewGetFrameRate(viewRef);
      nextEventTime = std::min(
          nextEventTime, std::chrono::steady_clock::time_point::clock::now() +
                             std::chrono::milliseconds(static_cast<int>(
                                 std::trunc(1000000.0 / frameRate))));
    }

    nextFlutterEventTime = std::max(nextFlutterEventTime, nextEventTime);
    _dispatch_main_queue_callback_4CF(nullptr);
  }
}
