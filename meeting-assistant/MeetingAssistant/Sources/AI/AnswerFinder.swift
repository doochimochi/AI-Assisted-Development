import Foundation

@MainActor
final class AnswerFinder: ObservableObject {
    @Published private(set) var entries: [AnswerEntry] = []

    private var lastAnswerTime: Date = .distantPast
    private let minIntervalSeconds: TimeInterval = 3

    func analyze(segment: TranscriptSegment, transcript: String, scenario: MeetingScenario, previousContext: String? = nil) async {
        guard !segment.isPartial else { return }
        guard segment.isQuestion else { return }

        let now = Date()
        guard now.timeIntervalSince(lastAnswerTime) >= minIntervalSeconds else { return }
        lastAnswerTime = now

        let question = segment.text
        var entry = AnswerEntry(question: question)
        entries.insert(entry, at: 0)
        if entries.count > 5 { entries.removeLast() }

        let entryId = entry.id
        let (system, user) = PromptTemplates.answerFinder(
            question: question,
            transcript: transcript,
            scenario: scenario,
            previousContext: previousContext
        )

        do {
            for try await token in AnthropicClient.shared.stream(systemPrompt: system, userPrompt: user, maxTokens: 400) {
                if let idx = entries.firstIndex(where: { $0.id == entryId }) {
                    entries[idx].answer += token
                }
            }
        } catch {
            if let idx = entries.firstIndex(where: { $0.id == entryId }) {
                entries[idx].answer = "Could not generate answer: \(error.localizedDescription)"
            }
        }

        if let idx = entries.firstIndex(where: { $0.id == entryId }) {
            entries[idx].isStreaming = false
        }
    }

    func clear() {
        entries.removeAll()
    }
}
