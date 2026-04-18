import Foundation
import Combine

@MainActor
final class TranscriptStore: ObservableObject {
    @Published private(set) var segments: [TranscriptSegment] = []
    @Published private(set) var lastFinalSegment: TranscriptSegment?

    private let maxDurationSeconds: TimeInterval

    init(maxMinutes: Int = 10) {
        self.maxDurationSeconds = TimeInterval(maxMinutes * 60)
    }

    func append(_ segment: TranscriptSegment) {
        if segment.isPartial {
            // Replace existing partial segment if present, else append
            if let idx = segments.lastIndex(where: { $0.isPartial }) {
                segments[idx] = segment
            } else {
                segments.append(segment)
            }
        } else {
            // Remove any trailing partial, append final
            segments.removeAll { $0.isPartial }
            segments.append(segment)
            lastFinalSegment = segment
            evictOldSegments()
        }
    }

    func clear() {
        segments.removeAll()
        lastFinalSegment = nil
    }

    /// Stores the translated text for a given segment id (called async after translation)
    func setTranslation(_ translation: String, for segmentId: UUID) {
        if let idx = segments.firstIndex(where: { $0.id == segmentId }) {
            segments[idx].translatedText = translation
        }
    }

    // Returns recent transcript as plain text — uses translated text for AI where available
    func recentText(approximateTokens: Int = 1500) -> String {
        let charLimit = approximateTokens * 4
        let full = segments.filter { !$0.isPartial }.map(\.textForAI).joined(separator: " ")
        if full.count <= charLimit { return full }
        return String(full.suffix(charLimit))
    }

    // Returns only final segments in the last N seconds
    func finalSegments(lastSeconds: TimeInterval = 30) -> [TranscriptSegment] {
        let cutoff = Date().addingTimeInterval(-lastSeconds)
        return segments.filter { !$0.isPartial && $0.timestamp > cutoff }
    }

    var fullTranscript: String {
        segments.filter { !$0.isPartial }.map(\.text).joined(separator: " ")
    }

    private func evictOldSegments() {
        let cutoff = Date().addingTimeInterval(-maxDurationSeconds)
        segments.removeAll { !$0.isPartial && $0.timestamp < cutoff }
    }
}
