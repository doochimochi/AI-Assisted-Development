# Meeting Assistant (Mac)

온라인 미팅 중 시스템 오디오를 실시간으로 캡처해 AI가 보조하는 macOS 네이티브 오버레이 앱.
Zoom, Teams, Google Meet 등 화상회의 앱 위에 반투명 플로팅 창으로 항상 떠 있으며, 미팅 앱의 포커스를 빼앗지 않습니다.

---

## 주요 기능

| 기능 | 설명 |
|------|------|
| **Answer Finder** | 상대방이 질문하면 자동 감지 → Claude가 스트리밍으로 답변 생성 |
| **Word Research** | 대화 중 전문/어려운 단어를 자동 감지 → 정의 설명 |
| **Question Generator** | 약 30초마다 맥락 기반 후속 질문 3개 제안 |
| **실시간 자막** | Google Cloud Speech-to-Text STT 기반, 라이브 표시 |
| **한국어 자동 번역** | 한국어 감지 시 Claude Haiku로 즉시 영어 번역, 🇰🇷/🇺🇸 플래그 표시 |
| **세션 메모리** | 세션 종료 시 자동 저장, 다음 유사 미팅에서 이전 컨텍스트 로드 |

### 시나리오

| 시나리오 | 포커스 |
|----------|--------|
| 🤝 Customer Call | 제품 지식, 반론 처리, 고객 만족 |
| 👥 Team Meeting | 프로젝트 결정사항, 블로커, 액션 아이템 |
| 🚨 War Room | 에러 코드, 근본 원인 분석, 런북, 즉각 해결 |

---

## 요구사항

- macOS 14.0 (Sonoma) 이상
- Xcode 15.4 이상
- [Anthropic API 키](https://console.anthropic.com)
- [Google Cloud API 키](https://console.cloud.google.com) (Cloud Speech-to-Text API 활성화 필요)

---

## 설치 및 빌드

### 1. 저장소 클론

```bash
git clone https://github.com/doochimochi/AI-Assisted-Development.git
cd AI-Assisted-Development/meeting-assistant
```

### 2. XcodeGen으로 프로젝트 생성

```bash
brew install xcodegen
xcodegen generate
```

### 3. Xcode에서 열기

```bash
open MeetingAssistant/MeetingAssistant.xcodeproj
```

### 4. API 키 설정 (Xcode Scheme)

Xcode 메뉴: **Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables**

| 변수명 | 값 |
|--------|----|
| `ANTHROPIC_API_KEY` | `sk-ant-...` |
| `GOOGLE_SPEECH_API_KEY` | `AIza...` |

### 5. 빌드 및 실행

Xcode에서 `Cmd+R` 또는:

```bash
xcodebuild -project MeetingAssistant/MeetingAssistant.xcodeproj \
           -scheme MeetingAssistant \
           -configuration Debug \
           build
```

---

## 권한 설정

앱 첫 실행 시 아래 권한이 필요합니다.

### Screen Recording (필수)

시스템 오디오 캡처에 필요합니다.

1. **System Settings → Privacy & Security → Screen Recording**
2. `MeetingAssistant` 항목을 찾아 활성화
3. 개발 중에는 **Xcode** 자체에도 권한 부여 필요

> 권한 미부여 시 앱 내에 노란색 경고 배너와 설정 이동 버튼이 표시됩니다.

### Microphone (향후 마이크 입력 사용 시)

`MeetingAssistant.entitlements`에 이미 선언되어 있습니다.

---

## 사용 방법

### 앱 시작

1. 앱을 실행하면 메뉴 바(우측 상단)에 아이콘이 나타납니다.
2. 아이콘 클릭 또는 **Cmd+Shift+M** 으로 오버레이 창 표시/숨김 토글.

### 미팅 시작

1. 오버레이 창에서 시나리오 선택 (Customer / Team / War Room)
2. **Start** 버튼 클릭
3. 오디오 레벨 미터가 활성화되면 캡처 시작

### 패널 사용

| 탭 | 사용법 |
|----|--------|
| **Answers** | 자동 표시. 상대방 질문 발화 후 수 초 내 스트리밍 답변 |
| **Terms** | 자동 표시. 전문 용어 감지 후 10초 내 정의 카드 |
| **Questions** | 30초마다 자동 갱신. 우측 상단 ↺ 버튼으로 즉시 갱신 |
| **Transcript** | 실시간 자막. 한국어는 🇰🇷 원문 + 🇺🇸 번역 함께 표시 |

### 미팅 종료

- **Stop** 버튼 클릭
- 세션 데이터(요약, 핵심 용어, Q&A)가 자동으로 로컬에 저장됩니다.
- 다음 같은 시나리오 미팅 시작 시 "관련 이전 세션 발견" 배너가 표시됩니다.

### 창 이동

- 오버레이 상단 드래그 핸들을 마우스로 드래그해 위치 변경

---

## 아키텍처 개요

```
시스템 오디오 (SCStream)
    └─ AudioBufferProcessor (Actor, 48kHz→16kHz 리샘플링)
        └─ GoogleSpeechEngine (REST, latest_long 모델, 침묵 감지 후 전송)
            └─ TranscriptStore (@MainActor, 롤링 10분)
                └─ MeetingCoordinator
                    ├─ Translator (Claude Haiku, 한국어 감지 시)
                    ├─ WordResearcher  ─┐
                    ├─ AnswerFinder    ─┼─ async let 병렬 실행
                    └─ QuestionGenerator─┘
                        └─ AnthropicClient (SSE 스트리밍)
                            └─ SwiftUI Overlay UI
```

**메모리 목표:** 유휴 < 50 MB / 미팅 중 < 150 MB
(Google Cloud STT 사용으로 on-device 모델 RAM 제로)

---

## 트러블슈팅

| 문제 | 해결 방법 |
|------|-----------|
| Start 버튼이 비활성화됨 | API 키 미설정 또는 Screen Recording 권한 미부여. 오버레이 내 경고 배너 확인 |
| 자막이 표시되지 않음 | Google Speech API 키 확인. `speech.googleapis.com:443` 아웃바운드 허용 필요. Cloud Speech-to-Text API가 프로젝트에서 활성화되어 있는지 확인 |
| "Dropping frame" 로그 반복 | SCStream 오디오+스크린 핸들러 둘 다 등록 필요 (코드에 이미 반영됨) |
| 전체화면 Zoom/Teams 위에 안 뜸 | 미팅 앱을 창 모드(windowed)로 실행하세요. 전체화면 앱 위 오버레이는 macOS 제한 사항 |
| 한국어가 번역 안 됨 | Anthropic API 키 확인. 번역은 보조 기능으로 실패 시 원문만 표시됨 |

---

## 세션 저장 위치

```
~/Library/Application Support/MeetingAssistant/sessions/YYYY-MM-DD_<uuid>.json
```

---

## 라이선스

이 프로젝트는 저장소 루트의 [LICENSE](../LICENSE)를 따릅니다.
