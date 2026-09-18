import SwiftUI

public struct TranslationSettingsView: View {
    @ObservedObject var appState: AppState

    @AppStorage("defaultSourceLanguage") private var storedSourceLanguage: String = "en"
    @AppStorage("defaultTargetLanguage") private var storedTargetLanguage: String = "vi"
    @AppStorage("defaultTranslationProvider") private var storedTranslationProvider: String = "apple"

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

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        Form {
            Section {
                Picker("Source Language", selection: Binding(
                    get: { appState.currentProfile.sourceLanguage },
                    set: {
                        appState.currentProfile.sourceLanguage = $0
                        storedSourceLanguage = $0
                    }
                )) {
                    ForEach(supportedLanguages, id: \.0) { code, name in
                        Text(name).tag(code)
                    }
                }

                Picker("Target Language", selection: Binding(
                    get: { appState.currentProfile.targetLanguage },
                    set: {
                        appState.currentProfile.targetLanguage = $0
                        storedTargetLanguage = $0
                    }
                )) {
                    ForEach(supportedLanguages, id: \.0) { code, name in
                        Text(name).tag(code)
                    }
                }

                Picker("Translation Provider", selection: Binding(
                    get: { appState.currentProfile.translationEngineType },
                    set: {
                        appState.currentProfile.translationEngineType = $0
                        storedTranslationProvider = $0
                    }
                )) {
                    Text("Apple Native Translation").tag("apple")
                    Text("Google Translate").tag("google_free")
                }
            } header: {
                Text("Languages & Engine")
            }

            Section {
                LabeledContent("Translation Engine") {
                    HStack(spacing: 6) {
                        Image(systemName: appState.currentProfile.translationEngineType == "apple" ? "apple.logo" : "globe")
                            .foregroundColor(appState.currentProfile.translationEngineType == "apple" ? .primary : .blue)
                        Text(appState.currentProfile.translationEngineType == "apple" ? "Apple Native Translation (Offline/macOS 15+)" : "Google Translate (Free Web API)")
                            .foregroundColor(.secondary)
                    }
                }

                LabeledContent("Vision OCR Engine") {
                    HStack(spacing: 6) {
                        Image(systemName: "cpu")
                            .foregroundColor(.green)
                        Text("Apple Neural Engine (Vision Framework)")
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Provider Details")
            }
        }
        .formStyle(.grouped)
    }
}
