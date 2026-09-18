import SwiftUI
import Combine

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()

    @Published public var profiles: [GameProfile] = []
    @Published public var currentProfile: GameProfile
    @Published public var isScanning: Bool = false
    @Published public var isLocked: Bool = true // Default to locked
    @Published public var isOverlaysVisible: Bool = false // Hidden on cold launch
    @Published public var isPositioningOverlays: Bool = false // True when user clicked "Position Overlays"
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

    private var prePositioningSourceRect: CodableRect?
    private var prePositioningDisplayRect: CodableRect?

    public func startPositioningOverlays() {
        prePositioningSourceRect = currentProfile.sourceRect
        prePositioningDisplayRect = currentProfile.displayRect
        isOverlaysVisible = true
        isPositioningOverlays = true
        isLocked = false
        statusMessage = "Positioning Overlays"
    }

    public func finishPositioningOverlays() {
        isPositioningOverlays = false
        isLocked = true
        saveCurrentProfile()
        statusMessage = "Overlays Saved & Locked"
        prePositioningSourceRect = nil
        prePositioningDisplayRect = nil
    }

    public func cancelPositioningOverlays() {
        if let src = prePositioningSourceRect, let dst = prePositioningDisplayRect {
            currentProfile.sourceRect = src
            currentProfile.displayRect = dst
        }
        isPositioningOverlays = false
        isLocked = true
        statusMessage = "Positioning Cancelled"
        prePositioningSourceRect = nil
        prePositioningDisplayRect = nil
    }

    public func toggleLock() {
        if isPositioningOverlays {
            finishPositioningOverlays()
        } else {
            startPositioningOverlays()
        }
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
        isOverlaysVisible = true
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

    public func testTranslate() {
        isOverlaysVisible = true
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
                targetLanguage: currentProfile.targetLanguage,
                engineType: currentProfile.translationEngineType
            )

            self.lastTranslatedText = translated
            self.statusMessage = "Translated (\(currentProfile.sourceLanguage.uppercased()) → \(currentProfile.targetLanguage.uppercased()))"
        } catch {
            self.isOCRActive = false
            self.statusMessage = "Error: \(error.localizedDescription)"
        }
    }

    private var debouncedSaveTask: Task<Void, Never>?

    public func scheduleSaveCurrentProfile() {
        debouncedSaveTask?.cancel()
        debouncedSaveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            guard !Task.isCancelled, let self = self else { return }
            self.saveCurrentProfile()
        }
    }

    public func updateSourceRectLive(_ rect: CGRect) {
        guard rect.width >= CodableRect.minWidth, rect.height >= CodableRect.minHeight else { return }
        currentProfile.sourceRect = CodableRect(cgRect: rect)
        scheduleSaveCurrentProfile()
    }

    public func updateDisplayRectLive(_ rect: CGRect) {
        guard rect.width >= CodableRect.minWidth, rect.height >= CodableRect.minHeight else { return }
        currentProfile.displayRect = CodableRect(cgRect: rect)
        scheduleSaveCurrentProfile()
    }

    public func updateSourceRect(_ rect: CGRect) {
        guard rect.width >= CodableRect.minWidth, rect.height >= CodableRect.minHeight else { return }
        currentProfile.sourceRect = CodableRect(cgRect: rect)
        saveCurrentProfile()
    }

    public func updateDisplayRect(_ rect: CGRect) {
        guard rect.width >= CodableRect.minWidth, rect.height >= CodableRect.minHeight else { return }
        currentProfile.displayRect = CodableRect(cgRect: rect)
        saveCurrentProfile()
    }

    public func resetOverlayZonesToDefault() {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let width: CGFloat = min(650, max(400, screen.width - 40))
        let captureHeight: CGFloat = 140
        let subtitleHeight: CGFloat = 120
        let centerX = max(0, (screen.width - width) / 2)
        // Dialogue box lower-mid screen (CoreGraphics top-left origin)
        let captureY = max(0, screen.height * 0.50)
        // Subtitle output zone near bottom
        let displayY = max(captureY + captureHeight + 10, min(screen.height - subtitleHeight - 20, screen.height * 0.78))

        currentProfile.sourceRect = CodableRect(x: centerX, y: captureY, width: width, height: captureHeight)
        currentProfile.displayRect = CodableRect(x: centerX, y: displayY, width: width, height: subtitleHeight)
        saveCurrentProfile()
        OverlayWindowManager.shared.updatePanelPositions(from: currentProfile)
        statusMessage = "Overlays Reset to Default"
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
