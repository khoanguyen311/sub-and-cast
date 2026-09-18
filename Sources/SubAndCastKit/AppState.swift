import SwiftUI
import Combine

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()

    @Published public var profiles: [GameProfile] = []
    @Published public var currentProfile: GameProfile
    @Published public var isScanning: Bool = false
    @Published public var isLocked: Bool = false
    @Published public var isOCRActive: Bool = false
    @Published public var lastRecognizedText: String = ""
    @Published public var lastTranslatedText: String = ""
    @Published public var statusMessage: String = "Ready"

    private var scanTask: Task<Void, Never>?
    private let captureManager = ScreenCaptureManager()
    private let imageDiffer = ImageDiffer()
    private let ocrManager = VisionOCRManager()
    private let translationCoordinator = TranslationCoordinator.shared

    public init() {
        let loadedProfiles = ProfileManager.shared.loadProfiles()
        self.profiles = loadedProfiles
        self.currentProfile = loadedProfiles.first ?? GameProfile()
    }

    public func toggleLock() {
        isLocked.toggle()
    }

    public func toggleScanning() {
        if isScanning {
            stopScanning()
        } else {
            startScanning()
        }
    }

    public func startScanning() {
        guard !isScanning else { return }
        isScanning = true
        statusMessage = "Auto-scan active"
        imageDiffer.reset()

        scanTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self, self.isScanning else { break }

                await self.performScanCycle()

                let interval = self.currentProfile.captureIntervalSeconds
                let nanoseconds = UInt64(max(0.2, interval) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
            }
        }
    }

    public func stopScanning() {
        isScanning = false
        scanTask?.cancel()
        scanTask = nil
        statusMessage = "Scanning paused"
    }

    public func triggerSnapshot() {
        Task { [weak self] in
            await self?.performScanCycle(force: true)
        }
    }

    private func performScanCycle(force: Bool = false) async {
        let rect = currentProfile.sourceRect.cgRect
        guard rect.width > 10 && rect.height > 10 else { return }

        do {
            let capturedImage = try await captureManager.captureRegion(rect: rect)

            // If not forced, check if image actually changed to save OCR/translation power
            if !force && !imageDiffer.hasImageChanged(cgImage: capturedImage) {
                return
            }

            self.isOCRActive = true

            // OCR languages based on profile source language
            var ocrLangs: [String] = []
            switch currentProfile.sourceLanguage.lowercased() {
            case "ja": ocrLangs = ["ja-JP", "en-US"]
            case "zh", "zh-hans": ocrLangs = ["zh-Hans", "en-US"]
            case "zh-hant": ocrLangs = ["zh-Hant", "en-US"]
            case "ko": ocrLangs = ["ko-KR", "en-US"]
            case "vi": ocrLangs = ["vi-VN", "en-US"]
            case "fr": ocrLangs = ["fr-FR", "en-US"]
            case "de": ocrLangs = ["de-DE", "en-US"]
            case "es": ocrLangs = ["es-ES", "en-US"]
            default: ocrLangs = ["en-US"]
            }

            let ocrResult = try await ocrManager.recognizeText(in: capturedImage, recognitionLanguages: ocrLangs)
            self.isOCRActive = false

            let cleanOCR = ocrResult.fullText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanOCR.isEmpty else { return }

            // If text hasn't changed, skip translation
            if cleanOCR == self.lastRecognizedText {
                return
            }

            self.lastRecognizedText = cleanOCR
            self.statusMessage = "Translating..."

            let translated = try await translationCoordinator.translate(
                text: cleanOCR,
                sourceLanguage: currentProfile.sourceLanguage,
                targetLanguage: currentProfile.targetLanguage
            )

            self.lastTranslatedText = translated
            self.statusMessage = "Translated (\(currentProfile.sourceLanguage.uppercased()) → \(currentProfile.targetLanguage.uppercased()))"
        } catch {
            self.isOCRActive = false
            self.statusMessage = "Error: \(error.localizedDescription)"
        }
    }

    public func updateSourceRect(_ rect: CGRect) {
        currentProfile.sourceRect = CodableRect(cgRect: rect)
        saveCurrentProfile()
    }

    public func updateDisplayRect(_ rect: CGRect) {
        currentProfile.displayRect = CodableRect(cgRect: rect)
        saveCurrentProfile()
    }

    public func selectProfile(_ profile: GameProfile) {
        self.currentProfile = profile
        saveCurrentProfile()
    }

    public func saveCurrentProfile() {
        if let idx = profiles.firstIndex(where: { $0.id == currentProfile.id }) {
            profiles[idx] = currentProfile
        } else {
            profiles.append(currentProfile)
        }
        ProfileManager.shared.saveProfiles(profiles)
    }

    public func addNewProfile(name: String) {
        let newProfile = GameProfile(name: name)
        profiles.append(newProfile)
        currentProfile = newProfile
        ProfileManager.shared.saveProfiles(profiles)
    }

    public func deleteProfile(id: UUID) {
        guard profiles.count > 1 else { return }
        profiles.removeAll(where: { $0.id == id })
        if currentProfile.id == id {
            currentProfile = profiles.first ?? GameProfile()
        }
        ProfileManager.shared.saveProfiles(profiles)
    }
}
