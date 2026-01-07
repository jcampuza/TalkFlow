# TalkFlow - Voice Dictation for macOS

## Overview

A native macOS menu bar application that enables voice-to-text dictation triggered by a configurable keyboard shortcut. Press and hold the trigger key to record, release to process. The app captures audio, removes silence client-side, sends it to an AI transcription service, and pastes the result into the currently focused input field.

## Core Requirements

### Target Platform
- **macOS 14 (Sonoma)** minimum
- Native Swift/SwiftUI application
- Menu bar app with Dock icon and standard app menu

### Trigger Mechanism
- **Default shortcut**: Right Command key (held)
- **Configurable**: User can remap to any modifier key, single key, or modifier+key combo
- **Activation**: Minimum hold threshold of ~300ms before recording begins (filters accidental taps)
- **Cancellation**: If another key is pressed while holding the trigger, recording cancels
- **Blocking**: New recordings blocked until current transcription completes and pastes

### Audio Capture
- Capture from system's current audio input device
- Real-time audio level monitoring for UI feedback
- **Max duration**: 2 minute hard limit
- **Warning**: Visual indicator at 1 minute mark
- **Device disconnect**: Cancel recording and notify user (do not auto-switch devices)

### Audio Processing (Client-Side)
- **Voice Activity Detection (VAD)**: Conservative - prioritize not cutting words over removing all silence
- **Silence detection**: Energy-based, configurable threshold (default -40dB)
- **Noise gate**: Basic noise gate to reduce constant low-level background noise
- **Padding**: Keep generous padding around detected speech segments
- **Output**: Compressed audio (Opus/AAC) for efficient transmission
- **Empty result**: If no speech detected after processing, show "No speech detected" message, don't call API

### Transcription
- **V1**: Remote API only (OpenAI Whisper API)
- **Model**: User-configurable (whisper-1 default, option for others when available)
- **Language**: Configurable with auto-detect option
- **Failure handling**: Silent retry up to 3 times, then show error in indicator
- **Future (V2+)**: Local whisper.cpp/MLX support

### Text Output
- **Primary**: Paste to currently focused input field via macOS Accessibility APIs
- **Fallback**: Clipboard + Cmd+V simulation
- **Clipboard preservation**: Save clipboard contents before paste, restore after
- **Invalid target**: Attempt paste anyway regardless of whether target appears editable (text is saved to history either way)
- **Format**: Single continuous block, exactly as Whisper returns
- **Punctuation mode**: Configurable toggle to strip punctuation (keeps capitalization)

### History Storage
- **Database**: SQLite via GRDB.swift
- **Retention**: Forever (manual deletion only)
- **No size limit**: Let database grow indefinitely
- **Audio files**: Never saved (text only for privacy/storage)
- **Schema**:
  ```sql
  transcriptions (
    id TEXT PRIMARY KEY,
    text TEXT NOT NULL,
    timestamp DATETIME NOT NULL,
    duration_ms INTEGER,
    confidence REAL,  -- stored but not displayed
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )
  ```
- **Search**: Full-text search on transcription text only

## User Interface

### Menu Bar
- **Icon**: Speech bubble glyph
- **Click action**: Opens dropdown menu
- **Menu items**:
  - Recent transcriptions (last 3-5 inline)
  - "View All History..."
  - Separator
  - "Settings..."
  - Separator
  - "Quit TalkFlow"

### Floating Status Indicator
- **Shape**: Circular badge
- **Size**: Medium (48-64px diameter)
- **Position**: Default bottom-right corner, user-draggable, position persisted
- **Multi-monitor**: Appears on display where cursor is located
- **Idle visibility**: Configurable (hidden when idle OR always visible subtle)

#### Indicator States
| State | Appearance | Animation | Duration |
|-------|------------|-----------|----------|
| Idle (if visible) | Gray/subtle | None | Persistent |
| Recording | Red/orange | Pulsing/breathing | While held |
| Processing | Blue/purple | Indeterminate progress | Until complete |
| Success | Green | None | 2-3 seconds |
| Error | Red | None | 2-3 seconds |
| No Speech | Yellow/orange | None | 2-3 seconds |
| 1min Warning | Recording + warning badge | Pulse faster | Until release |

### History Window
- **Access**: Menu bar > "View All History..."
- **Display**: List view with text preview + relative timestamp
- **Click action**: Copy to clipboard, show "Copied!" toast
- **Deletion**: Delete button per entry, with confirmation dialog
- **Search**: Text search field at top

