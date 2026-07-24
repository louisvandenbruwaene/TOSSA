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
  trick, P = pattern, O = object, 1/2 = step the count down/up (`k_count`; not one
  of the six remappable actions - device-aware only, Back/R3 on a pad), R = restart
  (practice only), S = shop, Tab = sheet, Esc = game menu, Enter = finish/cash in.
  Throw/catch/trick/switch-trick/pattern/restart are the six remappable actions.
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
  colours the whole act, rolled per act from The Street up, never the Backyard
  (`roll_encore`). "For the Danger" (only clubs/knives/torches score) is further
  excluded below The Circus AND unless a qualifying prop is owned in MIN_BALLS
  (3) quantity - owning a single club is not enough to switch to and juggle it,
  so it must never land on a player who cannot yet field a real routine under it.
- **Records/pay/rep:** records are the act's score per venue (assisted and Purist
  boards). Pay scales with surviving score; rep swings on goals reached (0 of 3
  loses rep). The WIN is a record at the World Arena - `TOP_VENUE` (5), which
  must never move. **The Midnight Show** (2026-07-18) is a 7th, bonus venue past
  it: gated on `won == true` AND Reputation 6000 (Legend), not reachable before
  the real win. A genuinely dark stage (`spot` half the Backyard's, the previous
  dimmest) built for the Glow-in-the-Dark Kit to actually matter in - the
  performer's suit nearly vanishes, the vest glows the Kit's own phosphor green.
  `MAX_VENUE` (6) is the real venue-count ceiling now, distinct from `TOP_VENUE`.
- **DAILY CHALLENGE** (2026-07-24, **UNVERIFIED** - see the caveat at the end of this
  entry): a new day-hub row beside PERFORM, same cost (a day segment) and the same
  real booking flow end to end (goals, pay, rep, records) - the only difference is
  WHERE and WHAT: venue and Encore are both seeded off today's date (`daily_seed`,
  `daily_venue`, `daily_encore`) instead of chosen/rolled, so two players on the same
  calendar day face the identical stage and challenge and only their own hands decide
  the score. Venue is still capped at whatever THIS save's Reputation has unlocked
  (`daily_venue`, same rule as `play_venue`), so it is comparable, not identical,
  across two careers at different points. `roll_encore`'s exclusion rules (no Encore
  below the Backyard, "For the Danger" gated below The Circus and MIN_BALLS) were
  factored out into `encore_pool` so the random roll and the seeded pick can never
  disagree. On resolve, a one-line shareable result (`daily_share` - venue, Encore,
  goals, score, best streak) is copied to the OS clipboard immediately and then shown
  as the day-hub's transient message on return from the results card. `--daily` (see
  Verification workflow) jumps a headless run straight into today's seeded act.
  **This whole entry was written and coded by Claude in a session with no Godot binary
  available to run the parse-check, `--daily --demo --booking`, or an actual playtest
  - none of it has been verified. Run the standard workflow below (parse-check first,
  then `--daily --demo --booking`, then a real hands-on pass over a couple of
  calendar-seeded venues) before trusting any of this description or the code behind it.**
- **The day loop:** day segments spent on perform/practice/eat/sleep/shop/skills.
  Stamina persists; sleep/meals restore it. Practice grants XP (per catch and a
  completion bonus banked even when leaving via Enter). The Energy-Drink Helmet
  (2026-07-19, ENERGY_HELMET_COST, 10,000g gear) is the alternative: buying it
  tops stamina up on the spot, and Energy Drinks bought after (ENERGY_DRINK_
  BATCH_COST, a bulk-only buy - 10 for 40g, cheaper than one at a time) sit in
  reserve and auto-pour through `spend_stamina` the instant stamina would
  actually hit empty, `+ENERGY_DRINK_STAMINA_PCT` (10%) each - a stocked player
  never sees EAT or SLEEP's gate (`too_tired`) at all, by design.
- **Skills screen:** every trick and pattern, whether it's yours yet, and the exact
  keys that pull it off. A selected PATTERN (2026-07-18, slowed/tightened/rebuilt
  2026-07-19 x2) also gets a live PREVIEW box (`draw_pattern_preview`): a small self-
  looping schematic built from the pattern's real inner/outer hand points and
  relative throw-height rules (see `pattern_preview_tracks`), not a real sim and not
  hooked to the live `balls`/`pattern` state - safe to animate from any screen. Every
  ball position is hard-clamped inside the box as a guarantee, not just sized to fit.
  `--skills [N]` dev flag opens it for a screenshot, optionally selecting entry N.
