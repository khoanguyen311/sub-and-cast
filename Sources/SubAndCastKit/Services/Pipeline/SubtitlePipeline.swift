import Foundation
import CoreGraphics

// MARK: - Pipeline Configuration

/// Configuration parameters for a subtitle pipeline execution cycle.
public struct SubtitlePipelineConfig: Sendable, Equatable {
    public var sourceLanguage: String
    public var targetLanguage: String
    public var translationEngineType: String
    public var mergeWrappedLines: Bool

    public init(
        sourceLanguage: String = "en",
        targetLanguage: String = "vi",
        translationEngineType: String = "apple",
        mergeWrappedLines: Bool = true
    ) {
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.translationEngineType = translationEngineType
        self.mergeWrappedLines = mergeWrappedLines
    }
}

// MARK: - Pipeline Output

/// Emitted result of a subtitle pipeline processing cycle.
public enum SubtitlePipelineOutput: Sendable, Equatable {
    /// Frame has not changed visually or dialogue text matches previously translated text; caller should keep existing display.
    case unchanged
    /// No text was detected in the frame; dialogue is absent.
    case empty
    /// Dialogue was recognized and translated.
    case dialogue(sourceText: String, translatedText: String, confidence: Float)
}

// MARK: - Subtitle Pipeline Protocol

/// Unified interface for executing the capture-diff-OCR-reconstruct-translate loop.
public protocol SubtitlePipelineProtocol: Sendable {
    func process(
        rect: CGRect,
        config: SubtitlePipelineConfig,
        force: Bool
    ) async throws -> SubtitlePipelineOutput

    func process(
        image: CGImage,
        config: SubtitlePipelineConfig,
        force: Bool
    ) async throws -> SubtitlePipelineOutput

    func reset()
}

// MARK: - Subtitle Pipeline Implementation

/// Deep module consolidating screen capture, image differencing, Vision OCR clustering,
/// dialogue line reconstruction, and translation caching behind a single execution interface.
public final class SubtitlePipeline: SubtitlePipelineProtocol, @unchecked Sendable {
    public let captureProvider: FrameCaptureProvider
    public let translationProvider: TranslationProvider
    private let imageDiffer: ImageDiffer
    private let ocrManager: VisionOCRManager
    private let lock = NSLock()

    private var _lastRecognizedText: String = ""
    private var _lastTranslatedText: String = ""
    private var _lastConfidence: Float = 0

    public var lastRecognizedText: String {
        lock.lock()
        defer { lock.unlock() }
        return _lastRecognizedText
    }

    public var lastTranslatedText: String {
        lock.lock()
        defer { lock.unlock() }
        return _lastTranslatedText
    }

    public var lastConfidence: Float {
        lock.lock()
        defer { lock.unlock() }
        return _lastConfidence
    }

    public init(
        captureProvider: FrameCaptureProvider = ScreenCaptureManager(),
        translationProvider: TranslationProvider = TranslationCoordinator.shared,
        imageDiffer: ImageDiffer = ImageDiffer(),
        ocrManager: VisionOCRManager = VisionOCRManager()
    ) {
        self.captureProvider = captureProvider
        self.translationProvider = translationProvider
        self.imageDiffer = imageDiffer
        self.ocrManager = ocrManager
    }

    /// Resets diff buffers and internal text caches.
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        imageDiffer.reset()
        _lastRecognizedText = ""
        _lastTranslatedText = ""
        _lastConfidence = 0
    }

    /// Captures the specified region via captureProvider and executes the processing pipeline.
    public func process(
        rect: CGRect,
        config: SubtitlePipelineConfig,
        force: Bool = false
    ) async throws -> SubtitlePipelineOutput {
        guard rect.width >= CodableRect.minWidth, rect.height >= CodableRect.minHeight else {
            return .empty
        }

        let capturedImage = try await captureProvider.captureRegion(rect: rect)
        return try await process(image: capturedImage, config: config, force: force)
    }

    /// Executes the pipeline directly on an existing CGImage.
    public func process(
        image: CGImage,
        config: SubtitlePipelineConfig,
        force: Bool = false
    ) async throws -> SubtitlePipelineOutput {
        // 1. Difference Detection (short-circuit if frame is visually identical)
        if !force {
            let changed = checkImageChanged(image)
            if !changed {
                return .unchanged
            }
        }

        // 2. Vision OCR & Line Clustering
        let ocrLangs = Self.ocrLanguages(for: config.sourceLanguage)
        let ocrResult = try await ocrManager.recognizeText(
            in: image,
            recognitionLanguages: ocrLangs,
            mergeWrappedLines: config.mergeWrappedLines
        )

        let cleanOCR = ocrResult.fullText.trimmingCharacters(in: .whitespacesAndNewlines)

        // 3. Empty text detection
        if cleanOCR.isEmpty {
            handleEmptyResult()
            return .empty
        }

        // 4. Check if text content is identical to last recognized (avoid re-translating static dialogue)
        if !force && isSameAsLastRecognized(cleanOCR) {
            return .unchanged
        }

        // 5. Translation
        let translated = try await translationProvider.translate(
            text: cleanOCR,
            sourceLanguage: config.sourceLanguage,
            targetLanguage: config.targetLanguage,
            engineType: config.translationEngineType
        )

        handleSuccessfulTranslation(source: cleanOCR, translated: translated, confidence: ocrResult.confidence)
        return .dialogue(sourceText: cleanOCR, translatedText: translated, confidence: ocrResult.confidence)
    }

    // MARK: - Synchronous State Helpers (Protected by lock)

    private func checkImageChanged(_ image: CGImage) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return imageDiffer.hasImageChanged(cgImage: image)
    }

    private func handleEmptyResult() {
        lock.lock()
        defer { lock.unlock() }
        _lastRecognizedText = ""
        _lastTranslatedText = ""
        _lastConfidence = 0
    }

    private func isSameAsLastRecognized(_ text: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return _lastRecognizedText == text
    }

    private func handleSuccessfulTranslation(source: String, translated: String, confidence: Float) {
        lock.lock()
        defer { lock.unlock() }
        _lastRecognizedText = source
        _lastTranslatedText = translated
        _lastConfidence = confidence
    }

    // MARK: - OCR Language Mapping

    public static func ocrLanguages(for sourceLanguage: String) -> [String] {
        switch sourceLanguage.lowercased() {
        case "ja": return ["ja-JP", "en-US"]
        case "zh", "zh-hans": return ["zh-Hans", "en-US"]
        case "zh-hant": return ["zh-Hant", "en-US"]
        case "ko": return ["ko-KR", "en-US"]
        case "vi": return ["vi-VN", "en-US"]
        case "fr": return ["fr-FR", "en-US"]
        case "de": return ["de-DE", "en-US"]
        case "es": return ["es-ES", "en-US"]
        default: return ["en-US"]
        }
    }
}
