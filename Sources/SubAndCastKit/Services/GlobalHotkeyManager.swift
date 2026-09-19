import Foundation
import AppKit
import Carbon

public enum HotkeyAction: UInt32, CaseIterable, Sendable {
    case toggleScan = 1
    case togglePositioning = 2

    public var displayName: String {
        switch self {
        case .toggleScan: return "Toggle Auto Scan"
        case .togglePositioning: return "Calibrate Overlays (Position)"
        }
    }

    var userDefaultsKey: String {
        switch self {
        case .toggleScan: return "hotkey_toggleScan"
        case .togglePositioning: return "hotkey_togglePositioning"
        }
    }
}

@MainActor
public final class GlobalHotkeyManager: ObservableObject {
    public static let shared = GlobalHotkeyManager()

    @Published public var toggleScanHotkey: AppHotkey? {
        didSet {
            saveHotkey(toggleScanHotkey, for: .toggleScan)
            updateRegistration(for: .toggleScan)
        }
    }

    @Published public var togglePositioningHotkey: AppHotkey? {
        didSet {
            saveHotkey(togglePositioningHotkey, for: .togglePositioning)
            updateRegistration(for: .togglePositioning)
        }
    }

    private var hotKeyRefs: [HotkeyAction: EventHotKeyRef] = [:]
    private static var isHandlerInstalled = false
    private let hotKeySignature = OSType(0x53414E43) // 'SANC'

    private init() {
        self.toggleScanHotkey = loadHotkey(for: .toggleScan)
        self.togglePositioningHotkey = loadHotkey(for: .togglePositioning)

        installCarbonHandler()
        updateRegistration(for: .toggleScan)
        updateRegistration(for: .togglePositioning)
    }

    /// Sets hotkey for a specified action with automatic duplicate clearing
    public func setHotkey(_ hotkey: AppHotkey?, for action: HotkeyAction) {
        if let hotkey = hotkey {
            switch action {
            case .toggleScan:
                if togglePositioningHotkey == hotkey {
                    togglePositioningHotkey = nil
                }
                toggleScanHotkey = hotkey
            case .togglePositioning:
                if toggleScanHotkey == hotkey {
                    toggleScanHotkey = nil
                }
                togglePositioningHotkey = hotkey
            }
        } else {
            switch action {
            case .toggleScan:
                toggleScanHotkey = nil
            case .togglePositioning:
                togglePositioningHotkey = nil
            }
        }
    }

    public func hotkeyForAction(_ action: HotkeyAction) -> AppHotkey? {
        switch action {
        case .toggleScan: return toggleScanHotkey
        case .togglePositioning: return togglePositioningHotkey
        }
    }

    // MARK: - Carbon Registration
    private func updateRegistration(for action: HotkeyAction) {
        // Unregister existing handler
        if let existingRef = hotKeyRefs[action] {
            UnregisterEventHotKey(existingRef)
            hotKeyRefs.removeValue(forKey: action)
        }

        // Register if a valid hotkey is assigned
        guard let hotkey = hotkeyForAction(action) else { return }

        let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: action.rawValue)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        if status == noErr, let ref = ref {
            hotKeyRefs[action] = ref
        }
    }

    private func installCarbonHandler() {
        guard !Self.isHandlerInstalled else { return }
        Self.isHandlerInstalled = true

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, theEvent, _) -> OSStatus in
                guard let event = theEvent else { return noErr }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return status }

                if let action = HotkeyAction(rawValue: hotKeyID.id) {
                    DispatchQueue.main.async {
                        GlobalHotkeyManager.shared.handleHotkeyTrigger(action)
                    }
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            nil
        )
    }

    private func handleHotkeyTrigger(_ action: HotkeyAction) {
        switch action {
        case .toggleScan:
            AppState.shared.toggleScanning()
        case .togglePositioning:
            AppState.shared.toggleLock()
        }
    }

    // MARK: - Persistence
    private func saveHotkey(_ hotkey: AppHotkey?, for action: HotkeyAction) {
        if let hotkey = hotkey, let data = try? JSONEncoder().encode(hotkey) {
            UserDefaults.standard.set(data, forKey: action.userDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: action.userDefaultsKey)
        }
    }

    private func loadHotkey(for action: HotkeyAction) -> AppHotkey? {
        guard let data = UserDefaults.standard.data(forKey: action.userDefaultsKey) else {
            return nil
        }
        return try? JSONDecoder().decode(AppHotkey.self, from: data)
    }
}
