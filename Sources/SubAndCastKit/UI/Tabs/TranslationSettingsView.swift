import SwiftUI

public struct TranslationSettingsView: View {
    @ObservedObject var appState: AppState

    @AppStorage("defaultSourceLanguage") private var storedSourceLanguage: String = "en"
    @AppStorage("defaultTargetLanguage") private var storedTargetLanguage: String = "vi"
    @AppStorage("defaultTranslationProvider") private var storedTranslationProvider: String = "apple"
    @AppStorage("defaultOCREngine") private var storedOCREngine: String = OCREngine.appleVision.rawValue

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
                // Row 1: Source Language
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

                // Row 2: Target Language
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

                // Row 3: Translation Engine
                Picker("Translation Engine", selection: Binding(
                    get: { appState.currentProfile.translationEngineType },
                    set: {
                        appState.currentProfile.translationEngineType = $0
                        storedTranslationProvider = $0
                    }
                )) {
                    Text("Apple Native Translation").tag("apple")
                    Text("Google Translate").tag("google_free")
                }

                // Row 4: OCR Engine (extensible via OCREngine enum)
                Picker("OCR Engine", selection: Binding(
                    get: { appState.currentProfile.ocrEngineType },
                    set: {
                        appState.currentProfile.ocrEngineType = $0
                        storedOCREngine = $0
                    }
                )) {
                    ForEach(OCREngine.allCases) { engine in
                        Text(engine.displayName).tag(engine.rawValue)
                    }
                }
            } header: {
                Text("Languages & Engine")
            }
        }
        .formStyle(.grouped)
    }
}
