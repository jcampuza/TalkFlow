# TalkFlow

<p align="center">
  <img src="assets/talkflow-app-icon-transparent.png" alt="TalkFlow Icon" width="200">
</p>

<p align="center">
  <strong>Voice-to-text dictation for macOS, powered by AI</strong>
</p>

<p align="center">
  Press and hold a key to record. Release to transcribe. Text appears instantly.
</p>

---

TalkFlow is a native macOS menu bar app that transforms your voice into text using OpenAI's Whisper. Choose between cloud-based transcription via the OpenAI API or completely private, on-device transcription using local Whisper models—no internet required. Hold down a trigger key (default: Right Command), speak, and release—your transcription is automatically pasted into whatever app you're using.

<p align="center">
  <img src="assets/app-screenshot.png" alt="TalkFlow App" width="600">
</p>

## Features

- **Press-and-hold activation** — Hold the trigger key to record, release to transcribe. No clicking required.
- **Instant paste** — Transcribed text is automatically inserted into your focused input field.
- **Local or cloud transcription** — Use on-device Whisper models for free, private transcription, or the OpenAI API for cloud-based processing.
- **Configurable shortcuts** — Remap the trigger to any modifier key, single key, or key combination.
- **Smart audio processing** — Voice activity detection and silence removal for clean, efficient transcriptions.
- **History with search** — All transcriptions are saved locally with full-text search.
- **Privacy-focused** — Audio is never saved to disk. API keys stored securely in macOS Keychain.
- **Visual feedback** — Floating indicator shows recording, processing, and completion states.
- **Multi-monitor support** — Indicator appears on whichever display your cursor is on.

## Requirements

- macOS 15 (Sequoia) or later
- **For cloud transcription:** OpenAI API key with access to the Whisper API
- **For local transcription:** Apple Silicon Mac recommended (Intel Macs supported but slower)

## Installation

### From Source

```bash
# Clone the repository
git clone https://github.com/jcampuza/voice-dictation-ai-macos.git
cd voice-dictation-ai-macos/TalkFlow

# Build the app
./Scripts/build-app.sh release

# Launch
open .build/release/TalkFlow.app
```

Or build and launch in one step:

```bash
./Scripts/build-app.sh release --run
```

## Setup

1. **Launch TalkFlow** — The app runs in your menu bar.
2. **Grant permissions** — You'll be prompted for:
   - **Accessibility**: Required for global shortcuts and text insertion
   - **Microphone**: Required for audio capture
3. **Choose your transcription mode:**
   - **Local (recommended)** — Download a Whisper model and transcribe entirely on-device. Free and private.
   - **Cloud** — Enter your OpenAI API key to use the Whisper API.
4. **Start dictating** — Hold Right Command (or your configured trigger), speak, and release.

<p align="center">
  <img src="assets/app-settings-screenshot.png" alt="TalkFlow Settings" width="600">
</p>

## Local Models

TalkFlow supports on-device transcription using [WhisperKit](https://github.com/argmaxinc/WhisperKit), which runs OpenAI's Whisper models locally via Apple's Core ML. This means:

- **Completely free** — No API costs, transcribe as much as you want
- **Private** — Audio never leaves your device
- **Works offline** — No internet connection required after model download

### Available Models

| Model | Size | Quality | Best For |
|-------|------|---------|----------|
| Tiny | ~40 MB | Basic | Quick notes, simple dictation |
| Small | ~250 MB | Good | General use, balanced speed/quality |
| Large v3 Turbo | ~950 MB | Best | Accuracy-critical work, complex vocabulary |

### First-Time Setup

> **Note:** The first transcription after downloading a model may take 10-30 seconds as the model compiles and warms up on your specific hardware. This is a one-time process—subsequent transcriptions are fast (typically under 2 seconds for short recordings).

To use local transcription:

1. Open **Settings** → **Transcription**
2. Select **Local** as your transcription mode
3. Choose a model and click **Download**
4. Once downloaded, the model is ready to use

### Performance Tips

- **Apple Silicon Macs** deliver the best performance with local models
- **Larger models** produce better results but require more memory and processing time
- **Keep the model loaded** — TalkFlow keeps the model in memory between transcriptions for faster response times

## Usage

| Action | Result |
|--------|--------|
| Hold trigger key | Start recording (after 300ms) |
| Release trigger key | Stop recording and transcribe |
| Press another key while holding | Cancel recording |
| Click menu bar icon | Open menu with recent transcriptions |

### Indicator States

| State | Appearance |
|-------|------------|
| Recording | Pulsing red/orange |
| Processing | Blue with spinner |
| Success | Green checkmark |
| Error | Red with message |
| No Speech | Yellow/orange |

## Settings

Access settings from the menu bar icon → Settings:

- **Shortcut** — Configure your trigger key
- **Audio** — Select input device, adjust silence threshold
- **Transcription** — Choose local or cloud mode, download/manage models, set language preference
- **Output** — Toggle punctuation stripping
- **Dictionary** — Add custom words and phrases to improve transcription accuracy
- **Appearance** — Indicator visibility and position

## Data Storage

- **Transcription history**: `~/Library/Application Support/TalkFlow/transcriptions.sqlite`
- **Local models**: `~/Library/Containers/com.josephcampuzano.TalkFlow/Data/Documents/huggingface/`
- **Logs**: `~/Library/Logs/TalkFlow/talkflow.log`
- **API key**: macOS Keychain (never stored in plain text)

## Development

```bash
# Debug build
swift build

# Run tests
swift test

# Build app bundle
./Scripts/build-app.sh

# Build and launch
./Scripts/build-app.sh --run
```

## Tech Stack

- **Swift 6** with modern concurrency (async/await, actors)
- **SwiftUI** for all UI components
- **AVFoundation** for audio capture
- **Accelerate/vDSP** for signal processing
- **WhisperKit** for on-device Whisper transcription via Core ML
- **GRDB.swift** for SQLite storage with full-text search

## License

MIT

---

<p align="center">
  <img src="assets/talkflow-app-icon.png" alt="TalkFlow" width="64">
</p>
