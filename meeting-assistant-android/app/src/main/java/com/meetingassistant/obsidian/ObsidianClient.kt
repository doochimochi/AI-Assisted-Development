package com.meetingassistant.obsidian

import com.meetingassistant.viewmodel.ScenarioType
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit

class ObsidianClient(
    private val baseUrl: String,   // e.g. http://192.168.1.10:27123
    private val apiKey: String
) {
    private val client = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    // Saves markdown to Obsidian vault via Local REST API plugin
    // PUT /vault/{path} creates or overwrites the file
    suspend fun saveNote(markdown: String, scenario: ScenarioType, folder: String = "Meetings"): String {
        val filename = WikiFormatter.filename(scenario)
        val path = "$folder/$filename"
        val url = "${baseUrl.trimEnd('/')}/vault/${path}"

        return try {
            val request = Request.Builder()
                .url(url)
                .put(markdown.toRequestBody("text/markdown".toMediaType()))
                .addHeader("Authorization", "Bearer $apiKey")
                .addHeader("Content-Type", "text/markdown")
                .build()

            val response = client.newCall(request).execute()
            if (response.isSuccessful) {
                "✓ Saved to Obsidian: $path"
            } else {
                "⚠ Obsidian error ${response.code}: ${response.body?.string()?.take(200)}"
            }
        } catch (e: Exception) {
            "⚠ Could not reach Obsidian (${e.message}). Is the Local REST API plugin running on your Mac?"
        }
    }
}
