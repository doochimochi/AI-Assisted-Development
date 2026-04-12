import Foundation

/// Finds previous sessions that are contextually relevant to the current session.
///
/// Matching strategy (simple, no vector DB needed):
/// 1. Same scenario type
/// 2. Contains at least 2 overlapping key terms
/// 3. Within the last 30 days
struct ContextMatcher {

    /// Returns up to `maxResults` previous sessions relevant to the given scenario and terms.
    func findRelated(
        scenario: MeetingScenario,
        currentTerms: [String] = [],
        maxResults: Int = 2
    ) -> [SessionRecord] {
        let recent = SessionMemoryManager.shared.loadRecent(limit: 20)
        let cutoff = Date.now.addingTimeInterval(-30 * 24 * 3600)

        return recent
            .filter { $0.date > cutoff && $0.scenario == scenario }
            .filter { record in
                guard !currentTerms.isEmpty else { return true }
                let prevTerms = record.keyTerms.map { $0.term.lowercased() }
                let overlap = currentTerms.filter { prevTerms.contains($0.lowercased()) }
                return overlap.count >= 1
            }
            .prefix(maxResults)
            .map { $0 }
    }

    /// Builds a context string to inject into AI prompts from a related session.
    func contextString(from record: SessionRecord) -> String {
        var lines = ["[Previous \(record.scenario.displayName) on \(record.date.formatted(.dateTime.month().day())):"]
        lines.append(record.summary)
        if !record.keyTerms.isEmpty {
            let terms = record.keyTerms.prefix(5).map { $0.term }.joined(separator: ", ")
            lines.append("Key topics discussed: \(terms)")
        }
        lines.append("]")
        return lines.joined(separator: "\n")
    }
}
