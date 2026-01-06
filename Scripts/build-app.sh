#!/bin/bash
set -e

# TalkFlow Build Script
# Creates a proper macOS .app bundle from Swift Package Manager build
# Includes auto-kill of running instances and optional launch

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/.build"
APP_NAME="TalkFlow"
BUNDLE_ID="com.josephcampuzano.TalkFlow"

# Parse arguments
CONFIGURATION="debug"
RUN_AFTER_BUILD=false
RUN_TESTS=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        release)
            CONFIGURATION="release"
            shift
            ;;
        --run)
            RUN_AFTER_BUILD=true
            shift
            ;;
        --test)
            RUN_TESTS=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [release] [--run] [--test]"
            echo ""
            echo "Options:"
            echo "  release    Build in release configuration (default: debug)"
            echo "  --run      Launch the app after building"
            echo "  --test     Run tests before building"
            echo "  --help     Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Set build paths based on configuration
if [[ "$CONFIGURATION" == "release" ]]; then
    SWIFT_CONFIG="release"
    BUILD_PATH="$BUILD_DIR/release"
else
    SWIFT_CONFIG="debug"
    BUILD_PATH="$BUILD_DIR/debug"
fi

APP_BUNDLE="$BUILD_PATH/$APP_NAME.app"

# Function to kill all running TalkFlow instances
kill_all_talkflow() {
    echo "Checking for running TalkFlow instances..."

    # Find and kill by process name
    local pids=$(pgrep -f "$APP_NAME" 2>/dev/null || true)

    if [[ -n "$pids" ]]; then
        echo "Stopping running TalkFlow instances..."

        # First try graceful termination
        for pid in $pids; do
            kill -TERM "$pid" 2>/dev/null || true
        done

        # Wait for graceful shutdown (up to 5 seconds)
        local wait_count=0
        while [[ $wait_count -lt 25 ]]; do
            pids=$(pgrep -f "$APP_NAME" 2>/dev/null || true)
            if [[ -z "$pids" ]]; then
                break
            fi
            sleep 0.2
            ((wait_count++))
        done

        # Force kill if still running
        pids=$(pgrep -f "$APP_NAME" 2>/dev/null || true)
        if [[ -n "$pids" ]]; then
            echo "Force killing remaining instances..."
            for pid in $pids; do
                kill -KILL "$pid" 2>/dev/null || true
            done
            sleep 0.5
        fi

        # Verify all instances are gone
        pids=$(pgrep -f "$APP_NAME" 2>/dev/null || true)
        if [[ -n "$pids" ]]; then
            echo "Warning: Some TalkFlow instances may still be running"
        else
            echo "All TalkFlow instances stopped"
        fi
    else
        echo "No running TalkFlow instances found"
    fi
}

# Function to verify app is running
verify_app_running() {
    local max_attempts=10
    local attempt=0

    echo "Verifying app is running..."

    while [[ $attempt -lt $max_attempts ]]; do
        sleep 0.4
        if pgrep -f "$APP_NAME" >/dev/null 2>&1; then
            echo "TalkFlow is running successfully"
            return 0
        fi
        ((attempt++))
    done

    echo "Warning: Could not verify TalkFlow is running"
    return 1
}

# Kill running instances before build
kill_all_talkflow

# Run tests if requested
if [[ "$RUN_TESTS" == true ]]; then
    echo ""
    echo "Running tests..."
    cd "$PROJECT_ROOT"
    swift test
    echo "Tests passed!"
    echo ""
fi

echo "Building TalkFlow ($CONFIGURATION)..."

# Build with Swift Package Manager
cd "$PROJECT_ROOT"
swift build -c "$SWIFT_CONFIG"

# Create app bundle structure
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "Creating app bundle at $APP_BUNDLE..."

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
cp "$BUILD_PATH/$APP_NAME" "$MACOS_DIR/$APP_NAME"

# Copy and process Info.plist (replace variables)
INFO_PLIST_SRC="$PROJECT_ROOT/TalkFlow/Resources/Info.plist"
INFO_PLIST_DST="$CONTENTS_DIR/Info.plist"

# Replace $(EXECUTABLE_NAME) with actual executable name
sed 's/\$(EXECUTABLE_NAME)/TalkFlow/g' "$INFO_PLIST_SRC" > "$INFO_PLIST_DST"

# Compile and copy asset catalog
ASSETS_SRC="$PROJECT_ROOT/TalkFlow/Resources/Assets.xcassets"
if [[ -d "$ASSETS_SRC" ]]; then
    echo "Compiling asset catalog..."
    xcrun actool "$ASSETS_SRC" \
        --compile "$RESOURCES_DIR" \
        --platform macosx \
        --minimum-deployment-target 14.0 \
        --app-icon AppIcon \
        --output-partial-info-plist "$BUILD_PATH/AssetCatalog-Info.plist" \
        2>/dev/null || echo "Warning: Asset catalog compilation skipped (may not have icons)"
fi

# Copy entitlements for reference (used during signing)
cp "$PROJECT_ROOT/TalkFlow/Resources/TalkFlow.entitlements" "$CONTENTS_DIR/"

# Create PkgInfo
echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"

# Sign the app (ad-hoc for development, allows accessibility permissions)
echo "Signing app bundle..."
codesign --force --deep --sign - \
    --entitlements "$PROJECT_ROOT/TalkFlow/Resources/TalkFlow.entitlements" \
    "$APP_BUNDLE"

echo ""
echo "Build complete!"
echo "App bundle: $APP_BUNDLE"

# Launch if requested
if [[ "$RUN_AFTER_BUILD" == true ]]; then
    echo ""
    echo "Launching TalkFlow..."
    open "$APP_BUNDLE"
    verify_app_running
else
    echo ""
    echo "To run:"
    echo "  open \"$APP_BUNDLE\""
    echo ""
    echo "Or to run from terminal with logs:"
    echo "  \"$APP_BUNDLE/Contents/MacOS/TalkFlow\""
    echo ""
    echo "Or use --run flag to auto-launch:"
    echo "  ./Scripts/build-app.sh --run"
fi