- **Arms mostly reach two points, `inner_pos` and `outer_pos`** - the same two
  the 3-ball Cascade always used. Amended 2026-07-19 (same day, later): a
  realistic-timing collision audit (`--latecatch`, see Verification workflow)
  found a genuine PERFECT-catch-then-immediate-throw could overlap wherever
  more than one ball shares a hand's own road at once - the even-count
  Cascade same-hand pair, and (Half Shower/Shower/Tennis cross every throw
  regardless of count, unlike Cascade) as early as four balls for those. Louis
  authorized a THIRD kind of position for exactly this case: a straight
  up-and-down `same_hand_lane_pool()` lane, toward centre from `inner_pos`,
  for whichever ball isn't alone on its road (`road_lane`) - explicitly not
  the rejected fix (the same-hand pair used to widen its landing 22px PAST
  `outer_pos`; "outward, past the established reach" was the objection this
  rule existed to stop). A crossing throw never gets a lane (pulling it
  toward centre closes the gap with the opposite line it crosses, measured
  worse not better) - that risk is carried by `prop_hit_scale` instead, whose
  shrink now starts at 4 balls and reaches a much lower floor by 4-5 rather
  than barely doing anything until 6+. Columns' lanes remain their own older,
  separate thing. The goal throughout was a CONSISTENT margin comparable to
  the Perfect catch window's own tolerance, not a hunt for exact zero on
  every single count/pattern/prop/trick - some combinations (Half Shower/
  Tennis around 5 balls, Cascade's highest odd counts at one specific catch
  offset) still carry a small (a few px) residual, left as an accepted
  tradeoff rather than chased with an ever-smaller hitbox.
