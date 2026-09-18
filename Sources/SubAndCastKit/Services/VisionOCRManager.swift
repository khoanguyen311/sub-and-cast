import Foundation
import Vision
import CoreGraphics

public struct OCRResult: Sendable {
    public let fullText: String
    public let lines: [String]
    public let confidence: Float

    public init(fullText: String, lines: [String], confidence: Float) {
        self.fullText = fullText
        self.lines = lines
        self.confidence = confidence
    }
}

public final class VisionOCRManager: @unchecked Sendable {
    public init() {}

    public func recognizeText(
        in cgImage: CGImage,
        recognitionLanguages: [String] = ["ja-JP", "en-US", "zh-Hans", "ko-KR"]
    ) async throws -> OCRResult {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: OCRResult(fullText: "", lines: [], confidence: 0))
                    return
                }

                // Sort observations top-to-bottom, left-to-right
                // Note: Vision coordinates have origin (0,0) at bottom-left
                let sortedObservations = observations.sorted { obs1, obs2 in
                    if abs(obs1.boundingBox.origin.y - obs2.boundingBox.origin.y) > 0.05 {
                        return obs1.boundingBox.origin.y > obs2.boundingBox.origin.y
                    }
                    return obs1.boundingBox.origin.x < obs2.boundingBox.origin.x
                }

                var extractedLines: [String] = []
                var totalConfidence: Float = 0

                for obs in sortedObservations {
                    guard let candidate = obs.topCandidates(1).first else { continue }
                    let cleaned = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleaned.isEmpty {
                        extractedLines.append(cleaned)
                        totalConfidence += candidate.confidence
                    }
                }

                let avgConfidence = extractedLines.isEmpty ? 0 : (totalConfidence / Float(extractedLines.count))
                let joinedText = extractedLines.joined(separator: "\n")

                continuation.resume(returning: OCRResult(
                    fullText: joinedText,
                    lines: extractedLines,
                    confidence: avgConfidence
                ))
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            if !recognitionLanguages.isEmpty {
                request.recognitionLanguages = recognitionLanguages
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
