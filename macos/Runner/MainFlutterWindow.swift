import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
    private let keyboardHandler = KeyboardStreamHandler()

    override func awakeFromNib() {
        let flutterViewController = FlutterViewController()
        let windowFrame = self.frame
        self.contentViewController = flutterViewController
        self.setFrame(windowFrame, display: true)

        RegisterGeneratedPlugins(registry: flutterViewController)

        let eventChannel = FlutterEventChannel(
            name: "com.kysy/keyboard_events",
            binaryMessenger: flutterViewController.engine.binaryMessenger
        )
        eventChannel.setStreamHandler(keyboardHandler)

        super.awakeFromNib()
    }
}
