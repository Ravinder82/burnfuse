#!/usr/bin/env bash
#
# One command to check the whole project before pushing.
#
#   ./scripts/verify.sh
#
# Runs the CLI tests, the Swift tests, a build of the app bundle, and a quick
# end-to-end smoke test of the burn-rate engine.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib.sh
source "$ROOT/scripts/lib.sh"
pass=0

step() { printf "\n▸ %s\n" "$1"; }
ok()   { printf "  ✓ %s\n" "$1"; pass=$((pass + 1)); }
die()  { printf "  ✗ %s\n" "$1"; exit 1; }

# --- CLI ---------------------------------------------------------------------

step "CLI tests"
(cd "$ROOT/cli" && node --test >/dev/null 2>&1) || die "cli tests failed"
ok "cli tests pass"

step "CLI smoke test"
TMP_STATE="$(mktemp -d)/state.json"
export BURNFUSE_STATE="$TMP_STATE"
node "$ROOT/cli/bin/burnfuse.js" demo >/dev/null
node "$ROOT/cli/bin/burnfuse.js" status >/dev/null || die "status failed"
ok "status runs"

# A normal reading must not trip.
node "$ROOT/cli/bin/burnfuse.js" record openai_prod 1.30 >/dev/null
if [ "$(node "$ROOT/cli/bin/burnfuse.js" export | grep -c '"status": "tripped"')" -ne 0 ]; then
  die "a normal reading tripped the breaker"
fi
ok "normal reading stays armed"

# A spike must trip, and the exit code must signal it.
set +e
node "$ROOT/cli/bin/burnfuse.js" record openai_prod 40 >/dev/null
code=$?
set -e
[ "$code" -eq 2 ] || die "expected exit code 2 on breach, got $code"
node "$ROOT/cli/bin/burnfuse.js" export | grep -q '"status": "tripped"' || die "spike did not trip"
ok "spike trips and exits 2"

node "$ROOT/cli/bin/burnfuse.js" arm all >/dev/null
ok "re-arm works"

# --- macOS -------------------------------------------------------------------

step "Swift tests"
swift_test >/dev/null 2>&1 || die "swift tests failed"
ok "swift tests pass"

step "App bundle"
"$ROOT/scripts/build-app.sh" release >/dev/null 2>&1 || die "app build failed"
APP="$ROOT/macos/build/BurnFuse.app"
[ -d "$APP" ] || die "no app bundle produced"
[ -f "$APP/Contents/MacOS/BurnFuse" ] || die "no executable in bundle"
[ -f "$APP/Contents/Resources/AppIcon.icns" ] || die "no icon in bundle"
ok "BurnFuse.app built with icon"

step "Launch check"
"$APP/Contents/MacOS/BurnFuse" &
PID=$!
sleep 2
if kill -0 "$PID" 2>/dev/null; then
  kill "$PID" 2>/dev/null || true
  wait "$PID" 2>/dev/null || true
  ok "app launches and stays running"
else
  die "app exited immediately"
fi

# BurnFuse is a real app now: it must own a Dock icon and open a window, not
# skulk in the menu bar as a background agent.
if /usr/libexec/PlistBuddy -c "Print :LSUIElement" "$APP/Contents/Info.plist" >/dev/null 2>&1; then
  die "LSUIElement is set — the app would have no Dock icon"
fi
ok "regular app (Dock icon, no LSUIElement)"

printf "\n  all %d checks passed\n\n" "$pass"