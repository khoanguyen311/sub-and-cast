import Foundation
import CoreGraphics
import ScreenCaptureKit

public final class ScreenCaptureManager: @unchecked Sendable {
    public init() {}

    /// Captures a specified rectangular region on screen (in screen coordinates).
    public func captureRegion(rect: CGRect) async throws -> CGImage {
        // First attempt using ScreenCaptureKit (hardware accelerated)
        if #available(macOS 14.0, *) {
            do {
                return try await captureWithScreenCaptureKit(rect: rect)
            } catch {
                // If ScreenCaptureKit fails (e.g. permission or display mismatch), fallback to CGWindowListCreateImage
                return try captureWithCGWindowList(rect: rect)
            }
        } else {
            return try captureWithCGWindowList(rect: rect)
        }
    }

    @available(macOS 14.0, *)
    private func captureWithScreenCaptureKit(rect: CGRect) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let primaryDisplay = content.displays.first else {
            throw NSError(domain: "ScreenCaptureManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No display found"])
        }

        // ScreenCaptureKit uses top-left coordinate system (display bounds)
        let config = SCStreamConfiguration()
        config.sourceRect = rect
        config.width = max(1, Int(rect.width * 2)) // Retina 2x scale
        config.height = max(1, Int(rect.height * 2))
        config.showsCursor = false
        config.scalesToFit = false

        let filter = SCContentFilter(display: primaryDisplay, excludingWindows: [])
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }

    private func captureWithCGWindowList(rect: CGRect) throws -> CGImage {
        guard let image = CGWindowListCreateImage(
            rect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        ) else {
            throw NSError(domain: "ScreenCaptureManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to capture screen with CGWindowListCreateImage"])
        }
        return image
    }
}
