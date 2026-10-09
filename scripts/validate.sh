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
cleanup() {
  local status=$?
  if [[ $status -eq 0 ]]; then
    rm -rf "$WORK"
  else
    log_warn "Validation logs kept at $WORK"
  fi
}
trap cleanup EXIT
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

# --- 1b. Extracted pure contracts -------------------------------------------
# These protect the seams intentionally moved out of Game.gd. A power-of-ten score
# regression or a reordered persisted pattern is easy to miss in a screenshot and
# too important to leave to visual review alone.
log_head "1b. Extracted pure contracts"
for test_script in tests/test_format.gd tests/test_catalog.gd tests/test_replay.gd tests/test_save_schema.gd tests/test_geometry.gd tests/test_rewards.gd tests/test_balance.gd tests/test_catch_comfort.gd tests/test_practice_result.gd tests/test_routine.gd tests/test_btb_pose.gd tests/test_performance_pose.gd; do
  log="$WORK/$(basename "$test_script" .gd).log"
  if "$GODOT_BIN" --headless --path "$PIXELTOSSA_ROOT" --script "$test_script" >"$log" 2>&1; then
    grep -E 'TossaFormat:|TossaCatalog:|TossaReplay:|TossaSaveSchema:|TossaGeometry:|TossaRewards:|TossaBalance:|TossaCatch:|TossaPractice:|TossaRoutine:|TossaPose:|TossaPerformancePose:' "$log" | tail -1 | sed 's/^/    [ ok ] /'
  else
    cat "$log" | sed 's/^/    /'
    fail "Pure contract failed: $test_script"
  fi
done

# --- 2. A real booked act ---------------------------------------------------
# Venue 0 (Backyard) on purpose: this is a fast correctness smoke test, not a
# balance check. Post-2026-07-29 every goal also carries a TIME floor
# (see CLAUDE.md's ANTE LADDER section - Theatre alone can take 200-370s
# even for a bot), so a higher venue here would make this check slow and
# venue-pacing-dependent rather than a quick "does resolution still work".
log_head "2. Booked act (--demo --booking --venue 0 --prop 0)"
if run_headless 90 "$WORK/booking.log" --demo --booking --venue 0 --prop 0; then :; fi
if grep -q "^ACT " "$WORK/booking.log"; then
  log_ok "$(grep '^ACT ' "$WORK/booking.log" | tail -1)"
else
  log_err "No 'ACT ...' resolve line found - act did not resolve."
  FAIL=1
fi
if grep -q '^PERFECT_BURST seconds=15 progress=0 tick=' "$WORK/booking.log"; then
  log_ok "Fifty Perfects triggered the live 15-second reward and reset its tally."
else
  fail "The booked-act harness did not trigger the live fifty-Perfect reward."
fi
scan_run_log "$WORK/booking.log" || FAIL=1

# --- 2b. Demo export presets ------------------------------------------------
# The game's `demo` feature is meaningful only if it can reach a shipping
# binary.  Keep this check declarative: export templates are optional on a
# development machine, while these three presets and their feature flag must
# exist in every checkout.
log_head "2b. Demo export presets"
for preset in "macOS Demo" "Windows Demo" "Linux Demo"; do
  if awk -v want="$preset" '
    /^\[preset\.[0-9]+\]$/ { in_preset = 0 }
    $0 == "name=\"" want "\"" { in_preset = 1 }
    in_preset && $0 == "custom_features=\"demo\"" { found = 1 }
    END { exit found ? 0 : 1 }
  ' export_presets.cfg; then
    log_ok "$preset carries the demo feature."
  else
    fail "$preset is missing or does not declare custom_features=\"demo\"."
  fi
done

# --- 3. Seeded daily act -----------------------------------------------------
log_head "3. Daily act (--daily --demo --booking)"
# 90, NOT 60, AND STEP 2 ABOVE ALREADY KNEW THAT (2026-08-20). These acts run the same demo
# save to the same kind of resolution - measured, 7119 ticks, which at the fixed 120Hz is 59.3s
# of wall clock - so a 60s ceiling was losing the race by a second or two and reporting it as a
# missing receipt. Step 2 was raised to 90 at some point and the two below were not.
run_headless 90 "$WORK/daily.log" --daily --demo --booking --prop 0 || true
if grep -q "^${GAME_TITLE:-TOSSA} Daily " "$WORK/daily.log"; then
	log_ok "Daily act resolved."
