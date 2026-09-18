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
        // Start ordered out (hidden on launch)
        sPanel.orderOut(nil)
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
        // Start ordered out (hidden on launch)
        subPanel.orderOut(nil)
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

        // Observe overlay visibility and positioning states
        Publishers.CombineLatest3(appState.$isOverlaysVisible, appState.$isPositioningOverlays, appState.$isScanning)
            .receive(on: RunLoop.main)
            .sink { [weak self] isVisible, isPositioning, isScanning in
                guard let self = self else { return }
                if isPositioning {
                    self.sourcePanel?.orderFrontRegardless()
                    self.subtitlePanel?.orderFrontRegardless()
                } else if isVisible || isScanning {
                    // During active scanning / dialogue display, source box is hidden from screen
                    // so it doesn't obstruct the game, while subtitle box is visible
                    self.sourcePanel?.orderOut(nil)
                    self.subtitlePanel?.orderFrontRegardless()
                } else {
                    self.sourcePanel?.orderOut(nil)
                    self.subtitlePanel?.orderOut(nil)
                }
            }
            .store(in: &cancellables)

        // Pre-warm settings window so first open is instant — build but do NOT show yet
        preWarmSettings(appState: appState)
    }

    // Builds the settings NSWindow and pre-renders its SwiftUI content graph
    // without showing it, so the first call to showSettings() is lag-free.
    private func preWarmSettings(appState: AppState) {
        let window = NSWindow(
            contentRect: NSRect(x: 200, y: 200, width: 520, height: 440),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Sub & Cast — Preferences"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsView(appState: appState))
        self.settingsWindow = window
    }

    /// Shows the Preferences window. Opens on launch and menu bar "Preferences…".
    public func showSettings(appState: AppState) {
        if settingsWindow == nil {
            preWarmSettings(appState: appState)
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
        // Convert AppKit (bottom-left origin) to CoreGraphics/ScreenCaptureKit (top-left origin)
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
