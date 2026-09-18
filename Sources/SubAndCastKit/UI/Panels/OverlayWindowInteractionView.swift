import AppKit
import SwiftUI

public enum OverlayResizeCorner {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    public var cursor: NSCursor {
        switch self {
        case .topLeft, .bottomRight:
            let sel = NSSelectorFromString("_windowResizeNorthWestSouthEastCursor")
            if let method = NSCursor.self.method(for: sel) {
                typealias CursorFunc = @convention(c) (AnyClass, Selector) -> NSCursor
                let function = unsafeBitCast(method, to: CursorFunc.self)
                return function(NSCursor.self, sel)
            }
            return .crosshair
        case .topRight, .bottomLeft:
            let sel = NSSelectorFromString("_windowResizeNorthEastSouthWestCursor")
            if let method = NSCursor.self.method(for: sel) {
                typealias CursorFunc = @convention(c) (AnyClass, Selector) -> NSCursor
                let function = unsafeBitCast(method, to: CursorFunc.self)
                return function(NSCursor.self, sel)
            }
            return .crosshair
        }
    }
}

// MARK: - Native Window Drag Background Area
public struct WindowDragAreaView: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> DragNSView {
        DragNSView()
    }

    public func updateNSView(_ nsView: DragNSView, context: Context) {}

    public class DragNSView: NSView {
        public override func resetCursorRects() {
            addCursorRect(bounds, cursor: .openHand)
        }

        public override func mouseDown(with event: NSEvent) {
            NSCursor.closedHand.push()
            window?.performDrag(with: event)
            NSCursor.pop()
        }
    }
}

// MARK: - Native Corner Resize Handle
public struct OverlayCornerResizeView: NSViewRepresentable {
    let corner: OverlayResizeCorner

    public init(corner: OverlayResizeCorner) {
        self.corner = corner
    }

    public func makeNSView(context: Context) -> CornerNSView {
        CornerNSView(corner: corner)
    }

    public func updateNSView(_ nsView: CornerNSView, context: Context) {
        nsView.corner = corner
    }

    public class CornerNSView: NSView {
        var corner: OverlayResizeCorner

        init(corner: OverlayResizeCorner) {
            self.corner = corner
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        public override func resetCursorRects() {
            addCursorRect(bounds, cursor: corner.cursor)
        }

        public override func mouseDown(with event: NSEvent) {
            guard let window = self.window else { return }
            let initialMouseLocation = NSEvent.mouseLocation
            let initialWindowFrame = window.frame

            while true {
                guard let nextEvent = window.nextEvent(matching: [.leftMouseUp, .leftMouseDragged]) else { break }
                if nextEvent.type == .leftMouseUp {
                    break
                }

                let currentMouseLocation = NSEvent.mouseLocation
                let dx = currentMouseLocation.x - initialMouseLocation.x
                let dy = currentMouseLocation.y - initialMouseLocation.y

                var newFrame = initialWindowFrame
                let minWidth: CGFloat = 120
                let minHeight: CGFloat = 50

                switch corner {
                case .bottomRight:
                    let newWidth = max(minWidth, initialWindowFrame.width + dx)
                    let newHeight = max(minHeight, initialWindowFrame.height - dy)
                    let newY = initialWindowFrame.maxY - newHeight
                    newFrame = NSRect(x: initialWindowFrame.origin.x, y: newY, width: newWidth, height: newHeight)

                case .bottomLeft:
                    let newWidth = max(minWidth, initialWindowFrame.width - dx)
                    let newX = initialWindowFrame.maxX - newWidth
                    let newHeight = max(minHeight, initialWindowFrame.height - dy)
                    let newY = initialWindowFrame.maxY - newHeight
                    newFrame = NSRect(x: newX, y: newY, width: newWidth, height: newHeight)

                case .topRight:
                    let newWidth = max(minWidth, initialWindowFrame.width + dx)
                    let newHeight = max(minHeight, initialWindowFrame.height + dy)
                    newFrame = NSRect(x: initialWindowFrame.origin.x, y: initialWindowFrame.origin.y, width: newWidth, height: newHeight)

                case .topLeft:
                    let newWidth = max(minWidth, initialWindowFrame.width - dx)
                    let newX = initialWindowFrame.maxX - newWidth
                    let newHeight = max(minHeight, initialWindowFrame.height + dy)
                    newFrame = NSRect(x: newX, y: initialWindowFrame.origin.y, width: newWidth, height: newHeight)
                }

                window.setFrame(newFrame, display: true)
            }
        }
    }
}
