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
        recognitionLanguages: [String] = ["ja-JP", "en-US", "zh-Hans", "ko-KR"],
        mergeWrappedLines: Bool = true
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

                struct TextFragment {
                    let rect: CGRect
                    let text: String
                    let confidence: Float
                }

                var fragments: [TextFragment] = []
                var totalConfidence: Float = 0

                for obs in observations {
                    guard let candidate = obs.topCandidates(1).first else { continue }
                    let cleaned = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleaned.isEmpty {
                        fragments.append(TextFragment(rect: obs.boundingBox, text: cleaned, confidence: candidate.confidence))
                        totalConfidence += candidate.confidence
                    }
                }

                guard !fragments.isEmpty else {
                    continuation.resume(returning: OCRResult(fullText: "", lines: [], confidence: 0))
                    return
                }

                // Sort fragments top-to-bottom (Y is inverted in Vision: 1.0 is top, 0.0 is bottom)
                fragments.sort { $0.rect.midY > $1.rect.midY }

                // Group fragments sharing the same visual horizontal baseline into lines
                struct LineCluster {
                    var minY: CGFloat
                    var maxY: CGFloat
                    var items: [TextFragment]
                    var midY: CGFloat { (minY + maxY) / 2.0 }
                }

                var lineClusters: [LineCluster] = []

                for frag in fragments {
                    var matchedIndex: Int?
                    for (idx, cluster) in lineClusters.enumerated() {
                        let overlap = max(0, min(frag.rect.maxY, cluster.maxY) - max(frag.rect.minY, cluster.minY))
                        let minHeight = min(frag.rect.height, cluster.maxY - cluster.minY)
                        let midDiff = abs(frag.rect.midY - cluster.midY)
                        let allowedMidDiff = max(frag.rect.height, cluster.maxY - cluster.minY) * 0.55

                        if (minHeight > 0 && overlap / minHeight >= 0.35) || midDiff <= allowedMidDiff {
                            matchedIndex = idx
                            break
                        }
                    }

                    if let idx = matchedIndex {
                        lineClusters[idx].items.append(frag)
                        lineClusters[idx].minY = min(lineClusters[idx].minY, frag.rect.minY)
                        lineClusters[idx].maxY = max(lineClusters[idx].maxY, frag.rect.maxY)
                    } else {
                        lineClusters.append(LineCluster(minY: frag.rect.minY, maxY: frag.rect.maxY, items: [frag]))
                    }
                }

                // Sort line clusters top-to-bottom
                lineClusters.sort { $0.midY > $1.midY }

                // Within each line cluster, sort left-to-right by X and join
                var extractedLines: [String] = []
                for cluster in lineClusters {
                    let sortedInLine = cluster.items.sorted { $0.rect.minX < $1.rect.minX }
                    let lineString = sortedInLine.map { $0.text }.joined(separator: " ")
                    if !lineString.isEmpty {
                        extractedLines.append(lineString)
                    }
                }

                // Apply intelligent dialogue reconstruction if enabled
                let finalLines = mergeWrappedLines
                    ? DialogueTextReconstructor.reconstruct(lines: extractedLines)
                    : extractedLines

                let avgConfidence = totalConfidence / Float(fragments.count)
                let joinedText = finalLines.joined(separator: "\n")

                continuation.resume(returning: OCRResult(
                    fullText: joinedText,
                    lines: finalLines,
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
