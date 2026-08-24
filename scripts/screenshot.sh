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

# name : tick : expected state : dev flags (--shot/--shotat added automatically)
#
# Note: a cold launch with no dev flags lands in Practice using the REAL
# save (verified 2026-07-31 - it is not the title screen at tick 30).
# `--menu` holds the title screen, which --shot otherwise skips past.
#
# WHY THE LIST IS LONG (PIXELTOSSA): this script is the project's only visual
# regression net, and a screen with no target here is a screen nobody has
# looked at since the art density changed. Every game_state that has a dev
# flag gets a target, even the one-off end cards. Two nesting rules matter:
# `--wardrobe`, `--glow` and `--nokit` are handled INSIDE the --demo branch,
# so they do nothing without it; `--establish` wants `--booking` to show the
# act's goals panel rather than a bare exterior.
#
# THE EXPECTED-STATE FIELD is what makes this list trustworthy. A capture can
# come back a valid PNG of the WRONG SCREEN, and it does: measured 2026-08-05,
# `--establish 2` and `--establish 3` each photographed the practice screen
# once and the right card on a retry of the identical command. Nothing about
# the file betrays it. So Game.gd prints `shot state: <n> <name>` next to every
# capture (see shot_state_name()) and each target below says which name it must
# be. The name is the OVERLAY where there is one - shop, sheet, pause and the
# rest all sit on ST_PLAY, so "play" would assert nothing. Empty = don't check.
declare -a TARGETS=(
  # --- the screens a player sees every run --------------------------------
  "title:60:menu:--menu"
  "practice_boot:30:play:"
  # `--binds off` IS NOT REDUNDANT, and leaving it out cost this script's duplicate-frame
  # guard a false alarm (2026-08-20). `--binds` deliberately writes back to the save - it
  # books a real limiter, unlike `--assists`, which pins for one run precisely so it cannot
  # - and a --shot run saves to pixeltossa_demo.cfg. So the FIRST time day_hub_binds runs,
  # every later plain `--day work` capture inherits BOUND from it, the two targets become
  # byte-identical, and the guard reports two screens that "cannot legitimately be the same
  # picture". They were the same picture, and the state was right; the target was underspecified.
  # Any capture of a saved toggle has to state the value it wants, not assume the default.
  "day_hub_work:40:day:--day work --binds off"
  "day_hub_rest:40:day:--day rest"
  "day_hub_prep:40:day:--day prep"
  # TONIGHT'S TWO LIMITERS, ON. They are set by walking the hub's cursor onto a row and
  # pressing Enter, which no capture can do - so the BOUND state of the rows, the perform
  # card's badge and the record board they switch to had no capture path (see --binds).
  "day_hub_binds:40:day:--day work --binds both"
  # THE HOVERED LIMITER MARK (2026-08-20). The two marks under the stage name light and take
  # an underline bar when the cursor is on one, and Enter is what strikes them out - a state
  # that needs a cursor INSIDE the perform card, which no other target puts it in. Row 1 of
  # the work drawer is the Accuracy mark; --binds spd strikes the other one, so the pair also
  # proves lit-and-clean reads differently from dim-and-struck in the same picture.
  "day_hub_mark_hover:40:day:--day work 1 --binds spd"
  # THE FIVE HUB VIGNETTES. They had no target until 2026-08-19 and could not have had
  # one: each plays for 0.8-1.8s in the middle of a hub action and then the ledger moves,
  # so a capture could never land on one. That is exactly why they were still smooth
  # vector shapes - two stacked ellipses for a hot meal, a triangle for a slice of pie -
  # long after everything around them became sprites. `--vign <id> <t>` holds one at a
  # fixed phase; the phase is part of the target, or the frame is not comparable run to run.
  "vignette_eat:60:day:--vign eat 0.55"
  "vignette_inn:60:day:--vign inn 0.55"
  "vignette_pie:60:day:--vign pie 0.55"
  "vignette_egg:60:day:--vign egg 0.75"
  "vignette_tomato:60:day:--vign tomato 0.55"
  "shop:60:shop:--shop"
  "skills:40:skills:--skills"
  "sheet:40:sheet:--sheet"
  "pause:60:pause:--pause"
  "in_act_stage:700:play:--demo --booking --venue 4"
  # THE GOAL STEM AT FOUR STAGES OF GROWTH. Like the vignettes, the meter had no target
  # and could not have had one: its fill is score against a venue's FINAL goal, so a bloom
  # needs a whole winning act to photograph and the four subgoal flowers appear at fills a
  # demo run may never sit on. `--stem <frac> [over]` pins it. Overflow only exists at full
  # fill, so only the last of these carries one.
  # THE FILLS ARE THE GOALS THEMSELVES (2026-08-19). The three goals are even thirds of
  # the act now and the painting's own milestones are mapped onto them, so 1/3 and 2/3 are
  # the two frames worth comparing run to run: one side flower open, then both. A fill
  # picked for looking sprouty says nothing about whether the plant and the ladder agree.
  "stem_bud:700:play:--demo --booking --venue 2 --stem 0.05 0"
  "stem_goal1:700:play:--demo --booking --venue 2 --stem 0.333 0"
  "stem_goal2:700:play:--demo --booking --venue 2 --stem 0.667 0"
  "stem_bloom:700:play:--demo --booking --venue 2 --stem 1.0 0.9"
  "results:60:results:--results"
  "credits:60:credits:--credits"
  # THE HELD FINAL CARD, which is the last thing the game ever shows and had no target:
  # the roll runs about 100 seconds and only assembles the card after all of it, so a
  # capture had to sit through the whole thing. `--credits <ticks>` seeds cine_tick, the
  # roll's only clock, so the card is reached exactly rather than waited for.
  "credits_card:60:credits:--credits 14600"
  # --- menus and meta screens ----------------------------------------------
  "settings:40:settings:--settings"
  "controls_keyboard:60:remap:--remap"
  "controls_gamepad:60:remap:--remap --pad"
  "slots:40:slots:--slots"
  "play_mode:40:playmode:--playmode"
  "stats:40:stats:--stats"
  "f9_experiments:40:f9:--f9"
  # --- the dressing room, and the figure actually dressed -------------------
  "tailor:60:tailor:--tailor 0"
  "dressed_stage:700:play:--demo --booking --venue 4 --wardrobe"
  # --- stage variants that change the whole picture -------------------------
  # Blackout (venue 5) is the venue the glowing kit exists for, and --nokit is
  # its mirror: the demo save owns glowing props, so without it every dark-stage
  # capture was silently the charged version.
  "stage_blackout_glow:700:play:--demo --booking --venue 5 --glow"
  "stage_blackout_dark:700:play:--demo --booking --venue 5 --nokit"
  # 350, NOT 700 like its neighbours: --boo drives the crowd out and the act COLLAPSES on
  # its own (measured, `collapsed=true ... ticks=398`), so by frame 700 there is no stage
  # left to photograph and the capture never happens. That silently killed the twelve
  # targets below it - see the `|| true` on the state grep for the other half of that bug.
  "stage_booed:350:play:--demo --booking --venue 2 --boo"
  "stage_eggbreak:120:play:--demo --eggbreak"
  # --- cards, banners and one-off end screens -------------------------------
  "establish:60:establish:--establish 3 --booking"
  # --unlock is handled INSIDE the --trick branch, so `--results --unlock` silently
  # captured a plain results screen - found by the duplicate-frame guard below, which
  # is what a byte-identical pair usually means in practice. The banner also needs a
  # RUN in progress and only lives 360 ticks from trick_unlock_tick (see line ~16216),
  # so the shot has to land inside that window.
  "unlock_banner:200:play:--demo --booking --trick spin --unlock"
  "ucard_trick:90:ucard:--demo --booking --ucard trick:spin"
  "ucard_back:60:ucard:--demo --booking --ucard back:trick"
  "tutorial:60:tutorial:--tutorial balls"
  "tutdone:60:tutdone:--tutdone"
  "menutour:60:menutour:--menutour"
  "purist_legend:60:legend:--legend"
  "gameover:60:gameover:--gameover"
  "demo_wallcard:60:demowall:--wallcard"
  # --- the juggling ANIMATION, sampled across its sweep ---------------------
  # The performer is no longer a choice, so there is nothing to A/B - but the animation is
  # picked per frame from the hand positions, so what needs a baseline is that the SWEEP
  # still happens. Three ticks a few frames apart should show three different poses; if
  # they ever come back identical the picker has stuck, which is exactly the failure the
  # duplicate-frame guard below catches.
  "juggle_a:700:play:--demo --booking --venue 3 --prop 0"
  "juggle_b:712:play:--demo --booking --venue 3 --prop 0"
  "juggle_c:724:play:--demo --booking --venue 3 --prop 0"
  "look_light_classic:700:play:--variant lighting:classic --demo --booking --venue 3"
  "look_light_depth:700:play:--variant lighting:depth --demo --booking --venue 3"
  "look_light_warm:700:play:--variant lighting:warm --demo --booking --venue 3"
)

