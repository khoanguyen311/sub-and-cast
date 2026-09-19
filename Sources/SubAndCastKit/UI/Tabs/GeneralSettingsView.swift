import SwiftUI

public struct GeneralSettingsView: View {
    @ObservedObject var appState: AppState
    @ObservedObject private var hotkeyManager = GlobalHotkeyManager.shared
    @State private var showingAddPopover: Bool = false
    @State private var showingDeleteAlert: Bool = false
    @State private var newProfileName: String = ""
    @FocusState private var isNameFieldFocused: Bool

    public init(appState: AppState) {
        self.appState = appState
    }

    private var isDeleteDisabled: Bool {
        appState.profiles.count <= 1 || appState.currentProfile.name == "Default Game"
    }

    public var body: some View {
        Form {
            Section {
                // Consolidated single row for Active Profile
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

                    // Inline + / - button group
                    HStack(spacing: 4) {
                        Button {
                            newProfileName = ""
                            showingAddPopover = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .help("Add new game profile")
                        .popover(isPresented: $showingAddPopover, arrowEdge: .bottom) {
                            addProfilePopover
                        }

                        Button {
                            showingDeleteAlert = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .help(isDeleteDisabled ? "Cannot delete the default profile" : "Delete active profile")
                        .disabled(isDeleteDisabled)
                        .alert("Delete Profile?", isPresented: $showingDeleteAlert) {
                            Button("Delete", role: .destructive) {
                                appState.deleteProfile(id: appState.currentProfile.id)
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("Are you sure you want to delete \"\(appState.currentProfile.name)\"? This action cannot be undone.")
                        }
                    }
                }
            } header: {
                Text("Game Profiles")
            }

            // MARK: - Global Shortcuts
            Section {
                HStack {
                    Text("Toggle Auto Scan")
                    Spacer()
                    ShortcutRecorderView(
                        hotkey: $hotkeyManager.toggleScanHotkey,
                        onSet: { newKey in
                            if hotkeyManager.togglePositioningHotkey == newKey {
                                hotkeyManager.togglePositioningHotkey = nil
                            }
                        }
                    )
                }

                HStack {
                    Text("Toggle Positioning Mode")
                    Spacer()
                    ShortcutRecorderView(
                        hotkey: $hotkeyManager.togglePositioningHotkey,
                        onSet: { newKey in
                            if hotkeyManager.toggleScanHotkey == newKey {
                                hotkeyManager.toggleScanHotkey = nil
                            }
                        }
                    )
                }
            } header: {
                Text("Global Shortcuts")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Add Profile Popover
    private var addProfilePopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New Profile")
                .font(.headline)

            TextField("Profile Name", text: $newProfileName)
                .textFieldStyle(.roundedBorder)
                .focused($isNameFieldFocused)
                .frame(width: 220)
                .onSubmit {
                    createProfile()
                }

            HStack {
                Button("Cancel") {
                    showingAddPopover = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create") {
                    createProfile()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(newProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(14)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isNameFieldFocused = true
            }
        }
    }

    private func createProfile() {
        let trimmed = newProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        appState.addNewProfile(name: trimmed)
        showingAddPopover = false
        newProfileName = ""
    }
}
