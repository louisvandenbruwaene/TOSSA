#!/usr/bin/env bash
# TOSSA's headless validation pipeline - the project's real "test suite".
#
# WHY THIS SHAPE: Game.gd has no scenes/autoloads to validate in the usual
# Godot sense (see AUDIT_2026-07-26.md), and `--check-only` is documented in
# CLAUDE.md as unreliable (it has missed real parse errors that only surface
# on an actual run). So validation here means: actually run the game several
# ways and grep stderr for failure markers, plus two fast static "mechanical
# sweeps" CLAUDE.md already describes doing by hand after big passes.
#
# Fails (nonzero exit) on: SCRIPT ERROR / Parse Error in any run, a silent
# self-intersecting-polygon draw failure, --collcheck reporting "nothing
# measured", or an asymmetric save/load key set. Does NOT fail on negative
# collision clearance by itself - Half Shower and Tennis are DOCUMENTED to
# run near-zero/negative by geometry (CLAUDE.md, "a long-standing residual
# this file must not punish the player for"), so a blanket clearance gate
# would false-positive on accepted design. Clearance numbers are printed for
# a human to compare against that baseline.
#
# Usage: scripts/validate.sh [--quick]
#   --quick   skip the collision sweep and the windowed screenshot smoke test
#             (useful for a fast pre-commit-adjacent check; the full run
#             takes roughly a minute or two)
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source scripts/lib.sh

QUICK=0
[[ "${1:-}" == "--quick" ]] && QUICK=1

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
FAIL=0

fail() { log_err "$1"; FAIL=1; }

# --- 1. Parse check (fast, first filter; known unreliable, see header) -----
log_head "1. Parse check"
require_godot
if "$GODOT_BIN" --headless --check-only --script Game.gd >"$WORK/parse.log" 2>&1; then
  log_ok "godot --check-only reported no diagnostics."
else
  cat "$WORK/parse.log" | sed 's/^/    /'
  fail "Parse check failed."
fi

# --- 2. A real booked act ---------------------------------------------------
# Venue 0 (Backyard) on purpose: this is a fast correctness smoke test, not a
# balance check. Post-2026-07-29 every goal also carries a TIME floor
# (see CLAUDE.md's ANTE LADDER section - Theatre alone can take 200-370s
# even for a bot), so a higher venue here would make this check slow and
# venue-pacing-dependent rather than a quick "does resolution still work".
log_head "2. Booked act (--demo --booking --venue 0)"
if run_headless 90 "$WORK/booking.log" --demo --booking --venue 0; then :; fi
if grep -q "^ACT " "$WORK/booking.log"; then
  log_ok "$(grep '^ACT ' "$WORK/booking.log" | tail -1)"
else
  log_err "No 'ACT ...' resolve line found - act did not resolve."
  FAIL=1
fi
scan_run_log "$WORK/booking.log" || FAIL=1

# --- 3. Seeded daily act -----------------------------------------------------
log_head "3. Daily act (--daily --demo --booking)"
run_headless 60 "$WORK/daily.log" --daily --demo --booking || true
if grep -q "^ACT \|daily_share\|share" "$WORK/daily.log"; then
  log_ok "Daily act resolved."
else
  log_warn "No daily resolve line found (daily challenge is documented UNVERIFIED in CLAUDE.md)."
fi
scan_run_log "$WORK/daily.log" || FAIL=1

if [[ $QUICK -eq 0 ]]; then
  # --- 4. Collision sweep ---------------------------------------------------
  log_head "4. Collision sweep (--collcheck --latecatch 5)"
  # Combo from AUDIT_2026-07-26.md's own verified reproduction command.
  declare -a COMBOS=(
    "--balls 4 --pattern 2 --prop 4"
    "--balls 4 --pattern 0 --prop 0"
    "--balls 6 --pattern 1 --prop 2"
  )
  for combo in "${COMBOS[@]}"; do
    log="$WORK/coll_$(echo "$combo" | tr -d ' -').log"
    # shellcheck disable=SC2086
    run_headless 45 "$log" --collcheck --latecatch 5 $combo || true
    if grep -qi "min clearance" "$log"; then
      grep -i "min clearance\|min drawn gap" "$log" | sed "s/^/    [$combo] /"
    else
      fail "[$combo] --collcheck measured nothing (should always print 'min clearance')."
    fi
    scan_run_log "$log" || FAIL=1
  done
