package com.padl.AndroidFlutter;

import io.flutter.plugin.common.BinaryMessenger;
import java.nio.ByteBuffer;

public class FlutterSwiftBinaryMessageHandler implements BinaryMessenger.BinaryMessageHandler {
  static {
    System.loadLibrary("FlutterSwift");
  }

  public native void onMessage(/* @Nullable */ ByteBuffer message, /* @NonNull */ BinaryMessenger.BinaryReply binaryReply);
}
