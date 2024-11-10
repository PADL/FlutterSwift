package com.example.counter

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.example.counter.ChannelManager

class MainActivity: FlutterActivity() {
  var channelManager: ChannelManager? = null

  override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    channelManager = ChannelManager(flutterEngine.dartExecutor.binaryMessenger)
    channelManager!!.initChannelManager()
    println("initialized channel manager $channelManager")
  }
}
