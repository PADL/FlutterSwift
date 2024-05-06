import Cocoa
import FlutterMacOS.FlutterBinaryMessenger
import FlutterSwift

class MainFlutterWindow: NSWindow {
  var runner: ChannelManager!

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = frame
    contentViewController = flutterViewController
    setFrame(windowFrame, display: true)

    Task { @MainActor in
      do {
        runner = try await ChannelManager(viewController: flutterViewController)
      } catch {
        NSApp.terminate(self)
      }
    }

    RegisterGeneratedPlugins(registry: flutterViewController)
    super.awakeFromNib()
  }
}

extension ChannelManager {
  convenience init(viewController: FlutterViewController) async throws {
    try await self
      .init(binaryMessenger: FlutterPlatformMessenger(
        wrapping: viewController.engine
          .binaryMessenger
      ))
  }
}
