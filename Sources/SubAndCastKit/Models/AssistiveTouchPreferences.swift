import Foundation

/// Manages persistence and defaults for AssistiveTouch preferences.
public struct AssistiveTouchPreferences: Sendable {
    private static let keyEnabled = "assistive_touch_enabled"
    private static let keySingleClick = "assistive_single_click"
    private static let keyDoubleClick = "assistive_double_click"
    private static let keyLongPress = "assistive_long_press"
    private static let keySize = "assistive_touch_size"
    private static let keyIdleOpacity = "assistive_touch_idle_opacity"

    public var isEnabled: Bool
    public var singleClick: AssistiveTouchAction
    public var doubleClick: AssistiveTouchAction
    public var longPress: AssistiveTouchAction
    public var size: CGFloat
    public var idleOpacity: Double

    public init(
        isEnabled: Bool = true,
        singleClick: AssistiveTouchAction = .oneTimeScan,
        doubleClick: AssistiveTouchAction = .toggleAutoScan,
        longPress: AssistiveTouchAction = .openQuickMenu,
        size: CGFloat = 40.0,
        idleOpacity: Double = 0.30
    ) {
        self.isEnabled = isEnabled
        self.singleClick = singleClick
        self.doubleClick = doubleClick
        self.longPress = longPress
        self.size = size
        self.idleOpacity = idleOpacity
    }

    public static func load(from defaults: UserDefaults = .standard) -> AssistiveTouchPreferences {
        let isEnabled = defaults.object(forKey: keyEnabled) != nil
            ? defaults.bool(forKey: keyEnabled)
            : true

        let singleClick = defaults.string(forKey: keySingleClick)
            .flatMap(AssistiveTouchAction.init(rawValue:)) ?? .oneTimeScan

        let doubleClick = defaults.string(forKey: keyDoubleClick)
            .flatMap(AssistiveTouchAction.init(rawValue:)) ?? .toggleAutoScan

        let longPress = defaults.string(forKey: keyLongPress)
            .flatMap(AssistiveTouchAction.init(rawValue:)) ?? .openQuickMenu

        let size: CGFloat
        if defaults.object(forKey: keySize) != nil {
            let saved = CGFloat(defaults.double(forKey: keySize))
            size = min(max(20, saved), 100)
        } else {
            size = 40.0
        }

        let idleOpacity: Double
        if defaults.object(forKey: keyIdleOpacity) != nil {
            let saved = defaults.double(forKey: keyIdleOpacity)
            idleOpacity = min(max(0.0, saved), 1.0)
        } else {
            idleOpacity = 0.30
        }

        return AssistiveTouchPreferences(
            isEnabled: isEnabled,
            singleClick: singleClick,
            doubleClick: doubleClick,
            longPress: longPress,
            size: size,
            idleOpacity: idleOpacity
        )
    }

    public func save(to defaults: UserDefaults = .standard) {
        defaults.set(isEnabled, forKey: Self.keyEnabled)
        defaults.set(singleClick.rawValue, forKey: Self.keySingleClick)
        defaults.set(doubleClick.rawValue, forKey: Self.keyDoubleClick)
        defaults.set(longPress.rawValue, forKey: Self.keyLongPress)
        defaults.set(Double(size), forKey: Self.keySize)
        defaults.set(idleOpacity, forKey: Self.keyIdleOpacity)
    }
}
