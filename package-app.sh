#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$ROOT_DIR/.build/debug"
APP_DIR="$ROOT_DIR/dist/OpenChord.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
EXECUTABLE="$BUILD_DIR/OpenChord"
BUNDLE_IDENTIFIER="${OPENCHORD_BUNDLE_IDENTIFIER:-com.openchord.app}"
SIGNING_IDENTITY="${OPENCHORD_SIGNING_IDENTITY:--}"

swift build --package-path "$ROOT_DIR"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$EXECUTABLE" "$MACOS_DIR/OpenChord"
cp "$ROOT_DIR/Resources/OpenChord.icns" "$RESOURCES_DIR/OpenChord.icns"
chmod +x "$MACOS_DIR/OpenChord"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>OpenChord</string>
    <key>CFBundleIdentifier</key>
    <string>com.openchord.app</string>
    <key>CFBundleName</key>
    <string>OpenChord</string>
    <key>CFBundleDisplayName</key>
    <string>OpenChord</string>
    <key>CFBundleIconFile</key>
    <string>OpenChord.icns</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSAppleMusicUsageDescription</key>
    <string>OpenChord uses Apple Music access to search your catalog and control playback.</string>
</dict>
</plist>
PLIST

plutil -replace CFBundleIdentifier -string "$BUNDLE_IDENTIFIER" "$CONTENTS_DIR/Info.plist"
codesign --force --deep --sign "$SIGNING_IDENTITY" "$APP_DIR" >/dev/null

echo "Packaged $APP_DIR"