### Settings Window
- **Style**: Standalone macOS preferences window
- **Sections**:
  - **General**: Trigger shortcut configuration
  - **Audio**: Input device selection, silence threshold
  - **Transcription**: API key, model selection, language
  - **Output**: Punctuation stripping toggle
  - **Appearance**: Indicator visibility, position reset

### Onboarding
- **Flow**: Permission prompts only (no tutorial screens)
- **Required permissions**:
  - Accessibility (for global shortcuts + text insertion)
  - Microphone (for audio capture)
- **API key**: User enters in Settings after launch

## Architecture

### Technology Stack

| Component | Technology | Rationale |
|-----------|------------|-----------|
| Language | Swift 5.9+ | Native macOS, best API access |
| UI Framework | SwiftUI | Modern, declarative, menu bar support |
| Audio Capture | AVFoundation | High-level, reliable audio APIs |
| Audio Processing | Accelerate/vDSP | Hardware-accelerated signal processing |
| Global Shortcuts | CGEvent tap | Low-level key event capture |
| Text Insertion | Accessibility API (AXUIElement) | Reliable cross-app text insertion |
| Local Storage | SQLite via GRDB.swift | Lightweight, performant, full-text search |
| Networking | URLSession | Native async/await support |
| Keychain | Security.framework | Secure API key storage |

### Project Structure

```
TalkFlow/
├── TalkFlow.xcodeproj
├── TalkFlow/
│   ├── App/
│   │   ├── TalkFlowApp.swift              # App entry point
│   │   ├── AppDelegate.swift              # Menu bar setup, permissions
│   │   └── DependencyContainer.swift      # Service initialization
│   │
│   ├── Features/
│   │   ├── Shortcut/
│   │   │   ├── ShortcutManager.swift      # Global key event monitoring
│   │   │   ├── KeyEventMonitor.swift      # CGEvent tap wrapper
│   │   │   └── ShortcutConfiguration.swift
│   │   │
│   │   ├── Audio/
│   │   │   ├── AudioCaptureService.swift  # AVAudioEngine wrapper
│   │   │   ├── AudioProcessor.swift       # VAD, silence removal, encoding
│   │   │   ├── VoiceActivityDetector.swift
│   │   │   └── NoiseGate.swift
│   │   │
│   │   ├── Transcription/
│   │   │   ├── TranscriptionService.swift # Protocol
│   │   │   ├── OpenAIWhisperService.swift # API implementation
│   │   │   └── TranscriptionResult.swift
│   │   │
│   │   ├── Output/
│   │   │   ├── TextOutputManager.swift    # Accessibility paste
│   │   │   └── ClipboardManager.swift     # Preserve/restore clipboard
│   │   │
│   │   └── History/
│   │       ├── HistoryStorage.swift       # GRDB operations
│   │       ├── TranscriptionRecord.swift  # Model
│   │       └── HistorySearcher.swift
│   │
│   ├── UI/
│   │   ├── MenuBar/
│   │   │   ├── MenuBarController.swift
│   │   │   └── MenuBarMenu.swift
│   │   │
│   │   ├── Indicator/
│   │   │   ├── StatusIndicatorWindow.swift
│   │   │   ├── StatusIndicatorView.swift
│   │   │   └── IndicatorState.swift
│   │   │
│   │   ├── History/
│   │   │   ├── HistoryWindow.swift
│   │   │   ├── HistoryListView.swift
│   │   │   └── HistoryRowView.swift
│   │   │
│   │   └── Settings/
│   │       ├── SettingsWindow.swift
│   │       ├── GeneralSettingsView.swift
│   │       ├── AudioSettingsView.swift
│   │       ├── TranscriptionSettingsView.swift
│   │       └── AppearanceSettingsView.swift
│   │
│   ├── Services/
│   │   ├── KeychainService.swift          # API key storage
│   │   ├── UpdateChecker.swift            # GitHub API version check
│   │   └── Logger.swift                   # File logging
│   │
│   ├── Shared/
│   │   ├── Configuration.swift
│   │   ├── Constants.swift
│   │   └── Extensions/
│   │
│   └── Resources/
│       ├── Assets.xcassets
│       ├── Localizable.strings
│       └── Info.plist
│
├── TalkFlowTests/
│   ├── AudioProcessorTests.swift
│   ├── VoiceActivityDetectorTests.swift
│   ├── HistoryStorageTests.swift
│   ├── TranscriptionServiceTests.swift
│   ├── Fixtures/
│   │   ├── speech_with_silence.wav
│   │   ├── silence_only.wav
│   │   └── continuous_speech.wav
│   └── Mocks/
│       ├── MockAudioCaptureService.swift
│       └── MockTranscriptionService.swift
│
└── README.md
```

