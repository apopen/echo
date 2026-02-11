<p align="center">
  <a href="https://github.com/apopen/echo/actions/workflows/ci.yml"><img src="https://github.com/apopen/echo/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue?style=flat-square" alt="macOS 14+">
  <img src="https://img.shields.io/badge/chip-Apple%20Silicon-black?style=flat-square" alt="Apple Silicon">
  <img src="https://img.shields.io/badge/swift-5.10-orange?style=flat-square" alt="Swift 5.10">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="MIT License"></a>
</p>

<h1 align="center">Echo</h1>

<p align="center">
  <strong>Privacy-first voice-to-text for macOS.</strong><br>
  Hold a key, speak, release — text appears wherever your cursor is.<br>
  Everything runs on your machine. No cloud. No accounts. No data leaves your device.
</p>

<p align="center">
  <img src="assets/echo-recording.png" alt="Echo recording waveform" width="600">
</p>

<p align="center">
  <a href="https://github.com/apopen/echo/releases/latest">
    <img src="https://img.shields.io/badge/%E2%AC%87%EF%B8%8F_Download_Echo-black?style=for-the-badge&logo=apple&logoColor=white" alt="Download Echo" height="40">
  </a>
</p>
<p align="center">
  <a href="https://github.com/apopen/echo/releases/latest"><img src="https://img.shields.io/github/v/release/apopen/echo?label=latest%20release&style=flat-square" alt="Latest Release"></a>
</p>

<p align="center">
  <a href="#quick-start">Quick Start</a> &bull;
  <a href="#features">Features</a> &bull;
  <a href="#how-it-works">How It Works</a> &bull;
  <a href="#settings">Settings</a> &bull;
  <a href="#models">Models</a> &bull;
  <a href="#privacy">Privacy</a> &bull;
  <a href="#building-from-source">Building from Source</a> &bull;
  <a href="#troubleshooting">Troubleshooting</a> &bull;
  <a href="#faq">FAQ</a>
</p>

---

## Quick Start

### Download

