import Foundation

/// Curated system prompt presets for steering Cloudflare Workers AI translation tone and style.
public enum PromptPreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case natural = "natural"
    case literal = "literal"
    case fantasy = "fantasy"
    case custom = "custom"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .natural:
            return "Natural Game Localization"
        case .literal:
            return "Literal & Faithful"
        case .fantasy:
            return "Fantasy & Historic RPG"
        case .custom:
            return "Custom"
        }
    }

    public var defaultPrompt: String {
        switch self {
        case .natural:
            return "You are a professional video game localizer. Translate in-game dialogue naturally, idiomatically, and fluently into the target language. Capture the emotional tone, slang, character personality, and dramatic context accurately. Avoid dry or mechanical phrasing. Output ONLY the translated dialogue."
        case .literal:
            return "You are a precise, literal translator. Translate the source dialogue into the target language faithfully, preserving the exact grammatical structure, word order, and phrasing as closely as possible without adding embellishments. Output ONLY the translated dialogue."
        case .fantasy:
            return "You are a narrative localization writer for fantasy and historical role-playing games. Translate dialogue using evocative, period-appropriate vocabulary, dignified honorifics, and immersive medieval fantasy tone suitable for heroes, lords, and sorcerers. Output ONLY the translated dialogue."
        case .custom:
            return ""
        }
    }
}
