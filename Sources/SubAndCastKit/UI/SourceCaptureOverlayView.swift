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

                    // 4 Corner Resizers
                    // 1. Top-Left
                    VStack {
                        HStack {
                            OverlayCornerResizeView(corner: .topLeft)
                                .frame(width: 22, height: 22)
                            Spacer()
                        }
                        Spacer()
                    }

                    // 2. Top-Right
                    VStack {
                        HStack {
                            Spacer()
                            OverlayCornerResizeView(corner: .topRight)
                                .frame(width: 22, height: 22)
                        }
                        Spacer()
                    }

                    // 3. Bottom-Left
                    VStack {
                        Spacer()
                        HStack {
                            OverlayCornerResizeView(corner: .bottomLeft)
                                .frame(width: 22, height: 22)
                            Spacer()
                        }
                    }

                    // 4. Bottom-Right (with visual corner indicator)
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            ZStack(alignment: .bottomTrailing) {
                                OverlayCornerResizeView(corner: .bottomRight)
                                    .frame(width: 22, height: 22)

                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(.cyan.opacity(0.8))
                                    .padding(4)
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
