import Foundation

/// Protocol defining a speech-to-text engine.
/// Conform to this for both DeepgramEngine (cloud) and WhisperKitEngine (offline).
protocol TranscriptionEngine: AnyObject {
    /// Start transcription, returning an async stream of segments.
    /// The stream produces both interim (isFinal=false) and final (isFinal=true) results.
    func startTranscription(audioStream: AsyncStream<Data>) async throws -> AsyncThrowingStream<TranscriptSegment, Error>

    /// Gracefully stop the transcription session.
    func stopTranscription() async
}
