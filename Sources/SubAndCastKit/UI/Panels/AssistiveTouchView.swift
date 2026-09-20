import SwiftUI
import AppKit

public struct AssistiveTouchView: View {
    @ObservedObject var appState: AppState
    @State private var opacity: Double = 1.0
    @State private var idleTimer: Task<Void, Never>?
    @State private var isHovering: Bool = false
    @State private var isPressed: Bool = false
    @State private var clickCount: Int = 0
    @State private var singleClickTimer: Task<Void, Never>?
    @State private var longPressTimer: Task<Void, Never>?
    @State private var didLongPress: Bool = false
    @State private var dragStartLocation: NSPoint?
    @State private var hasDragged: Bool = false

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        ZStack {
            if appState.isAssistiveQuickMenuOpen {
                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appState.isAssistiveQuickMenuOpen = false
                        resetIdleTimer()
                    }
                quickMenuView
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            } else {
                buttonBody
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(appState.isAssistiveQuickMenuOpen ? 1.0 : opacity)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: appState.isAssistiveQuickMenuOpen)
        .animation(.easeInOut(duration: 0.3), value: opacity)
        .onAppear {
            resetIdleTimer()
        }
        .onDisappear {
            idleTimer?.cancel()
            singleClickTimer?.cancel()
            longPressTimer?.cancel()
        }
        .onChange(of: appState.assistiveTouchIdleOpacity) { _, newOpacity in
            if !isHovering && !isPressed && !appState.isAssistiveQuickMenuOpen {
                withAnimation(.easeInOut(duration: 0.3)) {
                    opacity = newOpacity
                }
            }
        }
    }

    // MARK: - Assistive Touch Button
    private var buttonBody: some View {
        let size = appState.assistiveTouchSize
        let ringSize = size * 0.62
        let dotSize = size * 0.38
        let ringLineWidth = max(1.5, size * 0.048)
        let borderLineWidth = max(1.0, size * 0.03)
        let shadowRadius = max(3.0, size * 0.11)

        return ZStack {
            // Dark Frosted Glass Circle
            Circle()
                .fill(Color.black.opacity(0.68))
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.35), lineWidth: borderLineWidth)
                )
                .shadow(color: Color.black.opacity(0.45), radius: shadowRadius, x: 0, y: 3)

            // Inner AssistiveTouch Rings
            Circle()
                .stroke(Color.white.opacity(0.55), lineWidth: ringLineWidth)
                .frame(width: ringSize, height: ringSize)

            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: dotSize, height: dotSize)
                .shadow(color: Color.white.opacity(0.4), radius: shadowRadius * 0.5)
        }
        .frame(width: size, height: size)
        .scaleEffect(isPressed ? 0.92 : (isHovering ? 1.05 : 1.0))
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovering)
        .overlay(
            AssistiveTouchGestureDetector(
                onHoverChanged: { hovering in
                    isHovering = hovering
                    if hovering {
                        opacity = 1.0
                        idleTimer?.cancel()
                    } else if !appState.isAssistiveQuickMenuOpen {
                        resetIdleTimer()
                    }
                },
                onMouseDown: {
                    handleMouseDown()
                },
                onMouseDragged: { deltaX, deltaY in
                    handleMouseDragged(deltaX: deltaX, deltaY: deltaY)
                },
                onMouseUp: {
                    handleMouseUp()
                }
            )
        )
    }

    // MARK: - Quick Action Menu
    private var quickMenuView: some View {
        VStack(spacing: 12) {
            // Header with title and close
            HStack {
                Text("Sub & Cast")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
                Button {
                    appState.isAssistiveQuickMenuOpen = false
                    resetIdleTimer()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            // 2x2 Action Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                // 1. One-Time Scan
                quickActionButton(
                    icon: "viewfinder",
                    title: "Scan Once",
                    color: .cyan
                ) {
                    appState.isAssistiveQuickMenuOpen = false
                    appState.triggerOneTimeScan()
                    resetIdleTimer()
                }

                // 2. Toggle Auto-Scan
                quickActionButton(
                    icon: appState.isScanning ? "pause.circle.fill" : "play.circle.fill",
                    title: appState.isScanning ? "Pause Scan" : "Auto-Scan",
                    color: appState.isScanning ? .yellow : .green
                ) {
                    appState.isAssistiveQuickMenuOpen = false
                    appState.toggleScanning()
                    resetIdleTimer()
                }

                // 3. Position Overlays
                quickActionButton(
                    icon: "hand.draw",
                    title: appState.isPositioningOverlays ? "Save Zones" : "Move Zones",
                    color: .orange
                ) {
                    appState.isAssistiveQuickMenuOpen = false
                    appState.toggleLock()
                    resetIdleTimer()
                }

                // 4. Preferences
                quickActionButton(
                    icon: "gearshape.fill",
                    title: "Preferences",
                    color: .purple
                ) {
                    appState.isAssistiveQuickMenuOpen = false
                    OverlayWindowManager.shared.showSettings(appState: appState)
                    resetIdleTimer()
                }
            }
        }
        .padding(14)
        .frame(width: 200)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.82))
                .shadow(color: Color.black.opacity(0.6), radius: 14, x: 0, y: 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 1.5)
                )
        )
    }

    private func quickActionButton(
        icon: String,
        title: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.25))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(color)
                }
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Gesture Handling Logic
    private func handleMouseDown() {
        isPressed = true
        hasDragged = false
        didLongPress = false
        opacity = 1.0
        idleTimer?.cancel()

        // Start long-press timer (0.45s)
        longPressTimer?.cancel()
        longPressTimer = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled, !hasDragged else { return }
            didLongPress = true
            isPressed = false
            singleClickTimer?.cancel()
            clickCount = 0
            appState.executeAssistiveAction(appState.assistiveTouchLongPress)
        }
    }

    private func handleMouseDragged(deltaX: CGFloat, deltaY: CGFloat) {
        if abs(deltaX) > 1 || abs(deltaY) > 1 {
            hasDragged = true
            longPressTimer?.cancel()
            singleClickTimer?.cancel()
            clickCount = 0
        }

        // Move the floating window
        OverlayWindowManager.shared.moveAssistiveTouch(deltaX: deltaX, deltaY: deltaY)
    }

    private func handleMouseUp() {
        isPressed = false
        longPressTimer?.cancel()

        guard !hasDragged, !didLongPress else {
            resetIdleTimer()
            return
        }

        clickCount += 1

        if clickCount == 1 {
            singleClickTimer?.cancel()
            singleClickTimer = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 260_000_000)
                guard !Task.isCancelled else { return }
                if clickCount == 1 {
                    clickCount = 0
                    appState.executeAssistiveAction(appState.assistiveTouchSingleClick)
                    resetIdleTimer()
                }
            }
        } else if clickCount >= 2 {
            singleClickTimer?.cancel()
            clickCount = 0
            appState.executeAssistiveAction(appState.assistiveTouchDoubleClick)
            resetIdleTimer()
        }
    }

    // MARK: - Idle Timer
    private func resetIdleTimer() {
        idleTimer?.cancel()
        idleTimer = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds idle
            guard !Task.isCancelled, !isHovering, !appState.isAssistiveQuickMenuOpen else { return }
            withAnimation(.easeInOut(duration: 0.6)) {
                opacity = appState.assistiveTouchIdleOpacity
            }
        }
    }
}

