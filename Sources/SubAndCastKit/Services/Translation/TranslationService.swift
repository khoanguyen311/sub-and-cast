import Foundation

public protocol TranslationEngine: Sendable {
    var id: String { get }
    var displayName: String { get }
    func translate(text: String, sourceLanguage: String, targetLanguage: String) async throws -> String
}

// MARK: - Google Free / Public Web API (Zero Config / Free)
public final class GoogleFreeTranslationEngine: TranslationEngine {
    public let id = "google_free"
    public let displayName = "Google Translate (Free Web API)"

    public init() {}

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

        let (data, response) = try await URLSession.shared.data(for: request)

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

// MARK: - Google Gemini API (Free Tier)
public final class GeminiTranslationEngine: TranslationEngine {
    public let id = "gemini"
    public let displayName = "Google Gemini Flash (API Key)"
    private let apiKey: String
    private let modelName: String

    public init(apiKey: String, modelName: String = "gemini-2.0-flash") {
        self.apiKey = apiKey
        self.modelName = modelName
    }

    public func translate(text: String, sourceLanguage: String, targetLanguage: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw NSError(domain: "GeminiTranslation", code: 401, userInfo: [NSLocalizedDescriptionKey: "Gemini API key is not configured"])
        }

        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent?key=\(apiKey)"
        guard let url = URL(string: endpoint) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = """
        You are a real-time game subtitle translator. Translate the following text from \(sourceLanguage) to \(targetLanguage).
        Maintain dialogue tone, gaming context, and natural speech. Return ONLY the translated text without explanations or quotation marks.

        Text to translate:
        \(text)
        """

        let payload: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.2,
                "maxOutputTokens": 300
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "GeminiTranslation", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: "Gemini API error: \(errorBody)"])
        }

        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = root["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let textPart = parts.first?["text"] as? String else {
            throw URLError(.cannotParseResponse)
        }

        return textPart.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Translation Coordinator
public final class TranslationCoordinator: @unchecked Sendable {
    public static let shared = TranslationCoordinator()

    private let googleFreeEngine = GoogleFreeTranslationEngine()

    public init() {}

    public func translate(
        text: String,
        sourceLanguage: String,
        targetLanguage: String,
        engineType: String,
        geminiApiKey: String?
    ) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        switch engineType {
        case "gemini":
            if let key = geminiApiKey, !key.isEmpty {
                let geminiEngine = GeminiTranslationEngine(apiKey: key)
                return try await geminiEngine.translate(text: trimmed, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
            } else {
                // Fallback to free Google engine if key is missing
                return try await googleFreeEngine.translate(text: trimmed, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
            }
        default: // "apple" or "google_free"
            // Default to Google free web endpoint (reliable, zero auth, fast)
            return try await googleFreeEngine.translate(text: trimmed, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
        }
    }
}
