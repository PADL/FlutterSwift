import Flutter.FlutterBinaryMessenger
import FlutterSwift
import UIKit

@main
@objc
class AppDelegate: FlutterAppDelegate {
  var channelManager: ChannelManager?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let flutterViewController = window!.rootViewController as! FlutterViewController
    channelManager = ChannelManager(viewController: flutterViewController)
    try! channelManager?.configureHandlers()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

extension ChannelManager {
  convenience init(viewController: FlutterViewController) {
    self
      .init(binaryMessenger: FlutterPlatformMessenger(
        wrapping: viewController.engine.binaryMessenger
      ))
  }
}
