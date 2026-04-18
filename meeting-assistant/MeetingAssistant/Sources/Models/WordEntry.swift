import Foundation

struct WordEntry: Identifiable {
    let id: UUID
    let term: String
    let context: String
    var definition: String      // streams in token by token
    var isStreaming: Bool
    let timestamp: Date

    init(term: String, context: String) {
        self.id = UUID()
        self.term = term
        self.context = context
        self.definition = ""
        self.isStreaming = true
        self.timestamp = Date()
    }
}
