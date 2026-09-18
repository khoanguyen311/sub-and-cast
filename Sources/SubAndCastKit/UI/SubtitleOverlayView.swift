import SwiftUI
import Combine

public struct SubtitleOverlayView: View {
    @ObservedObject var appState: AppState
    @State private var opacity: Double = 1.0
    @State private var fadeTimer: AnyCancellable?

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            // Container box styling in setup mode
            if !appState.isLocked {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.orange, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .background(Color.orange.opacity(0.05))

                // Header tag
                HStack(spacing: 6) {
                    Image(systemName: "captions.bubble")
                        .font(.system(size: 11, weight: .bold))
                    Text("Subtitle Output Zone")
                        .font(.system(size: 11, weight: .semibold))

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
                        .background(Color.orange.opacity(0.3))
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
            }

            // Subtitle text area
            VStack {
                Spacer()

                if !appState.lastTranslatedText.isEmpty {
                    Text(appState.lastTranslatedText)
                        .font(.system(size: appState.currentProfile.fontSize, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(appState.currentProfile.backgroundOpacity))
                                .shadow(color: .black.opacity(0.5), radius: 6, x: 0, y: 3)
                        )
                        .opacity(opacity)
                        .animation(.easeInOut(duration: 0.3), value: opacity)
                        .padding(8)
                } else if !appState.isLocked {
                    Text("Translated subtitles will appear here...")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(12)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onReceive(appState.$lastTranslatedText) { newText in
            guard !newText.isEmpty else { return }
            opacity = 1.0
            resetFadeTimer()
        }
    }

    private func resetFadeTimer() {
        fadeTimer?.cancel()
        let timeout = appState.currentProfile.fadeTimeoutSeconds
        guard timeout > 0 else { return }

        fadeTimer = Just(())
            .delay(for: .seconds(timeout), scheduler: RunLoop.main)
            .sink { _ in
                withAnimation(.easeOut(duration: 0.8)) {
                    opacity = 0.0
                }
            }
    }
}
