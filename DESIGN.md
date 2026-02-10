# Voice-to-Text Assistant Technical Design

## Document Control
- Version: 3.0
- Date: February 10, 2026
- Target: Native macOS app (Apple Silicon, macOS 14.6+)

## 1. Architecture Summary
The system is a native menu-bar macOS app with a deterministic dictation pipeline:
1. Capture hotkey event.
2. Record microphone audio.
3. Run on-device ASR via whisper.cpp.
4. Apply local text-processing rules.
5. Insert text into focused app.
6. Persist history unless Privacy Mode is active.

No transcript or audio leaves the machine after model download.

## 2. Technology Decisions
- Language: Swift 5.10+
- UI: SwiftUI with AppKit integration for status item and advanced macOS APIs
- Audio: AVAudioEngine
- Persistence: SQLite (via GRDB.swift)
- ASR runtime: **whisper.cpp** — mature Swift bindings, proven Metal acceleration on Apple Silicon
- Distribution: signed and notarized macOS app

Rationale:
- Native stack minimizes latency and permission complexity.
- SQLite gives durable local history and indexed retrieval.
- whisper.cpp is the most mature local ASR option with Swift/Metal support. MLX backend deferred to V2 if needed.

### 2.1 Swift Package Dependencies
| Package | Purpose | URL |
|---------|---------|-----|
| whisper.cpp | ASR inference with Metal acceleration | https://github.com/ggerganov/whisper.cpp |
| HotKey | Global keyboard shortcuts | https://github.com/soffes/HotKey |
| GRDB.swift | SQLite wrapper for history/settings | https://github.com/groue/GRDB.swift |

All other functionality uses Apple frameworks: AVAudioEngine (audio), SwiftUI/AppKit (UI), Accessibility (insertion), CoreGraphics (CGEvent fallback).

## 3. Module Boundaries
- `AppShell`
  - app lifecycle, status item, windows
- `HotkeyService`
  - global key handling, mode-specific transitions
- `RecordingService`
  - AVAudioEngine start/stop, audio buffer lifecycle, 16kHz resampling, max duration enforcement
- `TranscriptionService`
  - model loading/unloading, inference execution, cancellation, VAD configuration
- `ProcessingPipeline`
  - text normalization/transforms and per-app rule resolution
- `InsertionService`
  - three-tier insertion: AXUIElement -> CGEvent keystrokes -> clipboard paste
- `HistoryStore`
  - local persistence and retention operations (SQLite via GRDB)
- `PrivacyService`
  - Privacy Mode state, destructive clear operations
- `SettingsStore`
  - durable configuration and migration
- `PermissionService`
  - mic/accessibility checks and onboarding integration
- `ModelManager`
  - model download, checksum verification, resume/retry, storage management

## 4. Runtime Sequence
### 4.1 Dictation Flow
1. `HotkeyService` emits `startRecording`.
2. `RecordingService` starts AVAudioEngine, resamples to 16kHz mono Float32, and buffers PCM frames.
3. `HotkeyService` emits `stopRecording` (or max duration auto-stop triggers).
4. `RecordingService` finalizes buffer and returns audio payload.
5. `TranscriptionService` runs VAD to filter silence, then runs whisper.cpp inference on a background queue.
6. Results dispatched to main thread.
7. `ProcessingPipeline` applies enabled transforms.
8. `InsertionService` inserts text in focused app (AX -> CGEvent -> clipboard fallback chain).
9. `HistoryStore` persists transcript if Privacy Mode is off.

### 4.2 Failure Flow
- Missing permission: stop pipeline, route to onboarding panel.
- Inference failure: show transient notification and preserve clipboard fallback option.
- Insertion failure (AX): try CGEvent keystroke simulation.
- Insertion failure (CGEvent): fall back to pasteboard write + Cmd+V simulation.
- All insertion methods fail: put text in clipboard and notify user.

## 5. State Machines
### 5.1 Recording State
- `Idle`
- `Recording`
- `Transcribing`
- `Inserting`
- `Error`

Transitions are controlled by hotkey events and service outcomes. Re-entrancy is blocked outside `Idle` except explicit cancel.

### 5.2 Privacy State
- `Normal`: history writes enabled.
- `Private`: history writes disabled, existing history cleared on entry.

## 6. Interfaces (Core Protocols)
```swift
protocol TranscriptionEngine {
    /// Load model from disk into memory for inference
    func loadModel(_ modelID: String) async throws
    /// Unload current model and free resources
    func unloadModel() async
    /// Whether a model is currently loaded and ready
    var isModelLoaded: Bool { get }
    /// Transcribe audio buffer to text
    /// - Parameters:
    ///   - audio: PCM audio buffer (16kHz mono Float32)
    ///   - language: Optional language code (nil = auto-detect)
    func transcribe(_ audio: AudioBuffer, language: String?) async throws -> String
    /// Cancel in-progress transcription
    func cancel() async
}

protocol TextInserter {
    /// Insert text into the focused application
    /// - Parameters:
    ///   - text: The text to insert
    ///   - autoSend: Whether to simulate Enter after insertion
    func insert(_ text: String, autoSend: Bool) async throws
}

protocol HistoryRepository {
    func save(_ item: TranscriptItem) throws
    func list(limit: Int) throws -> [TranscriptItem]
    func clearAll() throws
}
```

