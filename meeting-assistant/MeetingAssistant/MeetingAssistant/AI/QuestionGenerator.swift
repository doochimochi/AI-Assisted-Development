import Foundation
import Combine

/// Feature 3 — Periodically generates contextual questions the user can ask.
///
/// Runs on a timer (default 30 s) or when the user taps "Refresh".
@MainActor
final class QuestionGenerator: ObservableObject {

    @Published private(set) var suggestions: [QuestionSuggestion] = []

    private let client: AnthropicClientProtocol
    private let interval: TimeInterval
    private var timerCancellable: AnyCancellable?
    private var activeTask: Task<Void, Never>?
    private var getTranscript: () -> String  // injected closure to avoid strong ref to TranscriptStore

    init(
        client: AnthropicClientProtocol = AnthropicClient.shared,
        interval: TimeInterval = AppSettings.shared.questionGeneratorIntervalSeconds,
        transcriptProvider: @escaping () -> String = { "" }
    ) {
        self.client = client
        self.interval = interval
        self.getTranscript = transcriptProvider
    }

    // MARK: - Lifecycle

    func start(scenario: MeetingScenario) {
        timerCancellable = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.generateOnce(scenario: scenario) }
    }

    func stop() {
        timerCancellable?.cancel()
        activeTask?.cancel()
    }

    func generateOnce(scenario: MeetingScenario) {
        let transcript = getTranscript()
        guard !transcript.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        activeTask?.cancel()
        activeTask = Task {
            let system = PromptTemplates.questionGeneratorSystem(scenario: scenario)
            let user   = PromptTemplates.questionGeneratorUser(recentTranscript: transcript)

            var buffer = ""
            for await token in client.streamCompletion(systemPrompt: system, userPrompt: user, maxTokens: 200) {
                guard !Task.isCancelled else { return }
                buffer += token
            }

            // Parse 3 newline-separated questions
            let lines = buffer
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .prefix(3)

            suggestions = lines.map { QuestionSuggestion(text: $0) }
        }
    }
}
