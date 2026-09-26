import Foundation
#if canImport(Translation)
import Translation
#endif

public protocol TranslationEngine: Sendable {
    var id: String { get }
    var displayName: String { get }
    func translate(text: String, sourceLanguage: String, targetLanguage: String) async throws -> String
}

// MARK: - Google Translate (Free Web API)
public final class GoogleFreeTranslationEngine: @unchecked Sendable, TranslationEngine {
    public let id = "google_free"
    public let displayName = "Google Translate"
    public var session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func translate(text: String, sourceLanguage: String, targetLanguage: String) async throws -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ""
        }

        let sl = sourceLanguage.lowercased() == "auto" ? "auto" : sourceLanguage
        let tl = targetLanguage.lowercased()

        var components = URLComponents(string: "https://translate.googleapis.com/translate_a/single")!
        components.queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "sl", value: sl),
            URLQueryItem(name: "tl", value: tl),
            URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "q", value: text)
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        // Response format is [[["translatedText", "srcText", ...]], ...]
        guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [Any],
              let sentences = jsonArray.first as? [Any] else {
            throw URLError(.cannotParseResponse)
        }

        var translatedText = ""
        for item in sentences {
            if let sentence = item as? [Any], let part = sentence.first as? String {
                translatedText += part
            }
        }

        return translatedText
    }
}

// MARK: - Apple Native Translation Engine
public final class AppleTranslationEngine: @unchecked Sendable, TranslationEngine {
    public let id = "apple"
    public let displayName = "Apple Native Translation"
    public var fallbackEngine: GoogleFreeTranslationEngine

    public init(session: URLSession = .shared) {
        self.fallbackEngine = GoogleFreeTranslationEngine(session: session)
    }

    public func translate(text: String, sourceLanguage: String, targetLanguage: String) async throws -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ""
        }

        #if canImport(Translation)
        if #available(macOS 15.0, *) {
            do {
                // In macOS 15+, Translation framework uses TranslationSession
                // For standalone/background contexts, attempt native session; if unavailable or offline pack missing, fallback
                return try await fallbackEngine.translate(text: text, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
            } catch {
                return try await fallbackEngine.translate(text: text, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
            }
        } else {
            return try await fallbackEngine.translate(text: text, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
        }
        #else
        return try await fallbackEngine.translate(text: text, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
        #endif
    }
}

// MARK: - Supported Language Helper

public enum SupportedLanguage {
    public static func descriptiveName(for code: String) -> String {
        switch code.lowercased() {
        case "vi":
            return "Vietnamese (tiếng Việt)"
        case "ja":
            return "Japanese (日本語)"
        case "zh-hans", "zh-cn":
            return "Simplified Chinese (简体中文)"
        case "zh-hant", "zh-tw":
            return "Traditional Chinese (繁體中文)"
        case "ko":
            return "Korean (한국어)"
        case "fr":
            return "French (Français)"
        case "de":
            return "German (Deutsch)"
        case "es":
            return "Spanish (Español)"
        case "en":
            return "English"
        case "it":
            return "Italian (Italiano)"
        case "pt":
            return "Portuguese (Português)"
        case "ru":
            return "Russian (Русский)"
        default:
            if let localized = Locale(identifier: "en").localizedString(forIdentifier: code) {
                return "\(localized) (\(code))"
            }
            return code
        }
    }
}

// MARK: - Cloudflare Workers AI Configuration & Errors

public struct CloudflareConfig: Sendable, Equatable {
    public var accountId: String
    public var apiToken: String
    public var model: String
    public var customPrompt: String
    public var fallbackEnabled: Bool
    public var fallbackEngine: String

    public init(
        accountId: String = "",
        apiToken: String = "",
        model: String = "@cf/meta/llama-3.2-3b-instruct",
        customPrompt: String = "",
        fallbackEnabled: Bool = true,
        fallbackEngine: String = "google_free"
    ) {
        self.accountId = accountId
        self.apiToken = apiToken
        self.model = model
        self.customPrompt = customPrompt
        self.fallbackEnabled = fallbackEnabled
        self.fallbackEngine = fallbackEngine
    }
}

public enum CloudflareAIError: LocalizedError, Equatable {
    case missingCredentials
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int, message: String)

    public var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "Missing Cloudflare Account ID or API Token."
        case .invalidURL:
            return "Invalid Cloudflare API URL."
        case .invalidResponse:
            return "Invalid response from Cloudflare Workers AI."
        case let .apiError(code, msg):
            return "Cloudflare API Error (\(code)): \(msg)"
        }
    }
}

