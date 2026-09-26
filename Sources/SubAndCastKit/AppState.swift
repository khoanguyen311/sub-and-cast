import SwiftUI
import Combine

/// Clean presentation model coordinating UI state, pipeline events, shortcuts, and overlay positioning.
@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()

    // MARK: - Presentation State
    @Published public var profiles: [GameProfile] = []
    @Published public var currentProfile: GameProfile
    @Published public var isScanning: Bool = false
    @Published public var isOneTimeScanning: Bool = false
    @Published public var isOneTimeSubtitleVisible: Bool = false
    @Published public var oneTimeScanTriggerCount: Int = 0
    @Published public var isLocked: Bool = true
    @Published public var isOverlaysVisible: Bool = false
    @Published public var isPositioningOverlays: Bool = false
    @Published public var isOCRActive: Bool = false
    @Published public var isDialoguePresent: Bool = false
    @Published public var lastRecognizedText: String = ""
    @Published public var lastTranslatedText: String = ""
    @Published public var statusMessage: String = "Ready"
    @Published public var hudWarning: String? = nil
    private var hudWarningTimer: AnyCancellable?

    // MARK: - AssistiveTouch Settings
    @Published public var isAssistiveTouchEnabled: Bool {
        didSet { persistPreferences() }
    }
    @Published public var assistiveTouchSingleClick: AssistiveTouchAction {
        didSet { persistPreferences() }
    }
    @Published public var assistiveTouchDoubleClick: AssistiveTouchAction {
        didSet { persistPreferences() }
    }
    @Published public var assistiveTouchLongPress: AssistiveTouchAction {
        didSet { persistPreferences() }
    }
    @Published public var assistiveTouchSize: CGFloat {
        didSet { persistPreferences() }
    }
    @Published public var assistiveTouchIdleOpacity: Double {
        didSet { persistPreferences() }
    }
    @Published public var isAssistiveQuickMenuOpen: Bool = false

    // MARK: - Injected Core Subsystems
    public var profileStore: ProfileStore
    public var subtitlePipeline: SubtitlePipelineProtocol
    public var shortcutRegistry: ShortcutRegistry
    public var overlayCoordinator: OverlayCoordinator

    public var onOpenPreferences: (() -> Void)?
    public var onResetOverlays: ((GameProfile) -> Void)?

    private var scanTask: Task<Void, Never>?
    private var hotkeyTask: Task<Void, Never>?
    private let preferencesDefaults: UserDefaults

    public init(
        subtitlePipeline: SubtitlePipelineProtocol? = nil,
        profileStore: ProfileStore? = nil,
        shortcutRegistry: ShortcutRegistry? = nil,
        overlayCoordinator: OverlayCoordinator? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        self.subtitlePipeline = subtitlePipeline ?? SubtitlePipeline()
        let store = profileStore ?? ProfileStore.shared
        self.profileStore = store
        let registry = shortcutRegistry ?? ShortcutRegistry.shared
        self.shortcutRegistry = registry
        self.overlayCoordinator = overlayCoordinator ?? OverlayCoordinator.shared
        self.preferencesDefaults = userDefaults

        self.profiles = store.profiles
        self.currentProfile = store.activeProfile

        let prefs = AssistiveTouchPreferences.load(from: userDefaults)
        self.isAssistiveTouchEnabled = prefs.isEnabled
        self.assistiveTouchSingleClick = prefs.singleClick
        self.assistiveTouchDoubleClick = prefs.doubleClick
        self.assistiveTouchLongPress = prefs.longPress
        self.assistiveTouchSize = prefs.size
        self.assistiveTouchIdleOpacity = prefs.idleOpacity

        let stream = registry.actionStream
        self.hotkeyTask = Task { @MainActor [weak self] in
            for await action in stream {
                guard let self = self else { break }
                switch action {
                case .toggleScan: self.toggleScanning()
                case .togglePositioning: self.toggleLock()
                case .oneTimeScan: self.triggerOneTimeScan()
                }
            }
        }

        TranslationCoordinator.shared.onFallbackTriggered = { [weak self] targetEngine, _ in
            Task { @MainActor [weak self] in
                let engineName = (targetEngine == "apple") ? "Apple Native" : "Google Translate"
                self?.showHUDWarning("⚠️ Fallback: \(engineName)")
            }
        }
    }

    public func showHUDWarning(_ message: String, duration: Double = 3.0) {
        hudWarningTimer?.cancel()
        hudWarning = message
        hudWarningTimer = Just(())
            .delay(for: .seconds(duration), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                withAnimation(.easeOut(duration: 0.5)) {
                    self?.hudWarning = nil
                }
            }
    }

    private func persistPreferences() {
        let prefs = AssistiveTouchPreferences(
            isEnabled: isAssistiveTouchEnabled,
            singleClick: assistiveTouchSingleClick,
            doubleClick: assistiveTouchDoubleClick,
            longPress: assistiveTouchLongPress,
            size: assistiveTouchSize,
            idleOpacity: assistiveTouchIdleOpacity
        )
        prefs.save(to: preferencesDefaults)
    }

    // MARK: - Actions
    public func executeAssistiveAction(_ action: AssistiveTouchAction) {
        switch action {
        case .oneTimeScan: triggerOneTimeScan()
        case .toggleAutoScan: toggleScanning()
        case .togglePositioning: toggleLock()
        case .openQuickMenu: isAssistiveQuickMenuOpen.toggle()
        case .openPreferences: onOpenPreferences?()
        case .none: break
        }
    }

    public func startPositioningOverlays() {
        overlayCoordinator.beginPositioning(sourceRect: currentProfile.sourceRect, displayRect: currentProfile.displayRect)
        isOverlaysVisible = true
        isPositioningOverlays = true
        isLocked = false
        statusMessage = "Positioning Overlays"
    }

    public func finishPositioningOverlays() {
        overlayCoordinator.commitPositioning()
        isPositioningOverlays = false
        isLocked = true
        if !isScanning { isOverlaysVisible = false }
        isDialoguePresent = false
        lastTranslatedText = ""
        lastRecognizedText = ""
        saveCurrentProfile()
        statusMessage = "Overlays Saved & Locked"
    }

    public func cancelPositioningOverlays() {
        if let orig = overlayCoordinator.cancelPositioning() {
            currentProfile.sourceRect = orig.source
            currentProfile.displayRect = orig.display
        }
        isPositioningOverlays = false
        isLocked = true
        if !isScanning { isOverlaysVisible = false }
        isDialoguePresent = false
        lastTranslatedText = ""
        lastRecognizedText = ""
        statusMessage = "Positioning Cancelled"
    }

    public func toggleLock() {
        if isPositioningOverlays { finishPositioningOverlays() } else { startPositioningOverlays() }
    }

    public func toggleScanning() {
        if isScanning { stopScanning() } else { startScanning() }
    }

    public func currentPipelineConfig() -> SubtitlePipelineConfig {
        let cfConfig = CloudflareConfig(
            accountId: currentProfile.cloudflareAccountId,
            apiToken: currentProfile.cloudflareApiToken,
            model: currentProfile.cloudflareModel,
            customPrompt: currentProfile.cloudflareCustomPrompt,
            fallbackEnabled: currentProfile.cloudflareFallbackEnabled,
            fallbackEngine: currentProfile.cloudflareFallbackEngine
        )
        return SubtitlePipelineConfig(
            sourceLanguage: currentProfile.sourceLanguage,
            targetLanguage: currentProfile.targetLanguage,
            translationEngineType: currentProfile.translationEngineType,
            mergeWrappedLines: currentProfile.mergeWrappedLines,
            cloudflareConfig: cfConfig
        )
    }

    public func startScanning() {
        guard !isScanning else { return }
        isOverlaysVisible = true
        isScanning = true
        statusMessage = "Auto-scan active"

        let config = currentPipelineConfig()
        let stream = subtitlePipeline.startScan(rect: currentProfile.sourceRect.cgRect, config: config, intervalSeconds: currentProfile.captureIntervalSeconds)
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
        guard !isScanning && !isPositioningOverlays && !isOneTimeScanning else { return }
        let rect = currentProfile.sourceRect.cgRect
        guard rect.width >= CodableRect.minWidth && rect.height >= CodableRect.minHeight else {
            statusMessage = "Capture area invalid"
            return
        }

        isOneTimeScanning = true
        statusMessage = "Scanning..."
        isOCRActive = true

        let config = currentPipelineConfig()
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
        SubtitlePipeline.ocrLanguages(for: sourceLanguage)
    }

    public func testTranslate() {
        isOverlaysVisible = true
        isDialoguePresent = true
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let rect = self.currentProfile.sourceRect.cgRect
            guard rect.width >= CodableRect.minWidth, rect.height >= CodableRect.minHeight else { return }
            let config = self.currentPipelineConfig()
            let event = await self.subtitlePipeline.scanOnce(rect: rect, config: config)
            self.consumeSubtitleEvent(event)
        }
    }

    private func consumeSubtitleEvent(_ event: SubtitleEvent) {
        switch event {
        case .unchanged:
            if !lastRecognizedText.isEmpty { self.isDialoguePresent = true }
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

    // MARK: - Profile & Overlay Updates
    public func scheduleSaveCurrentProfile() {
        profileStore.updateActiveProfile { [weak self] p in
            guard let self = self else { return }
            p = self.currentProfile
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
        updateSourceRectLive(rect)
        profileStore.flush()
    }

    public func updateDisplayRect(_ rect: CGRect) {
        updateDisplayRectLive(rect)
        profileStore.flush()
    }

    public func resetOverlayZonesToDefault() {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let width: CGFloat = min(650, max(400, screen.width - 40))
        let captureHeight: CGFloat = 140
        let subtitleHeight: CGFloat = 120
        let centerX = max(0, (screen.width - width) / 2)
        let captureY = max(0, screen.height * 0.50)
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
        onResetOverlays?(currentProfile)
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
