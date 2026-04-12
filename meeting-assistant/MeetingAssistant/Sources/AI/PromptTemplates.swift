import Foundation

enum PromptTemplates {

    // MARK: - Word Research

    static func wordResearch(term: String, context: String, scenario: MeetingScenario) -> (system: String, user: String) {
        let system = scenario.wordResearchSystemPrompt
        let user = """
        Term: "\(term)"
        Meeting context: \(context.prefix(300))

        Explain this term briefly. Format: [Term]: [1-sentence definition]. [1 practical example or usage tip].
        """
        return (system, user)
    }

    // MARK: - Answer Finder

    static func answerFinder(question: String, transcript: String, scenario: MeetingScenario, previousContext: String? = nil) -> (system: String, user: String) {
        let system = scenario.answerFinderSystemPrompt
        var contextBlock = "Recent conversation:\n\(transcript.prefix(1500))"
        if let prev = previousContext, !prev.isEmpty {
            contextBlock = "Previous meeting context:\n\(prev.prefix(500))\n\n" + contextBlock
        }
        let user = """
        \(contextBlock)

        Question just asked: "\(question)"

        Provide a direct, confident answer I can say right now.
        """
        return (system, user)
    }

    // MARK: - Question Generator

    static func questionGenerator(transcript: String, scenario: MeetingScenario, previousContext: String? = nil) -> (system: String, user: String) {
        let system = scenario.questionGeneratorSystemPrompt
        var contextBlock = transcript.prefix(2000).description
        if let prev = previousContext, !prev.isEmpty {
            contextBlock = "Background from previous meeting:\n\(prev.prefix(400))\n\nCurrent conversation:\n\(contextBlock)"
        }
        let user = """
        Conversation so far:
        \(contextBlock)

        Suggest 3 questions I can ask next.
        """
        return (system, user)
    }

    // MARK: - Session Summary (for memory)

    static func sessionSummary(transcript: String, scenario: MeetingScenario) -> (system: String, user: String) {
        let system = "You are a meeting summarizer. Be concise and structured."
        let user = """
        Meeting type: \(scenario.displayName)

        Full transcript:
        \(transcript.prefix(8000))

        Write a 2-3 paragraph summary covering:
        1. Main topics discussed
        2. Key decisions or outcomes
        3. Action items or follow-ups (if any)
        """
        return (system, user)
    }

    // MARK: - Term detection heuristic

    /// Returns candidate terms from a segment that may be worth researching
    static func candidateTerms(from text: String) -> [String] {
        let words = text.components(separatedBy: .whitespaces)
        var candidates: [String] = []

        // Acronyms (2-5 uppercase letters)
        let acronymPattern = try? NSRegularExpression(pattern: "\\b[A-Z]{2,5}\\b")
        let range = NSRange(text.startIndex..., in: text)
        acronymPattern?.enumerateMatches(in: text, range: range) { match, _, _ in
            if let r = match.flatMap({ Range($0.range, in: text) }) {
                candidates.append(String(text[r]))
            }
        }

        // Long technical-looking words (>9 chars, camelCase or hyphenated)
        for word in words {
            let clean = word.trimmingCharacters(in: .punctuationCharacters)
            if clean.count > 9 && clean.first?.isLowercase == true {
                candidates.append(clean)
            }
        }

        return Array(Set(candidates)).prefix(3).map { $0 }
    }
}