1. Grab the latest **Echo.app** from the [Releases page](https://github.com/apopen/echo/releases/latest)
2. Unzip and drag **Echo.app** to your Applications folder
3. **Remove the quarantine flag** (required because the app is not notarized by Apple):
   ```bash
   xattr -cr /Applications/Echo.app
   ```
4. Launch Echo from Applications

> **Why is this needed?** macOS Gatekeeper blocks apps downloaded from the internet that aren't signed with an Apple Developer certificate. The `xattr -cr` command removes the quarantine flag so macOS will let you open it. This is standard for open-source Mac apps distributed outside the App Store.

### Or build from source

```bash
git clone https://github.com/apopen/echo.git
cd echo
swift build
swift run Echo
```

On first launch Echo walks you through a short setup:

1. **Grant permissions** — Microphone (to hear you) and Accessibility (to type for you)
2. **Download a model** — pick English-only for speed or Multilingual for 100+ languages
3. **Set your hotkey** — Page Down by default, or record any key combo you like
4. **Start dictating** — press your hotkey in any app and speak

That's it. Echo lives in your menu bar and is always one keypress away.

---

## Features

### Dictate Anywhere

Press your hotkey in **any** app — text editors, email, Slack, browsers, terminals — and speak naturally. Your words appear as text when you stop.

### Two Recording Modes

- **Hold to Record** — press and hold the hotkey while speaking, release to finish
- **Toggle** — press once to start recording, press again to stop

### Configurable Hotkey

Set any key or key combination (e.g. `F5`, `⌘⇧D`, `Page Down`) as your trigger. Change it anytime in Settings or during onboarding.

### Copy or Paste — Your Choice

Choose how transcribed text is delivered:

- **Copy to Clipboard** — text lands on your clipboard, paste it wherever you want
- **Paste at Cursor** — text is automatically pasted where your cursor is, no extra step

### Smart Text Processing

Clean up transcriptions automatically (all optional and toggleable):

- Remove filler words (um, uh, like...)
- Normalize spoken numbers ("three" becomes "3")
- Fix punctuation and capitalization
- Apply custom find-and-replace rules for names, acronyms, and jargon

### Per-App Rules

Configure app-specific behavior:

- Auto-send (simulate Enter after insertion) for chat apps like Slack
- Custom processing overrides per app

### On-Device Transcription

Powered by [whisper.cpp](https://github.com/ggerganov/whisper.cpp) with Metal GPU acceleration on Apple Silicon. Transcription is fast — typically under 1 second for short utterances.

### Voice Activity Detection

Built-in VAD filters out silence and background noise so you don't get phantom text from quiet recordings.

---

## How It Works

```
 Hotkey pressed         Record audio         Transcribe locally       Process text        Insert
 ┌───────────┐        ┌──────────────┐      ┌──────────────────┐    ┌──────────────┐    ┌────────────┐
 │ Page Down │───────>│  Microphone   │─────>│   whisper.cpp    │───>│ Filler/Number│───>│ Clipboard  │
 │  ⌘⇧D      │        │  16kHz mono   │      │   Metal GPU      │    │ Replacement  │    │   or       │
 │  F5  ...  │        │  Float32      │      │   on-device      │    │ Punctuation  │    │ Paste ⌘V   │
 └───────────┘        └──────────────┘      └──────────────────┘    └──────────────┘    └────────────┘
```

1. **You press the hotkey** — Echo starts recording from your microphone
2. **You speak** — audio is captured at 16kHz mono (whisper.cpp's native format)
3. **You release** — audio is sent to the local whisper.cpp engine (Metal-accelerated)
4. **Text is cleaned** — optional processing removes fillers, normalizes numbers, applies your rules
5. **Text is delivered** — copied to clipboard or pasted directly at your cursor

No audio is ever written to disk. No network requests are made. Everything happens in memory, on your CPU/GPU.

---

## Settings

Open Settings from the Echo menu bar icon. Available options:

| Section            | Setting                             | Description                                |
| ------------------ | ----------------------------------- | ------------------------------------------ |
| **Trigger**        | Recording hotkey                    | Any key or key combo (click Record to set) |
| **Recording Mode** | Hold / Toggle                       | Hold to record or toggle on/off            |
| **Output**         | Copy to Clipboard / Paste at Cursor | How transcribed text is delivered          |
| **Recording**      | Max duration                        | Auto-stop after N seconds (default: 120)   |
| **Models**         | Selected model                      | Switch between downloaded models           |
| **Processing**     | Filler removal                      | Remove "um", "uh", "like", etc.            |
|                    | Number normalization                | "three" becomes "3"                        |
|                    | Punctuation formatting              | Auto-capitalize and fix spacing            |
|                    | Custom replacements                 | Your own find/replace rules                |
| **App Rules**      | Per-app config                      | Auto-send, custom processing per app       |
| **Permissions**    | Mic / Accessibility                 | Status and quick-fix links                 |
| **System**         | Launch at Login                     | Start Echo when you log in                 |

---

## Models

Echo uses whisper.cpp GGML models downloaded from Hugging Face during setup. Models are verified with SHA256 checksums and stored locally.

| Model                | Size    | Languages      | Best For                                   |
| -------------------- | ------- | -------------- | ------------------------------------------ |
| **whisper-small.en** | ~460 MB | English only   | Fastest transcription for English speakers |
| **whisper-small**    | ~460 MB | 100+ languages | Multilingual support                       |

You can download additional models or switch between them in Settings > Models. Models are stored in `~/Library/Application Support/Echo/Models/` and can be deleted from the app.

---

## Privacy

Echo is designed around a simple principle: **your voice and your words stay on your machine**.

| Guarantee                    | Detail                                                                        |
| ---------------------------- | ----------------------------------------------------------------------------- |
| **No cloud processing**      | All transcription runs locally via whisper.cpp with Metal GPU acceleration    |
| **No telemetry**             | Zero analytics, crash reports, or usage tracking                              |
| **No audio storage**         | Raw audio is never written to disk — it lives in memory only during recording |
| **No transcript storage**    | Transcriptions are delivered and discarded — nothing is logged                |
| **No network requests**      | After the one-time model download, Echo makes zero network calls              |
| **Local data only**          | Settings and models live in `~/Library/Application Support/Echo/`             |
| **User-controlled deletion** | Delete models and reset settings from within the app                          |

---

## Building from Source

### Requirements

- macOS 14.0 or later
- Apple Silicon (M1 or newer)
- Swift 5.10+ / Xcode 15.4+

### Build

```bash
git clone <repo-url>
cd echo-fs

# Build
swift build

# Run
swift run Echo

# Run tests
swift test
```

Dependencies are resolved automatically by Swift Package Manager on first build.

### Dependencies

| Package                                                      | Purpose                                          |
| ------------------------------------------------------------ | ------------------------------------------------ |
| [WhisperCppKit](https://github.com/Justmalhar/WhisperCppKit) | Local speech recognition with Metal acceleration |

All other functionality uses Apple system frameworks (AVAudioEngine, SwiftUI, AppKit, Accessibility, CoreGraphics).

### Project Structure

```
echo-fs/
├── Echo/Sources/
│   ├── App/                  # App lifecycle, delegate, window management
│   ├── Models/               # Data types (HotkeyCombo, RecordingState, etc.)
│   ├── Services/             # Core logic (hotkey, recording, transcription, etc.)
│   └── Views/                # SwiftUI views (settings, onboarding, floating bar)
├── EchoTests/                # Unit tests
├── Package.swift             # SPM manifest
└── README.md
```

---

## Troubleshooting

### "Echo is damaged and can't be opened"

This is macOS Gatekeeper blocking the app because it isn't notarized by Apple. Run this command to fix it:

```bash
xattr -cr /Applications/Echo.app
```

Then open Echo again. This only needs to be done once.

### Echo isn't responding to my hotkey

- **Check Accessibility permission**: System Settings > Privacy & Security > Accessibility — make sure your terminal app (Terminal, iTerm2, Ghostty, etc.) or Echo is listed and enabled
- **Check Input Monitoring**: Some macOS versions also require Input Monitoring permission
- Open Echo Settings > Permissions and click **Refresh Permissions** to verify status

### Transcription produces no text

- Make sure a model is downloaded (Settings > Models)
- Check that your microphone is working and the correct input device is selected
- Speak clearly and close to the microphone — the VAD will filter very quiet audio

### Text isn't appearing in my app

- **Paste at Cursor mode** requires Accessibility permission to simulate keystrokes
- Some apps with protected text fields may not accept simulated paste — switch to **Copy to Clipboard** mode and paste manually
- Check Settings > Output to confirm which mode is active

### Model download failed

- Check your internet connection
- Try deleting the partial download in Settings > Models and re-downloading
- Models are downloaded from Hugging Face — ensure it's accessible from your network

### High memory usage

- Each model uses ~460 MB in memory when loaded. This is expected for on-device inference
- Idle memory (without a model loaded) should be under 250 MB

---

## FAQ

**Q: Does Echo work with Intel Macs?**
A: Echo targets Apple Silicon (M1+) for Metal GPU acceleration. It may build on Intel but transcription performance will be significantly slower without Metal.

**Q: Can I use my own whisper.cpp model?**
A: Currently Echo supports the models in its built-in catalog. Custom model support may be added in a future release.

**Q: Does Echo work offline?**
A: Yes — once you've downloaded a model during setup, Echo works completely offline. No internet required.

**Q: Will Echo work in [specific app]?**
A: Echo works in any app that accepts text input. In **Paste at Cursor** mode it simulates ⌘V, which works in virtually all apps. In **Copy to Clipboard** mode it always works since it just puts text on your clipboard.

**Q: How do I completely uninstall Echo?**
A: Delete the Echo binary and remove `~/Library/Application Support/Echo/` to clean up models and settings.

**Q: What languages are supported?**
A: The `whisper-small.en` model supports English only. The `whisper-small` model supports 100+ languages including Spanish, French, German, Chinese, Japanese, Arabic, Hindi, and many more.

**Q: Is my audio sent anywhere?**
A: No. Audio is captured in memory, transcribed locally, and discarded. It is never written to disk or transmitted over the network.

---

## Architecture

For contributors and the technically curious — Echo is a native Swift/SwiftUI menu bar app built as an SPM executable.

| Module                 | Responsibility                                                |
| ---------------------- | ------------------------------------------------------------- |
| `AppState`             | Central coordinator, state machine, service wiring            |
| `HotkeyService`        | Global keyboard monitoring via CGEvent tap                    |
| `RecordingService`     | AVAudioEngine capture, 16kHz resampling, duration limits      |
| `TranscriptionService` | whisper.cpp inference with VAD on background queue            |
| `ProcessingPipeline`   | Text transforms (fillers, numbers, replacements, punctuation) |
| `InsertionService`     | Clipboard copy or paste-at-cursor via CGEvent                 |
| `ModelManager`         | Model download, SHA256 verification, storage                  |
| `SettingsStore`        | Persistent configuration via UserDefaults                     |
| `PermissionService`    | Microphone and accessibility permission checks                |

See [DESIGN.md](DESIGN.md) for the full technical design document.

---

## License

This project is licensed under the [MIT License](LICENSE).
