import Foundation

/// A detected term and its streaming AI-generated definition.
struct WordEntry: Identifiable, Sendable {
    let id: UUID
    let term: String
    let context: String          // sentence where the term appeared
    var definition: String       // streams in token by token
    let detectedAt: Date

    init(term: String, context: String) {
        self.id = UUID()
        self.term = term
        self.context = context
        self.definition = ""
        self.detectedAt = .now
    }
}
