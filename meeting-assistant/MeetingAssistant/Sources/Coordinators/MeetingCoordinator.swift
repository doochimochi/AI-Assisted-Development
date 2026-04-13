import Foundation
import Combine

@MainActor
final class MeetingCoordinator: ObservableObject {
    // State
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var scenario: MeetingScenario = .team
    @Published var error: String?

    // Sub-components
    let audioCapture = AudioCaptureManager()
    let transcriptStore: TranscriptStore
    let wordResearcher = WordResearcher()
    let answerFinder = AnswerFinder()
    let questionGenerator = QuestionGenerator()
    let memoryManager = SessionMemoryManager.shared

    // Loaded previous context
    @Published private(set) var previousContext: String? = nil

    private var sessionStartTime: Date?
    private var pipelineTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init() {
        let settings = AppSettings.shared
        self.transcriptStore = TranscriptStore(maxMinutes: settings.maxTranscriptMinutes)
    }

    // MARK: - Session control

    func startSession(scenario: MeetingScenario) async {
        self.scenario = scenario
        self.error = nil

        // Load previous context for this scenario
        let related = memoryManager.relatedSessions(for: scenario, limit: 1)
        self.previousContext = related.first.map { session in
            "Previous \(session.scenario.displayName) (\(session.formattedDate)):\n\(session.summary)"
        }

        do {
            try await audioCapture.startCapture()
        } catch {
            self.error = error.localizedDescription
            return
        }

        sessionStartTime = Date()
        isRunning = true
        transcriptStore.clear()
        wordResearcher.clear()
        answerFinder.clear()
        questionGenerator.clear()

        guard let audioStream = audioCapture.audioDataStream else { return }

        pipelineTask = Task {
            await runPipeline(audioStream: audioStream)
        }
    }

    func stopSession() async {
        pipelineTask?.cancel()
        pipelineTask = nil

        await audioCapture.stopCapture()
        isRunning = false

        let duration = sessionStartTime.map { Date().timeIntervalSince($0) } ?? 0

        if AppSettings.shared.autoSaveSession {
            await memoryManager.saveSession(
                scenario: scenario,
                duration: duration,
                words: wordResearcher.entries,
                answers: answerFinder.entries,
                questions: questionGenerator.suggestions,
                transcript: transcriptStore.fullTranscript
            )
        }

        sessionStartTime = nil
    }

    // MARK: - Main pipeline

    private func runPipeline(audioStream: AsyncStream<Data>) async {
        let engine = DeepgramEngine(apiKey: AppSettings.shared.deepgramApiKey)

        do {
            try await engine.connect()
        } catch {
            await MainActor.run { self.error = "STT connection failed: \(error.localizedDescription)" }
            return
        }

        // Send audio data to Deepgram
        let sendTask = Task {
            for await chunk in audioStream {
                guard !Task.isCancelled else { break }
                try? await engine.send(audioData: chunk)
            }
            await engine.disconnect()
        }

        // Receive transcripts and trigger AI analysis
        do {
            for try await segment in engine.transcriptStream {
                guard !Task.isCancelled else { break }
                transcriptStore.append(segment)

                let transcript = transcriptStore.recentText(approximateTokens: 1500)
                let scenario = self.scenario
                let prevCtx = self.previousContext

                if !segment.isPartial {
                    // Step 1: Translate if Korean (fast, blocks briefly to get English text for AI)
                    if segment.isKorean {
                        if let translation = await Translator.shared.translateToEnglish(segment.text) {
                            transcriptStore.setTranslation(translation, for: segment.id)
                        }
                    }

                    // Step 2: Run all 3 AI features in parallel, using translated text if available
                    let updatedTranscript = transcriptStore.recentText(approximateTokens: 1500)
                    let updatedSegment = transcriptStore.segments.first(where: { $0.id == segment.id }) ?? segment
                    async let wordTask: () = wordResearcher.analyze(segment: updatedSegment, transcript: updatedTranscript, scenario: scenario)
                    async let answerTask: () = answerFinder.analyze(segment: updatedSegment, transcript: updatedTranscript, scenario: scenario, previousContext: prevCtx)
                    async let questionTask: () = questionGenerator.considerGeneration(transcript: updatedTranscript, scenario: scenario, previousContext: prevCtx)
                    _ = await (wordTask, answerTask, questionTask)
                }
            }
        } catch {
            if !Task.isCancelled {
                await MainActor.run { self.error = "Transcription error: \(error.localizedDescription)" }
            }
        }

        sendTask.cancel()
    }
}
