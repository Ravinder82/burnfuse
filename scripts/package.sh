#!/usr/bin/env bash
#
# Builds a double-clickable disk image: BurnFuse.dmg
#
#   ./scripts/package.sh
#
# Open the .dmg, drag BurnFuse onto Applications, and it's installed — Dock icon,
# menu-bar item and all. No terminal needed after this point.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib.sh
source "$ROOT/scripts/lib.sh"

APP="$MACOS_DIR/build/BurnFuse.app"
OUT_DIR="$MACOS_DIR/build"
DMG="$OUT_DIR/BurnFuse.dmg"

"$ROOT/scripts/build-app.sh" release

echo "▸ Staging disk image..."
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/BurnFuse.app"
ln -s /Applications "$STAGE/Applications"

echo "▸ Building $DMG..."
rm -f "$DMG"
hdiutil create \
    -volname "BurnFuse" \
    -srcfolder "$STAGE" \
    -ov -format UDZO \
    "$DMG" >/dev/null

rm -rf "$STAGE"

echo ""
echo "  ✓ Built $DMG"
echo ""
echo "    Install:  open \"$DMG\"  then drag BurnFuse into Applications"
echo ""