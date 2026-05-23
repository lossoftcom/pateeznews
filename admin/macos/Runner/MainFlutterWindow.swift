import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

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
