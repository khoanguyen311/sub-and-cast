import SwiftUI
import Combine

public struct SubtitleOverlayView: View {
    @ObservedObject var appState: AppState
    @State private var opacity: Double = 1.0
    @State private var fadeTimer: AnyCancellable?
    @State private var isTesting = false

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        if appState.isPositioningOverlays {
            positioningView
        } else {
            playbackView
        }
    }

    // MARK: - Positioning Mode (Unlocked)
    private var positioningView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Floating Header Bar floating immediately above the selection box
            HStack(spacing: 6) {
                Image(systemName: "captions.bubble")
                    .font(.system(size: 11, weight: .bold))
                Text("Subtitle Output Zone")
                    .font(.system(size: 11, weight: .semibold))

                Spacer()

                // Test Translate button
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

            // Selection Box (100% unobstructed display bounds)
            ZStack(alignment: .topLeading) {
                // Native Window Drag Area covering 100% of the dashed box
                WindowDragAreaView(cursor: .openHand)

                // Outer dashed border & subtle background tint
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.orange, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .background(Color.orange.opacity(0.05))
                    .allowsHitTesting(false)

                // Subtitle preview / placeholder
                VStack {
                    Spacer()
                    if !appState.lastTranslatedText.isEmpty {
                        subtitleCard
                    } else {
                        Text("Translated subtitles will appear here…")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.black.opacity(0.75))
                                    .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
                            )
                            .padding(12)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)

                // 4 Corner Resizers
                cornerResizers
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onReceive(appState.$lastTranslatedText) { newText in
            guard !newText.isEmpty else { return }
            opacity = 1.0
            resetFadeTimer()
        }
    }

    // MARK: - Playback Mode (Locked / Active scanning)
    private var playbackView: some View {
        VStack {
            Spacer()
            if !appState.lastTranslatedText.isEmpty {
                subtitleCard
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .onReceive(appState.$lastTranslatedText) { newText in
            guard !newText.isEmpty else { return }
            opacity = 1.0
            resetFadeTimer()
        }
    }

    // MARK: - Subtitle HUD Card
    private var subtitleCard: some View {
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
    }

    // MARK: - Exclusive Bottom-Right Resize Handle
    private var cornerResizers: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                OverlayBottomRightResizeHandle(tintColor: .orange)
                    .padding([.bottom, .trailing], 8)
            }
        }
    }

    // MARK: - Test Translate
    private func triggerTestTranslate() {
        guard !isTesting else { return }
        isTesting = true
        appState.triggerSnapshot()

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