wrong=0
blank=0

# THE THIRD WAY A CAPTURE LIES. The state assertion catches the wrong SCREEN and the
# duplicate check catches the same frame twice, but neither sees a frame that is simply
# EMPTY - the viewport read back before anything had been presented into it. Observed
# 2026-08-05: day_hub_rest came back 1280x720 of pure black, a perfectly valid PNG, in a
# run where its state assertion passed because the game really was in ST_DAY. Three
# straight retries of the same command were clean, so it is transient like the others.
#
# One unique colour is the test, and it cannot false-positive on a real screen: every
# screen in this game draws text, panels or a backdrop. Needs the venv; without it the
# check is skipped rather than guessed at.
frame_is_blank() {
  [[ -x .venv/bin/python ]] || return 1
  .venv/bin/python -c "
import sys
import numpy as np
from PIL import Image
a = np.asarray(Image.open(sys.argv[1]).convert('RGB'))
sys.exit(0 if len(np.unique(a.reshape(-1, 3), axis=0)) <= 1 else 1)
" "$1" 2>/dev/null
}

for entry in "${TARGETS[@]}"; do
  name="${entry%%:*}"
  rest="${entry#*:}"
  tick="${rest%%:*}"
  rest="${rest#*:}"
  expect="${rest%%:*}"
  flags="${rest#*:}"        # last field, so colons inside it (--ucard trick:spin) survive
  out="artifacts/screenshots/${name}_${ts}.png"
  log="$(mktemp)"

  got=""
  # Two attempts, because the wrong-screen capture is INTERMITTENT rather than
  # deterministic - the same command that photographed the practice screen got
  # the right card on a straight retry. One retry turns a flaky net into a
  # reliable one; a second failure is a real problem worth a human looking.
  for attempt in 1 2; do
    # shellcheck disable=SC2086
    # 45s, not 30: a --shotat 700 stage capture has to actually play ~700 ticks
    # before it can save, and validate.sh's own equivalent step already uses 45.
    # A success quits as soon as the shot is written, so the ceiling only costs
    # wall-clock on a screen that was going to fail anyway.
    run_windowed 45 "$log" $flags --shot "$out" --shotat "$tick" || true
    # `|| true` IS LOAD-BEARING, AND ITS ABSENCE COST THIS SCRIPT TWELVE SCREENS.
    # Under `set -e` plus `pipefail`, a command substitution whose pipeline fails aborts
    # the whole run - so when a capture produced no `shot state:` line at all (grep exits
    # 1), the sweep stopped dead at that target instead of logging a failure and moving on.
    # It looked like a SUCCESS from outside, because callers pipe this script into `tail`
    # and the pipeline reports tail's status. Two full sweeps came back "20/20 captured"
    # with a third of the list never attempted. A missing state line is exactly the case
    # the retry and the FAILED branch below already exist to handle.
    got="$(grep -m1 '^shot state: ' "$log" | awk '{print $4}' || true)"
    if [[ -s "$out" ]] && frame_is_blank "$out"; then
      log_warn "$name -> captured a BLANK frame - retrying"
      rm -f "$out"
      continue
    fi
    [[ -z "$expect" || "$got" == "$expect" ]] && break
    log_warn "$name -> captured '$got', expected '$expect' - retrying"
    rm -f "$out"
  done

  if [[ ! -s "$out" ]]; then
    log_warn "$name -> FAILED (see log below; screen may need more game state than a cold boot gives it)"
    tail -10 "$log" | sed 's/^/    /'
    fail=$((fail + 1))
  elif frame_is_blank "$out"; then
    log_err "$name -> BLANK FRAME twice (viewport read before anything was presented)"
    blank=$((blank + 1))
    fail=$((fail + 1))
  elif [[ -n "$expect" && "$got" != "$expect" ]]; then
    log_err "$name -> WRONG SCREEN: captured '$got', expected '$expect' (twice)"
    wrong=$((wrong + 1))
    fail=$((fail + 1))
  else
    log_ok "$name -> $out${expect:+  [$got]}"
    ok=$((ok + 1))
  fi
  rm -f "$log"
