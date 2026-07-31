#!/usr/bin/env bash
# Forces Godot to (re)import all assets headlessly (godot --import quits
# after importing, no editor UI needed), then checks for .import sidecar
# files whose source asset has gone missing - a real paper cut this repo has
# hit before (AUDIT_2026-07-26.md flagged a stray orphaned .import file).
#
# DANGER, VERIFIED 2026-07-31: `godot --headless --import` silently rewrites
# Game.gd's indentation (leading spaces used to align trailing comments
# become tabs - 192 lines changed in testing) as a side effect of the import
# pass, every single time. That comment alignment is deliberate documentation
# in this codebase (see docs/coding_guidelines.md), so this script snapshots
# Game.gd before running and auto-reverts + loudly warns if anything changed,
# rather than silently letting a "just check my assets" command corrupt it.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source scripts/lib.sh
require_godot

if git -C "$TOSSA_ROOT" diff --quiet -- Game.gd 2>/dev/null; then
  GAME_GD_WAS_CLEAN=1
else
  GAME_GD_WAS_CLEAN=0
  log_warn "Game.gd already had uncommitted changes - skipping the auto-revert guard (can't tell your edits from import side effects)."
fi

log_info "godot --headless --import ..."
"$GODOT_BIN" --headless --import --path "$TOSSA_ROOT" 2>&1 | tail -20

if [[ $GAME_GD_WAS_CLEAN -eq 1 ]] && ! git -C "$TOSSA_ROOT" diff --quiet -- Game.gd 2>/dev/null; then
  log_err "godot --import just rewrote Game.gd's whitespace (known issue - see header). Reverting automatically."
  git -C "$TOSSA_ROOT" checkout -- Game.gd
  log_ok "Game.gd reverted. Your assets were still imported; Game.gd itself is untouched."
fi

log_info "Checking for .import sidecars with a missing source asset..."
missing=0
while IFS= read -r -d '' importfile; do
  src="${importfile%.import}"
  if [[ ! -e "$src" ]]; then
    log_warn "Missing source for: $importfile"
    missing=$((missing + 1))
  fi
done < <(find . -name "*.import" -not -path "./.godot/*" -print0)

if [[ $missing -eq 0 ]]; then
  log_ok "No orphaned .import sidecars."
else
  log_warn "$missing orphaned .import sidecar(s) above - safe to delete; they regenerate if the source returns."
fi
