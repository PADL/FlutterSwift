package com.padl.AndroidFlutter;

import io.flutter.plugin.common.BinaryMessenger;
import java.nio.ByteBuffer;

public class FlutterSwiftBinaryReply implements BinaryMessenger.BinaryReply {
  public native void reply(/* @Nullable */ ByteBuffer replyBuffer);
}
