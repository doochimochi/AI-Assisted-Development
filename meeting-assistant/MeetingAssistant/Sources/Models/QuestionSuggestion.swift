import Foundation

struct QuestionSuggestion: Identifiable {
    let id: UUID
    let text: String
    var isCopied: Bool
    let timestamp: Date

    init(text: String) {
        self.id = UUID()
        self.text = text
        self.isCopied = false
        self.timestamp = Date()
    }
}
