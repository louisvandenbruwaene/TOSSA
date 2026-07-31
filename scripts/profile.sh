#!/usr/bin/env bash
# Captures a short performance sample using the game's own --fps probe
# (draw us, physics us, draws/s, engine fps, draw calls, primitives - see
# CLAUDE.md's PERFORMANCE entries for what each means and why 'draws/s' is
# the number to trust over 'engine fps' when unfocused/backgrounded).
# Runs WINDOWED on purpose: every performance number in this project's own
# docs was measured windowed, and --headless uses a null renderer that
# won't produce real draw-call/primitive counts.
#
# Usage: scripts/profile.sh [seconds] [dev flags...]
#   scripts/profile.sh 20 --demo --booking --venue 6
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source scripts/lib.sh
require_godot

SECS=20
if [[ "${1:-}" =~ ^[0-9]+$ ]]; then
  SECS="$1"
  shift
fi
FLAGS=("$@")
if [[ ${#FLAGS[@]} -eq 0 ]]; then
  FLAGS=(--demo --booking --venue 4)
fi
FLAGS+=(--fps)

mkdir -p artifacts/profiling
ts="$(timestamp)"
raw="artifacts/profiling/raw_${ts}.log"
report="artifacts/profiling/report_${ts}.md"

log_info "Profiling ${SECS}s: ${FLAGS[*]}"
run_windowed "$SECS" "$raw" "${FLAGS[@]}" || true

{
  echo "# TOSSA performance sample - $ts"
  echo
  echo "Flags: \`${FLAGS[*]}\`  Duration: ${SECS}s"
  echo
  echo '```'
  grep -iE "draw|physics|fps|calls|primitives" "$raw" | tail -30
  echo '```'
} >"$report"

log_ok "Report: $report"
scan_run_log "$raw" || log_warn "Errors present during profiling - see $raw"