else
	fail "Daily act did not emit its dated share receipt."
fi
scan_run_log "$WORK/daily.log" || FAIL=1

# --- 3a. Demo ceiling transition --------------------------------------------
log_head "3a. Demo-wall transition (--demowall --venue 2)"
run_headless 90 "$WORK/demowall.log" --demowall --demo --booking --venue 2 --prop 0 || true
if grep -q '^ACT .*demowall=true' "$WORK/demowall.log"; then
  log_ok "Crossing the scoped demo ceiling armed the demo-wall card."
else
  fail "Demo ceiling did not arm pending_demo_wall after resolution."
fi
scan_run_log "$WORK/demowall.log" || FAIL=1

# --- 3b. Mandatory first lesson ---------------------------------------------
# This is executable onboarding, not static copy: it must drive the real sim through
# held-height input, the two-ball exchange, and ten consecutive juggling catches.
log_head "3b. First-player tutorial (--tutorial balls)"
run_headless 60 "$WORK/tutorial.log" --demo --tutcheck --tutorial balls || true
if grep -q "TUTTRACE finished id=balls" "$WORK/tutorial.log"; then
  log_ok "Mandatory tutorial completed through the real simulation."
else
  fail "Mandatory tutorial did not reach its completion trace."
fi
scan_run_log "$WORK/tutorial.log" || FAIL=1

# --- 3c. Intermediate lesson choreography -----------------------------------
# Count and pattern lessons share one guided grammar: every prop goes up, then each
# arrival is caught and thrown back for two whole cycles. Exercise both the four-ball
# milestone and a shaped pattern so neither side of that shared beat can silently stall.
log_head "3c. Intermediate tutorials (count, pattern, toggle, live trick)"
for lesson in count_4 pattern_columns trick_btb trick_spin; do
  log="$WORK/tutorial_${lesson}.log"
  run_headless 20 "$log" --demo --tutcheck --tutorial "$lesson" || true
  if grep -q "TUTTRACE finished id=${lesson}" "$log"; then
    log_ok "$lesson completed its two-cycle guided pattern."
  else
    fail "$lesson did not complete its two-cycle guided pattern."
  fi
  scan_run_log "$log" || FAIL=1
done

# --- 3d. Dangerous-prop consequence -----------------------------------------
# THIS ASSERTS THE OPPOSITE OF WHAT IT USED TO, ON PURPOSE (2026-08-19, Louis: "disable the
# lose all stamina when hit by a dangerous object for now, it's irritating"). It used to
# require reason=chainsaw_injury; the rule is off, so a chainsaw drop must now end the act
# the ordinary way - on drops, on stamina, on the crowd - or not at all.
#
# The switch is Game.gd's INJURY_ENDS_ACT, and this test moves with it. That is the point of
# testing the BEHAVIOUR: turning the rule back on makes this check fail loudly, which is the
# reminder to flip it back, rather than leaving a green suite describing a game that no
# longer exists.
log_head "3d. Dangerous-prop drop (--prop 6, injury rule disabled)"
run_headless 30 "$WORK/injury.log" --demo --booking --venue 0 --prop 6 || true
if ! grep -q '^ACT ' "$WORK/injury.log"; then
  fail "Dangerous-prop act never resolved (no ACT line) - cannot tell what it did."
elif grep -q '^ACT .*reason=.*_injury' "$WORK/injury.log"; then
  fail "A dangerous prop still ended the act on injury - INJURY_ENDS_ACT is meant to be off."
else
  log_ok "A chainsaw drop no longer ends the act on injury ($(grep -m1 -o 'reason=[a-z_]*' "$WORK/injury.log"))."
fi
scan_run_log "$WORK/injury.log" || FAIL=1