### Component Diagram

```
┌────────────────────────────────────────────────────────────────────┐
│                         TalkFlow App                                │
├────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────┐                                               │
│  │  ShortcutManager │──── Key Down (after 300ms) ────┐             │
│  │  (CGEvent tap)   │                                 │             │
│  │                  │──── Key Up ────────────────────┐│             │
│  │                  │──── Cancel (combo detected) ──┐││             │
│  └─────────────────┘                                │││             │
│           │                                         │││             │
│           ▼                                         ▼▼▼             │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐ │
│  │ StatusIndicator │◀───│  AudioCapture   │───▶│ AudioProcessor  │ │
│  │    (SwiftUI)    │    │  (AVAudioEngine)│    │ (VAD + Encode)  │ │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘ │
│           │                                          │              │
│           │                                          ▼              │
│           │         ┌─────────────────┐    ┌─────────────────┐     │
│           │         │ HistoryStorage  │◀───│  Transcription  │     │
│           │         │    (GRDB)       │    │    Service      │     │
│           │         └─────────────────┘    └─────────────────┘     │
│           │                │                       │                │
│           ▼                ▼                       ▼                │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐       │
│  │   Menu Bar UI   │ │  History Window │ │ TextOutputManager│       │
│  │   (SwiftUI)     │ │   (SwiftUI)     │ │ (Accessibility)  │       │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘       │
│                                                   │                 │
│                                                   ▼                 │
│                                          ┌─────────────────┐       │
│                                          │ClipboardManager │       │
│                                          │(Save/Restore)   │       │
│                                          └─────────────────┘       │
└────────────────────────────────────────────────────────────────────┘
```

### Data Flow

```
1. User presses Right Cmd (or configured trigger)
   └─▶ ShortcutManager detects key down
       └─▶ Start 300ms timer

2. Timer completes (key still held)
   └─▶ AudioCaptureService.startRecording()
       └─▶ StatusIndicator shows "Recording" (pulsing red)
       └─▶ Audio buffers accumulate in memory

3. 1 minute elapsed (key still held)
   └─▶ StatusIndicator shows warning badge

4. User releases trigger key (or 2min limit reached)
   └─▶ ShortcutManager detects key up
       └─▶ AudioCaptureService.stopRecording() → raw PCM
           └─▶ StatusIndicator shows "Processing" (indeterminate)

5. Audio processing (on background queue)
   └─▶ AudioProcessor.process(rawAudio)
       ├─▶ VoiceActivityDetector identifies speech segments
       ├─▶ NoiseGate reduces background noise
       ├─▶ Trim silence, concatenate speech
       └─▶ Encode to Opus → compressed audio

   └─▶ If no speech detected:
       └─▶ StatusIndicator shows "No Speech" (2-3s) → hide
       └─▶ END

6. Transcription
   └─▶ OpenAIWhisperService.transcribe(processedAudio)
       └─▶ POST to api.openai.com/v1/audio/transcriptions
           ├─▶ On failure: Retry up to 3x silently
           └─▶ After 3 failures: StatusIndicator shows error
       └─▶ Returns TranscriptionResult { text, confidence }

7. Output
   ├─▶ ClipboardManager.save() → preserve current clipboard
   ├─▶ TextOutputManager.insert(text)
   │   ├─▶ Try AXUIElement.setValue() on focused element
   │   └─▶ Fallback: NSPasteboard + CGEvent Cmd+V
   ├─▶ ClipboardManager.restore() → restore original clipboard
   ├─▶ HistoryStorage.save(TranscriptionRecord)
   └─▶ StatusIndicator shows "Success" (green, 2-3s) → hide
```

## Configuration

