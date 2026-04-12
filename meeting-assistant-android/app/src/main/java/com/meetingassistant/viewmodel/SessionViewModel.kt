package com.meetingassistant.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.meetingassistant.MeetingAssistantApp
import com.meetingassistant.ai.AnswerFinder
import com.meetingassistant.ai.AnthropicClient
import com.meetingassistant.ai.QuestionGenerator
import com.meetingassistant.ai.WordResearcher
import com.meetingassistant.audio.AudioRecorder
import com.meetingassistant.memory.SessionEntity
import com.meetingassistant.obsidian.ObsidianClient
import com.meetingassistant.obsidian.WikiFormatter
import com.meetingassistant.transcription.DeepgramClient
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import java.time.Instant

data class WordEntry(val term: String, var definition: String = "", var isStreaming: Boolean = true)
data class AnswerEntry(val question: String, var answer: String = "", var isStreaming: Boolean = true)
data class QuestionSuggestion(val text: String, var isCopied: Boolean = false)

enum class ScenarioType(val displayName: String, val emoji: String) {
    CUSTOMER("Customer Call", "🤝"),
    TEAM("Team Meeting", "👥"),
    WAR_ROOM("War Room", "🚨")
}

data class SessionUiState(
    val isRecording: Boolean = false,
    val scenario: ScenarioType = ScenarioType.TEAM,
    val transcript: List<String> = emptyList(),
    val wordEntries: List<WordEntry> = emptyList(),
    val answerEntries: List<AnswerEntry> = emptyList(),
    val questions: List<QuestionSuggestion> = emptyList(),
    val audioLevel: Float = 0f,
    val error: String? = null,
    val isSavingToObsidian: Boolean = false,
    val obsidianSaveResult: String? = null,
    val selectedTab: SessionTab = SessionTab.ANSWERS
)

enum class SessionTab { ANSWERS, TERMS, QUESTIONS, TRANSCRIPT }

class SessionViewModel(application: Application) : AndroidViewModel(application) {

    private val settings = SettingsStore(application)
    private val db = (application as MeetingAssistantApp).database
    private val anthropic by lazy { AnthropicClient(settings) }
    private val wordResearcher by lazy { WordResearcher(anthropic) }
    private val answerFinder by lazy { AnswerFinder(anthropic) }
    private val questionGenerator by lazy { QuestionGenerator(anthropic) }

    private val _uiState = MutableStateFlow(SessionUiState())
    val uiState: StateFlow<SessionUiState> = _uiState.asStateFlow()

    private val transcriptBuffer = mutableListOf<String>()
    private var sessionStartTime: Long = 0
    private var audioRecorder: AudioRecorder? = null
    private var deepgramClient: DeepgramClient? = null
    private var pipelineJob: Job? = null
    private var previousContext: String? = null

    fun startSession(scenario: ScenarioType) {
        viewModelScope.launch {
            _uiState.update { it.copy(scenario = scenario, error = null) }
            sessionStartTime = System.currentTimeMillis()
            transcriptBuffer.clear()

            // Load previous context for this scenario
            previousContext = db.sessionDao().getLatestByScenario(scenario.name)
                ?.let { "Previous ${it.scenarioName} (${it.formattedDate}):\n${it.summary}" }

            val deepgramKey = settings.deepgramApiKey.first()
            if (deepgramKey.isBlank()) {
                _uiState.update { it.copy(error = "Deepgram API key not set. Go to Settings.") }
                return@launch
            }

            val recorder = AudioRecorder()
            audioRecorder = recorder

            val client = DeepgramClient(deepgramKey)
            deepgramClient = client

            try {
                client.connect()
            } catch (e: Exception) {
                _uiState.update { it.copy(error = "STT connection failed: ${e.message}") }
                return@launch
            }

            _uiState.update { it.copy(isRecording = true) }

            pipelineJob = viewModelScope.launch {
                // Send audio to Deepgram
                launch {
                    recorder.audioFlow.collect { chunk ->
                        client.send(chunk)
                    }
                }

                // Update audio level meter
                launch {
                    recorder.levelFlow.collect { level ->
                        _uiState.update { it.copy(audioLevel = level) }
                    }
                }

                // Process transcripts → AI in parallel
                client.transcriptFlow.collect { segment ->
                    if (!segment.isPartial) {
                        transcriptBuffer.add(segment.text)
                        if (transcriptBuffer.size > 200) transcriptBuffer.removeAt(0)

                        _uiState.update { state ->
                            state.copy(transcript = transcriptBuffer.takeLast(50).toList())
                        }

                        val recentText = transcriptBuffer.takeLast(50).joinToString(" ")
                        val ctx = previousContext

                        // Run 3 AI features concurrently
                        launch { processWordResearch(segment.text, recentText, scenario) }
                        launch { processAnswerFinding(segment.text, recentText, scenario, ctx) }
                        launch { considerQuestions(recentText, scenario, ctx) }
                    }
                }
            }

            recorder.start()
        }
    }

