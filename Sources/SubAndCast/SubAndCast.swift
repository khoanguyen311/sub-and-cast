import AppKit
import SwiftUI
import SubAndCastKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as accessory app (menu bar only, no dock icon)
        NSApp.setActivationPolicy(.accessory)

        let state = AppState.shared
        self.menuBarController = MenuBarController(appState: state)
        OverlayWindowManager.shared.setupOverlays(appState: state)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

@main
enum SubAndCastMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
