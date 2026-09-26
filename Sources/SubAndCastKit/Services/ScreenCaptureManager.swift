import Foundation
import CoreGraphics
import ScreenCaptureKit

public final class ScreenCaptureManager: @unchecked Sendable {
    public init() {}

    /// Captures a specified rectangular region on screen (in screen coordinates).
    public func captureRegion(rect: CGRect) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let targetDisplay = content.displays.first(where: { display in
            display.frame.intersects(rect)
        }) ?? content.displays.first

        guard let display = targetDisplay else {
            throw NSError(domain: "ScreenCaptureManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No display found"])
        }

        let relativeRect = CGRect(
            x: rect.origin.x - display.frame.origin.x,
            y: rect.origin.y - display.frame.origin.y,
            width: rect.width,
            height: rect.height
        )

        // ScreenCaptureKit uses top-left coordinate system (display bounds)
        let config = SCStreamConfiguration()
        config.sourceRect = relativeRect
        config.width = max(1, Int(rect.width * 2)) // Retina 2x scale
        config.height = max(1, Int(rect.height * 2))
        config.showsCursor = false
        config.scalesToFit = false

        let filter = SCContentFilter(display: display, excludingWindows: [])
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }
}
