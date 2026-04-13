package com.meetingassistant.viewmodel

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.dataStore by preferencesDataStore(name = "settings")

class SettingsStore(private val context: Context) {
    companion object {
        val ANTHROPIC_KEY        = stringPreferencesKey("anthropic_api_key")
        val GOOGLE_SPEECH_KEY    = stringPreferencesKey("google_speech_api_key")
        val OBSIDIAN_URL         = stringPreferencesKey("obsidian_api_url")   // e.g. http://192.168.1.10:27123
        val OBSIDIAN_KEY         = stringPreferencesKey("obsidian_api_key")
        val OBSIDIAN_VAULT_FOLDER = stringPreferencesKey("obsidian_vault_folder") // e.g. Meetings
    }

    val anthropicApiKey:    Flow<String> = context.dataStore.data.map { it[ANTHROPIC_KEY]     ?: "" }
    val googleSpeechApiKey: Flow<String> = context.dataStore.data.map { it[GOOGLE_SPEECH_KEY] ?: "" }
    val obsidianApiUrl:     Flow<String> = context.dataStore.data.map { it[OBSIDIAN_URL]      ?: "" }
    val obsidianApiKey:     Flow<String> = context.dataStore.data.map { it[OBSIDIAN_KEY]      ?: "" }
    val obsidianVaultFolder: Flow<String> = context.dataStore.data.map { it[OBSIDIAN_VAULT_FOLDER] ?: "Meetings" }

    suspend fun save(
        anthropicKey: String,
        googleSpeechKey: String,
        obsidianUrl: String,
        obsidianKey: String,
        vaultFolder: String
    ) {
        context.dataStore.edit { prefs ->
            prefs[ANTHROPIC_KEY]     = anthropicKey
            prefs[GOOGLE_SPEECH_KEY] = googleSpeechKey
            prefs[OBSIDIAN_URL]      = obsidianUrl
            prefs[OBSIDIAN_KEY]      = obsidianKey
            prefs[OBSIDIAN_VAULT_FOLDER] = vaultFolder
        }
    }
}
