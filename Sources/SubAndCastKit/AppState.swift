import SwiftUI
import Combine

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()

    @Published public var profiles: [GameProfile] = []
    @Published public var currentProfile: GameProfile
    @Published public var isScanning: Bool = false
    @Published public var isOneTimeScanning: Bool = false
    @Published public var isOneTimeSubtitleVisible: Bool = false
    @Published public var oneTimeScanTriggerCount: Int = 0
    @Published public var isLocked: Bool = true // Default to locked
    @Published public var isOverlaysVisible: Bool = false // Hidden on cold launch
    @Published public var isPositioningOverlays: Bool = false // True when user clicked "Position Overlays"
    @Published public var isOCRActive: Bool = false
    @Published public var isDialoguePresent: Bool = false
    @Published public var lastRecognizedText: String = ""
    @Published public var lastTranslatedText: String = ""
    @Published public var statusMessage: String = "Ready"

    // MARK: - AssistiveTouch Settings & State
    @Published public var isAssistiveTouchEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isAssistiveTouchEnabled, forKey: "assistive_touch_enabled")
        }
    }
    @Published public var assistiveTouchSingleClick: AssistiveTouchAction {
        didSet {
            UserDefaults.standard.set(assistiveTouchSingleClick.rawValue, forKey: "assistive_single_click")
        }
    }
    @Published public var assistiveTouchDoubleClick: AssistiveTouchAction {
        didSet {
            UserDefaults.standard.set(assistiveTouchDoubleClick.rawValue, forKey: "assistive_double_click")
        }
    }
    @Published public var assistiveTouchLongPress: AssistiveTouchAction {
        didSet {
            UserDefaults.standard.set(assistiveTouchLongPress.rawValue, forKey: "assistive_long_press")
        }
    }
    @Published public var assistiveTouchSize: CGFloat {
        didSet {
            UserDefaults.standard.set(Double(assistiveTouchSize), forKey: "assistive_touch_size")
        }
    }
    @Published public var assistiveTouchIdleOpacity: Double {
        didSet {
            UserDefaults.standard.set(assistiveTouchIdleOpacity, forKey: "assistive_touch_idle_opacity")
        }
    }
    @Published public var isAssistiveQuickMenuOpen: Bool = false

    private var scanTask: Task<Void, Never>?
    private let captureManager = ScreenCaptureManager()
    private let imageDiffer = ImageDiffer()
    private let ocrManager = VisionOCRManager()
    private let translationCoordinator = TranslationCoordinator.shared

    public init() {
        let loadedProfiles = ProfileManager.shared.loadProfiles()
        self.profiles = loadedProfiles
        self.currentProfile = loadedProfiles.first ?? GameProfile()

        if UserDefaults.standard.object(forKey: "assistive_touch_enabled") != nil {
            self.isAssistiveTouchEnabled = UserDefaults.standard.bool(forKey: "assistive_touch_enabled")
        } else {
            self.isAssistiveTouchEnabled = true
        }

        if let raw = UserDefaults.standard.string(forKey: "assistive_single_click"),
           let action = AssistiveTouchAction(rawValue: raw) {
            self.assistiveTouchSingleClick = action
        } else {
            self.assistiveTouchSingleClick = .oneTimeScan
        }

        if let raw = UserDefaults.standard.string(forKey: "assistive_double_click"),
           let action = AssistiveTouchAction(rawValue: raw) {
            self.assistiveTouchDoubleClick = action
        } else {
            self.assistiveTouchDoubleClick = .toggleAutoScan
        }

        if let raw = UserDefaults.standard.string(forKey: "assistive_long_press"),
           let action = AssistiveTouchAction(rawValue: raw) {
            self.assistiveTouchLongPress = action
        } else {
            self.assistiveTouchLongPress = .openQuickMenu
        }

        if UserDefaults.standard.object(forKey: "assistive_touch_size") != nil {
            let savedSize = CGFloat(UserDefaults.standard.double(forKey: "assistive_touch_size"))
            self.assistiveTouchSize = min(max(20, savedSize), 100)
        } else {
            self.assistiveTouchSize = 40.0
        }

        if UserDefaults.standard.object(forKey: "assistive_touch_idle_opacity") != nil {
            let savedOpacity = UserDefaults.standard.double(forKey: "assistive_touch_idle_opacity")
            self.assistiveTouchIdleOpacity = min(max(0.0, savedOpacity), 1.0)
        } else {
            self.assistiveTouchIdleOpacity = 0.30
        }
    }

    public func executeAssistiveAction(_ action: AssistiveTouchAction) {
        switch action {
        case .oneTimeScan:
            triggerOneTimeScan()
        case .toggleAutoScan:
            toggleScanning()
        case .togglePositioning:
            toggleLock()
        case .openQuickMenu:
            isAssistiveQuickMenuOpen.toggle()
        case .openPreferences:
            OverlayWindowManager.shared.showSettings(appState: self)
        case .none:
            break
        }
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
        if !isScanning {
            isOverlaysVisible = false
        }
        isDialoguePresent = false
        lastTranslatedText = ""
        lastRecognizedText = ""
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
        if !isScanning {
            isOverlaysVisible = false
        }
        isDialoguePresent = false
        lastTranslatedText = ""
        lastRecognizedText = ""
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
        isDialoguePresent = false
        isOneTimeSubtitleVisible = false
        statusMessage = "Scanning paused"
    }

    public func triggerOneTimeScan() {
        // Ignore if auto-scan is active, or if currently positioning overlays, or if already scanning
        guard !isScanning else { return }
        guard !isPositioningOverlays else { return }
        guard !isOneTimeScanning else { return }

        let rect = currentProfile.sourceRect.cgRect
        guard rect.width > 10 && rect.height > 10 else {
            statusMessage = "Capture area invalid"
            return
        }

        isOneTimeScanning = true
        statusMessage = "Scanning..."

        Task { [weak self] in
            guard let self = self else { return }
            defer { self.isOneTimeScanning = false }

            do {
                let capturedImage = try await self.captureManager.captureRegion(rect: rect)
                self.isOCRActive = true

                let ocrLangs = self.ocrLanguages(for: self.currentProfile.sourceLanguage)
                let ocrResult = try await self.ocrManager.recognizeText(
                    in: capturedImage,
                    recognitionLanguages: ocrLangs,
                    mergeWrappedLines: self.currentProfile.mergeWrappedLines
                )
                self.isOCRActive = false

                let cleanOCR = ocrResult.fullText.trimmingCharacters(in: .whitespacesAndNewlines)

                // If no text was recognized in the captured frame:
                if cleanOCR.isEmpty {
                    self.statusMessage = "No text detected"
                    return
                }

                self.lastRecognizedText = cleanOCR
                self.statusMessage = "Translating..."

                let translated = try await self.translationCoordinator.translate(
                    text: cleanOCR,
                    sourceLanguage: self.currentProfile.sourceLanguage,
                    targetLanguage: self.currentProfile.targetLanguage,
                    engineType: self.currentProfile.translationEngineType
                )

                self.lastTranslatedText = translated
                self.statusMessage = "Translated (\(self.currentProfile.sourceLanguage.uppercased()) → \(self.currentProfile.targetLanguage.uppercased()))"
                self.isOneTimeSubtitleVisible = true
                self.oneTimeScanTriggerCount += 1
            } catch {
                self.isOCRActive = false
                self.statusMessage = "Error: \(error.localizedDescription)"
            }
        }
    }

    public func ocrLanguages(for sourceLanguage: String) -> [String] {
        switch sourceLanguage.lowercased() {
        case "ja": return ["ja-JP", "en-US"]
        case "zh", "zh-hans": return ["zh-Hans", "en-US"]
        case "zh-hant": return ["zh-Hant", "en-US"]
        case "ko": return ["ko-KR", "en-US"]
        case "vi": return ["vi-VN", "en-US"]
        case "fr": return ["fr-FR", "en-US"]
        case "de": return ["de-DE", "en-US"]
        case "es": return ["es-ES", "en-US"]
        default: return ["en-US"]
        }
    }

    public func testTranslate() {
        isOverlaysVisible = true
        isDialoguePresent = true
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
                // Unchanged frame: if dialogue was already recognized, keep it present
                if !lastRecognizedText.isEmpty {
                    self.isDialoguePresent = true
                }
                return
            }

            self.isOCRActive = true

            // OCR languages based on profile source language
            let ocrLangs = ocrLanguages(for: currentProfile.sourceLanguage)

            let ocrResult = try await ocrManager.recognizeText(
                in: capturedImage,
                recognitionLanguages: ocrLangs,
                mergeWrappedLines: currentProfile.mergeWrappedLines
            )
            self.isOCRActive = false

            let cleanOCR = ocrResult.fullText.trimmingCharacters(in: .whitespacesAndNewlines)

            // If no text was recognized in the captured frame:
            if cleanOCR.isEmpty {
                if isDialoguePresent {
                    self.isDialoguePresent = false
                    self.lastRecognizedText = ""
                }
                return
            }

            // Dialogue text is present
            self.isDialoguePresent = true

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
