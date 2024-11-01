// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.padl.FlutterAndroid;

import io.flutter.plugin.common.BinaryMessenger;
import java.nio.ByteBuffer;

public class FlutterSwiftBinaryReply implements BinaryMessenger.BinaryReply {
  public long _block;

//  @Override
//  public native void finalize();

  public native void reply(/* @Nullable */ ByteBuffer replyBuffer);
}
