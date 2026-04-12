import Foundation

@MainActor
final class SessionMemoryManager: ObservableObject {
    @Published private(set) var recentSessions: [SessionRecord] = []

    static let shared = SessionMemoryManager()

    private let storageURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MeetingAssistant/sessions", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        loadRecent()
    }

    func save(_ record: SessionRecord) {
        let filename = "\(ISO8601DateFormatter().string(from: record.date))_\(record.id.uuidString.prefix(8)).json"
        let fileURL = storageURL.appendingPathComponent(filename)
        guard let data = try? encoder.encode(record) else { return }
        try? data.write(to: fileURL, options: .atomic)
        recentSessions.insert(record, at: 0)
        if recentSessions.count > 20 { recentSessions.removeLast() }
    }

    // Build and save session from coordinator state
    func saveSession(
        scenario: MeetingScenario,
        duration: TimeInterval,
        words: [WordEntry],
        answers: [AnswerEntry],
        questions: [QuestionSuggestion],
        transcript: String
    ) async {
        var record = SessionRecord(scenario: scenario, durationSeconds: duration)
        record.keyTerms = words.map { .init(term: $0.term, definition: $0.definition) }
        record.qaPairs = answers.map { .init(question: $0.question, answer: $0.answer) }
        record.suggestedQuestions = questions.map(\.text)
        record.transcriptExcerpt = String(transcript.suffix(2000))

        // Generate summary via Claude (non-blocking, best effort)
        let (system, user) = PromptTemplates.sessionSummary(transcript: transcript, scenario: scenario)
        var summary = ""
        do {
            for try await token in AnthropicClient.shared.stream(systemPrompt: system, userPrompt: user, maxTokens: 500) {
                summary += token
            }
        } catch {}
        record.summary = summary.isEmpty ? "(No summary generated)" : summary

        save(record)
    }

    func loadRecent() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: storageURL, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles
        ) else { return }

        let sorted = files
            .filter { $0.pathExtension == "json" }
            .sorted { a, b in
                let aDate = (try? a.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
                let bDate = (try? b.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
                return aDate > bDate
            }
            .prefix(20)

        recentSessions = sorted.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(SessionRecord.self, from: data)
        }
    }

    // Find sessions relevant to the given scenario
    func relatedSessions(for scenario: MeetingScenario, limit: Int = 3) -> [SessionRecord] {
        recentSessions.filter { $0.scenario == scenario }.prefix(limit).map { $0 }
    }
}
