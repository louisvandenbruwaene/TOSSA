#!/usr/bin/env bash
# Shared helpers for TOSSA's scripts/*.sh. Source this, don't run it directly.
set -euo pipefail

PIXELTOSSA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$(command -v godot || echo /opt/homebrew/bin/godot)}"
GTIMEOUT_BIN="${GTIMEOUT_BIN:-$(command -v gtimeout || echo /opt/homebrew/bin/gtimeout)}"

# Every non-interactive Godot run in this project is muted and must never wait
# on stdin. Louis works with sound off and is disturbed by unexpected audio -
# --audio-driver Dummy is an ENGINE flag, so it can't leak into a real build.
AUDIO_FLAGS=(--audio-driver Dummy)

if [[ -t 1 ]]; then
  C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YEL=$'\033[33m'; C_BLU=$'\033[34m'; C_BLD=$'\033[1m'; C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_BLD=""; C_RST=""
fi

log_info() { printf '%s[info]%s %s\n' "$C_BLU" "$C_RST" "$*"; }
log_ok()   { printf '%s[ ok ]%s %s\n' "$C_GRN" "$C_RST" "$*"; }
log_warn() { printf '%s[warn]%s %s\n' "$C_YEL" "$C_RST" "$*"; }
log_err()  { printf '%s[fail]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; }
log_head() { printf '\n%s%s%s\n' "$C_BLD" "$*" "$C_RST"; }

require_godot() {
  if [[ ! -x "$GODOT_BIN" ]]; then
    log_err "Godot binary not found/executable at: $GODOT_BIN (set GODOT_BIN to override)"
    exit 1
  fi
}

require_timeout() {
  if [[ ! -x "$GTIMEOUT_BIN" ]]; then
    log_err "gtimeout not found at $GTIMEOUT_BIN. Install with: brew install coreutils"
    exit 1
  fi
}

# run_headless SECONDS LOG_FILE -- <dev flags, no leading -->
# Runs Godot headless+muted with a hard wall-clock ceiling, dev flags after a
# bare '--' (required: without it Godot's user args are invisible and the
# game sits at the menu forever - see CLAUDE.md's "Verification workflow").
# Never fails on timeout by itself (the caller decides what a timeout means);
# always writes full stdout+stderr to LOG_FILE.
run_headless() {
  local secs="$1"; shift
  local log="$1"; shift
  require_godot; require_timeout
  set +e
  "$GTIMEOUT_BIN" --kill-after=5 "${secs}s" \
    "$GODOT_BIN" --headless "${AUDIO_FLAGS[@]}" --path "$PIXELTOSSA_ROOT" -- "$@" \
    >"$log" 2>&1
  local code=$?
  set -e
  return $code
}

# run_windowed SECONDS LOG_FILE -- <dev flags>
# Same, but windowed (required for --shot screenshot capture: this project's
# own notes are explicit that headless has no viewport texture to read).
run_windowed() {
  local secs="$1"; shift
  local log="$1"; shift
  require_godot; require_timeout
  set +e
  "$GTIMEOUT_BIN" --kill-after=5 "${secs}s" \
    "$GODOT_BIN" "${AUDIO_FLAGS[@]}" --path "$PIXELTOSSA_ROOT" -- "$@" \
    >"$log" 2>&1
  local code=$?
  set -e
  return $code
}

# scan_run_log LOG_FILE - prints problems found, returns nonzero if any.
# Codifies CLAUDE.md's own hard-won lesson: --check-only misses real errors,
# so every actual run must be grepped for these markers.
scan_run_log() {
  local log="$1"
  local bad=0
  if grep -qE "SCRIPT ERROR|Parse Error" "$log"; then
    log_err "Script/parse error found in $log:"
    grep -E "SCRIPT ERROR|Parse Error" "$log" | sed 's/^/    /'
    bad=1
  fi
  if grep -q "triangulation failed" "$log"; then
    log_err "Self-intersecting polygon (silent draw failure) in $log:"
    grep "triangulation failed" "$log" | sort -u | sed 's/^/    /'
    bad=1
  fi
  return $bad
}

# run_windowed_res SECONDS LOG_FILE WxH -- <dev flags>
# Same as run_windowed, at a specific WINDOW size. `--resolution` is an ENGINE
# flag, so it has to go before the bare '--' - putting it after makes it a
# silent no-op, which is exactly the failure mode dev flags have without the
# '--' in the first place.
#
# WHY A WINDOW SIZE IS WORTH TESTING (2026-08-21): the game's viewport used to
# take the window's own shape (aspect "expand"), so the size of the window
# changed what was drawn and how sharply. Fullscreen on a 2560x1606 framebuffer
# gave a 1280x803 viewport and stretched every 640x360 painting 2.231x
# vertically. It is now locked to the design size at every window shape, and
# this helper is how that lock is checked.
run_windowed_res() {
  local secs="$1"; shift
  local log="$1"; shift
  local res="$1"; shift
  require_godot; require_timeout
  set +e
  "$GTIMEOUT_BIN" --kill-after=5 "${secs}s" \
    "$GODOT_BIN" "${AUDIO_FLAGS[@]}" --resolution "$res" --path "$PIXELTOSSA_ROOT" -- "$@" \
    >"$log" 2>&1
  local code=$?
  set -e
  return $code
}

timestamp() { date +%Y%m%d_%H%M%S; }
