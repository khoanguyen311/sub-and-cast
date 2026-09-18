import Foundation

public enum OCREngine: String, CaseIterable, Identifiable, Codable, Sendable {
    case appleVision = "apple_vision"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .appleVision:
            return "Apple Neural Engine (Vision Framework)"
        }
    }

    public var subtitle: String {
        switch self {
        case .appleVision:
            return "On-device, hardware-accelerated"
        }
    }
}
