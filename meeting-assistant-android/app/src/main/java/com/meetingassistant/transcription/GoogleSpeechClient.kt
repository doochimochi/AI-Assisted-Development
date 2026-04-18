package com.meetingassistant.transcription

import android.util.Base64
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.launch
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit
import kotlin.math.sqrt

/**
 * Google Cloud Speech-to-Text v1 REST API client.
 * Accumulates 16kHz mono PCM audio, detects silence, then POSTs to the recognize endpoint.
 * No WebSocket — uses plain HTTP via OkHttp.
 *
 * API docs: https://cloud.google.com/speech-to-text/docs/reference/rest/v1/speech/recognize
 */
class GoogleSpeechClient(private val apiKey: String) {

    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .build()

    private val recognitionScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    // Audio accumulation & silence detection
    private val audioAccumulator = mutableListOf<Byte>()
    private var silentBytes = 0
    private val sampleRate = 16_000            // Hz
    private val bytesPerSample = 2             // Int16
    private val silenceRMSThreshold = 0.015f
    private val silenceTriggerMs = 600L        // send after 0.6 s silence
    private val maxBufferMs = 5_000L           // hard cap 5 s

    private val _transcriptFlow = MutableSharedFlow<TranscriptSegment>(
        replay = 0,
        extraBufferCapacity = 32,
        onBufferOverflow = BufferOverflow.DROP_OLDEST
    )
    val transcriptFlow: SharedFlow<TranscriptSegment> = _transcriptFlow.asSharedFlow()

    fun connect() {
        audioAccumulator.clear()
        silentBytes = 0
    }

    fun send(audioData: ByteArray) {
        audioAccumulator.addAll(audioData.toList())

        val rms = computeRMS(audioData)
        if (rms < silenceRMSThreshold) silentBytes += audioData.size else silentBytes = 0

        val silenceMs = (silentBytes.toLong() * 1000L) / (sampleRate * bytesPerSample)
        val bufferMs  = (audioAccumulator.size.toLong() * 1000L) / (sampleRate * bytesPerSample)

        val shouldSend = (silenceMs >= silenceTriggerMs && bufferMs >= 1000L) || bufferMs >= maxBufferMs

        if (shouldSend && audioAccumulator.isNotEmpty()) {
            val dataToSend = audioAccumulator.toByteArray()
            audioAccumulator.clear()
            silentBytes = 0
            recognitionScope.launch { recognize(dataToSend) }
        }
    }

    fun disconnect() {
        // Flush remaining audio (> 0.5 s) before shutting down
        if (audioAccumulator.size > sampleRate * bytesPerSample / 2) {
            val remaining = audioAccumulator.toByteArray()
            audioAccumulator.clear()
            recognitionScope.launch { recognize(remaining) }
        }
        recognitionScope.cancel()
    }

    // MARK: - Helpers

    private fun computeRMS(data: ByteArray): Float {
        val sampleCount = data.size / bytesPerSample
        if (sampleCount == 0) return 0f
        var sumSquares = 0.0
        for (i in 0 until sampleCount) {
            // Little-endian Int16
            val lo = data[i * 2].toInt() and 0xFF
            val hi = data[i * 2 + 1].toInt() shl 8
            val sample = (hi or lo).toShort()
            val normalized = sample / 32_768.0
            sumSquares += normalized * normalized
        }
        return sqrt(sumSquares / sampleCount).toFloat()
    }

    // MARK: - REST recognition

    private fun recognize(pcmData: ByteArray) {
        if (pcmData.isEmpty()) return

        val base64Audio = Base64.encodeToString(pcmData, Base64.NO_WRAP)
        val body = JSONObject().apply {
            put("config", JSONObject().apply {
                put("encoding", "LINEAR16")
                put("sampleRateHertz", sampleRate)
                put("languageCode", "en-US")
                put("alternativeLanguageCodes", JSONArray().apply {
                    put("ko-KR")
                    put("ja-JP")
                })
                put("model", "latest_long")
                put("enableAutomaticPunctuation", true)
            })
            put("audio", JSONObject().apply {
                put("content", base64Audio)
            })
        }

        try {
            val request = Request.Builder()
                .url("https://speech.googleapis.com/v1/speech:recognize?key=$apiKey")
                .post(body.toString().toRequestBody("application/json".toMediaType()))
                .build()

            val response = httpClient.newCall(request).execute()
            if (!response.isSuccessful) return

            val json = JSONObject(response.body?.string() ?: return)
            val results = json.optJSONArray("results") ?: return

            for (i in 0 until results.length()) {
                val result = results.getJSONObject(i)
                val alternatives = result.optJSONArray("alternatives") ?: continue
                val transcript = alternatives.getJSONObject(0)
                    .optString("transcript").trim().takeIf { it.isNotBlank() } ?: continue
                val languageCode = result.optString("languageCode").takeIf { it.isNotBlank() }

                _transcriptFlow.tryEmit(
                    TranscriptSegment(
                        text = transcript,
                        isPartial = false,
                        detectedLanguage = languageCode?.lowercase()
                    )
                )
            }
        } catch (_: Exception) {
            // Silent fail — STT is best-effort
        }
    }
}
