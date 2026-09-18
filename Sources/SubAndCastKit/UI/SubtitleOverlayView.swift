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

                // Full-sized backdrop background matching dashed frame bounds
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(appState.currentProfile.backgroundOpacity))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.orange, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    )
                    .allowsHitTesting(false)

                // Centered subtitle content
                VStack {
                    Spacer(minLength: 0)
                    Text(!appState.lastTranslatedText.isEmpty ? appState.lastTranslatedText : "Translated subtitles will appear here…")
                        .font(.system(size: appState.currentProfile.fontSize, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.9), radius: 2, x: 0, y: 1)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)

                // Exclusive Bottom-Right Resize Handle
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
        ZStack {
            if !appState.lastTranslatedText.isEmpty {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(appState.currentProfile.backgroundOpacity))
                    .shadow(color: .black.opacity(0.5), radius: 6, x: 0, y: 3)

                VStack {
                    Spacer(minLength: 0)
                    Text(appState.lastTranslatedText)
                        .font(.system(size: appState.currentProfile.fontSize, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.9), radius: 2, x: 0, y: 1)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(opacity)
        .animation(.easeInOut(duration: 0.3), value: opacity)
        .allowsHitTesting(false)
        .onReceive(appState.$lastTranslatedText) { newText in
            guard !newText.isEmpty else { return }
            opacity = 1.0
            resetFadeTimer()
        }
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
