#!/usr/bin/env bash
# TOSSA has exactly one scene (Main.tscn) with many dev-flag-selected screen
# states - there is no second scene to "run" the way a multi-scene project
# would. This wraps that reality: pass any dev flag(s) to jump straight to a
# screen, windowed and MUTED (use run_game.sh for real play with real audio).
#
# Examples:
#   scripts/run_scene.sh --day work
#   scripts/run_scene.sh --skills 2
#   scripts/run_scene.sh --demo --booking --venue 4
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source scripts/lib.sh
require_godot
if [[ $# -eq 0 ]]; then
  log_err "Usage: $0 <dev flags...>   e.g. $0 --day work"
  exit 1
fi
log_info "godot --audio-driver Dummy -- $*"
exec "$GODOT_BIN" "${AUDIO_FLAGS[@]}" --path "$TOSSA_ROOT" -- "$@"
