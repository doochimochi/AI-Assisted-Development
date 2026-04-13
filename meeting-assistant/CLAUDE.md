# Mac Meeting Assistant — Developer Guide

## Project Overview

A macOS native overlay app that sits transparently above all windows during online meetings
(Zoom, Teams, Google Meet, etc.) and provides real-time AI assistance by capturing all system audio.

**Core Features:**
1. **Word Research** — Detects and explains important/technical terms in real time
2. **Answer Finder** — When the other party asks a question, proactively surfaces an answer
3. **Question Generator** — Suggests contextual questions the user can ask next

**Supported Scenarios:** Customer call · Team meeting · Technical War Room

---

## Development Requirements

| Requirement | Version |
|-------------|---------|
| macOS (dev & target) | 14.0 (Sonoma)+ |
| Xcode | 15.4+ |
| Swift | 5.10+ |
| Hardware | Apple Silicon recommended |

---

## Required Permissions

### Screen Recording (runtime — no entitlement key)
ScreenCaptureKit requires the user to grant **Screen Recording** permission in
System Settings › Privacy & Security › Screen Recording.

The app calls `CGPreflightScreenCaptureAccess()` at launch.
If it returns `false`, `AudioPermissionManager` shows a blocking overlay
and calls `CGRequestScreenCaptureAccess()`.

> **Important during development:** Grant Screen Recording to **both** the built app
> and Xcode itself, otherwise `SCStream` will fail silently.

### Microphone (entitlement)
`com.apple.security.device.audio-input` is declared in `MeetingAssistant.entitlements`.
For current system-audio-only mode, Screen Recording permission is sufficient.

---

## Environment Setup

### API Keys
Store both keys in **Keychain** (production) or as environment variables (debug):

```bash
# For development — set in Xcode scheme's Environment Variables:
ANTHROPIC_API_KEY=sk-ant-...
GOOGLE_SPEECH_API_KEY=AIza...
```

`AppSettings` reads from `ProcessInfo.processInfo.environment` in DEBUG
and from Keychain items `anthropicApiKey` / `googleSpeechApiKey` in RELEASE.