## 7. Data Model

### 7.1 Settings
- `hotkey_combo`
- `record_mode` (`hold`, `toggle`, `both`)
- `selected_model_id`
- `processing_flags` (bitfield or JSON)
- `privacy_mode_enabled`
- `launch_at_login`
- `app_rules` (per-bundle-id overrides)
- `max_recording_duration` (seconds, default 120)

### 7.2 TranscriptItem
- `id`
- `created_at`
- `text_raw`
- `text_processed`
- `source_app_bundle_id`
- `model_id`
- `latency_ms`

Note: raw audio is never persisted.

### 7.3 Model Manifest
- `model_id` (e.g., `whisper-small.en`, `whisper-small`)
- `display_name`
- `download_url` (Hugging Face)
- `sha256_checksum`
- `file_size_bytes`
- `language_scope` (`english` or `multilingual`)

## 8. Audio Preprocessing
- AVAudioEngine captures at the device's native sample rate.
- `RecordingService` installs a tap on the input node and resamples to **16kHz mono Float32** using AVAudioConverter, as required by whisper.cpp.
- Audio buffers are accumulated in memory (not written to disk).
- A configurable max recording duration (default: 120 seconds) triggers auto-stop with a notification to the user.

## 9. Voice Activity Detection (VAD)
- whisper.cpp includes built-in energy-based VAD that filters leading/trailing silence.
- VAD is enabled by default to prevent hallucinated text from silence or background noise.
- Parameters exposed: `energy_threshold`, `no_speech_threshold`.
- If whisper.cpp VAD proves insufficient, Silero VAD can be added as a preprocessing step in V2.

## 10. Threading Model
- **Main thread**: UI updates, state machine transitions, hotkey handling.
- **Audio thread**: AVAudioEngine tap callback (minimal work — copy buffer only).
- **Inference queue**: Dedicated serial `DispatchQueue` for whisper.cpp inference. All model load/unload/transcribe operations run here.
- **Result dispatch**: Inference results are dispatched back to main thread via `DispatchQueue.main.async` before pipeline continues.
- whisper.cpp internally uses Metal for GPU acceleration; the inference queue serializes calls to prevent concurrent model access.

## 11. Inference and Model Management
- Model files stored under `~/Library/Application Support/echo-fs/Models/`.
- Available models:
  - `whisper-small.en` (~460MB, English-only, faster)
  - `whisper-small` (~460MB, multilingual, 100+ languages)
  - `whisper-base.en` (~140MB, lightweight English option for constrained systems)
- Downloads from Hugging Face with SHA256 checksum verification.
- Partial downloads resume/retry.
- Engine warm-up triggered at app start to reduce first-use latency.

## 12. Insertion Strategy
**Tier 1 — Accessibility (AXUIElement):**
- Query focused element via Accessibility API.
- Set `AXValue` if the element supports it.
- Most reliable for native macOS apps (TextEdit, Notes, etc.).

**Tier 2 — CGEvent keystroke simulation:**
- Generate CGEvent key-down/key-up events for each character.
- More reliable than AX in Electron apps, web views, and some cross-platform apps.
- Requires accessibility permission.

**Tier 3 — Clipboard paste fallback:**
- Save current clipboard contents.
- Write transcript to pasteboard.
- Simulate Cmd+V via CGEvent.
- Restore previous clipboard contents after brief delay.

**Auto-send:**
- If configured for the focused app, simulate Enter keystroke after insertion.
- Requires explicit user opt-in; disabled by default.

## 13. Privacy and Security Controls
- Network policy: block all runtime calls except explicit model download endpoint.
- No content logging to external sinks.
- Local logs redact transcript content by default.
- User can clear history and disable persistence via Privacy Mode.

## 14. Testing Strategy

### 14.1 Unit Tests
- State machine transitions
- Processing pipeline transforms
- Rule resolution for app-specific behavior
- Settings migration and defaults

### 14.2 Integration Tests
- End-to-end dictation using synthetic audio fixture
- Permission denial and recovery flows
- Insertion fallback path
- Privacy Mode enforcement

### 14.3 Manual QA Matrix
- Devices: M1, M2, M3
- OS: macOS 14.6, 15.x
- Apps: Notes, TextEdit, Slack, Mail, browser text inputs
- Conditions: sleep/wake, device mic change, rapid hotkey tapping

## 15. Observability (Local)
- Local-only event counters (non-content):
  - dictation_started
  - dictation_succeeded
  - dictation_failed
  - insertion_fallback_used
  - model_load_failed
- Export debug bundle manually for troubleshooting.

## 16. Implementation Plan
- Milestone A: App shell + permissions + hotkey + recording (with resampling and max duration)
- Milestone B: whisper.cpp integration + VAD + insertion (three-tier fallback)
- Milestone C: Model management + history + privacy mode + settings
- Milestone D: Processing pipeline + app rules + auto-send
- Milestone E: Hardening + packaging (no local rewrite in V1)

## 17. Definition of Done
- All FR and NFR criteria mapped to tests.
- No external content egress in network validation.
- Signed/notarized build installs and runs on clean macOS user account.
