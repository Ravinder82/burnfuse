#!/usr/bin/env bash
#
# Builds BurnFuse.app — a self-contained menu-bar app bundle.
#
#   ./scripts/build-app.sh            release build into macos/build/BurnFuse.app
#   ./scripts/build-app.sh debug      faster debug build
#
# No Xcode project, no dependencies. Just Swift Package Manager plus iconutil.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MACOS_DIR="$ROOT/macos"
CONFIG="${1:-release}"
APP_NAME="BurnFuse"
VERSION="1.0.0"
BUILD_DIR="$MACOS_DIR/.build/$CONFIG"
OUT_DIR="$MACOS_DIR/build"
APP="$OUT_DIR/$APP_NAME.app"

echo "▸ Building $APP_NAME ($CONFIG)…"
swift build -c "$CONFIG" --package-path "$MACOS_DIR"

echo "▸ Rendering app icon…"
ICON_TMP="$(mktemp -d)"
BIN_SHOTS="$(swift build -c "$CONFIG" --package-path "$MACOS_DIR" --show-bin-path)/burnfuse-shots"
"$BIN_SHOTS" icon "$ICON_TMP" >/dev/null
iconutil -c icns "$ICON_TMP/$APP_NAME.iconset" -o "$ICON_TMP/AppIcon.icns"

echo "▸ Assembling bundle…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BUILD_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp "$ICON_TMP/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp "$MACOS_DIR/Resources/Info.plist" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist" >/dev/null
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist" >/dev/null

echo "▸ Signing (ad-hoc)…"
codesign --force --sign - --timestamp=none "$APP" >/dev/null 2>&1 || true

rm -rf "$ICON_TMP"

echo ""
echo "  ✓ Built $APP"
echo ""
echo "    Open it:        open \"$APP\""
echo "    Install it:     cp -R \"$APP\" /Applications/"
echo "    It lives in the menu bar (⌘, opens settings)."
echo ""