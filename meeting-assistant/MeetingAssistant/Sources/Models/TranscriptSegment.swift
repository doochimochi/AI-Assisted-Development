import Foundation

struct TranscriptSegment: Identifiable, Equatable {
    let id: UUID
    let text: String
    let timestamp: Date
    let isPartial: Bool
    let detectedLanguage: String?   // e.g. "ko", "en" from Deepgram
    var translatedText: String?     // English translation (populated async)

    init(id: UUID = UUID(), text: String, timestamp: Date = Date(),
         isPartial: Bool = false, detectedLanguage: String? = nil) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.isPartial = isPartial
        self.detectedLanguage = detectedLanguage
        self.translatedText = nil
    }

    /// True when the segment contains Korean characters or Deepgram detected Korean
    var isKorean: Bool {
        if let lang = detectedLanguage { return lang.hasPrefix("ko") }
        return text.unicodeScalars.contains { $0.value >= 0xAC00 && $0.value <= 0xD7A3 }
    }

    /// The text to feed to AI features — English translation if available, original otherwise
    var textForAI: String { translatedText ?? text }

    var isQuestion: Bool {
        let t = textForAI.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasSuffix("?") { return true }
        let starters = ["what", "how", "why", "when", "where", "who", "which",
                        "could you", "can you", "would you", "is there", "are there",
                        "do you", "did you", "have you"]
        return starters.contains { t.lowercased().hasPrefix($0) }
    }
}

