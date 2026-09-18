import SwiftUI

public struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var newProfileName: String = ""

    private let supportedLanguages = [
        ("ja", "Japanese (日本語)"),
        ("zh-Hans", "Chinese Simplified (简体中文)"),
        ("zh-Hant", "Chinese Traditional (繁體中文)"),
        ("ko", "Korean (한국어)"),
        ("en", "English"),
        ("vi", "Vietnamese (Tiếng Việt)"),
        ("fr", "French (Français)"),
        ("de", "German (Deutsch)"),
        ("es", "Spanish (Español)")
    ]

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            HStack {
                Text("Sub & Cast Settings")
                    .font(.headline)
                Spacer()
                Text(appState.statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            Form {
                // MARK: - Game Profiles
                Section(header: Text("Game Profiles").font(.subheadline).bold()) {
                    HStack {
                        Picker("Active Profile", selection: Binding(
                            get: { appState.currentProfile.id },
                            set: { id in
                                if let found = appState.profiles.first(where: { $0.id == id }) {
                                    appState.selectProfile(found)
                                }
                            }
                        )) {
                            ForEach(appState.profiles) { profile in
                                Text(profile.name).tag(profile.id)
                            }
                        }

                        if appState.profiles.count > 1 {
                            Button("Delete") {
                                appState.deleteProfile(id: appState.currentProfile.id)
                            }
                        }
                    }

                    HStack {
                        TextField("New Profile Name", text: $newProfileName)
                        Button("Add Profile") {
                            let trimmed = newProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty {
                                appState.addNewProfile(name: trimmed)
                                newProfileName = ""
                            }
                        }
                        .disabled(newProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                Divider().padding(.vertical, 4)

                // MARK: - Languages
                Section(header: Text("Translation & Languages").font(.subheadline).bold()) {
                    Picker("Source Language (Game)", selection: $appState.currentProfile.sourceLanguage) {
                        ForEach(supportedLanguages, id: \.0) { code, name in
                            Text(name).tag(code)
                        }
                    }

                    Picker("Target Language (Subtitles)", selection: $appState.currentProfile.targetLanguage) {
                        ForEach(supportedLanguages, id: \.0) { code, name in
                            Text(name).tag(code)
                        }
                    }

                    Picker("Translation Provider", selection: $appState.currentProfile.translationEngineType) {
                        Text("Google Translate (Free Web API)").tag("google_free")
                        Text("Google Gemini Flash (API Key)").tag("gemini")
                        Text("Apple Native Translation").tag("apple")
                    }

                    if appState.currentProfile.translationEngineType == "gemini" {
                        SecureField("Gemini API Key", text: Binding(
                            get: { appState.currentProfile.geminiApiKey ?? "" },
                            set: { appState.currentProfile.geminiApiKey = $0 }
                        ))
                    }
                }

                Divider().padding(.vertical, 4)

                // MARK: - Capture & Timing
                Section(header: Text("Capture & Timing").font(.subheadline).bold()) {
                    HStack {
                        Text("Capture Interval: \(String(format: "%.1f", appState.currentProfile.captureIntervalSeconds))s")
                        Slider(value: $appState.currentProfile.captureIntervalSeconds, in: 0.3...3.0, step: 0.1)
                    }

                    HStack {
                        Text("Subtitle Fadeout: \(String(format: "%.1f", appState.currentProfile.fadeTimeoutSeconds))s")
                        Slider(value: $appState.currentProfile.fadeTimeoutSeconds, in: 1.0...10.0, step: 0.5)
                    }
                }

                Divider().padding(.vertical, 4)

                // MARK: - Subtitle Appearance
                Section(header: Text("Subtitle Appearance").font(.subheadline).bold()) {
                    HStack {
                        Text("Font Size: \(Int(appState.currentProfile.fontSize))pt")
                        Slider(value: $appState.currentProfile.fontSize, in: 14...36, step: 1)
                    }

                    HStack {
                        Text("Backdrop Opacity: \(Int(appState.currentProfile.backgroundOpacity * 100))%")
                        Slider(value: $appState.currentProfile.backgroundOpacity, in: 0.2...1.0, step: 0.05)
                    }
                }
            }
            .formStyle(.grouped)
            .onChange(of: appState.currentProfile) { _, _ in
                appState.saveCurrentProfile()
            }

            Divider()

            // Action Buttons
            HStack(spacing: 12) {
                Button(action: {
                    appState.triggerSnapshot()
                }) {
                    Label("Capture Snapshot", systemImage: "camera")
                }

                Button(action: {
                    appState.toggleScanning()
                }) {
                    Label(
                        appState.isScanning ? "Pause Auto-Scan" : "Start Auto-Scan",
                        systemImage: appState.isScanning ? "pause.fill" : "play.fill"
                    )
                }

                Spacer()

                Button(action: {
                    appState.toggleLock()
                }) {
                    Label(
                        appState.isLocked ? "Unlock Overlays (Edit)" : "Lock Overlays (Click-Through)",
                        systemImage: appState.isLocked ? "lock.fill" : "lock.open.fill"
                    )
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 500, height: 580)
    }
}