### Google Speech API Key 발급
1. [console.cloud.google.com](https://console.cloud.google.com) 접속
2. **APIs & Services → Library → "Cloud Speech-to-Text API"** 검색 → Enable
3. **APIs & Services → Credentials → Create API Key** → 복사

---

## Building and Running

```bash
# Open in Xcode
open meeting-assistant/MeetingAssistant/MeetingAssistant.xcodeproj

# Or build from CLI (run on a real Mac, not Simulator)
xcodebuild -project meeting-assistant/MeetingAssistant/MeetingAssistant.xcodeproj \
           -scheme MeetingAssistant \
           -configuration Debug \
           build

# Run tests
xcodebuild test -scheme MeetingAssistant \
                -destination 'platform=macOS'
```

> ScreenCaptureKit does **not** work in the iOS/macOS Simulator.
> Always run on a real Mac with permissions granted.

---

## Architecture Notes

### Actor Isolation Rules
| Layer | Isolation |
|-------|-----------|
| SCStream callbacks | `audioQueue` (private serial DispatchQueue) |
| `AudioBufferProcessor` | Swift `actor` |
| `GoogleSpeechEngine` | `final class` (URLSession async/await) |
| `TranscriptStore` | `@MainActor` |
| AI feature managers | `@MainActor ObservableObject` |
| UI views | `@MainActor` (SwiftUI default) |

**Never** call `AnthropicClient` or `GoogleSpeechEngine` from inside an SCStream
delegate callback. Always dispatch via `Task { await ... }`.

### STT Design — Google Cloud Speech-to-Text
`GoogleSpeechEngine` accumulates PCM audio chunks and uses RMS-based silence
detection (threshold 0.015, trigger at 0.6 s silence) to decide when to POST
to `speech.googleapis.com/v1/speech:recognize`. Max buffer is 5 s.

Unlike a WebSocket approach, results are final only (no partial transcripts).
Language: `en-US` primary, `ko-KR` / `ja-JP` as alternatives.

### Single Source of Truth
- All AI prompts live in `AI/PromptTemplates.swift`. Edit prompts there only.
- All user-facing settings are persisted via `Models/AppSettings.swift` (UserDefaults + Keychain).
- Session data is written by `Memory/SessionMemoryManager.swift` only.

### Concurrency Pattern
```swift
// MeetingCoordinator processes each new transcript segment like this:
async let wordTask: () = wordResearcher.analyze(segment: updatedSegment, ...)
async let answerTask: () = answerFinder.analyze(segment: updatedSegment, ...)
async let questionTask: () = questionGenerator.considerGeneration(...)
_ = await (wordTask, answerTask, questionTask)
```

### Memory Budget
| State | Target |
|-------|--------|
| Idle (no session) | < 50 MB RSS |
| Active meeting | < 150 MB RSS |
| After session end | < 60 MB RSS |

Key rules:
- `CMSampleBuffer` must be released **immediately** after PCM data is extracted.
- `TranscriptStore` evicts segments older than 10 minutes automatically.
- AI result arrays are capped at 10 entries per feature.

---

## Scenario System

Three scenarios change the system prompts for all three AI features:

| Scenario | Focus |
|----------|-------|
| `.customer` | Product knowledge, objection handling, customer satisfaction |
| `.team` | Project decisions, blockers, action items |
| `.warRoom` | Error codes, root cause analysis, runbooks, quick fixes |

To modify prompts: edit `AI/PromptTemplates.swift` — the static functions
`wordResearch(scenario:term:context:)`, `answerFinder(scenario:question:transcript:)`,
and `questionGenerator(scenario:transcript:)`.

---

## Memory (Session Persistence) System

Sessions are saved as JSON to:
```
~/Library/Application Support/MeetingAssistant/sessions/YYYY-MM-DD_<uuid>.json
```

**SessionRecord schema** — see `Memory/MemoryModels.swift`.

On new session start, `ContextMatcher` scans the 5 most recent sessions.
If it finds one with the same scenario and overlapping topic keywords,
it shows a "Related previous meeting found" banner.
If the user accepts, the previous session's `summary` is injected into all
AI feature system prompts as a `[Previous context]` block.

---

## Performance Monitoring

`PerformanceMonitor` (Swift `actor`) collects metrics at runtime:

| Metric | Target |
|--------|--------|
| SCStream → Google Speech first result | ~1–2 s (REST round-trip) |
| Claude API Time-to-First-Token | < 800 ms |
| Dropped audio chunks | 0 |

In DEBUG builds, use `os_signpost` intervals to profile in Instruments:
- `"AudioChunk"` — from SCStream callback to GoogleSpeechEngine buffer
- `"STTResult"` — from recognize() POST to TranscriptStore append
- `"AIResponse"` — from segment append to first Claude token

---

## Common Pitfalls

1. **Permission not granted**: `SCStream.startCapture()` throws silently if Screen Recording
   is denied. Always call `CGPreflightScreenCaptureAccess()` first.

2. **Full-screen meeting apps**: `.floating` window level does not overlay full-screen Zoom/Teams.
   Instruct users to run meeting apps in **windowed mode**.

3. **Google Speech API not enabled**: Create an API key is not enough — the
   **Cloud Speech-to-Text API must be enabled** in the GCP project. If you get a 403,
   go to APIs & Services → Library and enable it.

4. **STT latency vs Deepgram**: Google Speech REST has ~1–2 s round-trip vs Deepgram's
   ~100 ms WebSocket. Segments appear after silence is detected, not in real-time.

5. **CMSampleBuffer retain cycles**: Always copy PCM data and release the buffer
   before passing data across actor boundaries.

---

## Testing

- Unit tests mock `TranscriptionEngine` (protocol) — never use real audio in tests.
- `AnthropicClient` conforms to `AnthropicClientProtocol`; inject `MockAnthropicClient` in tests.
- Use recorded `.wav` fixture files in `MeetingAssistantTests/Fixtures/` for STT tests.

```bash
xcodebuild test -scheme MeetingAssistant -destination 'platform=macOS'
```

---

## SPM Dependencies

| Package | Use | Default? |
|---------|-----|---------|
| *(none)* | All networking via Apple URLSession | ✅ |
| `argmaxinc/WhisperKit` | Offline STT fallback | ❌ opt-in |

All production networking (Google Speech REST, Claude SSE) uses
`URLSession` from the Apple SDK. No third-party HTTP libraries.
