import Foundation

/// The three supported meeting scenarios.
/// Each scenario tunes AI prompt tone, focus area, and heuristic weights.
enum MeetingScenario: String, CaseIterable, Codable {
    case customer = "customer"
    case team     = "team"
    case warRoom  = "warRoom"

    var displayName: String {
        switch self {
        case .customer: return "Customer Call"
        case .team:     return "Team Meeting"
        case .warRoom:  return "War Room"
        }
    }

    var emoji: String {
        switch self {
        case .customer: return "🧑‍💼"
        case .team:     return "👥"
        case .warRoom:  return "🔥"
        }
    }

    var systemContext: String {
        switch self {
        case .customer:
            return "You are an AI assistant helping during a customer call. " +
                   "Focus on product knowledge, objection handling, and customer satisfaction. " +
                   "Be professional, solution-oriented, and concise."
        case .team:
            return "You are an AI assistant helping during an internal team meeting. " +
                   "Focus on project decisions, blockers, action items, and alignment. " +
                   "Be data-driven and direct."
        case .warRoom:
            return "You are an AI assistant helping during a technical incident war room. " +
                   "Focus on error codes, root cause analysis, runbooks, and fast resolution. " +
                   "Be precise, technical, and action-oriented."
        }
    }
}
