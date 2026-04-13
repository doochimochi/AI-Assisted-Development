# Meeting Assistant (Android)

스마트폰 마이크로 회의를 녹음하고 AI가 실시간으로 보조하는 Android 앱.
Zoom, Teams 등 미팅 앱과 함께 사용하거나 독립형 음성 보조 도구로 활용합니다.
세션 종료 시 Obsidian wiki 형식의 Markdown 파일로 자동 저장합니다.

---

## 주요 기능

| 기능 | 설명 |
|------|------|
| **Answer Finder** | 상대방 질문 자동 감지 → Claude 스트리밍 답변 |
| **Word Research** | 전문 용어 자동 감지 → 정의/설명 |
| **Question Generator** | 30초마다 맥락 기반 후속 질문 3개 제안 |
| **실시간 자막** | Deepgram Nova-3 기반 라이브 전사 |
| **한국어 자동 번역** | 한국어 감지 시 Claude Haiku로 즉시 영어 번역, 🇰🇷/🇺🇸 표시 |
| **Obsidian 저장** | 세션을 Obsidian wiki Markdown으로 내보내기 |
| **로컬 세션 기록** | Room DB에 지난 세션 자동 저장 |

### 시나리오

| 시나리오 | 포커스 |
|----------|--------|
| 🤝 Customer Call | 제품 지식, 반론 처리, 고객 만족 |
| 👥 Team Meeting | 프로젝트 결정사항, 블로커, 액션 아이템 |
| 🚨 War Room | 에러 코드, 근본 원인 분석, 런북, 즉각 해결 |

---

## 요구사항

- Android 10 (API 29) 이상
- Android Studio Hedgehog (2023.1.1) 이상
- [Anthropic API 키](https://console.anthropic.com)
- [Deepgram API 키](https://console.deepgram.com)
- Obsidian 저장 사용 시: Mac에 [Obsidian Local REST API 플러그인](https://github.com/coddingtonbear/obsidian-local-rest-api) 설치

---

## 설치

### 개발 중 설치 (Android Studio — 권장)

1. 저장소 클론

```bash
git clone https://github.com/doochimochi/AI-Assisted-Development.git
```

2. Android Studio 열기: **File → Open → `meeting-assistant-android/` 폴더 선택**

3. Gradle 동기화 완료 대기 (첫 실행 시 2~3분 소요)

4. 기기 연결 후 실행 (`Shift+F10` 또는 ▶ 버튼)

### 직접 APK 설치

```bash
cd AI-Assisted-Development/meeting-assistant-android
./gradlew assembleDebug

# APK 경로
# app/build/outputs/apk/debug/app-debug.apk
```

APK를 기기로 전송 후 설치:

```bash
# ADB 사용
adb install app/build/outputs/apk/debug/app-debug.apk
```

또는 파일 매니저로 APK를 열어 설치 (기기에서 **설정 → 보안 → 알 수 없는 소스 허용** 필요).

### USB 디버깅 활성화 (ADB 사용 시)

1. **설정 → 휴대전화 정보 → 빌드 번호** 7회 탭
2. **설정 → 개발자 옵션 → USB 디버깅** 활성화
3. USB로 PC에 연결

---

## API 키 설정

앱 실행 후 홈 화면의 **⚙ Settings** 버튼 탭.

| 항목 | 값 | 필수 |
|------|----|------|
| Anthropic API Key | `sk-ant-...` | ✅ AI 기능 |
| Deepgram API Key | `dg_...` | ✅ STT |
| Obsidian API URL | `http://192.168.X.X:27123` | Obsidian 저장 시 |
| Obsidian API Key | Obsidian 플러그인에서 복사 | Obsidian 저장 시 |

키는 기기 내 **DataStore** (암호화 저장소)에 보관되며 코드에 포함되지 않습니다.

---

## Obsidian 연동 설정 (선택)

Mac과 Android가 **같은 Wi-Fi 네트워크**에 있어야 합니다.

1. Mac Obsidian 열기 → **Settings → Community Plugins → Browse**
2. `Local REST API` 검색 → 설치 → 활성화
3. **Settings → Local REST API**에서 API Key 복사, 포트 확인 (기본: `27123`)
4. Mac IP 확인: **System Settings → Wi-Fi → Details → IP Address**
5. Android 앱 Settings에 URL(`http://Mac_IP:27123`)과 API Key 입력

저장된 노트 위치: `Meetings/YYYY-MM-DD_HH-mm_시나리오.md`

---

## 사용 방법

### 1. 세션 시작

1. 홈 화면에서 시나리오 선택 (Customer / Team / War Room)
2. **Start Session** 버튼 탭
3. 마이크 권한 허용
4. 오디오 레벨 미터가 활성화되면 녹음 시작

### 2. 4개 탭 활용

| 탭 | 설명 |
|----|------|
| **Answers** | 상대방 질문 감지 시 자동 표시. 카드당 복사 버튼 제공 |
| **Terms** | 전문 용어 자동 감지 → 정의. 최대 10개 카드 유지 |
| **Questions** | 30초마다 자동 갱신. ↺ 버튼으로 즉시 갱신 가능 |
| **Transcript** | 실시간 자막. 한국어는 🇰🇷 원문 + 🇺🇸 번역 함께 표시 |

### 3. Obsidian 저장

녹음 중 상단 우측의 **💾 저장** 아이콘 탭.
Claude가 세션을 요약하고 wiki 형식 Markdown을 Obsidian에 저장합니다.

저장되는 내용:
- 세션 요약 (2~3단락)
- 핵심 용어 & 정의
- Q&A 내역
- 제안된 질문들
- 최근 자막 발췌

### 4. 세션 종료

상단 우측 ⏹ 버튼 탭 → 홈 화면으로 돌아갑니다.
세션은 로컬 DB에 자동 저장됩니다.

---

## 아키텍처 개요

```
AudioRecorder (16kHz PCM, 250ms 청크)
    └─ DeepgramClient (OkHttp WebSocket)
        └─ SessionViewModel (coroutines, StateFlow)
            ├─ Translator (Claude Haiku, 한국어 감지 시)
            ├─ WordResearcher  ─┐
            ├─ AnswerFinder    ─┼─ launch{} 병렬 실행
            └─ QuestionGenerator─┘
                └─ AnthropicClient (SSE callbackFlow)
                    └─ Jetpack Compose UI
                        └─ ObsidianClient (세션 저장)
                            └─ Room DB (로컬 히스토리)
```

---

## 트러블슈팅

| 문제 | 해결 방법 |
|------|-----------|
| 마이크 권한 거부됨 | 설정 → 앱 → Meeting Assistant → 권한 → 마이크 허용 |
| Deepgram 연결 안 됨 | API 키 확인. `api.deepgram.com:443` 아웃바운드 허용 필요 |
| Obsidian에 저장 안 됨 | Mac과 같은 Wi-Fi인지 확인. Mac 방화벽에서 27123 포트 허용 |
| 백그라운드에서 녹음 중단 | 미팅 중 앱을 포그라운드로 유지하세요 (Foreground Service는 향후 추가 예정) |
| AI 응답 없음 | Anthropic API 키 확인. Settings에서 키 재입력 |
| Gradle 동기화 실패 | 인터넷 연결 확인 후 **File → Sync Project with Gradle Files** 재시도 |

---

## 라이선스

이 프로젝트는 저장소 루트의 [LICENSE](../LICENSE)를 따릅니다.
