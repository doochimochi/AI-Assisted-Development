import Foundation

/// Single source of truth for all AI prompts.
/// Edit here — do not embed prompt strings anywhere else.
enum PromptTemplates {

    // MARK: - Word Research

    static func wordResearchSystem(scenario: MeetingScenario) -> String {
        """
        \(scenario.systemContext)
        You are explaining terms that appeared in a conversation.
        Respond in exactly 2-3 sentences: definition, then a brief example in context.
        Do not use headers or bullet points. Be concise.
        """
    }

    static func wordResearchUser(term: String, context: String) -> String {
        """
        Term heard in conversation: "\(term)"
        Surrounding context: "\(context)"
        Explain this term briefly for someone in this meeting.
        """
    }

    // MARK: - Answer Finder

    static func answerFinderSystem(scenario: MeetingScenario) -> String {
        """
        \(scenario.systemContext)
        The other party just asked a question. Provide a direct, confident answer
        in 1-3 sentences maximum. If you are uncertain, say so briefly.
        Do not repeat the question. Start your answer immediately.
        """
    }

    static func answerFinderUser(question: String, recentTranscript: String) -> String {
        """
        Question asked: "\(question)"

        Recent conversation context:
        \(recentTranscript.suffix(1500))

        Provide a direct answer.
        """
    }

    // MARK: - Question Generator

    static func questionGeneratorSystem(scenario: MeetingScenario) -> String {
        """
        \(scenario.systemContext)
        Based on the conversation so far, suggest exactly 3 questions the user could ask next.
        Output only the 3 questions, one per line, no numbering, no preamble, no explanation.
        Questions should be concise (under 15 words each) and advance the conversation.
        """
    }

    static func questionGeneratorUser(recentTranscript: String) -> String {
        """
        Conversation so far:
        \(recentTranscript.suffix(2000))

        Suggest 3 follow-up questions.
        """
    }

    // MARK: - Session Summary (for Memory system)

    static func sessionSummarySystem() -> String {
        """
        You are summarising a meeting transcript for future reference.
        Write 2-3 concise paragraphs: what was discussed, key decisions made, and open questions.
        Do not use bullet points. Write in past tense.
        """
    }

    static func sessionSummaryUser(transcript: String, scenario: MeetingScenario) -> String {
        """
        Meeting type: \(scenario.displayName)
        Transcript:
        \(transcript.suffix(4000))

        Write a brief summary.
        """
    }
}