    fun stopSession() {
        viewModelScope.launch {
            pipelineJob?.cancel()
            audioRecorder?.stop()
            deepgramClient?.disconnect()
            audioRecorder = null
            deepgramClient = null

            val duration = (System.currentTimeMillis() - sessionStartTime) / 1000L
            _uiState.update { it.copy(isRecording = false, audioLevel = 0f) }

            // Auto-save session to local DB
            val state = _uiState.value
            saveSessionLocally(state, duration)
        }
    }

    fun saveToObsidian() {
        viewModelScope.launch {
            val state = _uiState.value
            _uiState.update { it.copy(isSavingToObsidian = true, obsidianSaveResult = null) }

            val obsidianUrl = settings.obsidianApiUrl.first()
            val obsidianKey = settings.obsidianApiKey.first()

            if (obsidianUrl.isBlank()) {
                _uiState.update { it.copy(isSavingToObsidian = false, obsidianSaveResult = "⚠ Obsidian API URL not set in Settings") }
                return@launch
            }

            // Generate wiki summary via Claude
            val anthropicKey = settings.anthropicApiKey.first()
            var summary = ""
            if (anthropicKey.isNotBlank()) {
                val transcript = transcriptBuffer.joinToString(" ")
                try {
                    anthropic.streamCompletion(
                        system = "You are a meeting summarizer. Write a concise 2-3 paragraph summary.",
                        user = "Meeting type: ${state.scenario.displayName}\n\nTranscript:\n${transcript.take(8000)}"
                    ).collect { token -> summary += token }
                } catch (_: Exception) {}
            }

            val markdown = WikiFormatter.format(
                scenario = state.scenario,
                summary = summary.ifBlank { "(No summary generated)" },
                wordEntries = state.wordEntries,
                answerEntries = state.answerEntries,
                questions = state.questions,
                transcriptExcerpt = transcriptBuffer.takeLast(20).joinToString("\n")
            )

            val client = ObsidianClient(obsidianUrl, obsidianKey)
            val result = client.saveNote(markdown, state.scenario)

            _uiState.update { it.copy(isSavingToObsidian = false, obsidianSaveResult = result) }
        }
    }

    fun generateQuestions() {
        viewModelScope.launch {
            val transcript = transcriptBuffer.takeLast(50).joinToString(" ")
            considerQuestions(transcript, _uiState.value.scenario, previousContext, force = true)
        }
    }

    fun selectTab(tab: SessionTab) = _uiState.update { it.copy(selectedTab = tab) }

    fun dismissObsidianResult() = _uiState.update { it.copy(obsidianSaveResult = null) }

    // MARK: - Private AI processing

    private suspend fun processWordResearch(segment: String, transcript: String, scenario: ScenarioType) {
        val result = wordResearcher.analyze(segment, transcript, scenario) ?: return
        val entry = WordEntry(term = result.term)
        _uiState.update { state ->
            val updated = (listOf(entry) + state.wordEntries).take(10)
            state.copy(wordEntries = updated)
        }
        result.stream.collect { token ->
            _uiState.update { state ->
                val updated = state.wordEntries.map {
                    if (it.term == result.term && it.isStreaming) it.copy(definition = it.definition + token)
                    else it
                }
                state.copy(wordEntries = updated)
            }
        }
        _uiState.update { state ->
            state.copy(wordEntries = state.wordEntries.map {
                if (it.term == result.term) it.copy(isStreaming = false) else it
            })
        }
    }

    private suspend fun processAnswerFinding(segment: String, transcript: String, scenario: ScenarioType, prevCtx: String?) {
        val result = answerFinder.analyze(segment, transcript, scenario, prevCtx) ?: return
        val entry = AnswerEntry(question = result.question)
        _uiState.update { state ->
            val updated = (listOf(entry) + state.answerEntries).take(5)
            state.copy(answerEntries = updated)
        }
        result.stream.collect { token ->
            _uiState.update { state ->
                val updated = state.answerEntries.map {
                    if (it.question == result.question && it.isStreaming) it.copy(answer = it.answer + token)
                    else it
                }
                state.copy(answerEntries = updated)
            }
        }
        _uiState.update { state ->
            state.copy(answerEntries = state.answerEntries.map {
                if (it.question == result.question) it.copy(isStreaming = false) else it
            })
        }
    }

    private var lastQuestionTime = 0L
    private suspend fun considerQuestions(transcript: String, scenario: ScenarioType, prevCtx: String?, force: Boolean = false) {
        val now = System.currentTimeMillis()
        if (!force && now - lastQuestionTime < 30_000) return
        if (transcript.split(" ").size < 30) return
        lastQuestionTime = now

        val suggestions = questionGenerator.generate(transcript, scenario, prevCtx)
        _uiState.update { it.copy(questions = suggestions.map { q -> QuestionSuggestion(q) }) }
    }

    private suspend fun saveSessionLocally(state: SessionUiState, duration: Long) {
        val entity = SessionEntity(
            scenarioName = state.scenario.name,
            durationSeconds = duration,
            summary = state.answerEntries.firstOrNull()?.answer ?: "",
            keyTermsJson = state.wordEntries.joinToString("|") { "${it.term}:${it.definition}" },
            transcriptExcerpt = transcriptBuffer.takeLast(20).joinToString(" "),
            createdAt = Instant.now().toEpochMilli()
        )
        db.sessionDao().insert(entity)
    }
}