- **Patterns, current roster (2026-07-19, second pass):** Cascade, Columns, Half
  Shower, Shower, Reverse Cascade, Tennis - six now, down from eight at the start
  of the day. **Fountain was removed** (Louis: "fountain isn't a pattern, that's
  just cascade for 4 balls") and folded into Cascade: the mechanic is unchanged
  (Cascade still crosses at an odd count, keeps each hand its own ball at an even
  one - `do_throw`'s `cross`), there is just no separate PATTERNS entry, unlock, or
  score multiplier for the even-count face any more, and its old same-hand landing
  no longer widens 22px past `outer_pos` (see the arms rule above - measured
  clearance dropped to ~5px via `--collcheck`, tight but real, an accepted
  tradeoff). Its preview is now Cascade's own, shown at 4 balls specifically since
  the odd/crossing face is already obvious from the weave shape at any other
  count; Columns' preview now runs 3 balls (two side lanes plus the odd-count
  middle lane) instead of 2. **Waterfall was removed** (Louis: identical to Half
  Shower) and folded into Half Shower, whose own weave side is now capped LOW
  (`HALFSHOWER_LOW`, 0.2) - it still crossed the over-the-top road too often with
  only `HALFSHOWER_MIN` raising the high side's floor. `load_progress` carries a
  versioned migration (`pattern_ver`, persisted) mapping any pre-2026-07-19 save's
  `pattern_sel` straight from the ORIGINAL 8-entry layout to the current one in one
  jump, folding Fountain and Waterfall into their closest surviving relative
  rather than letting either silently become whatever now sits at their old index.
- **A crossed even-count trick** stays a captured, unbuilt idea (see Still open
  below) - Louis confirmed the underlying odd/even mechanic itself is correct and
  should stay exactly as it is; only the separate "Fountain" PRESENTATION went.
- **Tutorial (the basics):** two guided call-and-response steps at 50% slowmo, then
  freestyle 1 ball, 2 balls (forced cascade so throws cross), then the finale: ten
  consecutive juggling catches of the 3-ball cascade at genuine full speed. The pace
  ladder TUT_PACES [0.5, 0.25, 0.15, 0.0] steps faster every 4 clean catches and
  back up on a drop. Enter appears ONLY between freestyle steps and always adds a
  ball. Trick/pattern/prop/count lessons queue at the hub's LEARN row on unlock.
  **Lesson UI (2026-07-18):** a small top card carries only the kind tag, the
  step's one-line title, and progress - the old two-line paragraph is gone from
  the live HUD. Throw/catch keys are bare letters over each hand (`draw_tut_key`
  via `draw_tut_prompts`, unboxed, no change from Louis's original approve). A
  hand still holding a ball NEVER shows a catch ring, however soon something
  else lands there - it keeps naming its own throw key until the stack is
  completely empty (Louis, three times: throw always outranks catch for a hand
  with a ball still in it). A key with no hand of its own - trick/pattern/
  restart - reads off the live sim (`tut_action_cue`) and shows in the same
  bordered-keycap slot as the Enter callout, dead centre at the bottom
  (`draw_tut_special_cue`). A "live" trick (Spin) only ever appears there when
  pressing it would actually fire - enough balls airborne AND off cooldown -
  which is what fixed "I press Space, it doesn't recognise": the old prompt was
  baked into the step text with no check against on_trick()'s own gate.
- **Unlocks (reward design):** never XP alone. Each new stage guarantees one arrival
  skill gated on the venue only: Street=Behind the Back, Theatre=Spin, Circus=Shower,
  Championship=Reverse Cascade, World Arena=Tennis. Composite level/stat walls fill
  the stretches between (High Toss lvl 3, Columns lvl4/acc8, Overthrow lvl6/str10,
  Half Shower lvl8/acc12/ven1). The REWARD DIRECTOR
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
- `--demo` autoplays; `--collcheck` audits mid-air clearance (self-drives now: it
  implies `--demo`, so a bare `--collcheck` actually juggles instead of reporting the
  1000000 px sentinel - and a run that still measured nothing prints a WARNING rather
  than a false all-clear); `--calib N` prints the
  robot's score; `--booking` runs a real act end to end and prints `ACT ...` on
  resolve; `--tutorial <id>` jumps into a lesson (the demo walks lessons end to end,
  miming Enter/R/P); `--remap` (add `--pad` for the gamepad column) opens the
  Controls screen; `--capsule` renders pure key-art (no UI) for Steam store
  assets - capture at native 1280x720 (`--shot <path> --shotat 30`), then
  `sips --cropToHeightWidth 706 1232 <path>` for a distortion-free 2x Main
  Capsule, `sips -z 353 616 <path>` to the real 616x353; `--glow` owns the
  Glow-in-the-Dark Kit for the session (no save touched) - pair with
  `--booking --encore blackout` to screenshot it. Windowed
  `--shot <path> --shotat <frame>` captures a frame. `--daily` (2026-07-24,
  unverified - see the Daily Challenge entry above) is used the same way as
  `--booking` but seeds today's venue/Encore instead of rolling; combine with
  `--demo` to auto-play it end to end (prints the shareable result line on resolve,
  same moment as `--booking`'s `ACT ...` line). Unlike `--booking`, it is not
  wired into `--establish`'s explicit-venue screenshot path - `--establish N`
  always means venue N specifically, which a seeded venue would fight.
- Parse check: `godot --headless --check-only --script Game.gd` (catches unknown
  identifiers, not just syntax; it does NOT catch a runtime type error like
  comparing a Dictionary's String value against an int constant - that only
  throws once the exact branch runs, and a script error mid-`_draw()` silently
  skips the rest of that draw call rather than crashing, which can look like a
  rendering bug rather than the type error it actually is. Check the run's
  stderr for `SCRIPT ERROR`, not just the screenshot, after any risky edit.)
- Dev flags parse only in debug builds (`OS.is_debug_build()`); release exports
  ignore them all.
- `--collcheck` (audits mid-air clearance) used to only ever exercise
  FRAME-PERFECT bot timing: near-instant catches, throws on a fixed metronome.
  `--latecatch N` (2026-07-19) is a realistic-timing variant: it catches N
  ticks LATE of a ball's ideal `land_tick` - still a genuine Perfect catch as
  long as N is within `perfect_window()` (0-7 for every player; up to 10 with
  enough Focus) - and immediately re-throws that hand on the very same tick,
  so the audit can answer "does a real, not-frame-0 Perfect catch followed by
  an immediate throw still clear?" It found real overlaps the frame-perfect
  bot never could: Cascade's even-count same-hand face, its own high-count
  faces of both parities, and Half Shower/Shower/Tennis's crossing weave as
  early as four balls (see the arms-mostly-two-points entry above for the
  fix - a `same_hand_lane_pool()` lane plus a much earlier, lower
  `prop_hit_scale` floor). Sweep it alongside `--balls`/`--pattern`/`--prop`/
  `--trick` - it is a permanent tool now, not a one-off finding.

## Music / audio

Louis's Suno tracks ("Juggling Game.mp3" juggling states, "Chill Trio Mix" for
menus/hub/results) loop with per-state volume automation; free-tier renders are
NON-COMMERCIAL - he will re-render under one paid Suno month before release and swap
the files. SFX are synthesized at startup (`gen_sfx`); catch sounds are quality-led
(perfect sparkle / good / dull late), crowd bed deleted, tonal stingers only.

## Still open (from ideas.rtf and the old docs, worth doing)

- **Teaching lessons as income** (mastered skills earn gold/rep as a day action).
- **A crossed even-count trick** (Louis, 2026-07-19, tentative - "perhaps"): a way to
  juggle an even ball count with Cascade-style crossing throws instead of Cascade's
  own natural same-hand face at that count, maybe by borrowing the throw rhythm of
  count-1 or count+1. Not designed or built - needs real shape/balance work first.
- **Eating eggs** (+10 stamina food that doubles as a risky scoring prop).
- **Rep pressure by difficulty:** make high venues effectively demand heavy props /
  high counts (Louis: "near impossible to unlock high venues with only 3 balls") -
  the goal numbers enforce some of this; validate with --calib per prop/count.
- **Cosmetics:** the Glow-in-the-Dark Kit is built (60,000g gear, GLOW_KIT_COST -
  makes Blackout's dark stretch an almost-fully-visible colour halo, brightened
  2026-07-19 off its original faint 0.09 alpha (too hard to actually see, not
  the "mercy" it was meant to be), see `draw_glow_in_dark` / `has_glow_kit`;
  Blackout itself was softened the same day - the SHAPE still goes past the
  apex, but the comet trail stays lit for everyone, and a torch's own flame is
  bright now too, not faint), and so is The Midnight Show, the
  bonus post-game venue it's really for (see the Records/pay/rep bullet above);
  player/prop skins beyond those two still open.
- **Settings depth:** Music/Sound are volume sliders now (not just on/off);
  separate per-channel sliders (catch/crowd/ambient) and difficulty presets
  alongside hard-mode collisions still open.
- **Steam:** capsule art is built (`--capsule` dev flag, see Verification workflow
  below). Steamworks integration (achievements, cloud saves, real leaderboards off
  the Purist boards) still needs Louis's own Partner account + App ID - not
  something buildable without those credentials. Deferred: slow-mo shader polish.
- **Later/maybe:** multiplayer, cross-platform saves, training-room variety,
  stage-specific music, costumes.
- **A post-win chase (Legend runs), from a 2026-07-19 professionalism pass:** true
  encore-stacking needs `encore` (a single int, not a list) turned into an array and
  every `encore_*_mult` function updated to combine active challenges - a real
  refactor, not a content change. A cheaper version gets most of the same payoff for
  free: a Purist-only replay of the full ladder, gated on `won`, touching none of the
  encore system.
- **Grow the ENCORES deck:** pure content. `ENCORES` is a flat array read through the
  single `encore_on(id)` choke point - a new challenge is one dict entry plus usually
  one `if encore_on(...)` check in whichever multiplier function it affects.
- ~~A seeded daily/weekly challenge act~~ - **built 2026-07-24, UNVERIFIED** (see the
  Daily Challenge entry above): venue/Encore seed off the date, the goal numbers
  already fall out of venue via the existing formula so nothing separate was needed
  there. Not yet confirmed to actually run correctly - the whole item is Claude's
  code from a session with no Godot to check it against.
- **The crowd reacting to a BAD night, not just a good one** - **built 2026-07-24,
  UNVERIFIED**: `draw_crowd` now gives each seat a stable per-seat threshold
  (`CROWD_LEAVE_BAND`) below which it goes empty as `applause` craters, on top of the
  existing bob/brighten/hands-up as it climbs. Untested - eye-check that it actually
  reads as "people leaving" and not as visual noise or flicker before trusting it.
- **Escalating streak feedback** - **built 2026-07-24, UNVERIFIED**: `streak % 10`
  milestones now scale by tier (every 50 bigger, every 100 biggest: more freeze, more
  rings, a confetti burst via the existing `spawn_parts` "confetti" kind). Untested -
  confirm the tiering actually feels escalating rather than just louder, and that the
  confetti burst doesn't clutter a real multi-ball set.
- **A colorblind pass:** mostly already true. PERFECT/GOOD/late/drop popups all pair
  a color with distinct literal text, so color is rarely the only signal - this is an
  audit more than a redesign. The stamina bar's green-to-red lerp got a second,
  non-color signal (2026-07-24, UNVERIFIED: the label itself now reads "STAMINA -
  LOW" and pulses under `STAM_LOW`) alongside its existing numeric readout - still
  needs an actual eye-check, ideally from someone who is colorblind, not just a
  claim that the code does the right thing.
- **A trailer** built from the existing `--shot`/`--shotat`/`--booking` capture
  tooling - assembly work outside the codebase, maybe one or two new shot sequences
  for beats the current dev flags can't already stage.
- **A scoped free demo:** `MAX_VENUE` is a `const`, so it cannot be dialed down by a
  runtime flag. Needs a fourth export preset with its own `custom_features` tag and
  one `OS.has_feature("demo")` check where progression should stop, showing a
  wishlist card instead of continuing.

## Gotchas that keep biting

- Godot user args need `--` (see above).
- Never accumulate a long-running phase in a PackedFloat32Array (loop clicks).
- Array-indexed numeric literals infer Variant: type the array or cast.
- `cine_tick` runs at 120/s: halve intuitive sin rates.
- Screenshot captures of BACKGROUND windows can show a stale render: foreground the
  window, or capture early frames.
- The IACTO juggler figure (stance, proportions) is settled: never reshape it as a
  side effect of a mechanics fix.
