package com.meetingassistant.ai

import com.meetingassistant.viewmodel.SettingsStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.first
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.sse.EventSource
import okhttp3.sse.EventSourceListener
import okhttp3.sse.EventSources
import org.json.JSONArray
import org.json.JSONObject
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.callbackFlow

class AnthropicClient(private val settings: SettingsStore) {
    private val httpClient = OkHttpClient.Builder()
        .readTimeout(60, java.util.concurrent.TimeUnit.SECONDS)
        .build()

    fun streamCompletion(
        system: String,
        user: String,
        maxTokens: Int = 400
    ): Flow<String> = callbackFlow {
        val apiKey = settings.anthropicApiKey.first()
        if (apiKey.isBlank()) {
            close(IllegalStateException("Anthropic API key not set"))
            return@callbackFlow
        }

        val body = JSONObject().apply {
            put("model", "claude-sonnet-4-6")
            put("max_tokens", maxTokens)
            put("stream", true)
            put("system", system)
            put("messages", JSONArray().put(JSONObject().apply {
                put("role", "user")
                put("content", user)
            }))
        }

        val request = Request.Builder()
            .url("https://api.anthropic.com/v1/messages")
            .post(body.toString().toRequestBody("application/json".toMediaType()))
            .addHeader("x-api-key", apiKey)
            .addHeader("anthropic-version", "2023-06-01")
            .addHeader("Accept", "text/event-stream")
            .build()

        val factory = EventSources.createFactory(httpClient)
        val source = factory.newEventSource(request, object : EventSourceListener() {
            override fun onEvent(eventSource: EventSource, id: String?, type: String?, data: String) {
                if (data == "[DONE]") { close(); return }
                try {
                    val json = JSONObject(data)
                    if (json.optString("type") == "message_stop") { close(); return }
                    if (json.optString("type") == "content_block_delta") {
                        val text = json.optJSONObject("delta")?.optString("text") ?: return
                        trySend(text)
                    }
                } catch (_: Exception) {}
            }

            override fun onFailure(eventSource: EventSource, t: Throwable?, response: Response?) {
                close(t ?: Exception("SSE stream failed: ${response?.code}"))
            }

            override fun onClosed(eventSource: EventSource) { close() }
        })

        awaitClose { source.cancel() }
    }
}
