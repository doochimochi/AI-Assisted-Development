import Foundation
import Combine
import os.signpost

private let log = OSLog(subsystem: "com.meetingassistant", category: "Coordinator")

/// Orchestrates the full pipeline: Audio → STT → AI features (parallel).
///
/// This is the single point of truth for session state.
/// All AI features run in a TaskGroup so they execute concurrently.
@MainActor
final class MeetingCoordinator: ObservableObject {

    static let shared = MeetingCoordinator()

    // MARK: - Published State

    @Published private(set) var isRunning = false
    @Published var scenario: MeetingScenario = .team
    @Published var relatedSession: SessionRecord? = nil
    @Published var showRelatedSessionBanner = false

    // MARK: - Sub-components (observable by UI)

    let transcriptStore   = TranscriptStore()
    let wordResearcher    = WordResearcher()
    let answerFinder      = AnswerFinder()
    let questionGenerator = QuestionGenerator()
    let permissionManager = AudioPermissionManager()

    // MARK: - Private

    private let bufferProcessor   = AudioBufferProcessor()
    private lazy var captureManager = AudioCaptureManager(bufferProcessor: bufferProcessor)
    private let deepgramEngine    = DeepgramEngine()
    private let memoryManager     = SessionMemoryManager.shared
    private let contextMatcher    = ContextMatcher()
    private let settings          = AppSettings.shared

    private var sessionStartTime: Date?
    private var sttTask: Task<Void, Never>?
    private var transcriptSink: AnyCancellable?

    // MARK: - Init

    private init() {
        // Wire QuestionGenerator's transcript provider
        questionGenerator.getTranscript = { [weak self] in
            self?.transcriptStore.recentTranscript(minutes: 3) ?? ""
        }
    }

    // MARK: - Session Lifecycle

    func startSession() async {
        guard !isRunning else { return }

        // 1. Check permissions
        await permissionManager.checkAndRequest()
        guard permissionManager.isGranted else { return }

        // 2. Check for related previous session
        let related = contextMatcher.findRelated(scenario: scenario)
        if let first = related.first {
            relatedSession = first
            showRelatedSessionBanner = true
        }

        // 3. Start audio capture
        do {
            try await captureManager.startCapture()
        } catch {
            print("[MeetingCoordinator] Audio capture failed: \(error)")
            return
        }

        // 4. Start STT
        let audioStream = await bufferProcessor.makeStream()
        let segmentStream: AsyncThrowingStream<TranscriptSegment, Error>
        do {
            segmentStream = try await deepgramEngine.startTranscription(audioStream: audioStream)
        } catch {
            print("[MeetingCoordinator] STT start failed: \(error)")
            await captureManager.stopCapture()
            return
        }

        // 5. Start AI features
        questionGenerator.start(scenario: scenario)

        // 6. Process segments — fan out to all AI features in parallel
        sttTask = Task {
            do {
                for try await segment in segmentStream {
                    guard !Task.isCancelled else { break }
                    await self.processSegment(segment)
                }
            } catch {
                print("[MeetingCoordinator] STT stream error: \(error)")
            }
        }

        sessionStartTime = .now
        isRunning = true
    }

    func endSession() async {
        guard isRunning else { return }
        isRunning = false

        sttTask?.cancel()
        await captureManager.stopCapture()
        await deepgramEngine.stopTranscription()
        questionGenerator.stop()

        await saveSession()
        transcriptStore.clear()
    }

    func loadRelatedSession() {
        showRelatedSessionBanner = false
        // Inject previous session context into all AI prompts via AppSettings / PromptTemplates
        // (handled by PromptTemplates reading from coordinator.relatedSessionContext)
    }

    func dismissRelatedSession() {
        showRelatedSessionBanner = false
        relatedSession = nil
    }

    // MARK: - Segment Processing

    private func processSegment(_ segment: TranscriptSegment) async {
        transcriptStore.append(segment)
        guard segment.isFinal else { return }

        let recentText = transcriptStore.recentTranscript(minutes: 3)

        // Run all three AI analyses concurrently via TaskGroup
        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                self.wordResearcher.analyze(segment, scenario: self.scenario)
            }
            group.addTask { @MainActor in
                self.answerFinder.analyze(
                    segment: segment,
                    recentTranscript: recentText,
                    scenario: self.scenario
                )
            }
            // QuestionGenerator runs on its own timer — no per-segment call needed
        }
    }

    // MARK: - Session Memory

    private func saveSession() async {
        let transcript = transcriptStore.fullTranscript()
        guard !transcript.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let duration = Date.now.timeIntervalSince(sessionStartTime ?? .now)

        // Generate summary via Claude
        var summary = ""
        let sysPrompt  = PromptTemplates.sessionSummarySystem()
        let userPrompt = PromptTemplates.sessionSummaryUser(transcript: transcript, scenario: scenario)
        for await token in AnthropicClient.shared.streamCompletion(
            systemPrompt: sysPrompt,
            userPrompt: userPrompt,
            maxTokens: 400
        ) {
            summary += token
        }

        let record = SessionRecord(
            id: UUID(),
            date: sessionStartTime ?? .now,
            scenario: scenario,
            durationSeconds: duration,
            summary: summary,
            keyTerms: wordResearcher.entries.map {
                SessionRecord.TermRecord(term: $0.term, definition: $0.definition)
            },
            qaPairs: answerFinder.entries.map {
                SessionRecord.QARecord(question: $0.question, answer: $0.answer)
            },
            suggestedQuestions: questionGenerator.suggestions.map(\.text),
            transcriptExcerpt: String(transcript.suffix(2000))
        )

        try? memoryManager.save(record)
    }
}