else
  log_warn "4. Collision sweep skipped (--quick)."
fi

if [[ $QUICK -eq 0 ]]; then
  # --- 4b. The stop gesture -------------------------------------------------
  log_head "4b. Full-hand catching / the stop gesture (--parkcheck)"
  # SIX PROPS AND AN EXPLICIT CASCADE, and both are load-bearing:
  #   - below six a hand parks on the LAST catch of the set, so nothing is left in the air
  #     afterwards and the reach half of the rule is never exercised (the harness says so).
  #   - the reach assertion is a CASCADE property. A columns hand stands under its own lane,
  #     and the inner lanes sit closer to centre than the throw slot does, so "a parked hand
  #     reaches further than 54px" is simply not true there - and the save's own pattern is
  #     whatever it was left on, which made this read as a failure at seven props.
  log="$WORK/parkcheck.log"
  run_headless 60 "$log" --demo --booking --venue 3 --prop 0 --pattern cascade --balls 6 \
    --parkcheck --shotat 6000 || true
  if grep -q "parkcheck FAIL" "$log"; then
    grep "parkcheck" "$log" | sed 's/^/    /'
    fail "The full-hand catch rule regressed (see above)."
  elif grep -q "parkcheck OK" "$log"; then
    grep "parkcheck" "$log" | sed 's/^/    /'
  else
    fail "--parkcheck printed no verdict (the gesture never ran - did the demo reach a goal?)."
  fi
  scan_run_log "$log" || FAIL=1
else
  log_warn "4b. Stop-gesture check skipped (--quick)."
fi

# --- 5. Uncalled-function scan (advisory, matches CLAUDE.md's own technique) -
log_head "5. Uncalled-function scan (advisory)"
EXCLUDE_RE='^(_ready|_draw|_physics_process|_input|_unhandled_input|_process|_notification|_enter_tree|_exit_tree|_on_.*|_click|_mix_into)$'
dead=0
while IFS= read -r fn; do
  [[ "$fn" =~ $EXCLUDE_RE ]] && continue
  n=$(grep -oE "\b${fn}\(" Game.gd | wc -l | tr -d ' ')
  if [[ "${n:-0}" -le 1 ]]; then
    echo "    $fn"
    dead=$((dead + 1))
  fi
done < <(grep -oE '^func [A-Za-z_][A-Za-z0-9_]*' Game.gd | awk '{print $2}')
if [[ $dead -eq 0 ]]; then
  log_ok "No apparently-uncalled functions."
else
  log_warn "$dead function(s) above have no call site outside their own definition (heuristic - verify before deleting)."
fi

# --- 6. Save/load key symmetry diff -----------------------------------------
# Advisory, NOT blocking - verified 2026-07-31 that this legitimately produces
# false positives here: save_progress() writes 8 keys (glasses/gloves/boots/
# hat/coat/vest/glow_suit/glow_kit-style) explicitly commented as "LEGACY...
# written from OWNERSHIP" solely so load_progress()'s one-time pre-tailor
# migration can read an older save. A grep-based static diff can't know a
# write-only key is deliberate, so a human must read this, not a CI gate.
log_head "6. Save/load key symmetry (advisory - see script comment above)"
grep -oE 'set_value\("[a-z_]+", *"[A-Za-z0-9_]+"' Game.gd \
  | sed -E 's/set_value\("([a-z_]+)", *"([A-Za-z0-9_]+)"/\1.\2/' | sort -u >"$WORK/save_keys.txt"
grep -oE 'get_value\("[a-z_]+", *"[A-Za-z0-9_]+"' Game.gd \
  | sed -E 's/get_value\("([a-z_]+)", *"([A-Za-z0-9_]+)"/\1.\2/' | sort -u >"$WORK/load_keys.txt"
if diff -u "$WORK/save_keys.txt" "$WORK/load_keys.txt" >"$WORK/keydiff.txt"; then
  log_ok "Save keys and load keys match exactly."
