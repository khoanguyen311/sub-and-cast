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

    public var profileStore: ProfileStore
    public var subtitlePipeline: SubtitlePipelineProtocol
    public var shortcutRegistry: ShortcutRegistry

    private var scanTask: Task<Void, Never>?
    private var hotkeyTask: Task<Void, Never>?

    public init(
        subtitlePipeline: SubtitlePipelineProtocol? = nil,
        profileStore: ProfileStore? = nil,
        shortcutRegistry: ShortcutRegistry? = nil
    ) {
        self.subtitlePipeline = subtitlePipeline ?? SubtitlePipeline()
        let store = profileStore ?? ProfileStore.shared
        self.profileStore = store
        let registry = shortcutRegistry ?? ShortcutRegistry.shared
        self.shortcutRegistry = registry
        self.profiles = store.profiles
        self.currentProfile = store.activeProfile

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

        let stream = registry.actionStream
        self.hotkeyTask = Task { @MainActor [weak self] in
            for await action in stream {
                guard let self = self else { break }
                switch action {
                case .toggleScan:
                    self.toggleScanning()
                case .togglePositioning:
                    self.toggleLock()
                case .oneTimeScan:
                    self.triggerOneTimeScan()
                }
            }
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

        let rect = currentProfile.sourceRect.cgRect
        let config = SubtitlePipelineConfig(
            sourceLanguage: currentProfile.sourceLanguage,
            targetLanguage: currentProfile.targetLanguage,
            translationEngineType: currentProfile.translationEngineType,
            mergeWrappedLines: currentProfile.mergeWrappedLines
        )
        let interval = currentProfile.captureIntervalSeconds

        let stream = subtitlePipeline.startScan(rect: rect, config: config, intervalSeconds: interval)
        scanTask = Task { @MainActor [weak self] in
            for await event in stream {
                guard let self = self, self.isScanning else { break }
                self.consumeSubtitleEvent(event)
            }
        }
    }

    public func stopScanning() {
        isScanning = false
        subtitlePipeline.stopScan()
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
        guard rect.width >= CodableRect.minWidth && rect.height >= CodableRect.minHeight else {
            statusMessage = "Capture area invalid"
            return
        }

        isOneTimeScanning = true
        statusMessage = "Scanning..."
        isOCRActive = true

        let config = SubtitlePipelineConfig(
            sourceLanguage: currentProfile.sourceLanguage,
            targetLanguage: currentProfile.targetLanguage,
            translationEngineType: currentProfile.translationEngineType,
            mergeWrappedLines: currentProfile.mergeWrappedLines
        )

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            defer {
                self.isOneTimeScanning = false
                self.isOCRActive = false
            }

            let event = await self.subtitlePipeline.scanOnce(rect: rect, config: config)
            switch event {
            case .empty:
                self.statusMessage = "No text detected"
            case .unchanged:
                self.statusMessage = "Translated (\(self.currentProfile.sourceLanguage.uppercased()) → \(self.currentProfile.targetLanguage.uppercased()))"
                self.isOneTimeSubtitleVisible = true
                self.oneTimeScanTriggerCount += 1
            case let .dialogue(sourceText, translatedText, _):
                self.lastRecognizedText = sourceText
                self.lastTranslatedText = translatedText
                self.statusMessage = "Translated (\(self.currentProfile.sourceLanguage.uppercased()) → \(self.currentProfile.targetLanguage.uppercased()))"
                self.isOneTimeSubtitleVisible = true
                self.oneTimeScanTriggerCount += 1
            case let .error(msg):
                self.statusMessage = "Error: \(msg)"
            }
        }
    }

    public func ocrLanguages(for sourceLanguage: String) -> [String] {
        return SubtitlePipeline.ocrLanguages(for: sourceLanguage)
    }

    public func testTranslate() {
        isOverlaysVisible = true
        isDialoguePresent = true
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let rect = self.currentProfile.sourceRect.cgRect
            guard rect.width >= CodableRect.minWidth, rect.height >= CodableRect.minHeight else { return }
            let config = SubtitlePipelineConfig(
                sourceLanguage: self.currentProfile.sourceLanguage,
                targetLanguage: self.currentProfile.targetLanguage,
                translationEngineType: self.currentProfile.translationEngineType,
                mergeWrappedLines: self.currentProfile.mergeWrappedLines
            )
            let event = await self.subtitlePipeline.scanOnce(rect: rect, config: config)
            self.consumeSubtitleEvent(event)
        }
    }

    private func consumeSubtitleEvent(_ event: SubtitleEvent) {
        switch event {
        case .unchanged:
            if !lastRecognizedText.isEmpty {
                self.isDialoguePresent = true
            }
        case .empty:
            if isDialoguePresent {
                self.isDialoguePresent = false
                self.lastRecognizedText = ""
            }
        case let .dialogue(sourceText, translatedText, _):
            self.isDialoguePresent = true
            self.lastRecognizedText = sourceText
            self.lastTranslatedText = translatedText
            self.statusMessage = "Translated (\(currentProfile.sourceLanguage.uppercased()) → \(currentProfile.targetLanguage.uppercased()))"
        case let .error(msg):
            self.statusMessage = "Error: \(msg)"
        }
    }

    public func scheduleSaveCurrentProfile() {
        profileStore.updateActiveProfile { [weak self] profile in
            guard let self = self else { return }
            profile = self.currentProfile
        }
    }

    public func updateSourceRectLive(_ rect: CGRect) {
        guard rect.width >= CodableRect.minWidth, rect.height >= CodableRect.minHeight else { return }
        currentProfile.sourceRect = CodableRect(cgRect: rect)
        profileStore.updateActiveProfile { $0.sourceRect = CodableRect(cgRect: rect) }
    }

    public func updateDisplayRectLive(_ rect: CGRect) {
        guard rect.width >= CodableRect.minWidth, rect.height >= CodableRect.minHeight else { return }
        currentProfile.displayRect = CodableRect(cgRect: rect)
        profileStore.updateActiveProfile { $0.displayRect = CodableRect(cgRect: rect) }
    }

    public func updateSourceRect(_ rect: CGRect) {
        guard rect.width >= CodableRect.minWidth, rect.height >= CodableRect.minHeight else { return }
        currentProfile.sourceRect = CodableRect(cgRect: rect)
        profileStore.updateActiveProfile { $0.sourceRect = CodableRect(cgRect: rect) }
        profileStore.flush()
    }

    public func updateDisplayRect(_ rect: CGRect) {
        guard rect.width >= CodableRect.minWidth, rect.height >= CodableRect.minHeight else { return }
        currentProfile.displayRect = CodableRect(cgRect: rect)
        profileStore.updateActiveProfile { $0.displayRect = CodableRect(cgRect: rect) }
        profileStore.flush()
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

        let src = CodableRect(x: centerX, y: captureY, width: width, height: captureHeight)
        let dst = CodableRect(x: centerX, y: displayY, width: width, height: subtitleHeight)

        currentProfile.sourceRect = src
        currentProfile.displayRect = dst

        profileStore.updateActiveProfile {
            $0.sourceRect = src
            $0.displayRect = dst
        }
        profileStore.flush()
        OverlayWindowManager.shared.updatePanelPositions(from: currentProfile)
        statusMessage = "Overlays Reset to Default"
    }

    public func selectProfile(_ profile: GameProfile) {
        profileStore.selectProfile(id: profile.id)
        self.currentProfile = profileStore.activeProfile
        self.profiles = profileStore.profiles
    }

    public func saveCurrentProfile() {
        profileStore.updateActiveProfile { [weak self] p in
            guard let self = self else { return }
            p = self.currentProfile
        }
        profileStore.flush()
        self.profiles = profileStore.profiles
        self.currentProfile = profileStore.activeProfile
    }

    public func addNewProfile(name: String) {
        let newProfile = profileStore.addProfile(name: name)
        self.profiles = profileStore.profiles
        self.currentProfile = newProfile
    }

    public func deleteProfile(id: UUID) {
        profileStore.deleteProfile(id: id)
        self.profiles = profileStore.profiles
        self.currentProfile = profileStore.activeProfile
    }
}
