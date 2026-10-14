#!/usr/bin/env bash
#
# Regenerates the README's images from the real app.
#
#   ./scripts/screenshots.sh
#
# Screens are captured by rendering the live SwiftUI view hierarchy, so these
# are the shipping views — not mockups. The icon is rendered from the same
# shape the app ships with. Writes to assets/.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSETS="$ROOT/assets"

mkdir -p "$ASSETS"
rm -f "$ASSETS"/*.png

echo "▸ Rendering icon and screens…"
swift build --package-path "$ROOT/macos" >/dev/null
BIN="$(swift build --package-path "$ROOT/macos" --show-bin-path)"
"$BIN/burnfuse-shots" icon "$ASSETS" >/dev/null
"$BIN/burnfuse-shots" screens "$ASSETS"

echo "▸ Cleaning up intermediates…"
rm -rf "$ASSETS/burnfuse.iconset"
# Keep a single source icon for the README; the rest are build inputs.
for size in 16 32 64 128 256; do rm -f "$ASSETS/icon_$size.png"; done
# Dev-only contact sheet, not part of the shipped docs.
rm -f "$ASSETS/_gallery.png"

echo "  ✓ Wrote $(ls "$ASSETS"/*.png | wc -l | tr -d ' ') images to assets/"