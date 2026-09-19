import AppKit
import SwiftUI
import SubAndCastKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Show in both Dock and menu bar so the app is easily discoverable
        NSApp.setActivationPolicy(.regular)

        let state = AppState.shared
        self.menuBarController = MenuBarController(appState: state)
        OverlayWindowManager.shared.setupOverlays(appState: state)
        _ = GlobalHotkeyManager.shared

        // Open Preferences immediately on first launch
        OverlayWindowManager.shared.showSettings(appState: state)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running when user closes Preferences; overlays stay active
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