// MARK: - Native Mouse Event Interceptor
private struct AssistiveTouchGestureDetector: NSViewRepresentable {
    let onHoverChanged: (Bool) -> Void
    let onMouseDown: () -> Void
    let onMouseDragged: (CGFloat, CGFloat) -> Void
    let onMouseUp: () -> Void

    func makeNSView(context: Context) -> EventTrackingView {
        let view = EventTrackingView()
        view.onHoverChanged = onHoverChanged
        view.onMouseDown = onMouseDown
        view.onMouseDragged = onMouseDragged
        view.onMouseUp = onMouseUp
        return view
    }

    func updateNSView(_ nsView: EventTrackingView, context: Context) {
        nsView.onHoverChanged = onHoverChanged
        nsView.onMouseDown = onMouseDown
        nsView.onMouseDragged = onMouseDragged
        nsView.onMouseUp = onMouseUp
    }
}

private final class EventTrackingView: NSView {
    var onHoverChanged: ((Bool) -> Void)?
    var onMouseDown: (() -> Void)?
    var onMouseDragged: ((CGFloat, CGFloat) -> Void)?
    var onMouseUp: (() -> Void)?
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChanged?(false)
    }

    override func mouseDown(with event: NSEvent) {
        onMouseDown?()
    }

    override func mouseDragged(with event: NSEvent) {
        onMouseDragged?(event.deltaX, -event.deltaY)
    }

    override func mouseUp(with event: NSEvent) {
        onMouseUp?()
    }
}