if [[ $QUICK -eq 0 ]]; then
  # --- 4. Collision sweep ---------------------------------------------------
  log_head "4. Collision sweep (--collcheck --latecatch 5)"
  # Combo from AUDIT_2026-07-26.md's own verified reproduction command.
  declare -a COMBOS=(
    "--balls 4 --pattern halfshower --prop 4"
    "--balls 4 --pattern cascade --prop 0"
    "--balls 6 --pattern columns --prop 2"
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
  log_head "7. Focused windowed screenshot smoke tests"
  # name : tick : expected `shot state` name : dev flags. The EXPECTED STATE is not
  # decoration - screenshot.sh's own note records that a capture can come back a perfectly
  # valid PNG of the wrong screen, and this step can now do it deliberately: Game.gd no
  # longer quits out from under a pending --shot, so a booked act that collapses early
  # leaves the run sitting on its results panel and photographs THAT at tick 700. Without
  # the check that reads as a pass.
  declare -a SHOT_CASES=(
    "stage:700:play:--demo --booking --venue 2 --prop 0 --encore none"
    "results:60:results:--results"
    "demo_wall:60:demowall:--wallcard"
  )
  for shot_case in "${SHOT_CASES[@]}"; do
    shot_name="${shot_case%%:*}"
    shot_rest="${shot_case#*:}"
    shot_at="${shot_rest%%:*}"
    shot_rest="${shot_rest#*:}"
    shot_want="${shot_rest%%:*}"
    shot_flags="${shot_rest#*:}"
    shot="$WORK/${shot_name}.png"
    shot_log="$WORK/shot_${shot_name}.log"
    # shellcheck disable=SC2086
    run_windowed 45 "$shot_log" $shot_flags --shot "$shot" --shotat "$shot_at" || true
    shot_got="$(grep -m1 '^shot state: ' "$shot_log" | awk '{print $4}' || true)"
    if [[ ! -s "$shot" ]]; then
      fail "$shot_name screenshot was not produced."
      tail -20 "$shot_log" | sed 's/^/    /'
    elif [[ -n "$shot_want" && "$shot_got" != "$shot_want" ]]; then
      fail "$shot_name photographed '$shot_got', wanted '$shot_want'."
      grep -m1 '^ACT ' "$shot_log" | sed 's/^/    /' || true
    else
      log_ok "$shot_name: captured $(du -h "$shot" | cut -f1) with no draw errors."
    fi
    scan_run_log "$shot_log" || FAIL=1
  done
  shot="$WORK/stage.png"  # the live frame used by the art-grid advisory below

  # --- 7b. The window shape a player actually runs in -----------------------
  # THE ONE MODE NOBODY HAD EVER PHOTOGRAPHED (2026-08-21). Every other capture in this
  # project is 1280x720 windowed, because Game.gd deliberately skips apply_fullscreen()
  # under --shot. Louis's settings say fullscreen=true, and macOS reports that framebuffer
  # as 2560x1606 - which under the old aspect "expand" made the VIEWPORT 1280x803, an odd
  # height the 2px art grid cannot tile. Every 640x360 venue painting was stretched 2.231x
  # vertically and a third of its rows drawn three screen pixels tall. Measured on the
  # Circus: 5.17% off-grid at the design size, 26.59% at 1280x803, and no capture in the
  # repo could see it.
  #
  # The lock is aspect "keep" + scale_mode "integer" in project.godot. This step is what
  # holds it: run a window at the real fullscreen SHAPE and assert the frame still comes
  # back at the design size. If someone sets "expand" again, the capture comes back
  # 1280x803 and this fails - which is the only way a settings line gets noticed.
  log_head "7b. Aspect lock at the fullscreen window shape (1280x803)"
  fs_shot="$WORK/fsshape.png"
  fs_log="$WORK/shot_fsshape.log"
  run_windowed_res 45 "$fs_log" 1280x803 \
    --demo --booking --venue 3 --encore none --shot "$fs_shot" --shotat 700 || true
  if [[ ! -s "$fs_shot" ]]; then
    fail "The fullscreen-shape capture was not produced."
    tail -20 "$fs_log" | sed 's/^/    /'
  elif [[ -x .venv/bin/python ]]; then
    fs_size="$(.venv/bin/python -c "
from PIL import Image
import sys
print('%dx%d' % Image.open(sys.argv[1]).size)" "$fs_shot")"
    if [[ "$fs_size" == "1280x720" ]]; then
      log_ok "A 1280x803 window still renders the 1280x720 design frame ($fs_size)."
    else
      fail "Aspect lock broken: a 1280x803 window rendered $fs_size, not 1280x720."
      log_err "project.godot's window/stretch/aspect must stay \"keep\" - see its own note."
    fi
  else
    log_warn "Skipped the size assertion - .venv/bin/python not found (run 'make setup')."
  fi
  scan_run_log "$fs_log" || FAIL=1
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