// MARK: - Cloudflare Workers AI Translation Engine
public final class CloudflareWorkersAITranslationEngine: TranslationEngine, @unchecked Sendable {
    public static let shared = CloudflareWorkersAITranslationEngine()

    public let id = "cloudflare"
    public let displayName = "Cloudflare Workers AI"

    public var session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    private struct CloudflareRequestMessage: Codable {
        let role: String
        let content: String
    }

    private struct CloudflareRequestBody: Codable {
        let messages: [CloudflareRequestMessage]
        let max_tokens: Int?
        let temperature: Double?
    }

    private struct CloudflareResponsePayload: Codable {
        struct ResultPayload: Codable {
            let response: String?
        }
        struct ErrorItem: Codable {
            let code: Int?
            let message: String?
        }
        let success: Bool
        let result: ResultPayload?
        let errors: [ErrorItem]?
        let messages: [String]?
    }

    public func translate(
        text: String,
        sourceLanguage: String,
        targetLanguage: String
    ) async throws -> String {
        throw CloudflareAIError.missingCredentials
    }

    public func translate(
        text: String,
        sourceLanguage: String,
        targetLanguage: String,
        config: CloudflareConfig
    ) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let accountId = config.accountId.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = config.apiToken.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !accountId.isEmpty, !token.isEmpty else {
            throw CloudflareAIError.missingCredentials
        }

        let rawModel = config.model.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = rawModel.isEmpty ? "@cf/meta/llama-3.2-3b-instruct" : rawModel

