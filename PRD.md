# Voice-to-Text Assistant PRD (Local macOS)

## Document Control
- Product: Local macOS Voice-to-Text Assistant
- Version: 3.0
- Date: February 10, 2026
- Status: Build-ready
- Target platform: macOS 14.6+ on Apple Silicon (M1 or newer)

## 1. Problem Statement
Users need fast dictation into any macOS app without sending audio or transcript data to cloud services. Existing options often require network processing, account setup, or app-specific integrations. The product must deliver private, local, system-wide dictation that is fast enough for everyday writing workflows.

## 2. Product Vision
A menu-bar-first assistant that feels instant: hold or toggle a hotkey, speak, release, and text appears in the active app with optional post-processing, all processed on-device.

## 3. Goals
- G1: System-wide dictation in any editable app.
- G2: Strict local processing after one-time model download.
- G3: Reliable low-latency transcription and insertion.
- G4: Minimal UX friction: setup once, then use by hotkey.
- G5: Practical customization for text cleanup and app-specific behavior.

## 4. Non-Goals (V1)
- Cloud sync, user accounts, or collaborative features.
- Meeting recording, diarization, or long-form audio archiving.
- Cross-platform clients (Windows/Linux/iOS).
- Real-time streaming transcript overlays in third-party apps.
- Local LLM rewrite pipeline (deferred to V2).

## 5. Target Users
- U1: Privacy-focused professionals (legal, finance, healthcare admin).
- U2: Developers/writers who want fast system-wide dictation.
- U3: Multilingual users who switch languages throughout the day.

## 6. Jobs To Be Done
- JTBD-1: "When I am writing in any app, I want to dictate quickly so I can keep flow without typing interruption."
- JTBD-2: "When content is sensitive, I want guaranteed local processing so I can comply with privacy expectations."
- JTBD-3: "When transcript cleanup is repetitive, I want automated formatting and replacements so output is usable immediately."

## 7. Scope
### In Scope (V1)
- Global hotkey dictation (hold and toggle modes)
- On-device model download/cache and switching
- Auto-insert into focused text field
- Local history and Privacy Mode
- Text processing pipeline (fillers, numbers, replacements, punctuation/capitalization)
- App-specific rules for formatting and auto-send
- Menu bar UI, settings, onboarding, permission flows
- Voice activity detection (VAD) to filter silence and noise
- Configurable max recording duration with auto-stop

### Out of Scope (V1)
- Cloud APIs for transcription/rewriting
- Account systems
- Team policy management
- Advanced acoustic tuning UI
- Local LLM rewrite (deferred to V2)

## 8. Functional Requirements

### FR-01 Recording Controls
- Provide configurable global hotkey.
- Support `hold-to-record` and `toggle-recording` modes.
- Show clear recording state and transition feedback.
- Enforce configurable max recording duration (default: 120 seconds) with auto-stop and notification.
- Acceptance:
  - User can complete record/transcribe/insert loop in both modes.
  - State transitions are deterministic under rapid key presses.
  - Recording auto-stops at max duration with user notification.

### FR-02 Permissions
- Request and validate microphone and accessibility permissions.
- Block recording/insertion gracefully when missing permissions.
- Acceptance:
  - User sees specific remediation UI for each missing permission.

### FR-03 Audio Capture
- Capture microphone audio only during active recording.
- Resample to 16kHz mono Float32 for whisper.cpp compatibility.
- Allow input device selection and runtime switching.
- Acceptance:
  - Device change while app is open does not require app restart.
  - Audio is correctly resampled regardless of device native rate.

### FR-04 Local Model Management
- One-time model download with progress, pause/retry, integrity checks (SHA256).
- Support at least two models:
  - `whisper-small.en` (~460MB, English-only, faster inference)
  - `whisper-small` (~460MB, multilingual, 100+ languages)
- Store models under `~/Library/Application Support/echo-fs/Models/`.
- Acceptance:
  - Selected model persists across restarts.
  - Corrupt/incomplete downloads are detected and recovered.

