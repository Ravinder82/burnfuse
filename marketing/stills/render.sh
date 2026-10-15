#!/usr/bin/env bash
#
# Renders every card in cards.html to out/<name>.png (2x) via headless Chrome.
#
#   ./render.sh            # all cards
#   ./render.sh quote-key  # one card
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$HERE/out"
mkdir -p "$OUT"

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
if [ ! -x "$CHROME" ]; then
  CHROME="$(command -v google-chrome || command -v chromium || command -v chromium-browser || true)"
fi
if [ -z "$CHROME" ]; then
  echo "error: Chrome not found" >&2
  exit 1
fi

# name width height
CARDS=(
  "launch-16x9    1600 900"
  "launch-square  1080 1080"
  "launch-portrait 1080 1350"
  "quote-key      1080 1080"
  "quote-number   1080 1080"
  "quote-local    1080 1080"
  "states-16x9    1600 900"
  "providers-16x9 1600 900"
  "trip-flow-16x9 1600 900"
  "reel-cover     1080 1920"
  "yt-thumb-a     1280 720"
  "yt-thumb-b     1280 720"
  "og-card        1200 630"
)

want="${1:-}"
for spec in "${CARDS[@]}"; do
  read -r name w h <<<"$spec"
  if [ -n "$want" ] && [ "$want" != "$name" ]; then continue; fi
  "$CHROME" --headless --disable-gpu --hide-scrollbars \
    --force-device-scale-factor=2 \
    --window-size="$w,$h" \
    --virtual-time-budget=1500 \
    --screenshot="$OUT/$name.png" \
    "file://$HERE/cards.html?card=$name" 2>/dev/null
  echo "▸ $name.png (${w}x${h} @2x)"
done

echo "▸ done — $OUT"
