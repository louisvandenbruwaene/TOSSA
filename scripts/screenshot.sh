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
  "day_hub_work:40:day:--day work"
  "day_hub_rest:40:day:--day rest"
  "day_hub_prep:40:day:--day prep"
  "shop:60:shop:--shop"
  "skills:40:skills:--skills"
  "sheet:40:sheet:--sheet"
  "pause:60:pause:--pause"
  "in_act_stage:700:play:--demo --booking --venue 4"
  "results:60:results:--results"
  "credits:60:credits:--credits"
  # --- menus and meta screens ----------------------------------------------
  "settings:40:settings:--settings"
  "slots:40:slots:--slots"
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
  "stage_booed:700:play:--demo --booking --venue 2 --boo"
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
    got="$(grep -m1 '^shot state: ' "$log" | awk '{print $4}')"
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
