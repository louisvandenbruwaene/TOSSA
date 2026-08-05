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
declare -a TARGETS=(
  # --- the screens a player sees every run --------------------------------
  "title:60:--menu"
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
  # --- menus and meta screens ----------------------------------------------
  "settings:40:--settings"
  "slots:40:--slots"
  "stats:40:--stats"
  "f9_experiments:40:--f9"
  # --- the dressing room, and the figure actually dressed -------------------
  "tailor:60:--tailor 0"
  "dressed_stage:700:--demo --booking --venue 4 --wardrobe"
  # --- stage variants that change the whole picture -------------------------
  # Blackout (venue 5) is the venue the glowing kit exists for, and --nokit is
  # its mirror: the demo save owns glowing props, so without it every dark-stage
  # capture was silently the charged version.
  "stage_blackout_glow:700:--demo --booking --venue 5 --glow"
  "stage_blackout_dark:700:--demo --booking --venue 5 --nokit"
  "stage_booed:700:--demo --booking --venue 2 --boo"
  "stage_eggbreak:120:--demo --eggbreak"
  # --- cards, banners and one-off end screens -------------------------------
  "establish:60:--establish 3 --booking"
  "unlock_banner:60:--results --unlock"
  "ucard_trick:90:--demo --booking --ucard trick:spin"
  "ucard_back:60:--demo --booking --ucard back:trick"
  "tutorial:60:--tutorial balls"
  "tutdone:60:--tutdone"
  "menutour:60:--menutour"
  "purist_legend:60:--legend"
  "gameover:60:--gameover"
  "demo_wallcard:60:--wallcard"
)

for entry in "${TARGETS[@]}"; do
  name="${entry%%:*}"
  rest="${entry#*:}"
  tick="${rest%%:*}"
  flags="${rest#*:}"
  out="artifacts/screenshots/${name}_${ts}.png"
  log="$(mktemp)"
  # shellcheck disable=SC2086
  # 45s, not 30: a --shotat 700 stage capture has to actually play ~700 ticks
  # before it can save, and validate.sh's own equivalent step already uses 45.
  # A success quits as soon as the shot is written, so the ceiling only costs
  # wall-clock on a screen that was going to fail anyway.
  run_windowed 45 "$log" $flags --shot "$out" --shotat "$tick" || true
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

# --- STALE-FRAME GUARD -------------------------------------------------------
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
dupes=$(md5 -q artifacts/screenshots/*_"${ts}".png 2>/dev/null | sort | uniq -d | wc -l | tr -d ' ')
if [[ "${dupes:-0}" -gt 0 ]]; then
  log_err "$dupes duplicate frame(s) - a capture went stale and served another screen's frame."
  log_err "Re-run with the window focused, or capture the affected screens one at a time:"
  md5 artifacts/screenshots/*_"${ts}".png | awk '{print $NF, $1}' | sort -k2 \
    | awk '{if ($2==p) print "    " l "\n    " $1; p=$2; l=$1}' | sort -u
  exit 1
fi
log_ok "No duplicate frames - every screen captured its own picture."

[[ $ok -gt 0 ]]  # exit 0 if at least one screen succeeded
