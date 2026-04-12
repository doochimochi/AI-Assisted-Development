import Foundation

/// A single transcribed segment from the STT pipeline.
/// Stores only text — no audio data is retained.
struct TranscriptSegment: Identifiable, Sendable {
    let id: UUID
    let text: String
    let timestamp: Date
    let isFinal: Bool          // false = Deepgram interim result

    init(text: String, isFinal: Bool = true, timestamp: Date = .now) {
        self.id = UUID()
        self.text = text
        self.isFinal = isFinal
        self.timestamp = timestamp
    }
}
