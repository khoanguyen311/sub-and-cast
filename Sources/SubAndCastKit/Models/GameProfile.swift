import Foundation
import CoreGraphics

public struct CodableRect: Codable, Equatable {
    public var x: CGFloat
    public var y: CGFloat
    public var width: CGFloat
    public var height: CGFloat

    public init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public init(cgRect: CGRect) {
        self.x = cgRect.origin.x
        self.y = cgRect.origin.y
        self.width = cgRect.size.width
        self.height = cgRect.size.height
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
        self.fontSize = try container.decodeIfPresent(CGFloat.self, forKey: .fontSize) ?? 20.0
        self.backgroundOpacity = try container.decodeIfPresent(Double.self, forKey: .backgroundOpacity) ?? 0.85
    }
}
