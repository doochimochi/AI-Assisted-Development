import Foundation

// Deepgram Nova-3 streaming STT via WebSocket
// Docs: https://developers.deepgram.com/docs/getting-started-with-live-streaming-audio
final class DeepgramEngine: TranscriptionEngine {
    private let apiKey: String
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var streamContinuation: AsyncThrowingStream<TranscriptSegment, Error>.Continuation?

    private(set) var isConnected = false

    lazy var transcriptStream: AsyncThrowingStream<TranscriptSegment, Error> = {
        AsyncThrowingStream { continuation in
            self.streamContinuation = continuation
        }
    }()

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func connect() async throws {
        var components = URLComponents()
        components.scheme = "wss"
        components.host = "api.deepgram.com"
        components.path = "/v1/listen"
        components.queryItems = [
            URLQueryItem(name: "model", value: "nova-3"),
            URLQueryItem(name: "language", value: "multi"),  // multilingual auto-detect
            URLQueryItem(name: "encoding", value: "linear16"),
            URLQueryItem(name: "sample_rate", value: "16000"),
            URLQueryItem(name: "channels", value: "1"),
            URLQueryItem(name: "interim_results", value: "true"),
            URLQueryItem(name: "endpointing", value: "300"),   // 300ms silence = end of utterance
            URLQueryItem(name: "smart_format", value: "true"),
            URLQueryItem(name: "punctuate", value: "true")
        ]
        guard let url = components.url else { throw DeepgramError.invalidURL }

        var request = URLRequest(url: url)
        request.addValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
        webSocketTask = session?.webSocketTask(with: request)
        webSocketTask?.resume()
        isConnected = true

        Task { await receiveLoop() }
    }

    func disconnect() async {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
        streamContinuation?.finish()
    }

    func send(audioData: Data) async throws {
        guard isConnected, let task = webSocketTask else { throw DeepgramError.notConnected }
        try await task.send(.data(audioData))
    }

    // MARK: - Receive loop

    private func receiveLoop() async {
        guard let task = webSocketTask else { return }
        do {
            while isConnected {
                let message = try await task.receive()
                switch message {
                case .string(let text):
                    if let segment = parseDeepgramResponse(text) {
                        streamContinuation?.yield(segment)
                    }
                case .data:
                    break  // Deepgram sends JSON strings only
                @unknown default:
                    break
                }
            }
        } catch {
            if isConnected {
                streamContinuation?.finish(throwing: error)
            }
        }
    }

    // MARK: - JSON parsing

    private func parseDeepgramResponse(_ json: String) -> TranscriptSegment? {
        guard let data = json.data(using: .utf8),
              let response = try? JSONDecoder().decode(DeepgramResponse.self, from: data),
              let alternative = response.channel?.alternatives?.first,
              !alternative.transcript.isEmpty else { return nil }

        return TranscriptSegment(
            text: alternative.transcript,
            isPartial: !(response.isFinal ?? true)
        )
    }

    enum DeepgramError: LocalizedError {
        case invalidURL, notConnected
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid Deepgram WebSocket URL"
            case .notConnected: return "Deepgram WebSocket is not connected"
            }
        }
    }
}

// MARK: - Deepgram response models

private struct DeepgramResponse: Decodable {
    let isFinal: Bool?
    let channel: DeepgramChannel?

    enum CodingKeys: String, CodingKey {
        case isFinal = "is_final"
        case channel
    }
}

private struct DeepgramChannel: Decodable {
    let alternatives: [DeepgramAlternative]?
}

private struct DeepgramAlternative: Decodable {
    let transcript: String
    let confidence: Double?
}
