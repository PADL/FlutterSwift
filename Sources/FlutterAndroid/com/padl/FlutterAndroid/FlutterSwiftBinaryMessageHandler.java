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

package com.padl.FlutterAndroid;

import io.flutter.plugin.common.BinaryMessenger;
import java.nio.ByteBuffer;

public final class FlutterSwiftBinaryMessageHandler extends SwiftHeapObjectHolder implements BinaryMessenger.BinaryMessageHandler {
  public FlutterSwiftBinaryMessageHandler(long swiftObject) {
    super(swiftObject);
  }

  public native void onMessage(/* @Nullable */ ByteBuffer message, /* @NonNull */ BinaryMessenger.BinaryReply binaryReply);
}
