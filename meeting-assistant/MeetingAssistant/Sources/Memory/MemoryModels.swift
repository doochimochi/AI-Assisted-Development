import Foundation

struct SessionRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    let scenario: MeetingScenario
    let durationSeconds: TimeInterval
    var summary: String
    var keyTerms: [KeyTermRecord]
    var qaPairs: [QAPairRecord]
    var suggestedQuestions: [String]
    var transcriptExcerpt: String  // last ~500 tokens for context

    struct KeyTermRecord: Codable {
        let term: String
        let definition: String
    }

    struct QAPairRecord: Codable {
        let question: String
        let answer: String
    }

    init(scenario: MeetingScenario, durationSeconds: TimeInterval) {
        self.id = UUID()
        self.date = Date()
        self.scenario = scenario
        self.durationSeconds = durationSeconds
        self.summary = ""
        self.keyTerms = []
        self.qaPairs = []
        self.suggestedQuestions = []
        self.transcriptExcerpt = ""
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }

    var formattedDuration: String {
        let mins = Int(durationSeconds) / 60
        let secs = Int(durationSeconds) % 60
        return mins > 0 ? "\(mins)m \(secs)s" : "\(secs)s"
    }
}
