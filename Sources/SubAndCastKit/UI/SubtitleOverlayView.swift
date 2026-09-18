import SwiftUI
import Combine

public struct SubtitleOverlayView: View {
    @ObservedObject var appState: AppState
    @State private var opacity: Double = 1.0
    @State private var fadeTimer: AnyCancellable?
    @State private var isHoveringBody = false
    @State private var isTesting = false

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            // Setup-mode border and chrome
            if !appState.isLocked {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.orange, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .background(Color.orange.opacity(0.05))

                // Header toolbar
                HStack(spacing: 6) {
                    Image(systemName: "captions.bubble")
                        .font(.system(size: 11, weight: .bold))
                    Text("Subtitle Output Zone")
                        .font(.system(size: 11, weight: .semibold))

                    Spacer()

                    // Test Translate button — runs a snapshot + translate immediately
                    Button(action: {
                        triggerTestTranslate()
                    }) {
                        HStack(spacing: 3) {
                            if isTesting {
                                Image(systemName: "arrow.2.circlepath")
                                    .rotationEffect(.degrees(isTesting ? 360 : 0))
                                    .animation(.linear(duration: 0.8).repeatForever(autoreverses: false), value: isTesting)
                            } else {
                                Image(systemName: "play.circle")
                            }
                            Text("Test")
                        }
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.35))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .disabled(isTesting)
                    .onHover { inside in
                        if inside {
                            NSCursor.pointingHand.set()
                        } else if isHoveringBody {
                            NSCursor.openHand.set()
                        } else {
                            NSCursor.arrow.set()
                        }
                    }

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
                    .onHover { inside in
                        if inside {
                            NSCursor.pointingHand.set()
                        } else if isHoveringBody {
                            NSCursor.openHand.set()
                        } else {
                            NSCursor.arrow.set()
                        }
                    }
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
                    Text("Translated subtitles will appear here…")
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
        // Show open-hand cursor to hint this zone is draggable
        .onHover { inside in
            isHoveringBody = inside
            if !appState.isLocked {
                if inside {
                    NSCursor.openHand.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
        }
    }

    // MARK: - Test Translate

    private func triggerTestTranslate() {
        guard !isTesting else { return }
        isTesting = true
        appState.triggerSnapshot()

        // Reset spinner state after a short delay regardless of result
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            isTesting = false
        }
    }

    // MARK: - Fade Timer

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
