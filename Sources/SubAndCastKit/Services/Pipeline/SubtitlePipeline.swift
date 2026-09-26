import Foundation
import CoreGraphics

// MARK: - Pipeline Configuration

/// Configuration parameters for a subtitle pipeline execution cycle.
public struct SubtitlePipelineConfig: Sendable, Equatable {
    public var sourceLanguage: String
    public var targetLanguage: String
    public var translationEngineType: String
    public var mergeWrappedLines: Bool
    public var cloudflareConfig: CloudflareConfig?

    public init(
        sourceLanguage: String = "en",
        targetLanguage: String = "vi",
        translationEngineType: String = "apple",
        mergeWrappedLines: Bool = true,
        cloudflareConfig: CloudflareConfig? = nil
    ) {
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.translationEngineType = translationEngineType
        self.mergeWrappedLines = mergeWrappedLines
        self.cloudflareConfig = cloudflareConfig
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

// MARK: - Pipeline Event

/// Event emitted by autonomous scanning loops or one-time scan evaluations.
public enum SubtitleEvent: Sendable, Equatable {
    case unchanged
    case empty
    case dialogue(sourceText: String, translatedText: String, confidence: Float)
    case error(String)

    public init(from output: SubtitlePipelineOutput) {
        switch output {
        case .unchanged:
            self = .unchanged
        case .empty:
            self = .empty
        case let .dialogue(src, trans, conf):
            self = .dialogue(sourceText: src, translatedText: trans, confidence: conf)
        }
    }
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

    func startScan(
        rect: CGRect,
        config: SubtitlePipelineConfig,
        intervalSeconds: Double
    ) -> AsyncStream<SubtitleEvent>

    func scanOnce(
        rect: CGRect,
        config: SubtitlePipelineConfig
    ) async -> SubtitleEvent

    func stopScan()
}

extension SubtitlePipelineProtocol {
    public func startScan(
        rect: CGRect,
        config: SubtitlePipelineConfig,
        intervalSeconds: Double
    ) -> AsyncStream<SubtitleEvent> {
        reset()
        return AsyncStream<SubtitleEvent> { continuation in
            let task = Task {
                while !Task.isCancelled {
                    do {
                        let output = try await self.process(rect: rect, config: config, force: false)
                        continuation.yield(SubtitleEvent(from: output))
                    } catch {
                        continuation.yield(.error(error.localizedDescription))
                    }

                    let delayNs = UInt64(max(0.2, intervalSeconds) * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: delayNs)
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    public func scanOnce(
        rect: CGRect,
        config: SubtitlePipelineConfig
    ) async -> SubtitleEvent {
        do {
            let output = try await process(rect: rect, config: config, force: true)
            return SubtitleEvent(from: output)
        } catch {
            return .error(error.localizedDescription)
        }
    }

    public func stopScan() {}
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
    private var activeScanTask: Task<Void, Never>?

    private var _lastRecognizedText: String = ""
    private var _lastTranslatedText: String = ""
    private var _lastConfidence: Float = 0
    private var _lastConfig: SubtitlePipelineConfig?

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

    /// Starts an autonomous background scanning loop emitting an event stream.
    public func startScan(
        rect: CGRect,
        config: SubtitlePipelineConfig,
        intervalSeconds: Double
    ) -> AsyncStream<SubtitleEvent> {
        stopScan()
        reset()

        return AsyncStream<SubtitleEvent> { continuation in
            let task = Task { [weak self] in
                while !Task.isCancelled {
                    guard let self = self else { break }

                    do {
                        let output = try await self.process(rect: rect, config: config, force: false)
                        continuation.yield(SubtitleEvent(from: output))
                    } catch {
                        continuation.yield(.error(error.localizedDescription))
                    }

                    let delayNs = UInt64(max(0.2, intervalSeconds) * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: delayNs)
                }
                continuation.finish()
            }

            self.lock.lock()
            self.activeScanTask = task
            self.lock.unlock()

            continuation.onTermination = { [weak self] _ in
                task.cancel()
                self?.lock.lock()
                if self?.activeScanTask == task {
                    self?.activeScanTask = nil
                }
                self?.lock.unlock()
            }
        }
    }

    /// Single-shot execution interface bypassing visual diff short-circuiting.
    public func scanOnce(
        rect: CGRect,
        config: SubtitlePipelineConfig
    ) async -> SubtitleEvent {
        do {
            let output = try await process(rect: rect, config: config, force: true)
            return SubtitleEvent(from: output)
        } catch {
            return .error(error.localizedDescription)
        }
    }

    /// Stops any active scanning loop.
    public func stopScan() {
        lock.lock()
        defer { lock.unlock() }
        activeScanTask?.cancel()
        activeScanTask = nil
    }

    /// Resets diff buffers and internal text caches.
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        imageDiffer.reset()
        _lastRecognizedText = ""
        _lastTranslatedText = ""
        _lastConfidence = 0
        _lastConfig = nil
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

        // 4. Check if text content matches previous scan with identical configuration
        if isSameAsLastScan(cleanOCR, config: config) {
            if !force {
                return .unchanged
            } else {
                let prev = previousTranslationResult()
                let conf = ocrResult.confidence > 0 ? ocrResult.confidence : prev.confidence
                return .dialogue(sourceText: cleanOCR, translatedText: prev.translatedText, confidence: conf)
            }
        }

        // 5. Translation
        let translated = try await translationProvider.translate(
            text: cleanOCR,
            sourceLanguage: config.sourceLanguage,
            targetLanguage: config.targetLanguage,
            engineType: config.translationEngineType,
            cloudflareConfig: config.cloudflareConfig
        )

        handleSuccessfulTranslation(source: cleanOCR, translated: translated, confidence: ocrResult.confidence, config: config)
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
        _lastConfig = nil
    }

    private func isSameAsLastScan(_ text: String, config: SubtitlePipelineConfig) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !_lastTranslatedText.isEmpty,
              _lastRecognizedText == text,
              let lastConfig = _lastConfig,
              lastConfig.sourceLanguage == config.sourceLanguage,
              lastConfig.targetLanguage == config.targetLanguage,
              lastConfig.translationEngineType == config.translationEngineType,
              lastConfig.cloudflareConfig == config.cloudflareConfig else {
            return false
        }
        return true
    }

    private func previousTranslationResult() -> (translatedText: String, confidence: Float) {
        lock.lock()
        defer { lock.unlock() }
        return (_lastTranslatedText, _lastConfidence)
    }

    private func handleSuccessfulTranslation(source: String, translated: String, confidence: Float, config: SubtitlePipelineConfig) {
        lock.lock()
        defer { lock.unlock() }
        _lastRecognizedText = source
        _lastTranslatedText = translated
        _lastConfidence = confidence
        _lastConfig = config
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
