# Initial Build Agent Prompt: Local macOS Voice-to-Text Assistant

You are the implementation agent for a privacy-first local voice-to-text macOS application.

## Mission

Build a native Apple Silicon macOS app that performs end-to-end dictation locally and inserts text system-wide. After initial model download, no transcript or audio data may be sent to external services.

## Read These Files First

1. `/Users/paul.brohman/Projects/echo-fs/PRD.md`
2. `/Users/paul.brohman/Projects/echo-fs/DESIGN.md`
3. `/Users/paul.brohman/Projects/echo-fs/USER_STORIES.md`

## Hard Constraints

- Platform: macOS 14.6+, Apple Silicon only.
- Architecture: native Swift/SwiftUI with AppKit integration as needed.
- Privacy: no content egress after model download.
- Permissions: microphone and accessibility are required for core flow.
- Audio persistence: do not store raw audio files.

## Scope Targets (V1)

- Global hotkey dictation in hold and toggle modes.
- Audio capture with device selection.
- Local model management (English + multilingual).
- On-device transcription and insertion to focused app.
- Text processing toggles (fillers, numbers, replacements, punctuation/caps).
- App-specific rules including optional auto-send.
- Menu bar history, clear history, Privacy Mode.
- Setup wizard and settings UI.

## Build Status

## Execution Plan You Must Follow

### Step 1: Repository Initialization

- Create a native app structure with clear modules aligned to `DESIGN.md`.
- Add CI/test scaffolding early.
- Add a top-level `README.md` describing setup, build, and privacy posture.

### Step 2: Milestone A (Foundation)

- Implement app shell, status bar item, settings window.
- Implement `PermissionService` and onboarding flow.
- Implement `HotkeyService` and recording state machine.
- Implement `RecordingService` with AVAudioEngine (16kHz mono Float32 output with resampling).
- Configurable max recording duration (default 120s) with auto-stop.

### Step 3: Milestone B (Core Dictation)

- Implement transcription engine using whisper.cpp Swift package.
- Integrate VAD (voice activity detection) to filter silence/noise.
- Run inference on background queue with main-thread result dispatch.
- Implement model download manager with SHA256 checksum verification.
- Implement insertion service with three-tier fallback: AXUIElement -> CGEvent keystrokes -> clipboard paste.
- Demonstrate end-to-end dictation in a supported text field.

### Step 4: Milestone C (Core Product Completeness)

- Add two-model selection (whisper-small.en + whisper-small multilingual).
- Add local history store with SQLite (via GRDB.swift).
- Add menu bar history UI with copy action.
- Add Privacy Mode semantics (clear + block writes).
- Add settings UI with persistence via SettingsStore.

### Step 5: Milestone D (Quality Features)

- Add text processing pipeline and per-feature toggles.
- Add replacement dictionary management UI.
- Add app-specific rule resolution by bundle ID.
- Add optional per-app auto-send behavior.

### Step 6: Milestone E (Hardening & Packaging)

- Sleep/wake resilience handling and rapid hotkey regression fixes.
- Insertion failure diagnostics and permission drift detection.
- Network policy validation (no egress after model download).
- Code signing and notarization.

## Technical Standards

- Keep interfaces protocol-driven and testable.
- Keep services single-responsibility.
- Use deterministic state transitions for recording and privacy behavior.
- Include meaningful logging that never includes transcript content by default.
- Run whisper inference on a background queue; dispatch results to main thread.

## Required Tests

- Unit tests for state machine transitions and processing pipeline.
- Integration tests for end-to-end dictation and insertion fallback.
- Privacy tests confirming no history writes in Privacy Mode.
- Network policy validation ensuring no content egress after setup.

## Acceptance Gates Per Milestone

- Gate A: user can launch app, grant permissions, and start/stop recording with max duration auto-stop.
- Gate B: user can complete dictation loop (record -> transcribe -> insert) with VAD filtering.
- Gate C: user can switch models and use history/privacy controls.
- Gate D: user can enable processing and app-specific rules.
- Gate E: app passes regression matrix, no content egress, signed/notarized build.

## Expected Output Format During Build

For each milestone, report:

1. Implemented files and modules.
2. Tests added/updated.
3. Known limitations.
4. Next milestone tasks.

## Conflict Resolution Rule

If any requirement conflicts with privacy/local-only constraints, privacy wins. Defer conflicting behavior and document rationale.
