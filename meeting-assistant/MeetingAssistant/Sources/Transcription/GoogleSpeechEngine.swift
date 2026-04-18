import Foundation

// Google Cloud Speech-to-Text v1 REST API
// Accumulates PCM audio, detects silence, then POSTs to the recognize endpoint.
// No gRPC dependency — uses plain URLSession.
// API: https://cloud.google.com/speech-to-text/docs/reference/rest/v1/speech/recognize
final class GoogleSpeechEngine: TranscriptionEngine {
    private let apiKey: String

    // Audio accumulation & silence detection
    private var audioAccumulator = Data()
    private var silentByteCount = 0
    private let sampleRate = 16_000            // 16kHz mono Int16
    private let bytesPerSample = 2             // Int16 = 2 bytes
    private let silenceRMSThreshold: Float = 0.015
    private let silenceTriggerSeconds: Double = 0.6   // send after this much silence
    private let maxBufferSeconds: Double = 5.0         // hard cap

    private(set) var isConnected = false

    private var streamContinuation: AsyncThrowingStream<TranscriptSegment, Error>.Continuation?

    lazy var transcriptStream: AsyncThrowingStream<TranscriptSegment, Error> = {
        AsyncThrowingStream { [weak self] continuation in
            self?.streamContinuation = continuation
        }
    }()

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func connect() async throws {
        audioAccumulator = Data()
        silentByteCount = 0
        isConnected = true
    }

    func disconnect() async {
        isConnected = false
        // Flush remaining buffer (> 0.5 s) before closing
        let remaining = audioAccumulator
        audioAccumulator = Data()
        if remaining.count > sampleRate * bytesPerSample / 2 {
            Task { await recognize(pcmData: remaining) }
        }
        streamContinuation?.finish()
    }

    func send(audioData: Data) async throws {
        guard isConnected else { throw GoogleSpeechError.notConnected }
        audioAccumulator.append(audioData)

        let rms = computeRMS(audioData)
        if rms < silenceRMSThreshold {
            silentByteCount += audioData.count
        } else {
            silentByteCount = 0
        }

        let silenceSec = Double(silentByteCount) / Double(sampleRate * bytesPerSample)
        let bufferSec  = Double(audioAccumulator.count) / Double(sampleRate * bytesPerSample)

        let shouldSend = (silenceSec >= silenceTriggerSeconds && bufferSec >= 1.0)
                      || bufferSec >= maxBufferSeconds

        if shouldSend {
            let data = audioAccumulator
            audioAccumulator = Data()
            silentByteCount = 0
            Task { await recognize(pcmData: data) }
        }
    }

    // MARK: - Helpers

    private func computeRMS(_ data: Data) -> Float {
        let count = data.count / bytesPerSample
        guard count > 0 else { return 0 }
        let sumOfSquares = data.withUnsafeBytes { ptr -> Float in
            let samples = ptr.bindMemory(to: Int16.self)
            return samples.prefix(count).reduce(Float(0)) { acc, s in
                let f = Float(s) / 32_768.0
                return acc + f * f
            }
        }
        return sqrt(sumOfSquares / Float(count))
    }

    // MARK: - REST recognition

    private func recognize(pcmData: Data) async {
        guard !pcmData.isEmpty else { return }

        let base64Audio = pcmData.base64EncodedString()
        let body: [String: Any] = [
            "config": [
                "encoding": "LINEAR16",
                "sampleRateHertz": sampleRate,
                "languageCode": "en-US",
                "alternativeLanguageCodes": ["ko-KR", "ja-JP"],
                "model": "latest_long",
                "enableAutomaticPunctuation": true
            ],
            "audio": ["content": base64Audio]
        ]

        guard let url = URL(string: "https://speech.googleapis.com/v1/speech:recognize?key=\(apiKey)"),
              let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        request.timeoutInterval = 12

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]] else { return }

            for result in results {
                guard let alternatives = result["alternatives"] as? [[String: Any]],
                      let transcript = alternatives.first?["transcript"] as? String,
                      !transcript.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
                let detectedLanguage = (result["languageCode"] as? String)?.lowercased()
                streamContinuation?.yield(TranscriptSegment(
                    text: transcript.trimmingCharacters(in: .whitespaces),
                    isPartial: false,
                    detectedLanguage: detectedLanguage
                ))
            }
        } catch {
            // Silent fail — STT is best-effort; network errors don't crash the session
        }
    }

    enum GoogleSpeechError: LocalizedError {
        case notConnected
        var errorDescription: String? { "Google Speech engine is not running" }
    }
}
