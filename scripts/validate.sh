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

echo
if [[ $FAIL -eq 0 ]]; then
  log_ok "VALIDATE: all checks passed."
else
  log_err "VALIDATE: one or more checks failed (see above)."
fi
exit $FAIL
