import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  // Dart tarafından gönderilen pencere başlığı kanalını canlı tutmak için saklanır.
  private var titleChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Pencere başlığını genel ayarlardaki site adıyla güncelle (Dart -> native).
    let channel = FlutterMethodChannel(
      name: "pateez/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "setTitle",
         let title = call.arguments as? String,
         !title.isEmpty {
        self?.title = title
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    self.titleChannel = channel

    super.awakeFromNib()

    self.isRestorable = false
    self.setFrameAutosaveName("")
    self.collectionBehavior.insert(.fullScreenPrimary)
    self.maximizeToVisibleFrame()

    DispatchQueue.main.async {
      self.maximizeToVisibleFrame()
    }
  }

  private func maximizeToVisibleFrame() {
    guard let screenFrame = (self.screen ?? NSScreen.main)?.visibleFrame else {
      return
    }

    self.setFrame(screenFrame, display: true, animate: false)
    self.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }
}
