import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.isOpaque = false
    self.backgroundColor = .clear
    self.hasShadow = false
    self.level = .floating

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
