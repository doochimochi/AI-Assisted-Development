import Foundation
import os.signpost

private let log = OSLog(subsystem: "com.meetingassistant", category: "AnthropicClient")

/// Protocol for dependency injection in tests.
protocol AnthropicClientProtocol {
    func streamCompletion(
        systemPrompt: String,
        userPrompt: String,
        maxTokens: Int
    ) -> AsyncThrowingStream<String, Error>
}

/// Streams Claude API responses token by token using Server-Sent Events (SSE).
///
/// Endpoint: POST https://api.anthropic.com/v1/messages
/// Model: claude-sonnet-4-6
/// All three AI features share this single client.
final class AnthropicClient: AnthropicClientProtocol {

    static let shared = AnthropicClient()

    private let model = "claude-sonnet-4-6"
    private let apiURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private let settings = AppSettings.shared

    private init() {}

    // MARK: - Streaming Completion

    func streamCompletion(
        systemPrompt: String,
        userPrompt: String,
        maxTokens: Int = 400
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let request = try self.buildRequest(
                        system: systemPrompt,
                        user: userPrompt,
                        maxTokens: maxTokens
                    )
                    os_signpost(.begin, log: log, name: "AIResponse")
                    try await self.performStreaming(request: request, continuation: continuation)
                    os_signpost(.end, log: log, name: "AIResponse")
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Private

    private func buildRequest(system: String, user: String, maxTokens: Int) throws -> URLRequest {
        let apiKey = settings.anthropicAPIKey
        guard !apiKey.isEmpty else { throw AnthropicError.missingAPIKey }

        var req = URLRequest(url: apiURL)
        req.httpMethod = "POST"
        req.setValue(apiKey,              forHTTPHeaderField: "x-api-key")
        req.setValue("application/json",  forHTTPHeaderField: "Content-Type")
        req.setValue("2023-06-01",        forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "stream": true,
            "system": system,
            "messages": [["role": "user", "content": user]]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return req
    }

    private func performStreaming(
        request: URLRequest,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnthropicError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw AnthropicError.httpError(httpResponse.statusCode)
        }

        var firstToken = true
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6))
            guard payload != "[DONE]" else { break }

            if let token = extractToken(from: payload) {
                if firstToken {
                    os_signpost(.end, log: log, name: "AIResponse")   // TTFT marker
                    firstToken = false
                }
                continuation.yield(token)
            }
        }
    }

    private func extractToken(from json: String) -> String? {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = obj["type"] as? String,
              type == "content_block_delta",
              let delta = obj["delta"] as? [String: Any],
              let text = delta["text"] as? String else { return nil }
        return text
    }

    // MARK: - Errors

    enum AnthropicError: Error, LocalizedError {
        case missingAPIKey
        case invalidResponse
        case httpError(Int)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:        return "Anthropic API key not set. Add it in Settings."
            case .invalidResponse:      return "Invalid response from Claude API."
            case .httpError(let code):  return "Claude API returned HTTP \(code)."
            }
        }
    }
}
