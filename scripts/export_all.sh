#!/usr/bin/env bash
# Exports TOSSA for every shipped platform (macOS, Windows, Linux) in one
# pass, release AND debug, so every binary in export/ is refreshed together
# instead of drifting out of sync when only one gets re-exported by hand.
# The three "X Debug" presets carry the "debug_launcher" custom feature,
# which Game.gd reads to start straight in debug_mode (free stat editing,
# F1-F7 venue jump, its own save file) with no command line needed - a
# portable version of what install_apps.sh's local "TOSSA Debug.app" does.
#
# Output paths are never hardcoded here - each preset's own export_path in
# export_presets.cfg is the single source of truth, and Godot's CLI export
# reads it when no destination argument is given.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source scripts/lib.sh
require_godot

PRESETS=(macOS Windows Linux "macOS Demo" "Windows Demo" "Linux Demo" "macOS Debug" "Windows Debug" "Linux Debug")
DIRS=(export/macos export/windows export/linux)

mkdir -p "${DIRS[@]}"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
FAIL=0

log_head "Exporting TOSSA for ${#PRESETS[@]} platforms"
for preset in "${PRESETS[@]}"; do
  log_info "Exporting: $preset"
  log="$WORK/${preset}.log"
  if "$GODOT_BIN" --headless --path "$PIXELTOSSA_ROOT" --export-release "$preset" >"$log" 2>&1 \
       && scan_run_log "$log"; then
    log_ok "$preset done"
  else
    log_err "$preset export failed (nonzero exit, or a script/parse error CLAUDE.md warns --check-only can miss):"
    tail -20 "$log" | sed 's/^/    /'
    FAIL=1
  fi
done

log_head "Export contents"
du -sh "${DIRS[@]}" 2>/dev/null

exit $FAIL
