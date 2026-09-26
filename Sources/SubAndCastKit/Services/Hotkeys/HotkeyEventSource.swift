import Foundation
import AppKit
import Carbon

/// Protocol abstracting system hotkey event listening from low-level OS APIs.
public protocol HotkeyEventSource: AnyObject, Sendable {
    func register(hotkey: AppHotkey, for action: HotkeyAction) -> Bool
    func unregister(action: HotkeyAction)
    func unregisterAll()
    func setEventHandler(_ handler: (@Sendable (HotkeyAction) -> Void)?)
}

/// Production Carbon-based event source listening to OS hotkey events.
public final class CarbonHotkeyEventSource: HotkeyEventSource, @unchecked Sendable {
    private let hotKeySignature = OSType(0x53414E43) // 'SANC'
    private var hotKeyRefs: [HotkeyAction: EventHotKeyRef] = [:]
    private nonisolated(unsafe) static var isHandlerInstalled = false
    private nonisolated(unsafe) static var globalHandler: (@Sendable (HotkeyAction) -> Void)?
    private let lock = NSLock()

    public init() {
        installCarbonHandlerIfNeeded()
    }

    public func setEventHandler(_ handler: (@Sendable (HotkeyAction) -> Void)?) {
        lock.lock()
        defer { lock.unlock() }
        Self.globalHandler = handler
    }

    public func register(hotkey: AppHotkey, for action: HotkeyAction) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if let existingRef = hotKeyRefs[action] {
            UnregisterEventHotKey(existingRef)
            hotKeyRefs.removeValue(forKey: action)
        }

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
            return true
        }
        return false
    }

    public func unregister(action: HotkeyAction) {
        lock.lock()
        defer { lock.unlock() }

        if let existingRef = hotKeyRefs[action] {
            UnregisterEventHotKey(existingRef)
            hotKeyRefs.removeValue(forKey: action)
        }
    }

    public func unregisterAll() {
        lock.lock()
        defer { lock.unlock() }

        for (_, ref) in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
    }

    private func installCarbonHandlerIfNeeded() {
        lock.lock()
        defer { lock.unlock() }

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
                    CarbonHotkeyEventSource.globalHandler?(action)
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            nil
        )
    }
}

/// Headless mock event source for unit testing hotkey trigger events.
public final class MockHotkeyEventSource: HotkeyEventSource, @unchecked Sendable {
    private var registered: [HotkeyAction: AppHotkey] = [:]
    private var handler: (@Sendable (HotkeyAction) -> Void)?
    private let lock = NSLock()

    public init() {}

    public func register(hotkey: AppHotkey, for action: HotkeyAction) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        registered[action] = hotkey
        return true
    }

    public func unregister(action: HotkeyAction) {
        lock.lock()
        defer { lock.unlock() }
        registered.removeValue(forKey: action)
    }

    public func unregisterAll() {
        lock.lock()
        defer { lock.unlock() }
        registered.removeAll()
    }

    public func setEventHandler(_ handler: (@Sendable (HotkeyAction) -> Void)?) {
        lock.lock()
        defer { lock.unlock() }
        self.handler = handler
    }

    public func simulateKeyPress(for action: HotkeyAction) {
        lock.lock()
        let h = self.handler
        lock.unlock()
        h?(action)
    }

    public func registeredHotkey(for action: HotkeyAction) -> AppHotkey? {
        lock.lock()
        defer { lock.unlock() }
        return registered[action]
    }
}
