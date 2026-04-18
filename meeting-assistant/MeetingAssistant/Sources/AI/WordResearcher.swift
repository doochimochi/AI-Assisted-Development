import Foundation

@MainActor
final class WordResearcher: ObservableObject {
    @Published private(set) var entries: [WordEntry] = []

    private var recentlyResearched = Set<String>()
    private var lastResearchTime: Date = .distantPast
    private let minIntervalSeconds: TimeInterval = 8

    func analyze(segment: TranscriptSegment, transcript: String, scenario: MeetingScenario) async {
        guard !segment.isPartial else { return }

        let now = Date()
        guard now.timeIntervalSince(lastResearchTime) >= minIntervalSeconds else { return }

        let candidates = PromptTemplates.candidateTerms(from: segment.text)
        let newTerms = candidates.filter { !recentlyResearched.contains($0.lowercased()) }
        guard let term = newTerms.first else { return }

        lastResearchTime = now
        recentlyResearched.insert(term.lowercased())

        let entry = WordEntry(term: term, context: transcript)
        entries.insert(entry, at: 0)
        // Keep max 10 entries in memory
        if entries.count > 10 { entries.removeLast() }

        let entryId = entry.id
        let (system, user) = PromptTemplates.wordResearch(term: term, context: transcript, scenario: scenario)

        do {
            for try await token in AnthropicClient.shared.stream(systemPrompt: system, userPrompt: user, maxTokens: 200) {
                if let idx = entries.firstIndex(where: { $0.id == entryId }) {
                    entries[idx].definition += token
                }
            }
        } catch {
            // Silently fail - word research is supplementary
        }

        if let idx = entries.firstIndex(where: { $0.id == entryId }) {
            entries[idx].isStreaming = false
        }
    }

    func clear() {
        entries.removeAll()
        recentlyResearched.removeAll()
    }
}