done

echo
log_info "Captured $ok/$((ok + fail)) screens."
[[ $wrong -gt 0 ]] && log_err "$wrong screen(s) photographed the wrong state twice - see above."
[[ $blank -gt 0 ]] && log_err "$blank screen(s) came back blank twice - see above."

# --- STALE-FRAME GUARD (the belt to the state assertion's braces) -------------
# The state check above catches a capture that landed in the wrong SCREEN. This
# catches one that landed in the right screen but an old FRAME of it, which the
# state name cannot distinguish.
# CLAUDE.md's own gotcha: `--shot` reads get_viewport().get_texture().get_image(),
# which hands back the last PRESENTED frame, and macOS throttles presentation for
# an unfocused window - so an unfocused capture can silently write a frame from
# seconds ago, i.e. the WRONG SCREEN. The file still appears and is still a
# plausible size, which is exactly why "did it produce a PNG?" never caught it.
#
# gen_char_refs.sh solves this by forcing focus with osascript. That is the wrong
# trade here: this script captures 32 screens, and grabbing the desktop 32 times
# hijacks the machine while Louis is using it.
#
# So detect the failure instead of preventing it, using a property of the target
# list: every screen above is a DIFFERENT picture. Two byte-identical captures can
# therefore only mean one frame got served twice. Cheap, exact, and it never
# touches window focus.
dupe_hashes=$(md5 -r artifacts/screenshots/*_"${ts}".png 2>/dev/null | awk '{print $1}' | sort | uniq -d)
if [[ -n "$dupe_hashes" ]]; then
  log_err "Identical frame(s) captured for different screens:"
  while read -r h; do
    [[ -z "$h" ]] && continue
    md5 -r artifacts/screenshots/*_"${ts}".png | awk -v h="$h" '$1==h {print "    " $2}'
    echo
  done <<<"$dupe_hashes"
  log_err "Two screens cannot legitimately be the same picture. Either a capture went"
  log_err "stale, or - more often - a dev flag in the pair above silently does nothing."
  exit 1
fi
log_ok "No duplicate frames - every screen captured its own picture."

# --- ART-GRID SWEEP ----------------------------------------------------------
# The one place this measurement is worth comparing run to run. validate.sh runs
# the same check but only on a LIVE ACT frame, which varies 22-28% between
# identical runs (props mid-flight, flowers in the air) and so says nothing.
# Most screens here are static, so their numbers are stable and a move is real.
# Read it as "how much of this screen is still vector drawing", remembering that
# text is off-grid on purpose - see scripts/check_pixel_grid.py's header.
if [[ -x .venv/bin/python ]]; then
  echo
  log_head "Art-grid drift, worst first"
  .venv/bin/python scripts/check_pixel_grid.py artifacts/screenshots/*_"${ts}".png \
    | sed 's/^/    /'
  log_info "--map <png> <out.png> paints the off-grid blocks magenta."
fi

[[ $ok -gt 0 ]]  # exit 0 if at least one screen succeeded
