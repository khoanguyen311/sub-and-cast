import AppKit
import SwiftUI
import Combine

@MainActor
public final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private let appState: AppState
    private var cancellables = Set<AnyCancellable>()

    public init(appState: AppState) {
        self.appState = appState
        super.init()
        setupStatusItem()
        setupObservers()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            let image = NSImage(systemSymbolName: "captions.bubble", accessibilityDescription: "Sub & Cast")?
                .withSymbolConfiguration(config)
            button.image = image
        }
        self.statusItem = item
        rebuildMenu()
    }

    private func setupObservers() {
        appState.$isScanning
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)

        appState.$isLocked
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)

        appState.$statusMessage
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)

        appState.$currentProfile
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)
    }

    public func rebuildMenu() {
        let menu = NSMenu()

        // Status Header
        let statusItem = NSMenuItem(title: "Sub & Cast: \(appState.statusMessage)", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        let profileItem = NSMenuItem(
            title: "Profile: \(appState.currentProfile.name) (\(appState.currentProfile.sourceLanguage.uppercased()) → \(appState.currentProfile.targetLanguage.uppercased()))",
            action: nil,
            keyEquivalent: ""
        )
        profileItem.isEnabled = false
        menu.addItem(profileItem)

        menu.addItem(NSMenuItem.separator())

        // Auto Scan Toggle
        let scanTitle = appState.isScanning ? "Pause Auto-Scan" : "Start Auto-Scan"
        let scanItem = NSMenuItem(title: scanTitle, action: #selector(toggleScan), keyEquivalent: "")
        scanItem.target = self
        menu.addItem(scanItem)

        // Snapshot Trigger
        let snapItem = NSMenuItem(title: "Capture Snapshot Now", action: #selector(captureSnapshot), keyEquivalent: "")
        snapItem.target = self
        menu.addItem(snapItem)

        menu.addItem(NSMenuItem.separator())

        // Positioning Toggle
        let lockTitle = appState.isPositioningOverlays ? "Save & Lock Overlays" : "Position Overlays (Adjust Zones)"
        let lockItem = NSMenuItem(title: lockTitle, action: #selector(toggleLock), keyEquivalent: "")
        lockItem.target = self
        menu.addItem(lockItem)

        // Settings
        let settingsItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit Sub & Cast", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.statusItem?.menu = menu
    }

    @objc private func toggleScan() {
        appState.toggleScanning()
    }

    @objc private func captureSnapshot() {
        appState.triggerSnapshot()
    }

    @objc private func toggleLock() {
        appState.toggleLock()
    }

    @objc private func openPreferences() {
        OverlayWindowManager.shared.showSettings(appState: appState)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
