import Foundation

/// A persisted record of one completed meeting session.
struct SessionRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    let scenario: MeetingScenario
    let durationSeconds: TimeInterval
    var summary: String
    var keyTerms: [TermRecord]
    var qaPairs: [QARecord]
    var suggestedQuestions: [String]
    var transcriptExcerpt: String          // last ~500 tokens of transcript
    var performanceMetrics: PerformanceMetrics?

    struct TermRecord: Codable {
        let term: String
        let definition: String
    }

    struct QARecord: Codable {
        let question: String
        let answer: String
    }

    struct PerformanceMetrics: Codable {
        let avgSTTLatencyMs: Double
        let avgClaudeTTFTMs: Double
        let peakMemoryMB: Double
        let droppedAudioChunks: Int
        let webSocketReconnects: Int
    }
}
