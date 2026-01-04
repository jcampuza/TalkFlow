# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run Commands

### Option 1: Xcode (Recommended for development)

```bash
# Open in Xcode
open TalkFlow.xcodeproj

# Then use Cmd+R to build and run
```

The Xcode project includes proper Info.plist, entitlements, and asset catalog configuration.

### Option 2: Command Line (Swift Package Manager)

```bash
# Build with Swift Package Manager
swift build                    # Debug build
swift build -c release         # Release build

# Run tests
swift test

# Create macOS app bundle (includes signing and entitlements)
./build-app.sh                 # Debug
./build-app.sh release         # Release

# Run the app
open .build/debug/TalkFlow.app
```

**Note**: SPM and Xcode builds have different code signatures. Each requires its own Accessibility permission grant in System Settings.

## Architecture Overview

TalkFlow is a native macOS menu bar app (Swift 5.9+/SwiftUI, macOS 14+) for voice-to-text dictation using OpenAI's Whisper API. Press and hold a trigger key to record, release to transcribe and paste.

### Core Data Flow

1. **ShortcutManager** (CGEvent tap) detects key hold > 300ms
2. **AudioCaptureService** (AVAudioEngine) captures audio
3. **AudioProcessor** applies VAD, silence removal, encoding
4. **OpenAIWhisperService** transcribes via API
5. **TextOutputManager** (Accessibility API) pastes to focused app
6. **HistoryStorage** (GRDB/SQLite) saves transcription

### Key Directories

- `TalkFlow/App/` - Entry point, AppDelegate, DependencyContainer
- `TalkFlow/Features/` - Core modules: Audio, Shortcut, Transcription, Output, History
- `TalkFlow/UI/` - SwiftUI views: MenuBar, Indicator, Settings, History
- `TalkFlow/Services/` - KeychainService, Logger, UpdateChecker
- `TalkFlowTests/` - Unit tests with mocks

### Dependency Injection

All services are lazily initialized in `DependencyContainer.swift` and accessed via AppDelegate. Add new services there following the existing pattern.

### Important Patterns

- **@Published** for reactive state (ConfigurationManager, AudioCaptureService, HistoryStorage)
- **Protocol-based services** for testability (TranscriptionService protocol)
- **async/await** for transcription and network operations
- **Combine** for configuration change propagation

## Key Files

- `SPEC.md` - Complete requirements and architecture specification
- `TalkFlow.xcodeproj` - Xcode project for development
- `Package.swift` - SPM manifest (single dependency: GRDB.swift)
- `build-app.sh` - Creates proper .app bundle with entitlements (for CLI builds)
- `TalkFlow/Resources/TalkFlow.entitlements` - Sandbox permissions (audio, network)
- `TalkFlow/Resources/Info.plist` - Bundle metadata and permission descriptions

## Database

SQLite via GRDB with FTS5 full-text search. Location: `~/Library/Application Support/TalkFlow/transcriptions.sqlite`

## Permissions Required

- **Accessibility**: Global shortcuts + text insertion (CGEvent tap, AXUIElement)
- **Microphone**: Audio capture (AVAudioEngine)
- **Network**: OpenAI API calls

## Logging

File-based logging to `~/Library/Logs/TalkFlow/talkflow.log` (7-day rotation). Use `Logger.shared.info()`, `.debug()`, `.error()`.

## API Key Storage

Stored in macOS Keychain via KeychainService. Service identifier: `com.josephcampuzano.TalkFlow`
