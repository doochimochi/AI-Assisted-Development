import Foundation

@MainActor
final class QuestionGenerator: ObservableObject {
    @Published private(set) var suggestions: [QuestionSuggestion] = []
    @Published private(set) var isGenerating: Bool = false

    private var generationTask: Task<Void, Never>?
    private var lastGenerationTime: Date = .distantPast
    private let autoIntervalSeconds: TimeInterval = 30

    // Called every time a new final segment arrives
    func considerGeneration(transcript: String, scenario: MeetingScenario, previousContext: String? = nil) async {
        let now = Date()
        guard now.timeIntervalSince(lastGenerationTime) >= autoIntervalSeconds else { return }
        guard transcript.split(separator: " ").count > 30 else { return }  // need enough content
        await generate(transcript: transcript, scenario: scenario, previousContext: previousContext)
    }

    // Manual trigger from UI
    func generate(transcript: String, scenario: MeetingScenario, previousContext: String? = nil) async {
        guard !isGenerating else { return }

        lastGenerationTime = Date()
        isGenerating = true
        var accumulated = ""

        let (system, user) = PromptTemplates.questionGenerator(
            transcript: transcript,
            scenario: scenario,
            previousContext: previousContext
        )

        do {
            for try await token in AnthropicClient.shared.stream(systemPrompt: system, userPrompt: user, maxTokens: 200) {
                accumulated += token
            }
            let questions = accumulated
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(3)
                .map { QuestionSuggestion(text: $0) }

            suggestions = Array(questions)
        } catch {
            // Silent fail - suggestions are supplementary
        }

        isGenerating = false
    }

    func markCopied(id: UUID) {
        if let idx = suggestions.firstIndex(where: { $0.id == id }) {
            suggestions[idx].isCopied = true
        }
    }

    func clear() {
        suggestions.removeAll()
        generationTask?.cancel()
    }
}
