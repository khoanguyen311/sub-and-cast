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
            TabView {
                generalTab
                    .tabItem {
                        Label("General", systemImage: "gearshape")
                    }

                translationTab
                    .tabItem {
                        Label("Translation", systemImage: "character.bubble")
                    }

                captureAndOverlaysTab
                    .tabItem {
                        Label("Capture & Overlays", systemImage: "viewfinder.circle")
                    }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)

            Divider()

            footerBar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 500, height: 420)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: appState.currentProfile) { _, _ in
            appState.saveCurrentProfile()
        }
    }

    // MARK: - Tab 1: General
    private var generalTab: some View {
        Form {
            Section {
                HStack(spacing: 8) {
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
                        Button(role: .destructive) {
                            appState.deleteProfile(id: appState.currentProfile.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .help("Delete active profile")
                    }
                }

                LabeledContent("New Profile") {
                    HStack(spacing: 8) {
                        TextField("Profile Name", text: $newProfileName)
                            .textFieldStyle(.roundedBorder)

                        Button("Add") {
                            let trimmed = newProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty {
                                appState.addNewProfile(name: trimmed)
                                newProfileName = ""
                            }
                        }
                        .disabled(newProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            } header: {
                Text("Game Profiles")
            }

            Section {
                LabeledContent("Auto-Scan") {
                    Text("⌘S").font(.callout.monospaced()).foregroundColor(.secondary)
                }
                LabeledContent("Snapshot Capture") {
                    Text("⌘T").font(.callout.monospaced()).foregroundColor(.secondary)
                }
                LabeledContent("Toggle Overlay Lock") {
                    Text("⌘L").font(.callout.monospaced()).foregroundColor(.secondary)
                }
            } header: {
                Text("Keyboard Shortcuts")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Tab 2: Translation
    private var translationTab: some View {
        Form {
            Section {
                Picker("Source Language", selection: $appState.currentProfile.sourceLanguage) {
                    ForEach(supportedLanguages, id: \.0) { code, name in
                        Text(name).tag(code)
                    }
                }

                Picker("Target Language", selection: $appState.currentProfile.targetLanguage) {
                    ForEach(supportedLanguages, id: \.0) { code, name in
                        Text(name).tag(code)
                    }
                }
            } header: {
                Text("Languages")
            }

            Section {
                LabeledContent("Translation Engine") {
                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                            .foregroundColor(.blue)
                        Text("Google Translate (Free Web API)")
                            .foregroundColor(.secondary)
                    }
                }

                LabeledContent("Vision OCR Engine") {
                    HStack(spacing: 6) {
                        Image(systemName: "cpu")
                            .foregroundColor(.green)
                        Text("Apple Neural Engine (On-Device)")
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Engines")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Tab 3: Capture & Overlays
    private var captureAndOverlaysTab: some View {
        Form {
            Section {
                LabeledContent("Capture Interval") {
                    HStack(spacing: 12) {
                        Slider(value: $appState.currentProfile.captureIntervalSeconds, in: 0.3...3.0, step: 0.1)
                        Text(String(format: "%.1fs", appState.currentProfile.captureIntervalSeconds))
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                            .frame(width: 45, alignment: .trailing)
                    }
                }

                LabeledContent("Subtitle Fadeout") {
                    HStack(spacing: 12) {
                        Slider(value: $appState.currentProfile.fadeTimeoutSeconds, in: 1.0...10.0, step: 0.5)
                        Text(String(format: "%.1fs", appState.currentProfile.fadeTimeoutSeconds))
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                            .frame(width: 45, alignment: .trailing)
                    }
                }
            } header: {
                Text("Scan Timings")
            }

            Section {
                LabeledContent("Font Size") {
                    HStack(spacing: 12) {
                        Slider(value: $appState.currentProfile.fontSize, in: 14...36, step: 1)
                        Text("\(Int(appState.currentProfile.fontSize)) pt")
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                            .frame(width: 45, alignment: .trailing)
                    }
                }

                LabeledContent("Backdrop Opacity") {
                    HStack(spacing: 12) {
                        Slider(value: $appState.currentProfile.backgroundOpacity, in: 0.2...1.0, step: 0.05)
                        Text("\(Int(appState.currentProfile.backgroundOpacity * 100))%")
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                            .frame(width: 45, alignment: .trailing)
                    }
                }
            } header: {
                Text("HUD Appearance")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Footer Status & Actions
    private var footerBar: some View {
        HStack(spacing: 10) {
            // Apple-style status indicator badge
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: statusColor.opacity(0.6), radius: appState.isScanning ? 3 : 0)

                Text(appState.statusMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Compact runtime trigger buttons with SF symbols (no text truncation)
            HStack(spacing: 8) {
                Button {
                    appState.triggerSnapshot()
                } label: {
                    Label("Snapshot", systemImage: "camera")
                }
                .controlSize(.regular)
                .help("Capture and translate a single frame (⌘T)")

                Button {
                    appState.toggleScanning()
                } label: {
                    Label(
                        appState.isScanning ? "Pause" : "Scan",
                        systemImage: appState.isScanning ? "pause.fill" : "play.fill"
                    )
                }
                .controlSize(.regular)
                .help(appState.isScanning ? "Pause auto-scan (⌘S)" : "Start continuous auto-scan (⌘S)")

                Button {
                    appState.toggleLock()
                } label: {
                    Label(
                        appState.isLocked ? "Unlock" : "Lock",
                        systemImage: appState.isLocked ? "lock.fill" : "lock.open.fill"
                    )
                }
                .controlSize(.regular)
                .help(appState.isLocked ? "Unlock overlays to drag/resize (⌘L)" : "Lock overlays to pass clicks to game (⌘L)")
            }
        }
    }

    private var statusColor: Color {
        if appState.isOCRActive {
            return .orange
        } else if appState.isScanning {
            return .green
        } else {
            return .gray
        }
    }
}
