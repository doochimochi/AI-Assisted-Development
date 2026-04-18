package com.meetingassistant.obsidian

import com.meetingassistant.viewmodel.AnswerEntry
import com.meetingassistant.viewmodel.QuestionSuggestion
import com.meetingassistant.viewmodel.ScenarioType
import com.meetingassistant.viewmodel.WordEntry
import java.text.SimpleDateFormat
import java.util.*

object WikiFormatter {
    fun format(
        scenario: ScenarioType,
        summary: String,
        wordEntries: List<WordEntry>,
        answerEntries: List<AnswerEntry>,
        questions: List<QuestionSuggestion>,
        transcriptExcerpt: String
    ): String {
        val now = Date()
        val dateTag = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(now)
        val timeTag = SimpleDateFormat("HH:mm", Locale.getDefault()).format(now)
        val scenarioTag = scenario.name.lowercase()

        return buildString {
            // YAML frontmatter
            appendLine("---")
            appendLine("date: $dateTag")
            appendLine("time: $timeTag")
            appendLine("scenario: $scenarioTag")
            appendLine("tags:")
            appendLine("  - meeting")
            appendLine("  - $scenarioTag")
            appendLine("---")
            appendLine()

            // Title
            appendLine("# ${scenario.emoji} ${scenario.displayName} — $dateTag $timeTag")
            appendLine()

            // Summary
            appendLine("## Summary")
            appendLine(summary)
            appendLine()

            // Key Terms
            if (wordEntries.isNotEmpty()) {
                appendLine("## Key Terms")
                wordEntries.forEach { entry ->
                    appendLine("- **${entry.term}**: ${entry.definition.trim()}")
                }
                appendLine()
            }

            // Q&A
            if (answerEntries.isNotEmpty()) {
                appendLine("## Q&A")
                answerEntries.forEach { entry ->
                    appendLine("**Q:** ${entry.question}")
                    appendLine("**A:** ${entry.answer.trim()}")
                    appendLine()
                }
            }

            // Follow-up Questions
            if (questions.isNotEmpty()) {
                appendLine("## Follow-up Questions")
                questions.forEach { q ->
                    appendLine("- [ ] ${q.text}")
                }
                appendLine()
            }

            // Transcript excerpt
            if (transcriptExcerpt.isNotBlank()) {
                appendLine("## Transcript Excerpt")
                appendLine("```")
                appendLine(transcriptExcerpt.trim())
                appendLine("```")
            }
        }
    }

    fun filename(scenario: ScenarioType): String {
        val date = SimpleDateFormat("yyyy-MM-dd_HH-mm", Locale.getDefault()).format(Date())
        return "${date}_${scenario.name.lowercase()}.md"
    }
}
