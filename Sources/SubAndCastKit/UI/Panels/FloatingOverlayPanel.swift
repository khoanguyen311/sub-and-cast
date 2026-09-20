import AppKit
import SwiftUI

public class FloatingOverlayPanel: NSPanel {
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )

        self.level = .screenSaver
        self.hidesOnDeactivate = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.isMovableByWindowBackground = true
        self.acceptsMouseMovedEvents = true
    }

    override public var canBecomeKey: Bool {
        // Can only become key during unlocked / positioning mode to process keyboard shortcuts
        return !ignoresMouseEvents
    }
    override public var canBecomeMain: Bool { false }

    public func setLocked(_ locked: Bool) {
        self.ignoresMouseEvents = locked
        self.isMovableByWindowBackground = !locked
    }
}

public final class AssistiveTouchPanel: NSPanel {
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .screenSaver
        self.hidesOnDeactivate = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.isMovableByWindowBackground = false
        self.acceptsMouseMovedEvents = true
        self.ignoresMouseEvents = false
    }

    override public var canBecomeKey: Bool { false }
    override public var canBecomeMain: Bool { false }
}

