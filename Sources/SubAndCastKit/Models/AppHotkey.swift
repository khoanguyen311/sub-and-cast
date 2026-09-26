import Foundation
import AppKit
import Carbon

public enum HotkeyAction: UInt32, CaseIterable, Sendable {
    case toggleScan = 1
    case togglePositioning = 2
    case oneTimeScan = 3

    public var displayName: String {
        switch self {
        case .toggleScan: return "Toggle Auto Scan"
        case .togglePositioning: return "Toggle Positioning Mode"
        case .oneTimeScan: return "One-Time Scan"
        }
    }

    public var userDefaultsKey: String {
        switch self {
        case .toggleScan: return "hotkey_toggleScan"
        case .togglePositioning: return "hotkey_togglePositioning"
        case .oneTimeScan: return "hotkey_oneTimeScan"
        }
    }
}

public struct AppHotkey: Codable, Equatable, Hashable, Sendable {
    public var keyCode: UInt32
    public var modifiers: UInt32

    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// Initializes an AppHotkey from an NSEvent.
    /// Strict validation: Returns nil if no modifier keys are pressed.
    public init?(from event: NSEvent) {
        var carbonMods: UInt32 = 0
        if event.modifierFlags.contains(.command) { carbonMods |= UInt32(cmdKey) }
        if event.modifierFlags.contains(.option) { carbonMods |= UInt32(optionKey) }
        if event.modifierFlags.contains(.control) { carbonMods |= UInt32(controlKey) }
        if event.modifierFlags.contains(.shift) { carbonMods |= UInt32(shiftKey) }

        guard carbonMods != 0 else { return nil }

        self.keyCode = UInt32(event.keyCode)
        self.modifiers = carbonMods
    }

    /// Formatted human-readable string (e.g., "⌥ ⌘ S", "⌃ ⇧ F1")
    public var displayString: String {
        var symbols: [String] = []
        if (modifiers & UInt32(controlKey)) != 0 { symbols.append("⌃") }
        if (modifiers & UInt32(optionKey)) != 0 { symbols.append("⌥") }
        if (modifiers & UInt32(shiftKey)) != 0 { symbols.append("⇧") }
        if (modifiers & UInt32(cmdKey)) != 0 { symbols.append("⌘") }

        let keyString = Self.stringForKeyCode(keyCode)
        symbols.append(keyString)
        return symbols.joined(separator: " ")
    }

    public static func stringForKeyCode(_ keyCode: UInt32) -> String {
        // Special keys
        switch keyCode {
        case 36: return "↩"
        case 48: return "⇥"
        case 49: return "Space"
        case 51: return "⌫"
        case 53: return "⎋"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        default:
            break
        }

        // Standard ANSI Key Codes
        let standardKeys: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: ".", 50: "`"
        ]

        if let str = standardKeys[keyCode] {
            return str
        }

        return "Key \(keyCode)"
    }
}
