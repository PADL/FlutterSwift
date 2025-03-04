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
    Task { @MainActor in
      do {
        channelManager = try await ChannelManager(viewController: flutterViewController)
      } catch {
        exit(1)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

extension ChannelManager {
  convenience init(viewController: FlutterViewController) async throws {
    await self
      .init(binaryMessenger: FlutterPlatformMessenger(
        wrapping: viewController.engine!.binaryMessenger
      ))
  }
}
