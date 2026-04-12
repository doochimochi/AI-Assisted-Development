import Foundation

/// A detected question from the other party and the AI-generated answer.
struct AnswerEntry: Identifiable, Sendable {
    let id: UUID
    let question: String
    var answer: String           // streams in token by token
    let detectedAt: Date

    init(question: String) {
        self.id = UUID()
        self.question = question
        self.answer = ""
        self.detectedAt = .now
    }
}
