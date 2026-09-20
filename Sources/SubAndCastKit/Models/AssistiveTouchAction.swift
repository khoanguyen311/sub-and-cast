import Foundation

public enum AssistiveTouchAction: String, Codable, CaseIterable, Identifiable, Sendable {
    case oneTimeScan = "One-Time Scan"
    case toggleAutoScan = "Toggle Auto-Scan"
    case togglePositioning = "Toggle Positioning Mode"
    case openQuickMenu = "Open Quick Menu"
    case openPreferences = "Open Preferences"
    case none = "None"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .oneTimeScan: return "viewfinder"
        case .toggleAutoScan: return "arrow.clockwise.circle"
        case .togglePositioning: return "hand.draw"
        case .openQuickMenu: return "square.grid.2x2"
        case .openPreferences: return "gearshape"
        case .none: return "slash.circle"
        }
    }
}
