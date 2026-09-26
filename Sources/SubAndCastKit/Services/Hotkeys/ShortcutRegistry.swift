import Foundation
import Combine

/// Protocol defining the deep shortcut registry interface.
@MainActor
public protocol ShortcutRegistryProtocol: AnyObject {
    var toggleScanHotkey: AppHotkey? { get set }
    var togglePositioningHotkey: AppHotkey? { get set }
    var oneTimeScanHotkey: AppHotkey? { get set }
    var actionStream: AsyncStream<HotkeyAction> { get }

    func setHotkey(_ hotkey: AppHotkey?, for action: HotkeyAction)
    func hotkeyForAction(_ action: HotkeyAction) -> AppHotkey?
}

/// Manages hotkey bindings, persistence, conflict unbinding, and action emission.
@MainActor
public final class ShortcutRegistry: ObservableObject, ShortcutRegistryProtocol {
    public static let shared = ShortcutRegistry()

    @Published public var toggleScanHotkey: AppHotkey? {
        didSet {
            saveHotkey(toggleScanHotkey, for: .toggleScan)
            updateSourceRegistration(for: .toggleScan)
        }
    }

    @Published public var togglePositioningHotkey: AppHotkey? {
        didSet {
            saveHotkey(togglePositioningHotkey, for: .togglePositioning)
            updateSourceRegistration(for: .togglePositioning)
        }
    }

    @Published public var oneTimeScanHotkey: AppHotkey? {
        didSet {
            saveHotkey(oneTimeScanHotkey, for: .oneTimeScan)
            updateSourceRegistration(for: .oneTimeScan)
        }
    }

    public let actionStream: AsyncStream<HotkeyAction>
    private var actionContinuation: AsyncStream<HotkeyAction>.Continuation?

    private let eventSource: HotkeyEventSource
    private let userDefaults: UserDefaults

    public init(eventSource: HotkeyEventSource? = nil, userDefaults: UserDefaults = .standard) {
        let source = eventSource ?? CarbonHotkeyEventSource()
        self.eventSource = source
        self.userDefaults = userDefaults

        var streamContinuation: AsyncStream<HotkeyAction>.Continuation?
        self.actionStream = AsyncStream { continuation in
            streamContinuation = continuation
        }
        self.actionContinuation = streamContinuation

        // Load existing hotkeys
        self.toggleScanHotkey = Self.loadHotkey(for: .toggleScan, defaults: userDefaults)
        self.togglePositioningHotkey = Self.loadHotkey(for: .togglePositioning, defaults: userDefaults)
        self.oneTimeScanHotkey = Self.loadHotkey(for: .oneTimeScan, defaults: userDefaults)

        // Wire event handler from event source to async stream
        self.eventSource.setEventHandler { [weak self] action in
            Task { @MainActor [weak self] in
                self?.actionContinuation?.yield(action)
            }
        }

        // Register initial hotkeys
        updateSourceRegistration(for: .toggleScan)
        updateSourceRegistration(for: .togglePositioning)
        updateSourceRegistration(for: .oneTimeScan)
    }

    deinit {
        actionContinuation?.finish()
        eventSource.unregisterAll()
        eventSource.setEventHandler(nil)
    }

    /// Sets hotkey for a specified action with automatic duplicate unbinding across other actions.
    public func setHotkey(_ hotkey: AppHotkey?, for action: HotkeyAction) {
        guard let hotkey = hotkey else {
            clearHotkey(for: action)
            return
        }

        // Automatically unbind duplicate assignment from any other action
        switch action {
        case .toggleScan:
            if togglePositioningHotkey == hotkey { togglePositioningHotkey = nil }
            if oneTimeScanHotkey == hotkey { oneTimeScanHotkey = nil }
            toggleScanHotkey = hotkey

        case .togglePositioning:
            if toggleScanHotkey == hotkey { toggleScanHotkey = nil }
            if oneTimeScanHotkey == hotkey { oneTimeScanHotkey = nil }
            togglePositioningHotkey = hotkey

        case .oneTimeScan:
            if toggleScanHotkey == hotkey { toggleScanHotkey = nil }
            if togglePositioningHotkey == hotkey { togglePositioningHotkey = nil }
            oneTimeScanHotkey = hotkey
        }
    }

    private func clearHotkey(for action: HotkeyAction) {
        switch action {
        case .toggleScan:
            toggleScanHotkey = nil
        case .togglePositioning:
            togglePositioningHotkey = nil
        case .oneTimeScan:
            oneTimeScanHotkey = nil
        }
    }

    public func hotkeyForAction(_ action: HotkeyAction) -> AppHotkey? {
        switch action {
        case .toggleScan: return toggleScanHotkey
        case .togglePositioning: return togglePositioningHotkey
        case .oneTimeScan: return oneTimeScanHotkey
        }
    }

    // MARK: - Event Source Registration
    private func updateSourceRegistration(for action: HotkeyAction) {
        if let hotkey = hotkeyForAction(action) {
            _ = eventSource.register(hotkey: hotkey, for: action)
        } else {
            eventSource.unregister(action: action)
        }
    }

    // MARK: - Persistence
    private func saveHotkey(_ hotkey: AppHotkey?, for action: HotkeyAction) {
        if let hotkey = hotkey, let data = try? JSONEncoder().encode(hotkey) {
            userDefaults.set(data, forKey: action.userDefaultsKey)
        } else {
            userDefaults.removeObject(forKey: action.userDefaultsKey)
        }
    }

    private static func loadHotkey(for action: HotkeyAction, defaults: UserDefaults) -> AppHotkey? {
        guard let data = defaults.data(forKey: action.userDefaultsKey) else {
            return nil
        }
        return try? JSONDecoder().decode(AppHotkey.self, from: data)
    }
}
