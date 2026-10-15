#!/usr/bin/env bash
#
# Installs BurnFuse into /Applications and opens it — so it becomes a real,
# clickable macOS app instead of something you launch from a terminal.
#
#   ./scripts/install.sh
#
# After this, launch BurnFuse from Launchpad, Spotlight or the Dock. Re-run it
# after a rebuild to update the installed copy.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib.sh
source "$ROOT/scripts/lib.sh"

APP="$MACOS_DIR/build/BurnFuse.app"
DEST="/Applications/BurnFuse.app"

"$ROOT/scripts/build-app.sh" release >/dev/null

echo "▸ Installing to /Applications..."
# Quit a running copy so the bundle isn't replaced underneath it.
osascript -e 'quit app "BurnFuse"' >/dev/null 2>&1 || true
pkill -f "BurnFuse.app/Contents/MacOS/BurnFuse" >/dev/null 2>&1 || true
sleep 1

rm -rf "$DEST"
cp -R "$APP" "$DEST"
# Clear the quarantine bit so it opens without a Gatekeeper prompt.
xattr -dr com.apple.quarantine "$DEST" >/dev/null 2>&1 || true

echo "▸ Launching..."
open "$DEST"

echo ""
echo "  ✓ Installed /Applications/BurnFuse.app"
echo ""
echo "    Launch it any time from Launchpad, Spotlight (⌘-Space, \"BurnFuse\") or the Dock."
echo ""