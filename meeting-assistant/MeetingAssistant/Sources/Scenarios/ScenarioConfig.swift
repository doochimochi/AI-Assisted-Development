import Foundation

enum MeetingScenario: String, CaseIterable, Identifiable, Codable {
    case customer = "customer"
    case team = "team"
    case warRoom = "warRoom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .customer: return "Customer Call"
        case .team:     return "Team Meeting"
        case .warRoom:  return "War Room"
        }
    }

    var emoji: String {
        switch self {
        case .customer: return "🤝"
        case .team:     return "👥"
        case .warRoom:  return "🚨"
        }
    }

    var wordResearchSystemPrompt: String {
        let base = "You are a real-time meeting assistant. Respond in 2-3 sentences max."
        switch self {
        case .customer:
            return base + " Focus on business, product, and sales terminology. Use plain language the user can immediately relay to a customer."
        case .team:
            return base + " Focus on engineering, product, and project management terms. Be precise and technical."
        case .warRoom:
            return base + " Focus on infrastructure, incident response, and technical terms. Include relevant commands or fixes when applicable."
        }
    }

    var answerFinderSystemPrompt: String {
        switch self {
        case .customer:
            return """
            You are helping someone on a customer call. The other party just asked a question.
            Give a direct, confident 1-2 sentence answer the user can say out loud immediately.
            Keep it professional and customer-friendly. If unsure, suggest acknowledging and following up.
            """
        case .team:
            return """
            You are helping in a team meeting. A team member asked a question.
            Give a concise technical answer. Use bullet points if listing steps. Max 3 sentences.
            """
        case .warRoom:
            return """
            You are helping in a technical incident war room. Someone asked a question about the incident.
            Give an immediate, actionable answer. Prioritize: root cause > immediate fix > monitoring.
            Be direct. Seconds matter.
            """
        }
    }

    var questionGeneratorSystemPrompt: String {
        switch self {
        case .customer:
            return """
            You are helping someone on a customer call.
            Based on the conversation so far, suggest exactly 3 follow-up questions to ask the customer.
            Focus on: understanding their needs, uncovering objections, moving toward a decision.
            Output exactly 3 questions, one per line, no numbering, no preamble.
            """
        case .team:
            return """
            You are helping in a team meeting.
            Based on the conversation, suggest exactly 3 clarifying or driving questions.
            Focus on: blockers, decisions needed, next actions.
            Output exactly 3 questions, one per line, no numbering, no preamble.
            """
        case .warRoom:
            return """
            You are helping in a technical incident.
            Based on the conversation, suggest exactly 3 diagnostic or resolution questions.
            Focus on: root cause investigation, blast radius, rollback options.
            Output exactly 3 questions, one per line, no numbering, no preamble.
            """
        }
    }
}
