# Voice-to-Text Assistant User Stories and Delivery Backlog

## Story Conventions
- Priority: P0 (must-have), P1 (should-have), P2 (nice-to-have)
- Dependencies reference story IDs
- Every story includes acceptance criteria

## Epic A: Onboarding and Permissions

### US-001 (P0)
As a first-time user, I want a guided setup wizard so I can configure the app without guessing.
- Depends on: none
- Acceptance:
  - Wizard includes steps for microphone, accessibility, model download, hotkey test.
  - User can skip and resume later from settings.

### US-002 (P0)
As a user, I want explicit permission diagnostics so I can fix blocked features quickly.
- Depends on: US-001
- Acceptance:
  - App displays current permission states and links to system settings.

### US-003 (P0)
As a user, I want a test dictation in setup so I can verify end-to-end readiness.
- Depends on: US-001
- Acceptance:
  - Successful test inserts text into a local test field.

## Epic B: Core Dictation Loop

### US-010 (P0)
As a user, I want hold-to-record so dictation feels immediate.
- Depends on: US-002
- Acceptance:
  - Press-and-hold starts recording; release ends and triggers transcription.

### US-011 (P0)
As a user, I want toggle mode so I can dictate hands-free.
- Depends on: US-010
- Acceptance:
  - Single hotkey press starts recording; second press stops recording.

### US-012 (P0)
As a user, I want an always-visible recording indicator option so I know capture state.
- Depends on: US-010
- Acceptance:
  - Indicator supports visible/minimal/hidden styles.

### US-013 (P0)
As a user, I want transcripts inserted into my active app so I do not switch context.
- Depends on: US-010
- Acceptance:
  - Transcript appears in focused editable field for supported apps.

### US-014 (P0)
As a user, I want clipboard fallback when insertion fails so output is never lost.
- Depends on: US-013
- Acceptance:
  - Failed insertion copies transcript to clipboard and displays a non-blocking notice.

### US-015 (P0)
As a user, I want a configurable max recording duration so a forgotten toggle does not record indefinitely.
- Depends on: US-010
- Acceptance:
  - Recording auto-stops at the configured max duration (default: 120 seconds).
  - User receives a notification when auto-stop triggers.

### US-016 (P1)
As a user, I want to select my audio input device so I can use an external microphone.
- Depends on: US-010
- Acceptance:
  - Device selection is available in settings.
  - Switching devices does not require app restart.

## Epic C: Models and Inference

### US-020 (P0)
As a user, I want a one-time model download with progress and retry so setup is reliable.
- Depends on: US-001
- Acceptance:
  - Download shows progress, supports retry, and validates SHA256 checksum.

### US-021 (P0)
As a user, I want an English model and multilingual model so I can optimize speed vs language support.
- Depends on: US-020
- Acceptance:
  - Both models (whisper-small.en and whisper-small) are selectable in settings and persist across restart.

### US-022 (P0)
As a user, I want local inference only so my content stays private.
- Depends on: US-021
- Acceptance:
  - No audio/text network egress after model installation.

### US-023 (P0)
As a user, I want voice activity detection so silence and background noise do not produce hallucinated text.
- Depends on: US-022
- Acceptance:
  - Silent recordings produce no output (or a "no speech detected" notification).
  - VAD is enabled by default.

## Epic D: Processing and Rules

### US-030 (P1)
As a user, I want filler-word removal so transcript quality is cleaner.
- Depends on: US-013
- Acceptance:
  - Feature toggle exists and is applied deterministically.

### US-031 (P1)
As a user, I want number normalization so spoken numbers become digits when desired.
- Depends on: US-013
- Acceptance:
  - Feature toggle exists and respects locale-safe defaults.

### US-032 (P1)
As a user, I want custom replacements for names/acronyms so text matches my vocabulary.
- Depends on: US-013
- Acceptance:
  - Replacement rules support case-sensitive and case-insensitive modes.

### US-033 (P1)
As a user, I want per-app rules so output behavior matches context.
- Depends on: US-030, US-031, US-032
- Acceptance:
  - Rule resolution uses focused app bundle ID.

### US-034 (P1)
As a user, I want optional auto-send per app so messaging workflows are faster.
- Depends on: US-033
- Acceptance:
  - Auto-send is opt-in and disabled by default.

## Epic E: History and Privacy

### US-040 (P0)
As a user, I want local transcript history in the menu bar so I can reuse text.
- Depends on: US-013
- Acceptance:
  - Last N items are visible with quick copy action.

### US-041 (P0)
As a user, I want one-click clear history so I can remove sensitive data.
- Depends on: US-040
- Acceptance:
  - Clear action removes all stored transcript entries.

### US-042 (P0)
As a user, I want Privacy Mode so no history is written while enabled.
- Depends on: US-040
- Acceptance:
  - Enabling Privacy Mode clears existing history and blocks future writes.

## Epic F: Reliability and Lifecycle

### US-050 (P0)
As a user, I want settings to persist across reboot so behavior stays consistent.
- Depends on: US-001
- Acceptance:
  - Hotkey/mode/model/rules/privacy settings persist after restart.

### US-051 (P1)
As a user, I want launch-at-login so the assistant is always ready.
- Depends on: US-050
- Acceptance:
  - Launch-at-login toggle works and reflects current system state.

### US-052 (P0)
As a user, I want stable behavior across sleep/wake so dictation does not break.
- Depends on: US-010
- Acceptance:
  - App recovers without restart in sleep/wake regression tests.

### US-053 (P0)
As a user, I want near-instant response for short dictations so the tool feels natural.
- Depends on: US-022
- Acceptance:
  - Median latency <= 1 second for <= 10-second utterances on baseline M-series hardware.

## Build Task Plan (Execution Order)

### Wave 1 (Foundation, P0)
- Implement app shell, status item, settings scaffold.
- Implement permission service and onboarding wizard.
- Implement hotkey service and recording service (with 16kHz resampling and max duration).
- Implement transcription service with whisper.cpp and VAD.
- Implement insertion service with three-tier fallback.

### Wave 2 (Core Product, P0)
- Add model manager for two-model selection.
- Add history store and menu bar history UI.
- Add Privacy Mode behavior and clear-history actions.
- Add reliability hardening for sleep/wake and rapid hotkeys.

### Wave 3 (Differentiators, P1)
- Add processing pipeline toggles.
- Add replacement dictionary editor.
- Add app-specific rules and auto-send policy.

## Definition of Ready (for any task)
- Story has ID, priority, dependencies, acceptance criteria.
- UX behavior and error behavior are both specified.
- Test approach is identified (unit/integration/manual).

## Definition of Done (for any task)
- Acceptance criteria validated.
- Regression tests added or updated.
- No content egress introduced.
- Documentation updated where behavior changed.