```swift
struct AppConfiguration: Codable {
    // Shortcut
    var triggerShortcut: ShortcutConfig = .rightCommand
    var minimumHoldDurationMs: Int = 300

    // Audio
    var inputDeviceUID: String? = nil  // nil = system default
    var silenceThresholdDb: Float = -40.0
    var noiseGateThresholdDb: Float = -50.0

    // Recording limits
    var maxRecordingDurationSeconds: Int = 120  // 2 minutes
    var warningDurationSeconds: Int = 60        // 1 minute

    // Transcription
    var whisperModel: String = "whisper-1"
    var language: String? = nil  // nil = auto-detect

    // Output
    var stripPunctuation: Bool = false

    // Indicator
    var indicatorVisibleWhenIdle: Bool = false
    var indicatorPosition: CGPoint? = nil  // nil = default bottom-right
}

struct ShortcutConfig: Codable {
    var keyCode: UInt16
    var modifiers: CGEventFlags

    static let rightCommand = ShortcutConfig(
        keyCode: 0x36,  // kVK_RightCommand
        modifiers: []
    )
}
```

## Permissions & Entitlements

### Required Entitlements (Info.plist)
```xml
<key>NSMicrophoneUsageDescription</key>
<string>TalkFlow needs microphone access to capture your voice for transcription.</string>

<key>NSAccessibilityUsageDescription</key>
<string>TalkFlow needs accessibility access to detect the trigger shortcut and paste transcriptions.</string>
```

### App Sandbox
```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.device.audio-input</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
```

## Testing Strategy

### Unit Tests
- **VoiceActivityDetector**: Test with synthetic waveforms (silence, speech, mixed)
- **AudioProcessor**: Test segment trimming, silence detection thresholds
- **HistoryStorage**: CRUD operations, full-text search, edge cases
- **TranscriptionService**: Mock API responses, retry logic, error handling
- **ClipboardManager**: Save/restore verification

### Integration Tests
- Audio capture → processing → encoding pipeline
- Full flow with mock transcription service
- History persistence across simulated app restarts

### Test Fixtures
- `speech_with_silence.wav`: 15s file with 5s speech, 5s silence, 5s speech
- `silence_only.wav`: 10s of ambient room noise
- `continuous_speech.wav`: 30s of continuous talking
- `short_burst.wav`: 0.5s utterance

### Manual Testing Checklist
- [ ] Shortcut triggers in: Finder, Safari, VS Code, Terminal, Slack
- [ ] Shortcut cancels when Cmd+C pressed during hold
- [ ] Accidental tap (<300ms) does not trigger recording
- [ ] Recording stops at 2 minute limit
- [ ] Warning appears at 1 minute
- [ ] Indicator appears on correct monitor (where cursor is)
- [ ] Indicator position persists after drag
- [ ] Clipboard contents preserved after paste
- [ ] History entries appear and are searchable
- [ ] Delete confirmation works
- [ ] Settings persist across app restart
- [ ] API key stored securely in Keychain
- [ ] Errors display in indicator (not modal dialogs)
- [ ] "No speech detected" shown for silence-only input

## Logging

- **Location**: `~/Library/Logs/TalkFlow/talkflow.log`
- **Rotation**: New file per day, keep last 7 days
- **Level**: Info in release, Debug in debug builds
- **Format**: `[YYYY-MM-DD HH:mm:ss.SSS] [LEVEL] [Component] Message`

## Update Checking

- **Mechanism**: Check GitHub API on app launch
- **Endpoint**: `https://api.github.com/repos/{owner}/TalkFlow/releases/latest`
- **Frequency**: Once per launch, with 24-hour cache
- **UI**: If newer version available, show badge on menu bar icon and menu item

## Security Considerations

- API keys stored in macOS Keychain, never in plain text or UserDefaults
- Audio never persisted to disk (processed in memory only)
- No audio sent to remote servers without explicit user configuration
- All network requests use HTTPS
- No telemetry or analytics

## Future Enhancements (Post-V1)

### Phase 2: Local Transcription
- whisper.cpp or MLX Whisper integration
- Model download/management UI
- Offline-first mode option

### Phase 3: Custom Terms
- User-defined replacement dictionary
- UI for managing term mappings
- Phonetic matching for technical terms

### Phase 4: Context Awareness
- Detect focused application
- App-specific formatting rules
- Smart capitalization based on context

### Phase 5: Advanced Features
- Multi-language support
- Punctuation inference improvements
- Voice commands ("new paragraph", "delete that")

## Build & Run

```bash
# Open in Xcode
cd voice-dictation-ai-macos
open TalkFlow.xcodeproj

# Build
xcodebuild -scheme TalkFlow -configuration Debug build

# Run tests
xcodebuild -scheme TalkFlow -configuration Debug test

# Archive for distribution
xcodebuild -scheme TalkFlow -configuration Release archive
```

## Bundle Identifier

`com.josephcampuzano.TalkFlow`
