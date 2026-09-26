import Foundation
import Combine

/// Legacy façade preserving backward compatibility for GlobalHotkeyManager while delegating to ShortcutRegistry.
@MainActor
public final class GlobalHotkeyManager: ObservableObject {
    public static let shared = GlobalHotkeyManager()

    private let registry: ShortcutRegistry
    private var cancellables = Set<AnyCancellable>()

    @Published public var toggleScanHotkey: AppHotkey? {
        didSet {
            if registry.toggleScanHotkey != toggleScanHotkey {
                registry.toggleScanHotkey = toggleScanHotkey
            }
        }
    }

    @Published public var togglePositioningHotkey: AppHotkey? {
        didSet {
            if registry.togglePositioningHotkey != togglePositioningHotkey {
                registry.togglePositioningHotkey = togglePositioningHotkey
            }
        }
    }

    @Published public var oneTimeScanHotkey: AppHotkey? {
        didSet {
            if registry.oneTimeScanHotkey != oneTimeScanHotkey {
                registry.oneTimeScanHotkey = oneTimeScanHotkey
            }
        }
    }

    public init(registry: ShortcutRegistry? = nil) {
        let reg = registry ?? ShortcutRegistry.shared
        self.registry = reg
        self.toggleScanHotkey = reg.toggleScanHotkey
        self.togglePositioningHotkey = reg.togglePositioningHotkey
        self.oneTimeScanHotkey = reg.oneTimeScanHotkey

        reg.$toggleScanHotkey.sink { [weak self] val in
            if self?.toggleScanHotkey != val {
                self?.toggleScanHotkey = val
            }
        }.store(in: &cancellables)

        reg.$togglePositioningHotkey.sink { [weak self] val in
            if self?.togglePositioningHotkey != val {
                self?.togglePositioningHotkey = val
            }
        }.store(in: &cancellables)

        reg.$oneTimeScanHotkey.sink { [weak self] val in
            if self?.oneTimeScanHotkey != val {
                self?.oneTimeScanHotkey = val
            }
        }.store(in: &cancellables)
    }

    /// Sets hotkey for a specified action with automatic duplicate clearing
    public func setHotkey(_ hotkey: AppHotkey?, for action: HotkeyAction) {
        registry.setHotkey(hotkey, for: action)
        self.toggleScanHotkey = registry.toggleScanHotkey
        self.togglePositioningHotkey = registry.togglePositioningHotkey
        self.oneTimeScanHotkey = registry.oneTimeScanHotkey
    }

    public func hotkeyForAction(_ action: HotkeyAction) -> AppHotkey? {
        registry.hotkeyForAction(action)
    }

    public func handleHotkeyTrigger(_ action: HotkeyAction) {
        switch action {
        case .toggleScan:
            AppState.shared.toggleScanning()
        case .togglePositioning:
            AppState.shared.toggleLock()
        case .oneTimeScan:
            AppState.shared.triggerOneTimeScan()
        }
    }
}
