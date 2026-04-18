import Foundation
import Combine

/// Stores the rolling transcript in memory.
///
/// - Runs on @MainActor so all UI bindings update on the main thread.
/// - Automatically evicts segments older than `windowDuration`.
/// - Caps memory by storing only text (no audio data).
@MainActor
final class TranscriptStore: ObservableObject {

    @Published private(set) var segments: [TranscriptSegment] = []

    private let windowDuration: TimeInterval
    private var evictionTimer: AnyCancellable?

    init(windowDuration: TimeInterval = AppSettings.shared.transcriptWindowMinutes) {
        self.windowDuration = windowDuration
        startEvictionTimer()
    }

    // MARK: - Public API

    func append(_ segment: TranscriptSegment) {
        if segment.isFinal {
            segments.append(segment)
        } else {
            // Replace the last interim result if there is one, otherwise append
            if let last = segments.last, !last.isFinal {
                segments[segments.count - 1] = segment
            } else {
                segments.append(segment)
            }
        }
    }

    /// Returns the last `minutes` minutes of final transcript text as a single string.
    func recentTranscript(minutes: Double = 3) -> String {
        let cutoff = Date.now.addingTimeInterval(-minutes * 60)
        return segments
            .filter { $0.isFinal && $0.timestamp > cutoff }
            .map(\.text)
            .joined(separator: " ")
    }

    /// Returns all final segments as plain text (for session summary / memory save).
    func fullTranscript() -> String {
        segments.filter(\.isFinal).map(\.text).joined(separator: " ")
    }

    func clear() {
        segments.removeAll()
    }

    // MARK: - Private

    private func startEvictionTimer() {
        evictionTimer = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.evictOldSegments() }
    }

    private func evictOldSegments() {
        let cutoff = Date.now.addingTimeInterval(-windowDuration)
        segments.removeAll { $0.timestamp < cutoff }
    }
}
