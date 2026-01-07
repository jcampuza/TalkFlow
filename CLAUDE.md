# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run Commands

```bash
# Build with Swift Package Manager
swift build                    # Debug build
swift build -c release         # Release build

# Run tests
swift test

# Create macOS app bundle (includes signing and entitlements)
./Scripts/build-app.sh                 # Debug build
./Scripts/build-app.sh release         # Release build
./Scripts/build-app.sh --run           # Build and launch
./Scripts/build-app.sh --test          # Run tests before building
./Scripts/build-app.sh release --run   # Release build and launch

# Run the app
open .build/debug/TalkFlow.app
```

The build script automatically kills running instances before rebuilding and can auto-launch the app with `--run`.

## Architecture Overview

TalkFlow is a native macOS menu bar app (Swift 6/SwiftUI, macOS 15+) for voice-to-text dictation using OpenAI's Whisper API. Press and hold a trigger key to record, release to transcribe and paste.

### Core Data Flow

1. **ShortcutManager** (CGEvent tap) detects key hold > 300ms
2. **AudioCaptureService** (AVAudioEngine) captures audio
3. **AudioProcessor** applies VAD, silence removal, encoding
4. **OpenAIWhisperService** transcribes via API
5. **TextOutputManager** (Accessibility API) pastes to focused app
6. **HistoryStorage** (GRDB/SQLite) saves transcription

### Key Directories

- `TalkFlow/App/` - Entry point, AppDelegate, DependencyContainer
- `TalkFlow/Features/` - Core modules: Audio, Shortcut, Transcription, Output, History, Dictionary
- `TalkFlow/UI/` - SwiftUI views: MenuBar, Indicator, Settings, History, Dictionary, Onboarding
- `TalkFlow/Services/` - KeychainService, Logger, UpdateChecker
- `TalkFlow/Shared/` - Configuration, EnvironmentKeys
- `TalkFlowTests/` - Unit tests with mocks
- `Scripts/` - Build scripts

### Dependency Injection

All services are lazily initialized in `DependencyContainer.swift` and injected via SwiftUI `@Environment` with custom keys defined in `EnvironmentKeys.swift`.

### Modern Swift/SwiftUI Patterns

This codebase uses modern Swift 6 patterns:

- **@Observable** macro for observable classes (replaces ObservableObject)
- **@Environment** with custom keys for DI (replaces @EnvironmentObject)
- **@Bindable** for bindings to @Observable objects in views
- **@MainActor** isolation for UI-bound properties (not entire classes)
- **withObservationTracking** for imperative observation outside SwiftUI
- **async/await** for all storage and network operations
- **Sendable** conformance on all value types for thread safety

### Important Patterns

- **@Observable** for reactive state (ConfigurationManager, HistoryStorage, IndicatorStateManager)
- **Protocol-based services** for testability (TranscriptionService, HistoryStorageProtocol)
- **async/await** for transcription, network, and storage operations
- **withObservationTracking** for configuration change propagation in non-SwiftUI code

## Key Files

- `SPEC.md` - Complete requirements and architecture specification
- `Package.swift` - SPM manifest (single dependency: GRDB.swift)
- `Scripts/build-app.sh` - Creates proper .app bundle with entitlements
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

## Crash Logs

macOS crash reports are stored in `~/Library/Logs/DiagnosticReports/`. Look for files named `TalkFlow-*.ips`.

```bash
# Find recent TalkFlow crashes
ls -la ~/Library/Logs/DiagnosticReports/ | grep -i talkflow

# Read most recent crash
cat ~/Library/Logs/DiagnosticReports/TalkFlow-*.ips | head -200
```

Key crash indicators:
- `"faultingThread"` - Which thread crashed
- `"exception"` - Exception type (EXC_BREAKPOINT = Swift runtime assertion)
- `"frames"` - Stack trace showing the crash location
- Look for `sourceFile` entries pointing to TalkFlow code

## API Key Storage

Stored in macOS Keychain via KeychainService. Service identifier: `com.josephcampuzano.TalkFlow`

## Development

- ALWAYS write tests for new code.
- ALWAYS run `swift test` when making changes to verify tests pass.
- ALWAYS run `./Scripts/build-app.sh` when making changes to verify the app compiles.
- All features should include relevant debug logging for agents to look up.

## CI Environment & Reproducing CI Failures

CI runs on GitHub Actions with **Swift 6.2** on macOS 15 (via `swift-actions/setup-swift`). This should match local development.

**To reproduce CI environment locally:**

```bash
# Check current Swift version
swift --version

# List available Xcode versions
ls /Applications | grep Xcode

# Switch to Xcode 16.4 (if installed) to match CI
sudo xcode-select -s /Applications/Xcode_16.4.app/Contents/Developer

# Verify switch worked
swift --version  # Should show Swift 6.1.2

# Now build/test - this should reproduce CI behavior
swift build
swift test

# Switch back to your default Xcode
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

**Common CI-only failures:**

1. **Sendable/concurrency errors**: Swift 6.1.x is stricter than 6.2.x. Fix with `@preconcurrency import` for third-party modules that aren't Sendable-compliant.

2. **Missing `@MainActor`**: Newer Swift may infer actor isolation that older versions require explicitly.

3. **Different SDK behavior**: macOS SDK differences between Xcode versions can cause API availability issues.

**If you don't have Xcode 16.4:**
- Download from https://developer.apple.com/download/all/ (requires Apple Developer account)
- Or update CI to use the Xcode version you have locally (update `.github/workflows/tests.yml`)

## UI/Styling Guidelines

**IMPORTANT: Never use system-adaptive colors in UI code.** The app uses a light-only theme that must look correct regardless of system dark/light mode.

- **NEVER** use: `.primary`, `.secondary`, `NSColor.controlBackgroundColor`, `NSColor.textColor`, `NSColor.labelColor`, `NSColor.separatorColor`, `NSColor.tertiaryLabelColor`, or any other system color that adapts to dark mode.
- **ALWAYS** use colors from `DesignConstants` (defined in `TalkFlow/Shared/DesignConstants.swift`):
  - Text: `DesignConstants.primaryText`, `.secondaryText`, `.tertiaryText`
  - Backgrounds: `DesignConstants.sidebarBackground`, `.contentBackground`, `.searchBarBackground`, `.hoverBackground`, etc.
  - Dividers: `DesignConstants.dividerColor`
- When adding new UI elements, add any new colors to `DesignConstants.swift` rather than using inline Color values.
- Use `Color.white` for content area backgrounds (this is an explicit value, not system-adaptive).
- The main window uses `.environment(\.colorScheme, .light)` to force light mode for all system controls (Pickers, Toggles, etc.). This ensures they display correctly regardless of system appearance.
- For NSView-based controls (like NSButton), use `attributedTitle` with explicit colors instead of `.title`.
