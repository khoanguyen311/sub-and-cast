import SwiftUI

public struct GeneralSettingsView: View {
    @ObservedObject var appState: AppState
    @State private var newProfileName: String = ""

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
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
                LabeledContent("Auto-Scan (Start / Pause)") {
                    Text("⌘⇧S").font(.callout.monospaced()).foregroundColor(.secondary)
                }
                LabeledContent("Snapshot Capture") {
                    Text("⌘⇧T").font(.callout.monospaced()).foregroundColor(.secondary)
                }
                LabeledContent("Position / Lock Overlays") {
                    Text("⌘⇧L").font(.callout.monospaced()).foregroundColor(.secondary)
                }
            } header: {
                Text("Global Hotkeys (In-Game)")
            }
        }
        .formStyle(.grouped)
    }
}
