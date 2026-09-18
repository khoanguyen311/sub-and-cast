import CoreGraphics
import Accelerate

public final class ImageDiffer: @unchecked Sendable {
    private var previousBuffer: [UInt8]?
    private let targetWidth = 32
    private let targetHeight = 32

    public init() {}

    /// Returns true if the image is considered changed compared to the previous image.
    /// Threshold is the fraction of total difference (0.0 to 1.0), default 0.03 (3%).
    public func hasImageChanged(cgImage: CGImage, threshold: Float = 0.03) -> Bool {
        guard let currentBuffer = extractDownscaledGrayscale(from: cgImage) else {
            return true
        }

        guard let prev = previousBuffer else {
            previousBuffer = currentBuffer
            return true
        }

        var totalDifference: Int = 0
        let count = targetWidth * targetHeight
        for i in 0..<count {
            let diff = abs(Int(currentBuffer[i]) - Int(prev[i]))
            totalDifference += diff
        }

        let maxDifference = count * 255
        let changeRatio = Float(totalDifference) / Float(maxDifference)

        if changeRatio >= threshold {
            previousBuffer = currentBuffer
            return true
        } else {
            return false
        }
    }

    public func reset() {
        previousBuffer = nil
    }

    private func extractDownscaledGrayscale(from image: CGImage) -> [UInt8]? {
        let count = targetWidth * targetHeight
        var buffer = [UInt8](repeating: 0, count: count)
        let colorSpace = CGColorSpaceCreateDeviceGray()

        guard let context = CGContext(
            data: &buffer,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: targetWidth,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .low
        context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        return buffer
    }
}
