import Foundation

final class AnthropicClient {
    static let shared = AnthropicClient()
    private init() {}

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model = "claude-sonnet-4-6"

    /// Streams a Claude response token by token.
    /// - Returns: `AsyncThrowingStream<String, Error>` yielding text deltas
    func stream(
        systemPrompt: String,
        userPrompt: String,
        maxTokens: Int = 400
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let apiKey = await AppSettings.shared.anthropicApiKey
                    guard !apiKey.isEmpty else {
                        throw AnthropicError.missingAPIKey
                    }

                    var request = URLRequest(url: self.endpoint)
                    request.httpMethod = "POST"
                    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
                    request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

                    let body: [String: Any] = [
                        "model": self.model,
                        "max_tokens": maxTokens,
                        "stream": true,
                        "system": systemPrompt,
                        "messages": [["role": "user", "content": userPrompt]]
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw AnthropicError.invalidResponse
                    }
                    guard httpResponse.statusCode == 200 else {
                        throw AnthropicError.httpError(httpResponse.statusCode)
                    }

                    // Parse SSE stream
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonStr = String(line.dropFirst(6))
                        if jsonStr == "[DONE]" { break }

                        guard let data = jsonStr.data(using: .utf8),
                              let event = try? JSONDecoder().decode(SSEEvent.self, from: data)
                        else { continue }

                        if event.type == "message_stop" { break }

                        if event.type == "content_block_delta",
                           let delta = event.delta,
                           delta.type == "text_delta",
                           let text = delta.text {
                            continuation.yield(text)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    enum AnthropicError: LocalizedError {
        case missingAPIKey
        case invalidResponse
        case httpError(Int)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey: return "Anthropic API key is not set. Add it in Settings."
            case .invalidResponse: return "Invalid response from Claude API."
            case .httpError(let code): return "Claude API error: HTTP \(code)"
            }
        }
    }
}

// MARK: - SSE Event models

private struct SSEEvent: Decodable {
    let type: String
    let delta: SSEDelta?
}

private struct SSEDelta: Decodable {
    let type: String?
    let text: String?
}
