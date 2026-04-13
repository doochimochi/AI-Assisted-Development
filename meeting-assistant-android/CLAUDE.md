# Meeting Assistant Android — Developer Guide

## What This App Does

Android standalone app for real-time meeting assistance via phone microphone.

- Records conversation using the device microphone (16kHz, PCM)
- Sends audio to **Google Cloud Speech-to-Text** for real-time STT
- 3 AI panels powered by **Claude API** (run in parallel):
  - **Answers** — detects questions → streams Claude answers
  - **Terms** — researches technical words automatically
  - **Questions** — suggests follow-up questions every ~30s
- 3 scenarios: Customer Call, Team Meeting, War Room
- End session → generates wiki-formatted Markdown → saves to **Obsidian** via Local REST API
- Local session history via Room database

---

## Requirements

- Android Studio Hedgehog (2023.1.1) or later
- Android SDK 35 / min SDK 29 (Android 10+)
- Kotlin 2.0+
- Physical Android device recommended (microphone + network work better than emulator)
- Google Cloud Speech-to-Text API key
- Anthropic API key
- Obsidian with [Local REST API plugin](https://github.com/coddingtonbear/obsidian-local-rest-api) on Mac (for Obsidian sync)

---

## Setup

```bash
# Clone repo
git clone https://github.com/doochimochi/AI-Assisted-Development.git
cd AI-Assisted-Development/meeting-assistant-android

# Open in Android Studio
# File → Open → select meeting-assistant-android/
```

In Android Studio:
1. Wait for Gradle sync to complete
2. **Run → Run 'app'** or press `Shift+F10`
3. Select your connected device or emulator

---

## Installing on Your Phone

### Option A: Android Studio (easiest during development)
1. Enable **Developer Options** on your phone:
   - Settings → About Phone → tap "Build Number" 7 times
2. Enable **USB Debugging** in Developer Options
3. Connect phone via USB
4. In Android Studio → select your device → Run (▶)

### Option B: Generate APK and sideload
```bash
# In Android Studio terminal or project root:
./gradlew assembleDebug

# APK location:
app/build/outputs/apk/debug/app-debug.apk

# Transfer to phone via:
# - ADB: adb install app/build/outputs/apk/debug/app-debug.apk
# - File transfer: copy .apk to phone, open with file manager
# Note: must enable "Install from unknown sources" in phone settings
```

---

## API Keys Setup

In the app: tap **Settings** (⚙) on home screen.

| Key | Where to get |
|-----|-------------|
| Anthropic API Key    | console.anthropic.com |
| Google Speech API Key | console.cloud.google.com → Credentials |
| Obsidian API URL     | `http://YOUR_MAC_IP:27123` |
| Obsidian API Key     | Obsidian → Settings → Local REST API |

Keys stored in **DataStore** (encrypted preferences). Never committed to git.

### Google Speech API Key 발급
1. [console.cloud.google.com](https://console.cloud.google.com) 접속
2. **APIs & Services → Library → "Cloud Speech-to-Text API"** 검색 → **Enable**
3. **APIs & Services → Credentials → Create API Key** → 복사 (`AIza...` 형식)

---

## Obsidian Setup (Mac)

1. Open Obsidian → Settings → Community Plugins → Browse
2. Search "Local REST API" → Install → Enable
3. Go to Settings → Local REST API:
   - Note the **API Key** (copy it)
   - Default port: `27123`
4. Find your Mac IP: System Settings → Wi-Fi → Details → IP Address
5. In the Android app Settings: enter `http://192.168.X.X:27123` and the API key
6. Notes saved to: `Meetings/YYYY-MM-DD_HH-mm_scenario.md`

---

## Architecture

```
AudioRecorder (AudioRecord, 16kHz PCM, 250ms chunks)
    → GoogleSpeechClient (OkHttp REST, silence-triggered batching)
        → SessionViewModel (coroutines, StateFlow)
            ├── Translator (Claude Haiku, Korean detection)
            ├── WordResearcher  → AnthropicClient (SSE callbackFlow)
            ├── AnswerFinder    → AnthropicClient (SSE callbackFlow)
            └── QuestionGenerator → AnthropicClient
                    ↓
            UI (Jetpack Compose, StateFlow.collectAsState)
                    ↓
            ObsidianClient (OkHttp PUT /vault/{path})
            WikiFormatter (Markdown generator)
            SessionDatabase (Room)
```

### STT Design — Google Cloud Speech-to-Text
`GoogleSpeechClient` accumulates PCM audio chunks from `AudioRecorder`.
When RMS drops below 0.015 for 0.6 s (silence), it POSTs the buffered audio
to `speech.googleapis.com/v1/speech:recognize` as base64 LINEAR16.
Max buffer is 5 s. Results are final only (no partial transcripts).

### Key Concurrency Rules
- `AudioRecorder` runs on a background Thread (AudioRecord requires dedicated thread)
- `GoogleSpeechClient.recognize()` runs on `Dispatchers.IO` via its own `CoroutineScope`
- All flows collected in `SessionViewModel.viewModelScope`
- 3 AI features launched with `launch { }` in parallel inside `collect` block
- `AnthropicClient.streamCompletion()` uses `callbackFlow` — safe to collect from coroutines
- `ObsidianClient` uses blocking OkHttp (called from coroutine with IO dispatcher)

---

## Key Files

| File | Purpose |
|------|---------|
| `viewmodel/SessionViewModel.kt` | Main orchestrator — wires all components |
| `viewmodel/SettingsStore.kt` | DataStore persistence for API keys |
| `audio/AudioRecorder.kt` | Microphone recording (16kHz PCM) |
| `transcription/GoogleSpeechClient.kt` | Google Speech REST STT with silence detection |
| `ai/Translator.kt` | Korean → English via Claude Haiku |
| `ai/AnthropicClient.kt` | Claude API SSE streaming via callbackFlow |
| `ai/AiFeatures.kt` | WordResearcher, AnswerFinder, QuestionGenerator |
| `obsidian/WikiFormatter.kt` | Obsidian Markdown generator |
| `obsidian/ObsidianClient.kt` | Obsidian Local REST API client |
| `memory/SessionDatabase.kt` | Room DB for local session history |
| `ui/screens/SessionScreen.kt` | Main recording UI with 4 panels |

---

## Common Issues

1. **Microphone permission denied**: App requests it on session start. If denied, go to System Settings → Apps → Meeting Assistant → Permissions.

2. **No transcription appearing**: Check Google Speech API key. Verify **Cloud Speech-to-Text API is enabled** in your GCP project (just creating a key is not enough). Check `speech.googleapis.com:443` outbound is allowed.

3. **Obsidian not reachable**: Mac and Android must be on **same WiFi network**. Check Mac IP and firewall. Test with: `curl -H "Authorization: Bearer KEY" http://MAC_IP:27123/vault/` from your Mac terminal first.

4. **Background recording stops**: Android kills background processes. Keep the app in foreground during meetings. Future: add Foreground Service for background recording.

5. **Build fails on first sync**: Let Gradle fully download all dependencies (may take 2-3 min on first run).
