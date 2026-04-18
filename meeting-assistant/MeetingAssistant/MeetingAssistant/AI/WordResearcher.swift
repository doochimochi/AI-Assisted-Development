import Foundation

/// Feature 1 — Detects important/technical terms in new transcript segments
/// and streams AI-generated definitions.
///
/// Rate limited to 1 research per `cooldown` seconds to avoid excessive API calls.
@MainActor
final class WordResearcher: ObservableObject {

    @Published private(set) var entries: [WordEntry] = []

    private let client: AnthropicClientProtocol
    private let cooldown: TimeInterval
    private var lastResearchTime: Date = .distantPast
    private var activeStreamTask: Task<Void, Never>?
    private let maxEntries: Int

    init(
        client: AnthropicClientProtocol = AnthropicClient.shared,
        cooldown: TimeInterval = AppSettings.shared.wordResearchCooldownSeconds,
        maxEntries: Int = AppSettings.shared.maxResultsPerFeature
    ) {
        self.client = client
        self.cooldown = cooldown
        self.maxEntries = maxEntries
    }

    // MARK: - Public API

    func analyze(_ segment: TranscriptSegment, scenario: MeetingScenario) {
        guard segment.isFinal else { return }
        guard Date.now.timeIntervalSince(lastResearchTime) >= cooldown else { return }

        guard let term = detectTerm(in: segment.text) else { return }
        lastResearchTime = .now

        var entry = WordEntry(term: term, context: segment.text)
        entries.insert(entry, at: 0)
        if entries.count > maxEntries { entries.removeLast() }

        // Capture entry id so the stream task can update the correct entry
        let entryID = entry.id

        activeStreamTask?.cancel()
        activeStreamTask = Task {
            let system = PromptTemplates.wordResearchSystem(scenario: scenario)
            let user   = PromptTemplates.wordResearchUser(term: term, context: segment.text)

            for await token in client.streamCompletion(systemPrompt: system, userPrompt: user, maxTokens: 300) {
                guard !Task.isCancelled else { break }
                if let idx = entries.firstIndex(where: { $0.id == entryID }) {
                    entries[idx].definition += token
                }
            }
        }
    }

    // MARK: - Term Detection Heuristic

    /// Detects a candidate term from a transcript segment.
    /// Looks for: acronyms, long words (>8 chars), or capitalized multi-word phrases.
    private func detectTerm(in text: String) -> String? {
        let words = text.components(separatedBy: .whitespaces)

        // Acronym (2-6 uppercase letters)
        if let acronym = words.first(where: { $0.range(of: #"^[A-Z]{2,6}$"#, options: .regularExpression) != nil }) {
            return acronym
        }

        // Long technical word (>8 chars, alphabetic)
        if let longWord = words.first(where: {
            $0.count > 8 &&
            $0.range(of: #"^[a-zA-Z]+$"#, options: .regularExpression) != nil
        }) {
            return longWord
        }

        // Capitalized phrase of 2-3 words (proper nouns, product names)
        let capitalizedRun = zip(words, words.dropFirst())
            .first { $0.0.first?.isUppercase == true && $0.1.first?.isUppercase == true }
            .map { "\($0.0) \($0.1)" }

        return capitalizedRun
    }
}
