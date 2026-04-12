import Foundation

struct TranscriptSegment: Identifiable, Equatable {
    let id: UUID
    let text: String
    let timestamp: Date
    let isPartial: Bool  // true = interim Deepgram result, will be replaced

    init(id: UUID = UUID(), text: String, timestamp: Date = Date(), isPartial: Bool = false) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.isPartial = isPartial
    }

    var isQuestion: Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("?") { return true }
        let questionWords = ["what", "how", "why", "when", "where", "who", "which", "could you", "can you", "would you", "is there", "are there", "do you", "did you", "have you"]
        let lower = trimmed.lowercased()
        return questionWords.contains { lower.hasPrefix($0) }
    }
}
