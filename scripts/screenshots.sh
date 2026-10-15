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
# shellcheck source=scripts/lib.sh
source "$ROOT/scripts/lib.sh"

ASSETS="$ROOT/assets"

mkdir -p "$ASSETS"
rm -f "$ASSETS"/*.png

echo "▸ Rendering icon and screens…"
swift_build >/dev/null
BIN="$(swift_bin_path)"
"$BIN/burnfuse-shots" icon "$ASSETS" >/dev/null
"$BIN/burnfuse-shots" screens "$ASSETS"

echo "▸ Cleaning up intermediates…"
rm -rf "$ASSETS/burnfuse.iconset"
# Keep a single source icon for the README; the rest are build inputs.
for size in 16 32 64 128 256; do rm -f "$ASSETS/icon_$size.png"; done
# Dev-only contact sheet, not part of the shipped docs.
rm -f "$ASSETS/_gallery.png"

# Fail loudly rather than quietly shipping a README with missing images.
expected=(
  window-overview-dark window-overview-light window-breach-dark
  window-insights-dark window-settings-dark window-settings-light
  window-switchoff-dark
  menubar-dark menubar-light menubar-climbing-dark menubar-breached-dark
  mini-panel-dark mini-panel-breach-dark
  social-card icon_512 icon_1024
)
missing=0
for name in "${expected[@]}"; do
  if [ ! -s "$ASSETS/$name.png" ]; then
    echo "  ✗ missing or empty: assets/$name.png"
    missing=1
  fi
done
[ "$missing" -eq 0 ] || { echo "  screenshots did not render as expected"; exit 1; }

echo "  ✓ Wrote ${#expected[@]} images to assets/"