import SwiftUI

public struct SourceCaptureOverlayView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        if !appState.isLocked {
            VStack(alignment: .leading, spacing: 0) {
                // Floating Header Bar floating immediately above the selection box
                HStack(spacing: 6) {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 11, weight: .bold))
                    Text("OCR Capture Zone")
                        .font(.system(size: 11, weight: .semibold))

                    if appState.isOCRActive {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                    }

                    Spacer()

                    // Settings toggle button
                    Button(action: {
                        OverlayWindowManager.shared.toggleSettings(appState: appState)
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "gearshape")
                            Text("Settings")
                        }
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()

                    Button(action: {
                        appState.finishPositioningOverlays()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Save & Done")
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.4))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    ZStack {
                        Color.black.opacity(0.8)
                        WindowDragAreaView(cursor: .arrow)
                    }
                )
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 1)
                .frame(height: 26)
                .padding(.bottom, 6)
                .frame(height: OverlayLayoutConstants.headerOffset, alignment: .topLeading)

                // Selection Box (100% unobstructed capture bounds)
                ZStack(alignment: .topLeading) {
                    // Transparent Drag Area covering 100% of the dashed box
                    WindowDragAreaView(cursor: .openHand)

                    // Dashed border & background tint
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            appState.isOCRActive ? Color.green : Color.cyan,
                            style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.cyan.opacity(0.06))
                        )
                        .allowsHitTesting(false)

                    // Exclusive Bottom-Right Resize Handle with 8pt inset padding
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            OverlayBottomRightResizeHandle(tintColor: .cyan)
                                .padding([.bottom, .trailing], 8)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
