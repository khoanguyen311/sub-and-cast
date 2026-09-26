import Foundation
import CoreGraphics

// MARK: - Frame Capture Provider Protocol & Implementations

/// Abstract provider for acquiring screen graphics regions.
public protocol FrameCaptureProvider: Sendable {
    func captureRegion(rect: CGRect) async throws -> CGImage
}

extension ScreenCaptureManager: FrameCaptureProvider {}

/// In-memory static frame provider for deterministic testing without display hardware.
public final class StaticImageFrameProvider: FrameCaptureProvider, @unchecked Sendable {
    private var imageQueue: [CGImage]
    private var defaultImage: CGImage?
    private let lock = NSLock()
    private var _capturedRects: [CGRect] = []

    public var capturedRects: [CGRect] {
        lock.lock()
        defer { lock.unlock() }
        return _capturedRects
    }

    public init(images: [CGImage] = [], defaultImage: CGImage? = nil) {
        self.imageQueue = images
        self.defaultImage = defaultImage
    }

    public func setImages(_ images: [CGImage]) {
        lock.lock()
        defer { lock.unlock() }
        self.imageQueue = images
    }

    public func setDefaultImage(_ image: CGImage?) {
        lock.lock()
        defer { lock.unlock() }
        self.defaultImage = image
    }

    private func dequeueImage(for rect: CGRect) throws -> CGImage {
        lock.lock()
        defer { lock.unlock() }
        _capturedRects.append(rect)
        if !imageQueue.isEmpty {
            return imageQueue.removeFirst()
        }
        if let fallback = defaultImage {
            return fallback
        }
        throw NSError(
            domain: "StaticImageFrameProvider",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "No mock frames available"]
        )
    }

    public func captureRegion(rect: CGRect) async throws -> CGImage {
        return try dequeueImage(for: rect)
    }
}

// MARK: - Translation Provider Protocol & Implementations

/// Abstract provider for translating text between languages.
public protocol TranslationProvider: Sendable {
    func translate(
        text: String,
        sourceLanguage: String,
        targetLanguage: String,
        engineType: String
    ) async throws -> String

    func translate(
        text: String,
        sourceLanguage: String,
        targetLanguage: String,
        engineType: String,
        cloudflareConfig: CloudflareConfig?
    ) async throws -> String
}

extension TranslationProvider {
    public func translate(
        text: String,
        sourceLanguage: String,
        targetLanguage: String,
        engineType: String,
        cloudflareConfig: CloudflareConfig?
    ) async throws -> String {
        try await translate(
            text: text,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            engineType: engineType
        )
    }
}

extension TranslationCoordinator: TranslationProvider {}

/// In-memory mock translation provider for offline, deterministic testing.
public final class MockTranslationProvider: TranslationProvider, @unchecked Sendable {
    private let lock = NSLock()
    public var translationHandler: (@Sendable (String, String, String, String) async throws -> String)?
    public var cannedTranslations: [String: String] = [:]
    public var prefix: String?
    private var _callCount: Int = 0
    private var _recordedRequests: [(text: String, source: String, target: String, engine: String)] = []

    public var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _callCount
    }

    public var recordedRequests: [(text: String, source: String, target: String, engine: String)] {
        lock.lock()
        defer { lock.unlock() }
        return _recordedRequests
    }

    public init(prefix: String? = nil, canned: [String: String] = [:]) {
        self.prefix = prefix
        self.cannedTranslations = canned
    }

    private func recordAndGetSnapshot(
        text: String,
        sourceLanguage: String,
        targetLanguage: String,
        engineType: String
    ) -> (handler: (@Sendable (String, String, String, String) async throws -> String)?, canned: String?, prefix: String?) {
        lock.lock()
        defer { lock.unlock() }
        _callCount += 1
        _recordedRequests.append((text, sourceLanguage, targetLanguage, engineType))
        return (translationHandler, cannedTranslations[text], prefix)
    }

    public func translate(
        text: String,
        sourceLanguage: String,
        targetLanguage: String,
        engineType: String
    ) async throws -> String {
        let (handler, canned, currentPrefix) = recordAndGetSnapshot(
            text: text,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            engineType: engineType
        )

        if let handler = handler {
            return try await handler(text, sourceLanguage, targetLanguage, engineType)
        }
        if let canned = canned {
            return canned
        }
        if let prefix = currentPrefix {
            return "\(prefix): \(text)"
        }
        return "[Mock \(sourceLanguage)->\(targetLanguage)] \(text)"
    }
}
