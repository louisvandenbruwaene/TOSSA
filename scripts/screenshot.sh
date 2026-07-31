#!/usr/bin/env bash
# Captures TOSSA's real screens (not a generic Main Menu/Inventory/Battle
# template - this game's story was cut; these are the actual screens per
# CLAUDE.md) using its existing documented dev flags. Windowed + muted.
# Output: artifacts/screenshots/<name>_<timestamp>.png
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source scripts/lib.sh
require_godot
mkdir -p artifacts/screenshots

ts="$(timestamp)"
ok=0
fail=0

# name : tick : dev flags (without --shot/--shotat, added automatically)
# Note: a cold launch with no dev flags lands in Practice using the REAL
# save (verified 2026-07-31 - it is not the title/menu screen at tick 30;
# no documented dev flag jumps to the title screen itself, so it isn't
# captured here). Practice is still a real, useful screen to have.
declare -a TARGETS=(
  "practice_boot:30:"
  "day_hub_work:40:--day work"
  "day_hub_rest:40:--day rest"
  "day_hub_prep:40:--day prep"
  "shop:60:--shop"
  "skills:40:--skills"
  "sheet:40:--sheet"
  "pause:60:--pause"
  "in_act_stage:700:--demo --booking --venue 4"
  "results:60:--results"
  "credits:60:--credits"
)

for entry in "${TARGETS[@]}"; do
  name="${entry%%:*}"
  rest="${entry#*:}"
  tick="${rest%%:*}"
  flags="${rest#*:}"
  out="artifacts/screenshots/${name}_${ts}.png"
  log="$(mktemp)"
  # shellcheck disable=SC2086
  run_windowed 30 "$log" $flags --shot "$out" --shotat "$tick" || true
  if [[ -s "$out" ]]; then
    log_ok "$name -> $out"
    ok=$((ok + 1))
  else
    log_warn "$name -> FAILED (see log below; screen may need more game state than a cold boot gives it)"
    tail -10 "$log" | sed 's/^/    /'
    fail=$((fail + 1))
  fi
  rm -f "$log"
done

echo
log_info "Captured $ok/$((ok + fail)) screens."
[[ $ok -gt 0 ]]  # exit 0 if at least one screen succeeded
