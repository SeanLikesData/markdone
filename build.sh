#!/bin/bash
# Build Markdone and assemble a proper .app bundle.
#
# This compiles the Swift sources directly with `swiftc` rather than using
# Swift Package Manager. On a machine with only the Xcode Command Line Tools
# (no full Xcode), SwiftPM's manifest step fails to link, so `swift build`
# does not work. Compiling with swiftc sidesteps that entirely.
#
# A menu bar app needs an Info.plist with LSUIElement = true so it runs as a
# background accessory (no Dock icon), which this script writes.
#
# Pass --install to also replace /Applications/Markdone.app and relaunch it.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Markdone"
BUNDLE_ID="com.markdone.app"
VERSION="1.0"
BUILD_VERSION="1"

INSTALL=0
if [[ "${1:-}" == "--install" ]]; then
    INSTALL=1
fi

SDK_PATH="$(xcrun --show-sdk-path)"
ARCH="$(uname -m)"
if [[ "$ARCH" != "arm64" && "$ARCH" != "x86_64" ]]; then
    echo "Unsupported architecture: $ARCH" >&2
    exit 1
fi
TARGET="$ARCH-apple-macosx14.0"

APP_DIR="build/$APP_NAME.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"

echo "==> Preparing $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$APP_DIR/Contents/Resources"

SOURCES=$(find Sources/Markdone -name '*.swift')

echo "==> Compiling with swiftc"
# shellcheck disable=SC2086
swiftc \
    -parse-as-library \
    -target "$TARGET" \
    -sdk "$SDK_PATH" \
    -framework SwiftUI \
    -framework AppKit \
    -framework ServiceManagement \
    $SOURCES \
    -o "$MACOS_DIR/$APP_NAME"

if [[ -f Resources/AppIcon.icns ]]; then
    echo "==> Copying resources"
    cp Resources/AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

echo "==> Writing Info.plist"
cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

echo "==> Ad-hoc code signing"
codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true

echo "==> Done: $APP_DIR"

if [[ "$INSTALL" == "1" ]]; then
    echo "==> Installing to /Applications"
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
    sleep 0.3
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP_DIR" "/Applications/$APP_NAME.app"
    open "/Applications/$APP_NAME.app"
    echo "    Installed and launched /Applications/$APP_NAME.app"
else
    echo "    Run it with: open \"$APP_DIR\""
fi
