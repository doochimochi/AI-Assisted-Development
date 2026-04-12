package com.meetingassistant.ai

import com.meetingassistant.viewmodel.ScenarioType
import kotlinx.coroutines.flow.Flow

// Shared result type: carries the detected key + a streaming flow of the AI response
data class WordResult(val term: String, val stream: Flow<String>)
data class AnswerResult(val question: String, val stream: Flow<String>)

// ─── Word Researcher ──────────────────────────────────────────────────────────

class WordResearcher(private val client: AnthropicClient) {
    private val recentTerms = mutableSetOf<String>()
    private var lastTime = 0L

    suspend fun analyze(segment: String, transcript: String, scenario: ScenarioType): WordResult? {
        val now = System.currentTimeMillis()
        if (now - lastTime < 8_000) return null

        val candidates = detectTerms(segment).filter { it.lowercase() !in recentTerms }
        val term = candidates.firstOrNull() ?: return null

        lastTime = now
        recentTerms.add(term.lowercase())
        if (recentTerms.size > 50) recentTerms.remove(recentTerms.first())

        val (system, user) = promptFor(term, transcript, scenario)
        return WordResult(term, client.streamCompletion(system, user, maxTokens = 200))
    }

    private fun detectTerms(text: String): List<String> {
        val results = mutableListOf<String>()
        // Acronyms: 2–5 uppercase letters
        Regex("\\b[A-Z]{2,5}\\b").findAll(text).mapTo(results) { it.value }
        // Long technical words (>9 chars, lowercase start)
        text.split(" ").forEach { w ->
            val clean = w.trim(',', '.', '?', '!')
            if (clean.length > 9 && clean.first().isLowerCase()) results.add(clean)
        }
        return results.distinct().take(3)
    }

    private fun promptFor(term: String, ctx: String, scenario: ScenarioType): Pair<String, String> {
        val system = when (scenario) {
            ScenarioType.CUSTOMER -> "You are a real-time meeting assistant. Focus on business and product terminology. 2-3 sentences max."
            ScenarioType.TEAM     -> "You are a real-time meeting assistant. Focus on engineering terms. 2-3 sentences max."
            ScenarioType.WAR_ROOM -> "You are a real-time incident assistant. Focus on infrastructure/ops terms. Include commands if relevant. 2-3 sentences max."
        }
        val user = "Term: \"$term\"\nContext: ${ctx.take(300)}\n\nExplain briefly: [Term]: [definition]. [practical example]."
        return system to user
    }
}

// ─── Answer Finder ────────────────────────────────────────────────────────────

class AnswerFinder(private val client: AnthropicClient) {
    private var lastTime = 0L

    suspend fun analyze(segment: String, transcript: String, scenario: ScenarioType, prevCtx: String?): AnswerResult? {
        if (!isQuestion(segment)) return null
        val now = System.currentTimeMillis()
        if (now - lastTime < 3_000) return null
        lastTime = now

        val (system, user) = promptFor(segment, transcript, scenario, prevCtx)
        return AnswerResult(segment, client.streamCompletion(system, user, maxTokens = 400))
    }

    private fun isQuestion(text: String): Boolean {
        val t = text.trim()
        if (t.endsWith("?")) return true
        val starters = listOf("what", "how", "why", "when", "where", "who", "which",
            "could you", "can you", "would you", "is there", "do you", "did you")
        return starters.any { t.lowercase().startsWith(it) }
    }

    private fun promptFor(question: String, transcript: String, scenario: ScenarioType, prevCtx: String?): Pair<String, String> {
        val system = when (scenario) {
            ScenarioType.CUSTOMER -> "You are helping on a customer call. Give a direct 1-2 sentence answer the user can say immediately. Be professional and customer-friendly."
            ScenarioType.TEAM     -> "You are helping in a team meeting. Give a concise technical answer. Max 3 sentences."
            ScenarioType.WAR_ROOM -> "You are helping in a technical incident. Give an immediate, actionable answer. Root cause > fix > monitoring. Be direct."
        }
        val ctxBlock = buildString {
            if (!prevCtx.isNullOrBlank()) appendLine("Previous context:\n${prevCtx.take(400)}\n")
            appendLine("Recent conversation:\n${transcript.take(1500)}")
        }
        val user = "$ctxBlock\nQuestion asked: \"$question\"\n\nGive a direct answer I can say right now."
        return system to user
    }
}

// ─── Question Generator ───────────────────────────────────────────────────────

class QuestionGenerator(private val client: AnthropicClient) {
    suspend fun generate(transcript: String, scenario: ScenarioType, prevCtx: String?): List<String> {
        val system = when (scenario) {
            ScenarioType.CUSTOMER -> "Based on the customer conversation, suggest exactly 3 follow-up questions. Focus on: needs, objections, next steps. One per line, no numbers."
            ScenarioType.TEAM     -> "Based on the team meeting, suggest exactly 3 clarifying questions. Focus on: blockers, decisions, actions. One per line, no numbers."
            ScenarioType.WAR_ROOM -> "Based on the incident discussion, suggest exactly 3 diagnostic questions. Focus on: root cause, blast radius, rollback. One per line, no numbers."
        }
        val ctxBlock = buildString {
            if (!prevCtx.isNullOrBlank()) appendLine("Background:\n${prevCtx.take(400)}\n")
            append("Conversation:\n${transcript.take(2000)}")
        }

        var accumulated = ""
        client.streamCompletion(system, ctxBlock, maxTokens = 200).collect { accumulated += it }

        return accumulated.lines()
            .map { it.trim() }
            .filter { it.isNotBlank() }
            .take(3)
    }
}
