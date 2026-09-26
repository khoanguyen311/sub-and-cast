import SwiftUI

public struct TranslationSettingsView: View {
    @ObservedObject var appState: AppState

    @AppStorage("defaultSourceLanguage") private var storedSourceLanguage: String = "en"
    @AppStorage("defaultTargetLanguage") private var storedTargetLanguage: String = "vi"
    @AppStorage("defaultTranslationProvider") private var storedTranslationProvider: String = "apple"
    @AppStorage("defaultOCREngine") private var storedOCREngine: String = OCREngine.appleVision.rawValue

    @State private var isTokenVisible: Bool = false
    @State private var isTestingConnection: Bool = false
    @State private var testConnectionSuccess: Bool = false
    @State private var testConnectionMessage: String? = nil

    private let supportedLanguages = [
        ("en", "English"),
        ("vi", "Vietnamese (Tiếng Việt)"),
        ("ja", "Japanese (日本語)"),
        ("zh-Hans", "Chinese Simplified (简体中文)"),
        ("zh-Hant", "Chinese Traditional (繁體中文)"),
        ("ko", "Korean (한국어)"),
        ("fr", "French (Français)"),
        ("de", "German (Deutsch)"),
        ("es", "Spanish (Español)")
    ]

    private let curatedModels = [
        ("@cf/meta/llama-3.2-3b-instruct", "Llama 3.2 3B Instruct (Default - Fast)"),
        ("@cf/meta/llama-3.1-8b-instruct", "Llama 3.1 8B Instruct (High Quality)"),
        ("@cf/meta/llama-3.3-70b-instruct-fp8-fast", "Llama 3.3 70B Instruct (Maximum Quality)"),
        ("custom", "Custom Model...")
    ]

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        Form {
            Section("Languages & Engine") {
                // Row 1: Source Language
                Picker("Source Language", selection: Binding(
                    get: { appState.currentProfile.sourceLanguage },
                    set: {
                        appState.currentProfile.sourceLanguage = $0
                        storedSourceLanguage = $0
                        appState.scheduleSaveCurrentProfile()
                    }
                )) {
                    ForEach(supportedLanguages, id: \.0) { code, name in
                        Text(name).tag(code)
                    }
                }

                // Row 2: Target Language
                Picker("Target Language", selection: Binding(
                    get: { appState.currentProfile.targetLanguage },
                    set: {
                        appState.currentProfile.targetLanguage = $0
                        storedTargetLanguage = $0
                        appState.scheduleSaveCurrentProfile()
                    }
                )) {
                    ForEach(supportedLanguages, id: \.0) { code, name in
                        Text(name).tag(code)
                    }
                }

                // Row 3: Translation Engine
                Picker("Translation Engine", selection: Binding(
                    get: { appState.currentProfile.translationEngineType },
                    set: {
                        appState.currentProfile.translationEngineType = $0
                        storedTranslationProvider = $0
                        appState.scheduleSaveCurrentProfile()
                    }
                )) {
                    Text("Apple Native Translation").tag("apple")
                    Text("Google Translate").tag("google_free")
                    Text("Cloudflare Workers AI").tag("cloudflare")
                }

                // Row 4: OCR Engine (extensible via OCREngine enum)
                Picker("OCR Engine", selection: Binding(
                    get: { appState.currentProfile.ocrEngineType },
                    set: {
                        appState.currentProfile.ocrEngineType = $0
                        storedOCREngine = $0
                        appState.scheduleSaveCurrentProfile()
                    }
                )) {
                    ForEach(OCREngine.allCases) { engine in
                        Text(engine.displayName).tag(engine.rawValue)
                    }
                }
            }

            // Cloudflare Workers AI Sections (Disclosed when Cloudflare Workers AI is chosen)
            if appState.currentProfile.translationEngineType == "cloudflare" {
                // 1. Credentials & Connection
                Section("Cloudflare Credentials") {
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                        GridRow {
                            Text("Account ID")
                                .frame(width: 90, alignment: .leading)

                            TextField("", text: Binding(
                                get: { appState.currentProfile.cloudflareAccountId },
                                set: {
                                    appState.currentProfile.cloudflareAccountId = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                                    appState.scheduleSaveCurrentProfile()
                                }
                            ), prompt: Text("Required"))
                            .textFieldStyle(.plain)
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .frame(maxWidth: .infinity)
                            .background(Color(NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                            )
                        }

                        GridRow {
                            Text("API Token")
                                .frame(width: 90, alignment: .leading)

                            Group {
                                if isTokenVisible {
                                    TextField("", text: Binding(
                                        get: { appState.currentProfile.cloudflareApiToken },
                                        set: {
                                            appState.currentProfile.cloudflareApiToken = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                                            appState.scheduleSaveCurrentProfile()
                                        }
                                    ), prompt: Text("Required"))
                                } else {
                                    SecureField("", text: Binding(
                                        get: { appState.currentProfile.cloudflareApiToken },
                                        set: {
                                            appState.currentProfile.cloudflareApiToken = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                                            appState.scheduleSaveCurrentProfile()
                                        }
                                    ), prompt: Text("Required"))
                                }
                            }
                            .textFieldStyle(.plain)
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                            .padding(.leading, 8)
                            .padding(.trailing, 28)
                            .padding(.vertical, 5)
                            .frame(maxWidth: .infinity)
                            .background(Color(NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                            )
                            .overlay(alignment: .trailing) {
                                Button {
                                    isTokenVisible.toggle()
                                } label: {
                                    Image(systemName: isTokenVisible ? "eye.slash" : "eye")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 12))
                                }
                                .buttonStyle(.plain)
                                .padding(.trailing, 8)
                                .help(isTokenVisible ? "Hide API Token" : "Show API Token")
                            }
                        }

                        GridRow {
                            Text("")
                                .frame(width: 90, alignment: .leading)

                            HStack {
                                if let result = testConnectionMessage {
                                    HStack(spacing: 5) {
                                        Image(systemName: testConnectionSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                            .foregroundColor(testConnectionSuccess ? .green : .red)
                                        Text(result)
                                            .font(.caption)
                                            .foregroundColor(testConnectionSuccess ? .green : .red)
                                    }
                                }

                                Spacer()

                                Button {
                                    testCloudflareConnection()
                                } label: {
                                    HStack(spacing: 5) {
                                        if isTestingConnection {
                                            ProgressView()
                                                .controlSize(.small)
                                        } else {
                                            Image(systemName: "network")
                                        }
                                        Text("Test Connection")
                                    }
                                }
                                .disabled(isTestingConnection || appState.currentProfile.cloudflareAccountId.isEmpty || appState.currentProfile.cloudflareApiToken.isEmpty)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 2)
                }

                // 2. Model Selection
                Section("Model Selection") {
                    Picker("Model", selection: Binding(
                        get: {
                            let current = appState.currentProfile.cloudflareModel
                            if curatedModels.contains(where: { $0.0 == current }) {
                                return current
                            }
                            return "custom"
                        },
                        set: { selected in
                            if selected != "custom" {
                                appState.currentProfile.cloudflareModel = selected
                            } else if curatedModels.contains(where: { $0.0 == appState.currentProfile.cloudflareModel }) {
                                appState.currentProfile.cloudflareModel = ""
                            }
                            appState.scheduleSaveCurrentProfile()
                        }
                    )) {
                        ForEach(curatedModels, id: \.0) { modelId, displayName in
                            Text(displayName).tag(modelId)
                        }
                    }

                    if !curatedModels.dropLast().contains(where: { $0.0 == appState.currentProfile.cloudflareModel }) {
                        LabeledContent("Model ID") {
                            TextField("", text: Binding(
                                get: { appState.currentProfile.cloudflareModel },
                                set: {
                                    appState.currentProfile.cloudflareModel = $0
                                    appState.scheduleSaveCurrentProfile()
                                }
                            ), prompt: Text("e.g. @cf/meta/llama-3.2-3b-instruct"))
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.leading)
                            .labelsHidden()
                        }
                    }
                }

                // 3. Prompt & Narrative Style
                Section("Prompt & Narrative Style") {
                    Picker("Preset", selection: Binding(
                        get: {
                            PromptPreset(rawValue: appState.currentProfile.cloudflarePromptPreset) ?? .natural
                        },
                        set: { newPreset in
                            appState.currentProfile.cloudflarePromptPreset = newPreset.rawValue
                            if newPreset != .custom {
                                appState.currentProfile.cloudflareCustomPrompt = newPreset.defaultPrompt
                            }
                            appState.scheduleSaveCurrentProfile()
                        }
                    )) {
                        ForEach(PromptPreset.allCases) { preset in
                            Text(preset.displayName).tag(preset)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Directives")
                            .font(.subheadline)
                            .foregroundColor(.primary)

                        TextEditor(text: Binding(
                            get: { appState.currentProfile.cloudflareCustomPrompt },
                            set: {
                                appState.currentProfile.cloudflareCustomPrompt = $0
                                if appState.currentProfile.cloudflarePromptPreset != PromptPreset.custom.rawValue {
                                    appState.currentProfile.cloudflarePromptPreset = PromptPreset.custom.rawValue
                                }
                                appState.scheduleSaveCurrentProfile()
                            }
                        ))
                        .font(.system(size: 11, design: .monospaced))
                        .frame(minHeight: 85, maxHeight: 130)
                        .padding(6)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                        )
                    }
                    .padding(.top, 4)
                }

                // 4. Failover Policy
                Section("Failover Policy") {
                    Toggle("Fallback on Error / Quota Exhaustion", isOn: Binding(
                        get: { appState.currentProfile.cloudflareFallbackEnabled },
                        set: {
                            appState.currentProfile.cloudflareFallbackEnabled = $0
                            appState.scheduleSaveCurrentProfile()
                        }
                    ))

                    if appState.currentProfile.cloudflareFallbackEnabled {
                        Picker("Fallback Engine", selection: Binding(
                            get: { appState.currentProfile.cloudflareFallbackEngine },
                            set: {
                                appState.currentProfile.cloudflareFallbackEngine = $0
                                appState.scheduleSaveCurrentProfile()
                            }
                        )) {
                            Text("Google Translate").tag("google_free")
                            Text("Apple Native Translation").tag("apple")
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func testCloudflareConnection() {
        guard !isTestingConnection else { return }
        isTestingConnection = true
        testConnectionMessage = nil

        let accountId = appState.currentProfile.cloudflareAccountId
        let token = appState.currentProfile.cloudflareApiToken
        let model = appState.currentProfile.cloudflareModel

        Task {
            do {
                let success = try await CloudflareWorkersAITranslationEngine.shared.testConnection(
                    accountId: accountId,
                    apiToken: token,
                    model: model
                )
                await MainActor.run {
                    self.isTestingConnection = false
                    self.testConnectionSuccess = success
                    self.testConnectionMessage = success ? "Connected successfully" : "Connection failed"
                }
            } catch {
                await MainActor.run {
                    self.isTestingConnection = false
                    self.testConnectionSuccess = false
                    self.testConnectionMessage = error.localizedDescription
                }
            }
        }
    }
}
