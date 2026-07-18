# IACTO

A skill-based juggling game with a light performer-career sim around it. Godot 4.7, 2D,
GDScript, one self-contained file (`Game.gd`), code-only art and mostly code-rendered
audio, aimed at a polished $10 Steam release. This file is THE working document: the
old GDD/STORY/ROADMAP/PLAN/ART docs and ideas.rtf were distilled into it (2026-07-17)
and deleted. History lives in git.

## The three pillars (never trade these away)

1. **Skill first.** Stats govern access and comfort (which props and counts are
   practical, how forgiving catches are). Player skill governs excellence (score,
   records, high counts). Stats must never auto-play the timing floor.
2. **Juggling is real.** At least one prop in the air at all times, else it is just
   throwing and catching one object - the sim, the scoring, and the tutorial all
   enforce this (`juggling_catch`).
3. **The first impression is calm.** Chill music (Louis's own Suno tracks), warm
   theatrical stage, smooth UI. The dopamine is in the catch/drop sounds, streaks,
   tricks, and unlocks - not in flash.

## How the game plays now

- **Input:** per hand a THROW (F/J) and a CATCH (D/K), Space = trick, C = switch
  trick, P = pattern, O = object, 3-9 = count, R = restart (practice only), S = shop,
  Tab = sheet, Esc = game menu, Enter = finish/cash in. All remappable (six actions).
- **Controller (Louis's own layout, X/Y and A/B swapped 2026-07-18):** bumpers
  throw, triggers catch (always fixed, never remapped), X = Space/trick, A = Enter,
  B = Escape, Y = Tab; dpad in play: up O, right P, down S, left R (menus: dpad =
  arrows); both sticks move menu focus. Trick-cycling (Switch Trick) now has a pad
  button too (default Left Stick click). TRICK and Switch Trick are remappable to
  any pad button via Settings > Controls, which now has a keyboard column and a
  gamepad column (Tab, or the pad's own Y, swaps focus between them).
- **Throw model:** a tap is the lowest, snappiest throw; holding lifts continuously
  toward 1.4 (1.8 for a held High Toss). Height buys airtime, costs accuracy.
  Under-Strength throws sag and wobble. (ideas.rtf's discrete five heights were
  deliberately replaced by this continuous model after playtesting.)
- **Catch model:** Perfect always secures; Good/Late are a chance that rises with
  Accuracy and falls with throw height. Focus (Accuracy past 100) first cuts stamina
  costs, then widens the Perfect window (to 250).
- **THE ACT (performances):** one continuous act at the chosen venue, three GOALS
  (first/second/final = VENUE_BASE x GOAL_STEP [1.0, 1.9, 3.2] x ante). From the
  first goal on you may CASH IN at any time: press Enter, or catch every ball and
  hold them (the empty air ends the act). A collapse (crowd empties, drop limit,
  or empty stamina) strips the score back to the last goal reached, and the player
  is told the ONE real reason they failed. One optional CHALLENGE (ENCORES deck)
  colours the whole act, rolled per act from The Street up, never the Backyard.
- **Records/pay/rep:** records are the act's score per venue (assisted and Purist
  boards). Pay scales with surviving score; rep swings on goals reached (0 of 3
  loses rep). The WIN is a record at the World Arena.
- **The day loop:** day segments spent on perform/practice/eat/sleep/shop/skills.
  Stamina persists; sleep/meals restore it. Practice grants XP (per catch and a
  completion bonus banked even when leaving via Enter).
- **Tutorial (the basics):** two guided call-and-response steps at 50% slowmo, then
  freestyle 1 ball, 2 balls (forced cascade so throws cross), then the finale: ten
  consecutive juggling catches of the 3-ball cascade at genuine full speed. The pace
  ladder TUT_PACES [0.5, 0.25, 0.15, 0.0] steps faster every 4 clean catches and
  back up on a drop. Enter appears ONLY between freestyle steps and always adds a
  ball. Trick/pattern/prop/count lessons queue at the hub's LEARN row on unlock.
- **Unlocks (reward design):** never XP alone. Each new stage guarantees one arrival
  skill gated on the venue only: Street=Behind the Back, Theatre=Spin, Circus=Shower,
  Championship=Reverse Cascade, World Arena=Tennis. Composite level/stat walls fill
  the stretches between (High Toss lvl 3, Columns lvl4/acc8, Overthrow lvl6/str10,
  Half Shower lvl8/acc12/ven1, Waterfall lvl11/str14/ven2). The REWARD DIRECTOR
  (enter_day) gifts the nearest walled skill after 6 acts without any unlock, leaves
  a pie for a broke player (one per day), and buys one once-per-career meal when
  broke and spent.
- **Completion arc:** points per level = 3 + level/12, so the four stat caps
  (Acc 250, Str/End/Spd 200 = 839 points) complete at ~level 115, ~2.4M XP,
  roughly 30-40 hours of skilled play. All content unlocks by ~level 20-25.
  After the caps, MASTERY converts level-ups to gold.

## Verification workflow (hard-won)

- Dev flags MUST follow a bare `--` separator: `godot --headless -- --demo --booking
  --venue 2 --shotat 25000`. Without `--`, `OS.get_cmdline_user_args()` is empty and
  the game sits at the menu forever (looks like a hang - burned two sessions).
- `--demo` autoplays; `--collcheck` audits mid-air clearance; `--calib N` prints the
  robot's score; `--booking` runs a real act end to end and prints `ACT ...` on
  resolve; `--tutorial <id>` jumps into a lesson (the demo walks lessons end to end,
  miming Enter/R/P); `--remap` (add `--pad` for the gamepad column) opens the
  Controls screen; `--capsule` renders pure key-art (no UI) for Steam store
  assets - capture at native 1280x720 (`--shot <path> --shotat 30`), then
  `sips --cropToHeightWidth 706 1232 <path>` for a distortion-free 2x Main
  Capsule, `sips -z 353 616 <path>` to the real 616x353. Windowed
  `--shot <path> --shotat <frame>` captures a frame.
- Parse check: `godot --headless --check-only --script Game.gd` (catches unknown
  identifiers, not just syntax).
- Dev flags parse only in debug builds (`OS.is_debug_build()`); release exports
  ignore them all.

## Music / audio

Louis's Suno tracks ("Juggling Game.mp3" juggling states, "Chill Trio Mix" for
menus/hub/results) loop with per-state volume automation; free-tier renders are
NON-COMMERCIAL - he will re-render under one paid Suno month before release and swap
the files. SFX are synthesized at startup (`gen_sfx`); catch sounds are quality-led
(perfect sparkle / good / dull late), crowd bed deleted, tonal stingers only.

## Still open (from ideas.rtf and the old docs, worth doing)

- **Teaching lessons as income** (mastered skills earn gold/rep as a day action).
- **Eating eggs** (+10 stamina food that doubles as a risky scoring prop).
- **Rep pressure by difficulty:** make high venues effectively demand heavy props /
  high counts (Louis: "near impossible to unlock high venues with only 3 balls") -
  the goal numbers enforce some of this; validate with --calib per prop/count.
- **Cosmetics:** player/prop skins, the Glow-in-the-Dark set (a visual challenge).
- **Settings depth:** separate audio sliders (catch/crowd/ambient), difficulty
  presets alongside hard-mode collisions.
- **Steam:** Steamworks integration, capsule art. Deferred: slow-mo shader polish.
- **Later/maybe:** multiplayer, cross-platform saves, training-room variety,
  stage-specific music, costumes.

## Gotchas that keep biting

- Godot user args need `--` (see above).
- Never accumulate a long-running phase in a PackedFloat32Array (loop clicks).
- Array-indexed numeric literals infer Variant: type the array or cast.
- `cine_tick` runs at 120/s: halve intuitive sin rates.
- Screenshot captures of BACKGROUND windows can show a stale render: foreground the
  window, or capture early frames.
- The IACTO juggler figure (stance, proportions) is settled: never reshape it as a
  side effect of a mechanics fix.
