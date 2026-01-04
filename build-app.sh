#!/bin/bash
set -e

# TalkFlow Build Script
# Creates a proper macOS .app bundle from Swift Package Manager build

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build"
APP_NAME="TalkFlow"
BUNDLE_ID="com.josephcampuzano.TalkFlow"

# Configuration
CONFIGURATION="${1:-debug}"
if [[ "$CONFIGURATION" == "release" ]]; then
    SWIFT_CONFIG="release"
    BUILD_PATH="$BUILD_DIR/release"
else
    SWIFT_CONFIG="debug"
    BUILD_PATH="$BUILD_DIR/debug"
fi

echo "Building TalkFlow ($CONFIGURATION)..."

# Build with Swift Package Manager
swift build -c "$SWIFT_CONFIG"

# Create app bundle structure
APP_BUNDLE="$BUILD_PATH/$APP_NAME.app"
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
INFO_PLIST_SRC="$SCRIPT_DIR/TalkFlow/Resources/Info.plist"
INFO_PLIST_DST="$CONTENTS_DIR/Info.plist"

# Replace $(EXECUTABLE_NAME) with actual executable name
sed 's/\$(EXECUTABLE_NAME)/TalkFlow/g' "$INFO_PLIST_SRC" > "$INFO_PLIST_DST"

# Compile and copy asset catalog
ASSETS_SRC="$SCRIPT_DIR/TalkFlow/Resources/Assets.xcassets"
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
cp "$SCRIPT_DIR/TalkFlow/Resources/TalkFlow.entitlements" "$CONTENTS_DIR/"

# Create PkgInfo
echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"

# Sign the app (ad-hoc for development, allows accessibility permissions)
echo "Signing app bundle..."
codesign --force --deep --sign - \
    --entitlements "$SCRIPT_DIR/TalkFlow/Resources/TalkFlow.entitlements" \
    "$APP_BUNDLE"

echo ""
echo "Build complete!"
echo "App bundle: $APP_BUNDLE"
echo ""
echo "To run:"
echo "  open \"$APP_BUNDLE\""
echo ""
echo "Or to run from terminal with logs:"
echo "  \"$APP_BUNDLE/Contents/MacOS/TalkFlow\""
