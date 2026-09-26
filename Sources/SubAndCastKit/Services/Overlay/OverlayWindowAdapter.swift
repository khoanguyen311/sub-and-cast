import Foundation
import CoreGraphics

/// Abstraction for window panels to allow headless test verification without NSWindow/NSPanel.
@MainActor
public protocol OverlayWindowAdapter: AnyObject {
    var frame: CGRect { get }
    var isVisible: Bool { get }
    var isKeyWindow: Bool { get }

    func setFrame(_ frame: CGRect, display: Bool)
    func orderFrontRegardless()
    func orderOut(_ sender: Any?)
    func makeKey()
    func setLocked(_ locked: Bool)
}

/// Headless test double tracking window adapter frame and visibility mutations.
@MainActor
public final class MockOverlayWindowAdapter: OverlayWindowAdapter {
    public var frame: CGRect
    public var isVisible: Bool = false
    public var isKeyWindow: Bool = false
    public var isLocked: Bool = false

    public init(frame: CGRect = .zero) {
        self.frame = frame
    }

    public func setFrame(_ frame: CGRect, display: Bool) {
        self.frame = frame
    }

    public func orderFrontRegardless() {
        self.isVisible = true
    }

    public func orderOut(_ sender: Any?) {
        self.isVisible = false
        self.isKeyWindow = false
    }

    public func makeKey() {
        self.isKeyWindow = true
    }

    public func setLocked(_ locked: Bool) {
        self.isLocked = locked
    }
}