### FR-05 Transcription Pipeline
- Convert recorded audio to text on-device using whisper.cpp.
- Apply voice activity detection (VAD) to filter silence and background noise before transcription.
- Run inference on a background queue; dispatch results to main thread.
- Return transcript for short utterances with low perceived delay.
- Acceptance:
  - Median latency <= 1000 ms for <= 10-second utterances on M-series baseline hardware.
  - Silent/noise-only recordings do not produce hallucinated text.

### FR-06 Text Processing
- Optional filler-word removal.
- Optional number normalization.
- Optional replacement dictionary with case-sensitive option.
- Optional punctuation/capitalization formatting.
- Acceptance:
  - Each stage can be toggled independently.
  - Processing order is deterministic and documented.

### FR-07 App-Specific Rules
- Allow per-app overrides for:
  - auto-send
  - formatting toggles
- Acceptance:
  - Rule resolution uses focused app bundle ID.

### FR-08 Text Insertion
- Insert final transcript into active field using three-tier strategy:
  1. AXUIElement accessibility insertion (primary)
  2. CGEvent keystroke simulation (fallback for Electron/web apps)
  3. Clipboard paste with Cmd+V simulation (final fallback)
- Acceptance:
  - On failure, user receives non-blocking error and clipboard fallback output.

### FR-09 Local Rewrite (Deferred to V2)
- Not included in V1. Local LLM rewrite deferred to V2.

### FR-10 History and Privacy Mode
- Maintain local history in menu bar.
- Provide one-click "clear history".
- Privacy Mode must clear history and disable future writes while enabled.
- Acceptance:
  - Privacy Mode state is clearly visible and persisted.

### FR-11 Onboarding
- First-run wizard for permissions, model selection/download, hotkey setup, test dictation.
- Acceptance:
  - New user can complete setup and produce first dictation in <= 5 minutes.

### FR-12 Settings and Lifecycle
- Settings for hotkey, modes, model, processing pipeline, privacy, launch-at-login, max recording duration.
- Acceptance:
  - Settings persist and load correctly after restart.

## 9. Non-Functional Requirements

### NFR-01 Privacy
- No network egress for audio/text after model download completes.
- Any optional telemetry defaults to OFF and excludes content payloads.

### NFR-02 Performance
- App launch <= 2 seconds on baseline hardware.
- Idle CPU near zero.
- Idle memory target <= 250 MB (hard ceiling <= 400 MB).

### NFR-03 Reliability
- Stable through sleep/wake and fast repeated recordings.
- Crash-free session target >= 99.5% in beta.

### NFR-04 UX Quality
- Recording indicator visible and configurable.
- Error states are actionable and specific.

### NFR-05 Security
- Download integrity verification (SHA256 checksum).
- Local data stored under user Application Support with explicit deletion controls.

## 10. Success Metrics
- SM-01 Activation: >= 90% of installers complete onboarding.
- SM-02 Time-to-value: median <= 5 minutes to first successful insert.
- SM-03 Reliability: >= 99.5% crash-free dictation sessions.
- SM-04 Speed: median transcription latency <= 1 second for short utterances.
- SM-05 Privacy confidence: zero content egress defects in QA tests.

## 11. Risks and Mitigations
- R1: Accessibility permission friction
  - Mitigation: explicit onboarding guidance and in-app diagnostic checks.
- R2: Model quality variance by environment
  - Mitigation: model switching, mic tips, replacements, per-app rules.
- R3: Insertion failures in protected fields/apps
  - Mitigation: three-tier fallback (AX -> CGEvent -> clipboard) and clear feedback.
- R4: Feature creep from rewrite/advanced options
  - Mitigation: strict V1 scope gates and phased roadmap. Rewrite deferred to V2.

## 12. Release Plan
- Phase 1: Core dictation loop (FR-01/02/03/04/05/08/11)
- Phase 2: Processing and app rules (FR-06/07/12)
- Phase 3: History/privacy and polish (FR-10 + NFR hardening)

## 13. Resolved Decisions
- O1: Local LLM rewrite — **Deferred to V2**. Not included in V1.
- O2: ASR runtime — **whisper.cpp**. Mature Swift bindings, proven Metal acceleration.
- O3: Persistence backend — **SQLite** via GRDB.swift.
