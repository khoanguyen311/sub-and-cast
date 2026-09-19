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
    private var wasPositioning = false
    private var localKeyMonitor: Any?
    private var globalKeyMonitor: Any?

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
            height: initialSourceRect.height + OverlayLayoutConstants.headerOffset
        )

        let sPanel = FloatingOverlayPanel(contentRect: sourceRect)
        sPanel.title = "SubAndCast - Source"
        sPanel.delegate = self
        sPanel.contentView = NSHostingView(rootView: SourceCaptureOverlayView(appState: appState))
        // Start ordered out (hidden on launch)
        sPanel.orderOut(nil as Any?)
        self.sourcePanel = sPanel

        // 2. Subtitle Output Panel
        let initialDisplayRect = appState.currentProfile.displayRect.cgRect
        let initialSubHeight = appState.isPositioningOverlays
            ? initialDisplayRect.height + OverlayLayoutConstants.headerOffset
            : initialDisplayRect.height
        let displayRect = NSRect(
            x: initialDisplayRect.origin.x,
            y: screenRect.height - initialDisplayRect.origin.y - initialDisplayRect.height,
            width: initialDisplayRect.width,
            height: initialSubHeight
        )

        let subPanel = FloatingOverlayPanel(contentRect: displayRect)
        subPanel.title = "SubAndCast - Subtitles"
        subPanel.delegate = self
        subPanel.contentView = NSHostingView(rootView: SubtitleOverlayView(appState: appState))
        // Start ordered out (hidden on launch)
        subPanel.orderOut(nil as Any?)
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
        Publishers.CombineLatest4(appState.$isOverlaysVisible, appState.$isPositioningOverlays, appState.$isScanning, appState.$isOneTimeSubtitleVisible)
            .receive(on: RunLoop.main)
            .sink { [weak self] isVisible, isPositioning, isScanning, isOneTimeVisible in
                guard let self = self else { return }
                self.updatePanelPositions(from: appState.currentProfile, isPositioning: isPositioning)
                if isPositioning {
                    self.wasPositioning = true
                    self.settingsWindow?.orderOut(nil)
                    self.sourcePanel?.orderFrontRegardless()
                    self.sourcePanel?.makeKey()
                    self.subtitlePanel?.orderFrontRegardless()
                    self.startPositioningKeyMonitoring(appState: appState)
                } else {
                    let shouldRestoreSettings = self.wasPositioning
                    self.wasPositioning = false
                    self.stopPositioningKeyMonitoring()

                    if isScanning || isOneTimeVisible {
                        // During active scanning or one-time scan display, source box is hidden from screen
                        // so it doesn't obstruct the game, while subtitle box is visible
                        self.sourcePanel?.orderOut(nil as Any?)
                        self.subtitlePanel?.orderFrontRegardless()
                    } else {
                        self.sourcePanel?.orderOut(nil as Any?)
                        self.subtitlePanel?.orderOut(nil as Any?)
                    }

                    if shouldRestoreSettings {
                        self.showSettings(appState: appState)
                    }
                }
            }
            .store(in: &cancellables)

        // Pre-warm settings window so first open is instant — build but do NOT show yet
        preWarmSettings(appState: appState)
    }

    // MARK: - Positioning Keyboard Shortcuts (Escape / Enter)
    private func startPositioningKeyMonitoring(appState: AppState) {
        stopPositioningKeyMonitoring()

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak appState] event in
            guard let appState = appState, appState.isPositioningOverlays else { return event }
            if event.keyCode == 53 { // Escape
                appState.cancelPositioningOverlays()
                return nil
            } else if event.keyCode == 36 || event.keyCode == 76 { // Return / Enter
                appState.finishPositioningOverlays()
                return nil
            }
            return event
        }

        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak appState] event in
            guard let appState = appState, appState.isPositioningOverlays else { return }
            if event.keyCode == 53 { // Escape
                DispatchQueue.main.async {
                    appState.cancelPositioningOverlays()
                }
            } else if event.keyCode == 36 || event.keyCode == 76 { // Return / Enter
                DispatchQueue.main.async {
                    appState.finishPositioningOverlays()
                }
            }
        }
    }

    private func stopPositioningKeyMonitoring() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyMonitor = nil
        }
    }

    // Builds the settings NSWindow and pre-renders its SwiftUI content graph
    // without showing it, so the first call to showSettings() is lag-free.
    private func preWarmSettings(appState: AppState) {
        let window = NSWindow(
            contentRect: NSRect(x: 200, y: 200, width: 540, height: 650),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Preferences"
        window.minSize = NSSize(width: 480, height: 460)
        window.maxSize = NSSize(width: 760, height: 900)
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("MainPreferencesWindow")

        if !window.setFrameUsingName("MainPreferencesWindow") {
            window.center()
        } else if let screen = NSScreen.main {
            // Validate saved frame does not violate screen bounds if opened on a different monitor
            var frame = window.frame
            let visible = screen.visibleFrame
            frame.size.width = max(window.minSize.width, min(frame.size.width, min(window.maxSize.width, visible.width)))
            frame.size.height = max(window.minSize.height, min(frame.size.height, min(window.maxSize.height, visible.height)))
            frame.origin.x = max(visible.minX, min(frame.origin.x, visible.maxX - frame.size.width))
            frame.origin.y = max(visible.minY, min(frame.origin.y, visible.maxY - frame.size.height))
            window.setFrame(frame, display: false)
        }

        window.contentView = NSHostingView(rootView: SettingsView(appState: appState))
        self.settingsWindow = window
    }

    /// Shows the Preferences window. Opens on launch and menu bar "Preferences…".
    public func showSettings(appState: AppState) {
        if settingsWindow == nil {
            preWarmSettings(appState: appState)
        }
        if appState.isPositioningOverlays {
            settingsWindow?.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
            settingsWindow?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        } else {
            settingsWindow?.level = .normal
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Toggles the Preferences window visibility.
    public func toggleSettings(appState: AppState) {
        if settingsWindow == nil {
            preWarmSettings(appState: appState)
        }
        guard let window = settingsWindow else { return }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            if appState.isPositioningOverlays {
                window.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            } else {
                window.level = .normal
            }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private var isProgrammaticUpdate = false
    private var isUserDraggingOrResizing = false

    public func updatePanelPositions(from profile: GameProfile, isPositioning: Bool? = nil) {
        guard !isUserDraggingOrResizing else { return }
        guard let screen = NSScreen.main else { return }
        let screenHeight = screen.frame.height

        let positioning = isPositioning ?? AppState.shared.isPositioningOverlays
        let offset = positioning ? OverlayLayoutConstants.headerOffset : 0

        isProgrammaticUpdate = true
        defer { isProgrammaticUpdate = false }

        // 1. Source capture panel always has headerOffset when active
        let src = profile.sourceRect.cgRect
        let srcAppKit = NSRect(
            x: src.origin.x,
            y: screenHeight - src.origin.y - src.height,
            width: src.width,
            height: src.height + OverlayLayoutConstants.headerOffset
        )
        if let sPanel = sourcePanel, sPanel.frame != srcAppKit {
            sPanel.setFrame(srcAppKit, display: true)
        }

        // 2. Subtitle panel has headerOffset only during positioning mode
        let dst = profile.displayRect.cgRect
        let dstAppKit = NSRect(
            x: dst.origin.x,
            y: screenHeight - dst.origin.y - dst.height,
            width: dst.width,
            height: dst.height + offset
        )
        if let subPanel = subtitlePanel, subPanel.frame != dstAppKit {
            subPanel.setFrame(dstAppKit, display: true)
        }
    }

    // MARK: - NSWindowDelegate
    public func windowWillStartLiveResize(_ notification: Notification) {
        isUserDraggingOrResizing = true
    }

    public func windowDidEndLiveResize(_ notification: Notification) {
        isUserDraggingOrResizing = false
        AppState.shared.saveCurrentProfile()
    }

    public func windowDidMove(_ notification: Notification) {
        handleWindowFrameChange(notification)
    }

    public func windowDidResize(_ notification: Notification) {
        handleWindowFrameChange(notification)
    }

    private func handleWindowFrameChange(_ notification: Notification) {
        guard !isProgrammaticUpdate else { return }
        guard let window = notification.object as? NSWindow,
              let screen = NSScreen.main else { return }

        let appState = AppState.shared
        // Guard against coordinate corruption when positioning mode is inactive
        guard appState.isPositioningOverlays else { return }
        guard window.isVisible && window.frame.width > 0 && window.frame.height > 0 else { return }

        let screenHeight = screen.frame.height
        let frame = window.frame
        let offset = OverlayLayoutConstants.headerOffset

        if window == sourcePanel {
            let boxHeight = max(CodableRect.minHeight, frame.height - offset)
            let boxWidth = max(CodableRect.minWidth, frame.width)
            let cgRect = CGRect(
                x: max(0, frame.origin.x),
                y: max(0, screenHeight - frame.origin.y - boxHeight),
                width: boxWidth,
                height: boxHeight
            )
            appState.updateSourceRectLive(cgRect)
        } else if window == subtitlePanel {
            let boxHeight = max(CodableRect.minHeight, frame.height - offset)
            let boxWidth = max(CodableRect.minWidth, frame.width)
            let cgRect = CGRect(
                x: max(0, frame.origin.x),
                y: max(0, screenHeight - frame.origin.y - boxHeight),
                width: boxWidth,
                height: boxHeight
            )
            appState.updateDisplayRectLive(cgRect)
        }
    }
}
