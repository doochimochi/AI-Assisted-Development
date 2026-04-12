package com.meetingassistant.audio

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.withContext
import kotlin.math.sqrt

class AudioRecorder {
    companion object {
        const val SAMPLE_RATE = 16000
        const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
        // 250ms chunk = 4000 samples × 2 bytes = 8000 bytes
        val CHUNK_SIZE = (SAMPLE_RATE * 0.25).toInt() * 2
    }

    private val _audioFlow = MutableSharedFlow<ByteArray>(
        replay = 0,
        extraBufferCapacity = 8,
        onBufferOverflow = BufferOverflow.DROP_OLDEST
    )
    val audioFlow: Flow<ByteArray> = _audioFlow.asSharedFlow()

    private val _levelFlow = MutableSharedFlow<Float>(
        replay = 1,
        onBufferOverflow = BufferOverflow.DROP_OLDEST
    )
    val levelFlow: Flow<Float> = _levelFlow.asSharedFlow()

    private var audioRecord: AudioRecord? = null
    private var isRecording = false

    fun start() {
        val minBuffer = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
        val bufferSize = maxOf(minBuffer, CHUNK_SIZE * 4)

        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.VOICE_COMMUNICATION,  // Echo cancellation + noise suppression
            SAMPLE_RATE,
            CHANNEL_CONFIG,
            AUDIO_FORMAT,
            bufferSize
        )

        isRecording = true
        audioRecord?.startRecording()

        Thread {
            val buffer = ByteArray(CHUNK_SIZE)
            while (isRecording) {
                val read = audioRecord?.read(buffer, 0, buffer.size) ?: break
                if (read > 0) {
                    val chunk = buffer.copyOf(read)
                    _audioFlow.tryEmit(chunk)
                    _levelFlow.tryEmit(rmsLevel(chunk))
                }
            }
        }.apply {
            isDaemon = true
            start()
        }
    }

    fun stop() {
        isRecording = false
        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null
    }

    private fun rmsLevel(bytes: ByteArray): Float {
        var sum = 0.0
        val samples = bytes.size / 2
        for (i in 0 until samples) {
            val sample = (bytes[i * 2 + 1].toInt() shl 8) or (bytes[i * 2].toInt() and 0xFF)
            val normalized = sample.toShort().toFloat() / Short.MAX_VALUE
            sum += normalized * normalized
        }
        return if (samples > 0) minOf(sqrt(sum / samples).toFloat() * 8f, 1f) else 0f
    }
}
