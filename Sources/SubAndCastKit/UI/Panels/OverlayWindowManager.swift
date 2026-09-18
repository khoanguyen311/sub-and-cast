import AppKit
import SwiftUI
import Combine

@MainActor
public final class OverlayWindowManager: NSObject, NSWindowDelegate {
    public static let shared = OverlayWindowManager()

    private var sourcePanel: FloatingOverlayPanel?
    private var subtitlePanel: FloatingOverlayPanel?
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    private override init() {
        super.init()
    }

    public func setupOverlays(appState: AppState) {
        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        // 1. Source Capture Panel
        let initialSourceRect = appState.currentProfile.sourceRect.cgRect
        let sourceRect = NSRect(
            x: initialSourceRect.origin.x,
            y: screenRect.height - initialSourceRect.origin.y - initialSourceRect.height,
            width: initialSourceRect.width,
            height: initialSourceRect.height
        )

        let sPanel = FloatingOverlayPanel(contentRect: sourceRect)
        sPanel.title = "SubAndCast - Source"
        sPanel.delegate = self
        sPanel.contentView = NSHostingView(rootView: SourceCaptureOverlayView(appState: appState))
        sPanel.orderFrontRegardless()
        self.sourcePanel = sPanel

        // 2. Subtitle Output Panel
        let initialDisplayRect = appState.currentProfile.displayRect.cgRect
        let displayRect = NSRect(
            x: initialDisplayRect.origin.x,
            y: screenRect.height - initialDisplayRect.origin.y - initialDisplayRect.height,
            width: initialDisplayRect.width,
            height: initialDisplayRect.height
        )

        let subPanel = FloatingOverlayPanel(contentRect: displayRect)
        subPanel.title = "SubAndCast - Subtitles"
        subPanel.delegate = self
        subPanel.contentView = NSHostingView(rootView: SubtitleOverlayView(appState: appState))
        subPanel.orderFrontRegardless()
        self.subtitlePanel = subPanel

        // Observe lock status
        appState.$isLocked
            .receive(on: RunLoop.main)
            .sink { [weak self] locked in
                self?.sourcePanel?.setLocked(locked)
                self?.subtitlePanel?.setLocked(locked)
            }
            .store(in: &cancellables)

        // Observe profile changes to reposition panels
        appState.$currentProfile
            .receive(on: RunLoop.main)
            .sink { [weak self] profile in
                self?.updatePanelPositions(from: profile)
            }
            .store(in: &cancellables)
    }

    private func updatePanelPositions(from profile: GameProfile) {
        guard let screen = NSScreen.main else { return }
        let screenHeight = screen.frame.height

        let src = profile.sourceRect.cgRect
        let srcAppKit = NSRect(x: src.origin.x, y: screenHeight - src.origin.y - src.height, width: src.width, height: src.height)
        sourcePanel?.setFrame(srcAppKit, display: true)

        let dst = profile.displayRect.cgRect
        let dstAppKit = NSRect(x: dst.origin.x, y: screenHeight - dst.origin.y - dst.height, width: dst.width, height: dst.height)
        subtitlePanel?.setFrame(dstAppKit, display: true)
    }

    public func showSettings(appState: AppState) {
        if let existing = settingsWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 200, y: 200, width: 520, height: 600),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Sub & Cast - Preferences"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsView(appState: appState))
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.settingsWindow = window
    }

    // MARK: - NSWindowDelegate
    public func windowDidMove(_ notification: Notification) {
        handleWindowFrameChange(notification)
    }

    public func windowDidResize(_ notification: Notification) {
        handleWindowFrameChange(notification)
    }

    private func handleWindowFrameChange(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let screen = NSScreen.main else { return }

        let screenHeight = screen.frame.height
        let frame = window.frame
        // Convert AppKit (bottom-left) to ScreenCaptureKit / CoreGraphics (top-left)
        let cgRect = CGRect(
            x: frame.origin.x,
            y: screenHeight - frame.origin.y - frame.height,
            width: frame.width,
            height: frame.height
        )

        let appState = AppState.shared
        if window == sourcePanel {
            appState.updateSourceRect(cgRect)
        } else if window == subtitlePanel {
            appState.updateDisplayRect(cgRect)
        }
    }
}
