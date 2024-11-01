// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.padl.FlutterAndroid;

import io.flutter.plugin.common.BinaryMessenger;
import java.nio.ByteBuffer;

public class FlutterSwiftBinaryMessageHandler implements BinaryMessenger.BinaryMessageHandler {
  static {
    System.loadLibrary("FlutterSwift");
  }

  public long _box;

  @Override
  public native void finalize();

  public native void onMessage(/* @Nullable */ ByteBuffer message, /* @NonNull */ BinaryMessenger.BinaryReply binaryReply);
}