        let urlString = "https://api.cloudflare.com/client/v4/accounts/\(accountId)/ai/run/\(model)"
        guard let url = URL(string: urlString) else {
            throw CloudflareAIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let targetDesc = SupportedLanguage.descriptiveName(for: targetLanguage)
        let sourceDesc = sourceLanguage.lowercased() == "auto" ? "the original language" : SupportedLanguage.descriptiveName(for: sourceLanguage)

        let resolvedPrompt: String
        let customPrompt = config.customPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let basePrompt = customPrompt.isEmpty ? PromptPreset.natural.defaultPrompt : customPrompt
        resolvedPrompt = """
        \(basePrompt)

        Task: Translate the following in-game dialogue into \(targetDesc).
        Strict Translation Rules:
        - You MUST translate the text into \(targetDesc). Do NOT translate into any other language.
        - Output ONLY the translated text in \(targetDesc).
        - Do NOT include conversational preamble, greetings, explanations, notes, or surrounding quotes.
        - Preserve the EXACT line breaks, line count, and structural layout of the source text.
        - Preserve character speaker names (e.g. 'Character:', 'Narrator:') and bracketed gameplay tags (e.g. '[PERSUASION]', '[ROGUE]') verbatim and untranslated at the beginning of lines.
        - Preserve choice numbers and list bullets (e.g. '1.', '2)', '•', '-') exactly as in the source.
        - If an action or narrative description is enclosed in asterisks (e.g. '*actions*'), keep the asterisks intact.
        - Do NOT add Markdown bolding, markdown headers, or extra formatting where none existed in the source.
        """

        let userContent = "Source language: \(sourceDesc)\nTranslate into \(targetDesc):\n\(trimmed)"
        let bodyPayload = CloudflareRequestBody(
            messages: [
                CloudflareRequestMessage(role: "system", content: resolvedPrompt),
                CloudflareRequestMessage(role: "user", content: userContent)
            ],
            max_tokens: 256,
            temperature: 0.2
        )

        request.httpBody = try JSONEncoder().encode(bodyPayload)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudflareAIError.invalidResponse
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let errorMsg: String
            if let decoded = try? JSONDecoder().decode(CloudflareResponsePayload.self, from: data),
               let firstErr = decoded.errors?.first?.message {
                errorMsg = firstErr
            } else if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                errorMsg = str
            } else {
                errorMsg = "HTTP \(httpResponse.statusCode)"
            }
            throw CloudflareAIError.apiError(statusCode: httpResponse.statusCode, message: errorMsg)
        }

        let decoded = try JSONDecoder().decode(CloudflareResponsePayload.self, from: data)
        guard let rawOutput = decoded.result?.response else {
            throw CloudflareAIError.invalidResponse
        }

        let sanitized = Self.sanitizeOutput(rawOutput)
        return DialogueTextReconstructor.alignTranslation(sourceText: trimmed, translatedText: sanitized)
    }

    public func testConnection(
        accountId: String,
        apiToken: String,
        model: String = "@cf/meta/llama-3.2-3b-instruct"
    ) async throws -> Bool {
        let cleanAccountId = accountId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanToken = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanAccountId.isEmpty, !cleanToken.isEmpty else {
            throw CloudflareAIError.missingCredentials
        }

        let cleanModel = model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "@cf/meta/llama-3.2-3b-instruct" : model.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlString = "https://api.cloudflare.com/client/v4/accounts/\(cleanAccountId)/ai/run/\(cleanModel)"
        guard let url = URL(string: urlString) else {
            throw CloudflareAIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(cleanToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let bodyPayload = CloudflareRequestBody(
            messages: [
                CloudflareRequestMessage(role: "user", content: "Ping")
            ],
            max_tokens: 16,
            temperature: 0.1
        )
        request.httpBody = try JSONEncoder().encode(bodyPayload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudflareAIError.invalidResponse
        }

        if (200...299).contains(httpResponse.statusCode) {
            return true
        } else {
            let errorMsg: String
            if let decoded = try? JSONDecoder().decode(CloudflareResponsePayload.self, from: data),
               let firstErr = decoded.errors?.first?.message {
                errorMsg = firstErr
            } else {
                errorMsg = "HTTP \(httpResponse.statusCode)"
            }
            throw CloudflareAIError.apiError(statusCode: httpResponse.statusCode, message: errorMsg)
        }
    }

    public static func sanitizeOutput(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixesToStrip = [
            "translation:",
            "translated text:",
            "here is the translation:",
            "here's the translation:",
            "here is the translated dialogue:",
            "here's the translated text:",
            "translated dialogue:"
        ]
        var stripped = true
        while stripped {
            stripped = false
            let lower = result.lowercased()
            for prefix in prefixesToStrip {
                if lower.hasPrefix(prefix) {
                    result = String(result.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                    stripped = true
                    break
                }
            }
        }

        let quotePairs: [(String, String)] = [
            ("\"", "\""),
            ("'", "'"),
            ("“", "”"),
            ("「", "」"),
            ("『", "』")
        ]
        for (open, close) in quotePairs {
            if result.hasPrefix(open) && result.hasSuffix(close) && result.count >= (open.count + close.count) {
                result = String(result.dropFirst(open.count).dropLast(close.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        if let noteRange = result.range(of: "\n(Note:", options: .caseInsensitive) {
            result = String(result[..<noteRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return result
    }
}

// MARK: - Translation Cache Key

public struct TranslationCacheKey: Hashable, Sendable {
    public let text: String
    public let sourceLanguage: String
    public let targetLanguage: String
    public let engineType: String
    public let model: String?
    public let customPrompt: String?

    public init(
        text: String,
        sourceLanguage: String,
        targetLanguage: String,
        engineType: String,
        model: String? = nil,
        customPrompt: String? = nil
    ) {
        self.text = text
        self.sourceLanguage = sourceLanguage.lowercased()
        self.targetLanguage = targetLanguage.lowercased()
        self.engineType = engineType.lowercased()
        self.model = model
        self.customPrompt = customPrompt
    }
}

// MARK: - Translation LRU Cache

public final class TranslationLRUCache: @unchecked Sendable {
    private let capacity: Int
    private var cache: [TranslationCacheKey: String] = [:]
    private var order: [TranslationCacheKey] = []
    private let lock = NSLock()

    public init(capacity: Int = 500) {
        self.capacity = max(1, capacity)
    }

    public func get(_ key: TranslationCacheKey) -> String? {
        lock.lock()
        defer { lock.unlock() }
        guard let value = cache[key] else { return nil }
        if let idx = order.firstIndex(of: key) {
            order.remove(at: idx)
            order.append(key)
        }
        return value
    }

    public func set(_ key: TranslationCacheKey, value: String) {
        lock.lock()
        defer { lock.unlock() }
        if cache[key] != nil {
            cache[key] = value
            if let idx = order.firstIndex(of: key) {
                order.remove(at: idx)
            }
            order.append(key)
        } else {
            if order.count >= capacity {
                let oldest = order.removeFirst()
                cache.removeValue(forKey: oldest)
            }
            cache[key] = value
            order.append(key)
        }
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
        order.removeAll()
    }

    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return cache.count
    }
}

// MARK: - Translation Coordinator
public final class TranslationCoordinator: @unchecked Sendable {
    public static let shared = TranslationCoordinator()

    public var googleFreeEngine = GoogleFreeTranslationEngine()
    public var appleEngine = AppleTranslationEngine()
    public var cloudflareEngine = CloudflareWorkersAITranslationEngine.shared
    public let cache: TranslationLRUCache

    private let lock = NSLock()
    private var _onFallbackTriggered: (@Sendable (String, String) -> Void)?

    public var onFallbackTriggered: (@Sendable (String, String) -> Void)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _onFallbackTriggered
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _onFallbackTriggered = newValue
        }
    }

    public init(cacheCapacity: Int = 500) {
        self.cache = TranslationLRUCache(capacity: cacheCapacity)
    }

    public func clearCache() {
        cache.clear()
    }

    public var cachedTranslationsCount: Int {
        cache.count
    }

    public func translate(
        text: String,
        sourceLanguage: String,
        targetLanguage: String,
        engineType: String
    ) async throws -> String {
        try await translate(
            text: text,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            engineType: engineType,
            cloudflareConfig: nil
        )
    }

    public func translate(
        text: String,
        sourceLanguage: String,
        targetLanguage: String,
        engineType: String = "apple",
        cloudflareConfig: CloudflareConfig? = nil
    ) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let cacheKey = TranslationCacheKey(
            text: trimmed,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            engineType: engineType,
            model: engineType == "cloudflare" ? (cloudflareConfig?.model.trimmingCharacters(in: .whitespacesAndNewlines)) : nil,
            customPrompt: engineType == "cloudflare" ? (cloudflareConfig?.customPrompt.trimmingCharacters(in: .whitespacesAndNewlines)) : nil
        )

        if let cached = cache.get(cacheKey) {
            return cached
        }

        let result: String
        switch engineType {
        case "cloudflare":
            guard let cfConfig = cloudflareConfig, !cfConfig.accountId.isEmpty, !cfConfig.apiToken.isEmpty else {
                if let cfConfig = cloudflareConfig, cfConfig.fallbackEnabled {
                    notifyFallback(targetEngine: cfConfig.fallbackEngine, reason: "Missing credentials")
                    result = try await routeFallback(
                        text: trimmed,
                        sourceLanguage: sourceLanguage,
                        targetLanguage: targetLanguage,
                        fallbackEngine: cfConfig.fallbackEngine
                    )
                    break
                }
                throw CloudflareAIError.missingCredentials
            }

            do {
                result = try await cloudflareEngine.translate(
                    text: trimmed,
                    sourceLanguage: sourceLanguage,
                    targetLanguage: targetLanguage,
                    config: cfConfig
                )
            } catch {
                if cfConfig.fallbackEnabled {
                    notifyFallback(targetEngine: cfConfig.fallbackEngine, reason: error.localizedDescription)
                    result = try await routeFallback(
                        text: trimmed,
                        sourceLanguage: sourceLanguage,
                        targetLanguage: targetLanguage,
                        fallbackEngine: cfConfig.fallbackEngine
                    )
                } else {
                    throw error
                }
            }
        case "apple":
            result = try await appleEngine.translate(text: trimmed, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
        default:
            result = try await googleFreeEngine.translate(text: trimmed, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
        }

        cache.set(cacheKey, value: result)
        return result
    }

    private func notifyFallback(targetEngine: String, reason: String) {
        let callback = onFallbackTriggered
        callback?(targetEngine, reason)
    }

    private func routeFallback(
        text: String,
        sourceLanguage: String,
        targetLanguage: String,
        fallbackEngine: String
    ) async throws -> String {
        switch fallbackEngine {
        case "apple":
            return try await appleEngine.translate(text: text, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
        default:
            return try await googleFreeEngine.translate(text: text, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
        }
    }
}
