# Echo

A privacy-first, local voice-to-text assistant for macOS. Hold a hotkey, speak, release — text appears in any app. All processing happens on-device via whisper.cpp with Metal acceleration. No data leaves your machine after the initial model download.

## Requirements

- macOS 14.6 or later
- Apple Silicon (M1 or newer)
- Xcode 15.4 or later
- Microphone permission
- Accessibility permission (for text insertion)

## Build

```bash
# Clone the repository
git clone <repo-url>
cd echo-fs

# Build from command line
swift build

# Run tests
swift test
```

Swift Package dependencies are resolved automatically on first build.

## Architecture

Echo is a native Swift/SwiftUI menu bar app with these core services:

| Module | Responsibility |
|--------|---------------|
| `AppShell` | App lifecycle, status item, window management |
| `HotkeyService` | Global keyboard shortcuts (hold and toggle modes) |
| `RecordingService` | AVAudioEngine capture, 16kHz resampling, max duration |
| `TranscriptionService` | whisper.cpp inference with VAD, background queue |
| `ProcessingPipeline` | Text transforms (fillers, numbers, replacements, punctuation) |
| `InsertionService` | Clipboard-based text insertion |
| `ModelManager` | Model download, checksum verification, storage |
| `SettingsStore` | Persistent configuration |
| `PermissionService` | Microphone and accessibility checks |

## Privacy

- **No cloud processing**: All transcription runs locally via whisper.cpp with Metal GPU acceleration.
- **No telemetry**: No usage data, analytics, or crash reports are sent anywhere.
- **No audio storage**: Raw audio is never written to disk.
- **No history**: Nothing is saved — transcriptions are copied to clipboard and discarded.
- **Network isolation**: After the one-time model download from Hugging Face, no network requests are made.
- **Local storage**: Settings and models reside under `~/Library/Application Support/Echo/` with user-controlled deletion.

## Models

Echo uses whisper.cpp GGML models:

| Model | Size | Languages | Use case |
|-------|------|-----------|----------|
| `whisper-small.en` | ~460 MB | English only | Faster inference |
| `whisper-small` | ~460 MB | 100+ languages | Multilingual support |

Models are downloaded during first-run setup and stored locally with SHA256 integrity verification.

## Dependencies

| Package | Purpose |
|---------|---------|
| [WhisperCppKit](https://github.com/Justmalhar/WhisperCppKit) | Local ASR with Metal acceleration |
| [HotKey](https://github.com/soffes/HotKey) | Global keyboard shortcuts |

All other functionality uses Apple system frameworks.

## License

Private use only. Not for redistribution.
