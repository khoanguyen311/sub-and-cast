import Foundation
import Carbon
import AppKit

public final class GlobalHotKeyManager: @unchecked Sendable {
    public static let shared = GlobalHotKeyManager()

    private var eventHandlerRef: EventHandlerRef?
    private var hotKeyRefs: [EventHotKeyRef] = []

    public init() {}

    public func registerHotKeys(appState: AppState) {
        unregisterHotKeys()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handler: EventHandlerUPP = { _, inEvent, _ -> OSStatus in
            guard let inEvent = inEvent else { return noErr }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                inEvent,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            guard status == noErr else { return noErr }

            DispatchQueue.main.async {
                let state = AppState.shared
                switch hotKeyID.id {
                case 1: // ⌘⇧S -> Toggle Auto-Scan
                    state.toggleScanning()
                case 2: // ⌘⇧T -> Snapshot
                    state.triggerSnapshot()
                case 3: // ⌘⇧L -> Position / Lock Overlays
                    state.toggleLock()
                default:
                    break
                }
            }

            return noErr
        }

        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, &eventHandlerRef)

        let signature = OSType(0x53554243) // "SUBC"

        // 1. Cmd + Shift + S: Toggle Auto-Scan
        registerKey(keyCode: UInt32(kVK_ANSI_S), modifiers: UInt32(cmdKey | shiftKey), id: 1, signature: signature)

        // 2. Cmd + Shift + T: Snapshot
        registerKey(keyCode: UInt32(kVK_ANSI_T), modifiers: UInt32(cmdKey | shiftKey), id: 2, signature: signature)

        // 3. Cmd + Shift + L: Position / Lock Overlays
        registerKey(keyCode: UInt32(kVK_ANSI_L), modifiers: UInt32(cmdKey | shiftKey), id: 3, signature: signature)
    }

    private func registerKey(keyCode: UInt32, modifiers: UInt32, id: UInt32, signature: OSType) {
        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let ref = hotKeyRef {
            hotKeyRefs.append(ref)
        }
    }

    public func unregisterHotKeys() {
        for ref in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()

        if let handlerRef = eventHandlerRef {
            RemoveEventHandler(handlerRef)
            eventHandlerRef = nil
        }
    }

    deinit {
        unregisterHotKeys()
    }
}
