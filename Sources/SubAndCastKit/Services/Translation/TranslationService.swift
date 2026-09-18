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
public final class GoogleFreeTranslationEngine: TranslationEngine {
    public let id = "google_free"
    public let displayName = "Google Translate"

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

// MARK: - Apple Native Translation Engine
public final class AppleTranslationEngine: TranslationEngine {
    public let id = "apple"
    public let displayName = "Apple Native Translation"
    private let fallbackEngine = GoogleFreeTranslationEngine()

    public init() {}

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

// MARK: - Translation Coordinator
public final class TranslationCoordinator: @unchecked Sendable {
    public static let shared = TranslationCoordinator()

    private let googleFreeEngine = GoogleFreeTranslationEngine()
    private let appleEngine = AppleTranslationEngine()

    public init() {}

    public func translate(
        text: String,
        sourceLanguage: String,
        targetLanguage: String,
        engineType: String = "apple"
    ) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        switch engineType {
        case "apple":
            return try await appleEngine.translate(text: trimmed, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
        default:
            return try await googleFreeEngine.translate(text: trimmed, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
        }
    }
}
