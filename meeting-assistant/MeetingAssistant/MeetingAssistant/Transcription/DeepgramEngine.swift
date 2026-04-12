import Foundation
import os.signpost

private let log = OSLog(subsystem: "com.meetingassistant", category: "Deepgram")

/// Cloud STT using Deepgram Nova-3 via WebSocket streaming.
///
/// Audio chunks (16 kHz int16 PCM) are sent as binary WebSocket frames.
/// Deepgram returns JSON transcription results; interim results arrive first,
/// followed by final results with `is_final: true`.
///
/// WebSocket URL format:
///   wss://api.deepgram.com/v1/listen?model=nova-3&encoding=linear16&sample_rate=16000
///   &channels=1&interim_results=true&smart_format=true&token=<API_KEY>
actor DeepgramEngine: TranscriptionEngine {

    private var webSocketTask: URLSessionWebSocketTask?
    private var sendTask: Task<Void, Error>?
    private var receiveTask: Task<Void, Never>?
    private var continuation: AsyncThrowingStream<TranscriptSegment, Error>.Continuation?
    private let settings = AppSettings.shared

    // MARK: - TranscriptionEngine

    nonisolated func startTranscription(audioStream: AsyncStream<Data>) async throws -> AsyncThrowingStream<TranscriptSegment, Error> {
        try await self._startTranscription(audioStream: audioStream)
    }

    private func _startTranscription(audioStream: AsyncStream<Data>) async throws -> AsyncThrowingStream<TranscriptSegment, Error> {
        let apiKey = settings.deepgramAPIKey
        guard !apiKey.isEmpty else { throw DeepgramError.missingAPIKey }

        let url = buildURL(apiKey: apiKey)
        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: url)
        webSocketTask = task
        task.resume()

        let (stream, cont) = AsyncThrowingStream<TranscriptSegment, Error>.makeStream()
        continuation = cont

        // Send audio chunks
        sendTask = Task {
            for await chunk in audioStream {
                guard !Task.isCancelled else { break }
                os_signpost(.begin, log: log, name: "STTResult")
                try await task.send(.data(chunk))
            }
            // Signal end of stream to Deepgram
            try? await task.send(.string("{\"type\":\"CloseStream\"}"))
        }

        // Receive transcription results
        receiveTask = Task { [weak self] in
            guard let self else { return }
            await self.receiveLoop(task: task)
        }

        return stream
    }

    nonisolated func stopTranscription() async {
        await _stopTranscription()
    }

    private func _stopTranscription() {
        sendTask?.cancel()
        receiveTask?.cancel()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        continuation?.finish()
        webSocketTask = nil
        continuation = nil
    }

    // MARK: - WebSocket Receive Loop

    private func receiveLoop(task: URLSessionWebSocketTask) async {
        while !Task.isCancelled {
            do {
                let message = try await task.receive()
                switch message {
                case .string(let text):
                    if let segment = parseDeepgramResult(text) {
                        os_signpost(.end, log: log, name: "STTResult")
                        continuation?.yield(segment)
                    }
                case .data:
                    break // Deepgram sends JSON as text
                @unknown default:
                    break
                }
            } catch {
                continuation?.finish(throwing: error)
                return
            }
        }
    }

    // MARK: - JSON Parsing

    private func parseDeepgramResult(_ json: String) -> TranscriptSegment? {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let channel = (obj["channel"] as? [String: Any]),
              let alternatives = channel["alternatives"] as? [[String: Any]],
              let transcript = alternatives.first?["transcript"] as? String,
              !transcript.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }

        let isFinal = (obj["is_final"] as? Bool) ?? false
        return TranscriptSegment(text: transcript, isFinal: isFinal)
    }

    // MARK: - URL Builder

    private func buildURL(apiKey: String) -> URL {
        var components = URLComponents()
        components.scheme = "wss"
        components.host = "api.deepgram.com"
        components.path = "/v1/listen"
        components.queryItems = [
            URLQueryItem(name: "model",            value: "nova-3"),
            URLQueryItem(name: "encoding",         value: "linear16"),
            URLQueryItem(name: "sample_rate",      value: "16000"),
            URLQueryItem(name: "channels",         value: "1"),
            URLQueryItem(name: "interim_results",  value: "true"),
            URLQueryItem(name: "smart_format",     value: "true"),
            URLQueryItem(name: "token",            value: apiKey)
        ]
        return components.url!
    }

    // MARK: - Error

    enum DeepgramError: Error {
        case missingAPIKey
        case connectionFailed
    }
}