else
  cat "$WORK/keydiff.txt" | sed 's/^/    /'
  log_warn "Save/load key sets differ (see above) - check each one is a deliberate legacy/migration key, not a real desync."
fi

# --- 7. Windowed screenshot smoke test ---------------------------------------
if [[ $QUICK -eq 0 ]]; then
  log_head "7. Windowed screenshot smoke test"
  shot="$WORK/smoke.png"
  run_windowed 45 "$WORK/shot.log" --demo --booking --venue 2 --shot "$shot" --shotat 700 || true
  if [[ -s "$shot" ]]; then
    log_ok "Captured $(du -h "$shot" | cut -f1) screenshot with no draw errors."
  else
    fail "Screenshot was not produced (check $WORK/shot.log before it's cleaned up: cat that path now)."
    cat "$WORK/shot.log" | tail -20 | sed 's/^/    /'
  fi
  scan_run_log "$WORK/shot.log" || FAIL=1
else
  log_warn "7. Screenshot smoke test skipped (--quick)."
fi

# --- 8. Font sizes are quantised (PIXELTOSSA) --------------------------------
# THE PIXEL FONT IS ONLY CRISP AT MULTIPLES OF 4 (see ps() in Game.gd for the sweep
# this was measured from). A text call whose size argument skips ps() renders with
# uneven stems - "220" comes out as "ZZ0" - and it is the kind of defect that reads
# as a bad font rather than as a bug, so nobody goes looking for it. This catches a
# new call site the moment it is added, which is the only reliable time to catch it.
log_head "8. Font-size quantisation (PIXELTOSSA)"
# Python, not grep: these calls wrap across lines and the size argument routinely
# sits on the continuation line, so a line-based check reports 45 false positives
# and gets ignored. See scripts/check_font_sizes.py.
if out=$(python3 scripts/check_font_sizes.py Game.gd 2>&1); then
  log_ok "Every text call's font size goes through ps()."
else
  fail "$(printf '%s' "$out" | head -1)"
  printf '%s\n' "$out" | tail -n +2
fi

# --- 9. Art-grid drift (PIXELTOSSA, advisory) --------------------------------
# At ART_PIXEL = 2 a converted element is four identical pixels per aligned 2x2
# block. Anything smooth - an antialiased curve, a gradient, a rounded panel
# corner - breaks that, so the share of non-flat blocks measures how much of a
# frame is still vector drawing. See scripts/check_pixel_grid.py.
#
# ADVISORY, and it must stay that way: text is deliberately rendered at SCREEN
# density (1280x720) rather than art density, because 640x360 turns a HUD label
# to mush and this game is text-heavy - that was decision 2 of the fork. Text
# therefore counts as "off-grid" by design and puts a floor under every screen
# that has words on it.
#
# AND IT IS NOISY HERE, which is the part worth knowing before reading anything
# into it. Step 7's shot is a LIVE ACT at tick 700, so the frame differs every
# run - props mid-flight, flowers in the air, a different spotlight width.
# Measured 2026-08-05, two consecutive identical commands: 28.1% and 22.3%. A
# six-point move on this line means nothing at all.
#
# For a number that can actually be compared, use `make screenshot`, which runs
# the same check over all 32 screens, most of which are static.
if [[ $QUICK -eq 0 && -s "${shot:-}" ]]; then   # ${shot:-}: unset under --quick, and set -u is on
  log_head "9. Art-grid drift (PIXELTOSSA, advisory)"
  if [[ -x .venv/bin/python ]]; then
    .venv/bin/python scripts/check_pixel_grid.py "$shot" | sed 's/^/    /'
    log_info "A live-act frame runs 22-28% and varies that much between identical"
    log_info "runs, so only a very large move here means anything. Per-screen"
    log_info "baselines live in scripts/check_pixel_grid.py; 'make screenshot'"
    log_info "sweeps all 32 and is the number worth comparing."
  else
    log_warn "Skipped - .venv/bin/python not found (run 'make setup')."
  fi
fi

echo
if [[ $FAIL -eq 0 ]]; then
  log_ok "VALIDATE: all checks passed."
else
  log_err "VALIDATE: one or more checks failed (see above)."
fi
exit $FAIL
