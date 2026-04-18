package com.meetingassistant.transcription

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass
import com.squareup.moshi.Moshi
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import okhttp3.*
import okio.ByteString.Companion.toByteString

data class TranscriptSegment(
    val text: String,
    val isPartial: Boolean,
    val detectedLanguage: String? = null,  // e.g. "ko", "en" from Deepgram
    val translatedText: String? = null     // populated async after translation
)

class DeepgramClient(private val apiKey: String) {
    private val moshi = Moshi.Builder().build()
    private val responseAdapter = moshi.adapter(DeepgramResponse::class.java)

    private val client = OkHttpClient.Builder()
        .readTimeout(0, java.util.concurrent.TimeUnit.MILLISECONDS)
        .build()

    private var webSocket: WebSocket? = null

    private val _transcriptFlow = MutableSharedFlow<TranscriptSegment>(
        replay = 0,
        extraBufferCapacity = 32,
        onBufferOverflow = BufferOverflow.DROP_OLDEST
    )
    val transcriptFlow: SharedFlow<TranscriptSegment> = _transcriptFlow.asSharedFlow()

    fun connect() {
        val url = buildString {
            append("wss://api.deepgram.com/v1/listen")
            append("?model=nova-3")
            append("&language=multi")
            append("&encoding=linear16")
            append("&sample_rate=16000")
            append("&channels=1")
            append("&interim_results=true")
            append("&endpointing=300")
            append("&smart_format=true")
            append("&punctuate=true")
        }

        val request = Request.Builder()
            .url(url)
            .addHeader("Authorization", "Token $apiKey")
            .build()

        webSocket = client.newWebSocket(request, DeepgramListener())
    }

    fun send(audioData: ByteArray) {
        webSocket?.send(audioData.toByteString())
    }

    fun disconnect() {
        webSocket?.close(1000, null)
        webSocket = null
    }

    private inner class DeepgramListener : WebSocketListener() {
        override fun onMessage(webSocket: WebSocket, text: String) {
            try {
                val response = responseAdapter.fromJson(text) ?: return
                val transcript = response.channel?.alternatives?.firstOrNull()?.transcript ?: return
                if (transcript.isBlank()) return
                _transcriptFlow.tryEmit(TranscriptSegment(
                    text = transcript,
                    isPartial = response.isFinal != true,
                    detectedLanguage = response.channel?.detectedLanguage
                ))
            } catch (_: Exception) {}
        }

        override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
            _transcriptFlow.tryEmit(TranscriptSegment("[Connection error: ${t.message}]", false))
        }
    }
}

@JsonClass(generateAdapter = true)
data class DeepgramResponse(
    @Json(name = "is_final") val isFinal: Boolean?,
    val channel: DeepgramChannel?
)

@JsonClass(generateAdapter = true)
data class DeepgramChannel(
    val alternatives: List<DeepgramAlternative>?,
    @Json(name = "detected_language") val detectedLanguage: String? = null
)

@JsonClass(generateAdapter = true)
data class DeepgramAlternative(
    val transcript: String,
    val confidence: Double?
)
