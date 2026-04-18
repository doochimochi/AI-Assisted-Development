import Foundation

// Translates Korean (or any non-English) text to English using Claude Haiku.
// Haiku is used intentionally: fastest latency (~200–400ms), cheapest cost.
// Translation runs as a fire-and-forget task alongside AI features.
@MainActor
final class Translator {
    static let shared = Translator()
    private init() {}

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    // Haiku: fastest + cheapest — ideal for short translation tasks
    private let model = "claude-haiku-4-5-20251001"

    /// Translates text to English. Returns nil if translation is unnecessary or fails.
    func translateToEnglish(_ text: String) async -> String? {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        let apiKey = AppSettings.shared.anthropicApiKey
        guard !apiKey.isEmpty else { return nil }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 10   // fast timeout — translation is best-effort
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 300,
            "system": "Translate the following to English. Output only the translation, nothing else. Preserve the original meaning exactly.",
            "messages": [["role": "user", "content": text]]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let content = (json["content"] as? [[String: Any]])?.first,
               let translation = content["text"] as? String {
                return translation.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch { /* silent fail — translation is supplementary */ }

        return nil
    }
}
