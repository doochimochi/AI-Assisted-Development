package com.meetingassistant.ai

import com.meetingassistant.viewmodel.SettingsStore
import kotlinx.coroutines.flow.first
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/**
 * Translates Korean (or any non-English) text to English using Claude Haiku.
 * Haiku chosen for: fastest latency (~200-400ms), lowest cost.
 * Translation is best-effort — failure is silently swallowed.
 */
class Translator(private val settings: SettingsStore) {
    private val client = OkHttpClient.Builder()
        .connectTimeout(8, TimeUnit.SECONDS)
        .readTimeout(10, TimeUnit.SECONDS)
        .build()

    // claude-haiku: fastest & cheapest for short translation tasks
    private val model = "claude-haiku-4-5-20251001"

    suspend fun translateToEnglish(text: String): String? {
        if (text.isBlank()) return null
        val apiKey = settings.anthropicApiKey.first()
        if (apiKey.isBlank()) return null

        return try {
            val body = JSONObject().apply {
                put("model", model)
                put("max_tokens", 300)
                put("system", "Translate the following to English. Output only the translation, nothing else.")
                put("messages", JSONArray().put(JSONObject().apply {
                    put("role", "user")
                    put("content", text)
                }))
            }

            val request = Request.Builder()
                .url("https://api.anthropic.com/v1/messages")
                .post(body.toString().toRequestBody("application/json".toMediaType()))
                .addHeader("x-api-key", apiKey)
                .addHeader("anthropic-version", "2023-06-01")
                .build()

            val response = client.newCall(request).execute()
            if (!response.isSuccessful) return null

            val json = JSONObject(response.body?.string() ?: return null)
            val translation = (json.optJSONArray("content")?.optJSONObject(0))
                ?.optString("text")
                ?.trim()

            translation?.takeIf { it.isNotBlank() }
        } catch (_: Exception) {
            null // silent fail — translation is supplementary
        }
    }
}

/** Returns true if the string contains Korean Hangul characters */
fun String.isKorean(): Boolean =
    any { it.code in 0xAC00..0xD7A3 }
