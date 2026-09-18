import AppKit
import SwiftUI

public enum OverlayLayoutConstants {
    /// Height reserved above the selection box for the floating header bar (pill + vertical gap)
    public static let headerOffset: CGFloat = 36
    /// Minimum width for the selection box (keeps it wider than the floating header pill)
    public static let minBoxWidth: CGFloat = 320
    /// Minimum height for the selection box (ensures text/HUD visibility)
    public static let minBoxHeight: CGFloat = 70
}

// MARK: - Native Window Drag Background Area
public struct WindowDragAreaView: NSViewRepresentable {
    public let cursor: NSCursor

    public init(cursor: NSCursor = .openHand) {
        self.cursor = cursor
    }

    public func makeNSView(context: Context) -> DragNSView {
        DragNSView(cursor: cursor)
    }

    public func updateNSView(_ nsView: DragNSView, context: Context) {
        nsView.cursor = cursor
        nsView.window?.invalidateCursorRects(for: nsView)
    }

    public class DragNSView: NSView {
        var cursor: NSCursor
        private var trackingArea: NSTrackingArea?

        init(cursor: NSCursor) {
            self.cursor = cursor
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        public override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let existing = trackingArea {
                removeTrackingArea(existing)
            }
            let area = NSTrackingArea(
                rect: bounds,
                options: [.cursorUpdate, .activeAlways, .inVisibleRect, .mouseEnteredAndExited],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(area)
            self.trackingArea = area
        }

        public override func cursorUpdate(with event: NSEvent) {
            cursor.set()
        }

        public override func resetCursorRects() {
            addCursorRect(bounds, cursor: cursor)
        }

        public override func hitTest(_ point: NSPoint) -> NSView? {
            let localPoint = convert(point, from: superview)
            return bounds.contains(localPoint) ? self : nil
        }

        public override func mouseDown(with event: NSEvent) {
            if cursor == .openHand {
                NSCursor.closedHand.push()
                window?.performDrag(with: event)
                NSCursor.pop()
            } else {
                window?.performDrag(with: event)
            }
        }
    }
}

// MARK: - Native Cursor Rect Area
public struct CursorRectView: NSViewRepresentable {
    public let cursor: NSCursor

    public init(cursor: NSCursor) {
        self.cursor = cursor
    }

    public func makeNSView(context: Context) -> CursorNSView {
        CursorNSView(cursor: cursor)
    }

    public func updateNSView(_ nsView: CursorNSView, context: Context) {
        nsView.cursor = cursor
        nsView.window?.invalidateCursorRects(for: nsView)
    }

    public class CursorNSView: NSView {
        var cursor: NSCursor
        private var trackingArea: NSTrackingArea?

        init(cursor: NSCursor) {
            self.cursor = cursor
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        public override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let existing = trackingArea {
                removeTrackingArea(existing)
            }
            let area = NSTrackingArea(
                rect: bounds,
                options: [.cursorUpdate, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(area)
            self.trackingArea = area
        }

        public override func cursorUpdate(with event: NSEvent) {
            cursor.set()
        }

        public override func resetCursorRects() {
            addCursorRect(bounds, cursor: cursor)
        }
    }
}

extension View {
    public func pointingHandCursor() -> some View {
        self
            .overlay(
                CursorRectView(cursor: .pointingHand)
                    .allowsHitTesting(false)
            )
            .onHover { isInside in
                if isInside {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

// MARK: - Native Bottom-Right Resize Handle
public struct OverlayBottomRightResizeHandle: View {
    public let tintColor: Color

    public init(tintColor: Color = .cyan) {
        self.tintColor = tintColor
    }

    public var body: some View {
        ZStack {
            // Interactive AppKit resize hit-target
            BottomRightResizeNSViewRepresentable()
                .frame(width: 24, height: 24)

            // Visual handle: inset SF Symbol with subtle rounded backing
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(tintColor.opacity(0.85))
                .frame(width: 20, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.black.opacity(0.35))
                )
                .allowsHitTesting(false)
        }
        .frame(width: 24, height: 24)
    }
}

public struct BottomRightResizeNSViewRepresentable: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> BottomRightResizeNSView {
        BottomRightResizeNSView()
    }

    public func updateNSView(_ nsView: BottomRightResizeNSView, context: Context) {}
}

public class BottomRightResizeNSView: NSView {
    private var trackingArea: NSTrackingArea?

    public static var diagonalResizeCursor: NSCursor {
        let sel = NSSelectorFromString("_windowResizeNorthWestSouthEastCursor")
        if let method = NSCursor.self.method(for: sel) {
            typealias CursorFunc = @convention(c) (AnyClass, Selector) -> NSCursor
            let function = unsafeBitCast(method, to: CursorFunc.self)
            return function(NSCursor.self, sel)
        }
        return .crosshair
    }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.cursorUpdate, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        self.trackingArea = area
    }

    public override func cursorUpdate(with event: NSEvent) {
        Self.diagonalResizeCursor.set()
    }

    public override func resetCursorRects() {
        addCursorRect(bounds, cursor: Self.diagonalResizeCursor)
    }

    public override func hitTest(_ point: NSPoint) -> NSView? {
        let localPoint = convert(point, from: superview)
        return bounds.contains(localPoint) ? self : nil
    }

    public override func mouseDown(with event: NSEvent) {
        guard let window = self.window else { return }
        let initialMouseLocation = NSEvent.mouseLocation
        let initialWindowFrame = window.frame

        let minWidth: CGFloat = OverlayLayoutConstants.minBoxWidth
        let minHeight: CGFloat = OverlayLayoutConstants.minBoxHeight + OverlayLayoutConstants.headerOffset

        while true {
            guard let nextEvent = window.nextEvent(matching: [.leftMouseUp, .leftMouseDragged]) else { break }
            if nextEvent.type == .leftMouseUp {
                break
            }

            let currentMouseLocation = NSEvent.mouseLocation
            let dx = currentMouseLocation.x - initialMouseLocation.x
            let dy = currentMouseLocation.y - initialMouseLocation.y

            let newWidth = max(minWidth, initialWindowFrame.width + dx)
            let newHeight = max(minHeight, initialWindowFrame.height - dy)
            let newY = initialWindowFrame.maxY - newHeight

            let newFrame = NSRect(
                x: initialWindowFrame.origin.x,
                y: newY,
                width: newWidth,
                height: newHeight
            )

            window.setFrame(newFrame, display: true)
        }

        AppState.shared.saveCurrentProfile()
    }
}
