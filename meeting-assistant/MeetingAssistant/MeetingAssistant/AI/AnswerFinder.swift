import Foundation

/// Feature 2 — Detects questions from the other party in the transcript
/// and streams AI-generated answers.
///
/// Rate limited to 1 answer per `cooldown` seconds.
@MainActor
final class AnswerFinder: ObservableObject {

    @Published private(set) var entries: [AnswerEntry] = []

    private let client: AnthropicClientProtocol
    private let cooldown: TimeInterval
    private var lastAnswerTime: Date = .distantPast
    private var activeStreamTask: Task<Void, Never>?
    private let maxEntries: Int

    init(
        client: AnthropicClientProtocol = AnthropicClient.shared,
        cooldown: TimeInterval = AppSettings.shared.answerFinderCooldownSeconds,
        maxEntries: Int = AppSettings.shared.maxResultsPerFeature
    ) {
        self.client = client
        self.cooldown = cooldown
        self.maxEntries = maxEntries
    }

    // MARK: - Public API

    func analyze(segment: TranscriptSegment, recentTranscript: String, scenario: MeetingScenario) {
        guard segment.isFinal else { return }
        guard Date.now.timeIntervalSince(lastAnswerTime) >= cooldown else { return }

        guard let question = detectQuestion(in: segment.text) else { return }
        lastAnswerTime = .now

        var entry = AnswerEntry(question: question)
        entries.insert(entry, at: 0)
        if entries.count > maxEntries { entries.removeLast() }

        let entryID = entry.id

        activeStreamTask?.cancel()
        activeStreamTask = Task {
            let system = PromptTemplates.answerFinderSystem(scenario: scenario)
            let user   = PromptTemplates.answerFinderUser(question: question, recentTranscript: recentTranscript)

            for await token in client.streamCompletion(systemPrompt: system, userPrompt: user, maxTokens: 500) {
                guard !Task.isCancelled else { break }
                if let idx = entries.firstIndex(where: { $0.id == entryID }) {
                    entries[idx].answer += token
                }
            }
        }
    }

    // MARK: - Question Detection Heuristic

    /// Detects whether a segment contains a question.
    /// Checks for: ends with "?", or starts with interrogative words.
    private func detectQuestion(in text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasSuffix("?") { return trimmed }

        let interrogatives = ["what", "how", "why", "when", "where", "who",
                              "which", "could you", "can you", "do you", "did you",
                              "are you", "is there", "have you"]
        let lower = trimmed.lowercased()
        if interrogatives.contains(where: { lower.hasPrefix($0) }) {
            return trimmed
        }

        return nil
    }
}
