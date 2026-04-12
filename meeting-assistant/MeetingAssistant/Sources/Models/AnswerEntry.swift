import Foundation

struct AnswerEntry: Identifiable {
    let id: UUID
    let question: String
    var answer: String          // streams in token by token
    var isStreaming: Bool
    let timestamp: Date

    init(question: String) {
        self.id = UUID()
        self.question = question
        self.answer = ""
        self.isStreaming = true
        self.timestamp = Date()
    }
}
