import SwiftUI

public struct SourceCaptureOverlayView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Outer dashed border
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        appState.isLocked
                            ? Color.clear
                            : (appState.isOCRActive ? Color.green : Color.cyan),
                        style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(appState.isLocked ? Color.clear : Color.cyan.opacity(0.06))
                    )

                if !appState.isLocked {
                    // Header tag
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
                            appState.toggleLock()
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "lock.open")
                                Text("Lock")
                            }
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.cyan.opacity(0.3))
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.75))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(4)

                    // Bottom-right resize grip indicator
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 10))
                                .foregroundColor(.cyan)
                                .padding(4)
                        }
                    }
                }
            }
        }
    }
}
