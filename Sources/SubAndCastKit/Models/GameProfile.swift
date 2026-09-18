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
    public var sourceLanguage: String // e.g. "ja", "en", "auto", "zh-Hans"
    public var targetLanguage: String // e.g. "en", "vi", "es"
    public var captureIntervalSeconds: Double
    public var fadeTimeoutSeconds: Double
    public var fontSize: CGFloat
    public var backgroundOpacity: Double
    public var translationEngineType: String // "apple", "gemini", "google_free"
    public var geminiApiKey: String?

    public init(
        id: UUID = UUID(),
        name: String = "Default Game",
        sourceRect: CodableRect = CodableRect(x: 100, y: 150, width: 600, height: 120),
        displayRect: CodableRect = CodableRect(x: 100, y: 300, width: 600, height: 140),
        sourceLanguage: String = "ja",
        targetLanguage: String = "en",
        captureIntervalSeconds: Double = 0.8,
        fadeTimeoutSeconds: Double = 4.0,
        fontSize: CGFloat = 20.0,
        backgroundOpacity: Double = 0.85,
        translationEngineType: String = "apple",
        geminiApiKey: String? = nil
    ) {
        self.id = id
        self.name = name
        self.sourceRect = sourceRect
        self.displayRect = displayRect
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.captureIntervalSeconds = captureIntervalSeconds
        self.fadeTimeoutSeconds = fadeTimeoutSeconds
        self.fontSize = fontSize
        self.backgroundOpacity = backgroundOpacity
        self.translationEngineType = translationEngineType
        self.geminiApiKey = geminiApiKey
    }
}
