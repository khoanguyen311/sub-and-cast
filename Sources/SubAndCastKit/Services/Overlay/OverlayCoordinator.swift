import Foundation
import CoreGraphics
import Combine

/// State machine tracking overlay positioning sessions.
public enum OverlayPositioningState: Equatable, Sendable {
    case locked
    case positioning(snapshotSource: CodableRect, snapshotDisplay: CodableRect)
}

/// Deep coordinator encapsulating:
/// - Coordinate space inversion between AppKit (bottom-left origin) and CoreGraphics (top-left origin).
/// - 36pt floating header offset math.
/// - Positioning sessions with undo rollback snapshots.
/// - Minimum boundary clamping (>= 120x40).
@MainActor
public final class OverlayCoordinator: ObservableObject {
    public static let shared = OverlayCoordinator()

    @Published public private(set) var positioningState: OverlayPositioningState = .locked

    public var isPositioning: Bool {
        if case .positioning = positioningState { return true }
        return false
    }

    public init() {}

    // MARK: - Coordinate Transformations
    /// Converts a CoreGraphics rect (top-left origin, selection box without header)
    /// to an AppKit window frame (bottom-left origin), adding the 36pt header offset if includeHeader is true.
    public static func appKitFrame(
        from cgRect: CGRect,
        screenHeight: CGFloat,
        includeHeader: Bool
    ) -> CGRect {
        let boxWidth = max(CodableRect.minWidth, cgRect.width)
        let boxHeight = max(CodableRect.minHeight, cgRect.height)
        let headerOffset = includeHeader ? OverlayLayoutConstants.headerOffset : 0
        let totalHeight = boxHeight + headerOffset

        let y = screenHeight - cgRect.origin.y - boxHeight
        return CGRect(
            x: max(0, cgRect.origin.x),
            y: max(0, y),
            width: boxWidth,
            height: totalHeight
        )
    }

    /// Converts an AppKit window frame (bottom-left origin) to a CoreGraphics rect (top-left origin),
    /// subtracting the 36pt header offset if headerIsPresent is true.
    public static func coreGraphicsRect(
        from appKitFrame: CGRect,
        screenHeight: CGFloat,
        headerIsPresent: Bool
    ) -> CGRect {
        let offset = headerIsPresent ? OverlayLayoutConstants.headerOffset : 0
        let boxHeight = max(CodableRect.minHeight, appKitFrame.height - offset)
        let boxWidth = max(CodableRect.minWidth, appKitFrame.width)
        let cgY = screenHeight - appKitFrame.origin.y - boxHeight

        return CGRect(
            x: max(0, appKitFrame.origin.x),
            y: max(0, cgY),
            width: boxWidth,
            height: boxHeight
        )
    }

    // MARK: - Positioning Session State Machine
    /// Begins a positioning session, capturing the initial snapshots of source and display rects for undo.
    public func beginPositioning(sourceRect: CodableRect, displayRect: CodableRect) {
        positioningState = .positioning(snapshotSource: sourceRect, snapshotDisplay: displayRect)
    }

    /// Commits the positioning session and locks overlays. Returns nil if not positioning.
    @discardableResult
    public func commitPositioning() -> Bool {
        guard case .positioning = positioningState else { return false }
        positioningState = .locked
        return true
    }

    /// Cancels the positioning session and returns the original snapshot rects for rollback.
    public func cancelPositioning() -> (source: CodableRect, display: CodableRect)? {
        guard case let .positioning(origSource, origDisplay) = positioningState else {
            return nil
        }
        positioningState = .locked
        return (origSource, origDisplay)
    }

    /// Clamps and sanitizes a live dragged or resized rect.
    public static func clampRect(_ rect: CGRect) -> CGRect {
        let width = max(CodableRect.minWidth, rect.width)
        let height = max(CodableRect.minHeight, rect.height)
        let x = max(0, rect.origin.x)
        let y = max(0, rect.origin.y)
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
