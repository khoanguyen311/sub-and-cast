import Foundation
import CoreGraphics

public struct CodableRect: Codable, Equatable, Sendable {
    public static let minWidth: CGFloat = 120
    public static let minHeight: CGFloat = 40

    public var x: CGFloat {
        didSet { x = max(0, x) }
    }
    public var y: CGFloat {
        didSet { y = max(0, y) }
    }
    public var width: CGFloat {
        didSet { width = max(Self.minWidth, width) }
    }
    public var height: CGFloat {
        didSet { height = max(Self.minHeight, height) }
    }

    public init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        self.x = max(0, x)
        self.y = max(0, y)
        self.width = max(Self.minWidth, width)
        self.height = max(Self.minHeight, height)
    }

    public init(cgRect: CGRect) {
        self.x = max(0, cgRect.origin.x)
        self.y = max(0, cgRect.origin.y)
        self.width = max(Self.minWidth, cgRect.size.width)
        self.height = max(Self.minHeight, cgRect.size.height)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawX = try container.decodeIfPresent(CGFloat.self, forKey: .x) ?? 0
        let rawY = try container.decodeIfPresent(CGFloat.self, forKey: .y) ?? 0
        let rawW = try container.decodeIfPresent(CGFloat.self, forKey: .width) ?? Self.minWidth
        let rawH = try container.decodeIfPresent(CGFloat.self, forKey: .height) ?? Self.minHeight
        self.x = max(0, rawX)
        self.y = max(0, rawY)
        self.width = max(Self.minWidth, rawW)
        self.height = max(Self.minHeight, rawH)
    }

    public var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

public struct GameProfile: Codable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var sourceRect: CodableRect
    public var displayRect: CodableRect
    public var sourceLanguage: String // default: "en"
    public var targetLanguage: String // default: "vi"
    public var translationEngineType: String // "apple" or "google_free"
    public var ocrEngineType: String // "apple_vision"
    public var captureIntervalSeconds: Double
    public var fadeTimeoutSeconds: Double
    public var oneTimeFadeTimeoutSeconds: Double
    public var mergeWrappedLines: Bool
    public var fontSize: CGFloat
    public var backgroundOpacity: Double

    public init(
        id: UUID = UUID(),
        name: String = "Default Game",
        sourceRect: CodableRect = CodableRect(x: 100, y: 150, width: 600, height: 120),
        displayRect: CodableRect = CodableRect(x: 100, y: 300, width: 600, height: 140),
        sourceLanguage: String = "en",
        targetLanguage: String = "vi",
        translationEngineType: String = "apple",
        ocrEngineType: String = OCREngine.appleVision.rawValue,
        captureIntervalSeconds: Double = 0.8,
        fadeTimeoutSeconds: Double = 4.0,
        oneTimeFadeTimeoutSeconds: Double = 5.0,
        mergeWrappedLines: Bool = true,
        fontSize: CGFloat = 20.0,
        backgroundOpacity: Double = 0.85
    ) {
        self.id = id
        self.name = name
        self.sourceRect = sourceRect
        self.displayRect = displayRect
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.translationEngineType = translationEngineType
        self.ocrEngineType = ocrEngineType
        self.captureIntervalSeconds = captureIntervalSeconds
        self.fadeTimeoutSeconds = fadeTimeoutSeconds
        self.oneTimeFadeTimeoutSeconds = oneTimeFadeTimeoutSeconds
        self.mergeWrappedLines = mergeWrappedLines
        self.fontSize = fontSize
        self.backgroundOpacity = backgroundOpacity
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Default Game"
        self.sourceRect = try container.decodeIfPresent(CodableRect.self, forKey: .sourceRect) ?? CodableRect(x: 100, y: 150, width: 600, height: 120)
        self.displayRect = try container.decodeIfPresent(CodableRect.self, forKey: .displayRect) ?? CodableRect(x: 100, y: 300, width: 600, height: 140)
        self.sourceLanguage = try container.decodeIfPresent(String.self, forKey: .sourceLanguage) ?? "en"
        self.targetLanguage = try container.decodeIfPresent(String.self, forKey: .targetLanguage) ?? "vi"
        self.translationEngineType = try container.decodeIfPresent(String.self, forKey: .translationEngineType) ?? "apple"
        self.ocrEngineType = try container.decodeIfPresent(String.self, forKey: .ocrEngineType) ?? OCREngine.appleVision.rawValue
        self.captureIntervalSeconds = try container.decodeIfPresent(Double.self, forKey: .captureIntervalSeconds) ?? 0.8
        self.fadeTimeoutSeconds = try container.decodeIfPresent(Double.self, forKey: .fadeTimeoutSeconds) ?? 4.0
        self.oneTimeFadeTimeoutSeconds = try container.decodeIfPresent(Double.self, forKey: .oneTimeFadeTimeoutSeconds) ?? 5.0
        self.mergeWrappedLines = try container.decodeIfPresent(Bool.self, forKey: .mergeWrappedLines) ?? true
        self.fontSize = try container.decodeIfPresent(CGFloat.self, forKey: .fontSize) ?? 20.0
        self.backgroundOpacity = try container.decodeIfPresent(Double.self, forKey: .backgroundOpacity) ?? 0.85
    }
}
