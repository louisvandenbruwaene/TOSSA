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
- **PROP IDENTITY (2026-07-26, VERIFIED with --maxstats calib):** every prop class is a
  real CHOICE, not just a heavier ball, across four levers held in `PROPS` + code, so a
  matched choice is rewarded and a mismatched one punished (the balance goal). Perfect
  window (`pwin`, difficulty): balls/eggs/rings 7, clubs 6 (forgiving for its weight),
  knives 5, torches 4, floored at `PWIN_FLOOR` 3 so heavy+Cold Hands stays hittable.
  Score multiplier (`smult`, reward, read by `prop_score_mult` -> `object_mult`): balls
  1.00 up to torches 1.70, replacing the old flat per-weight-step bonus - climbing weight
  AND count compounds. Throw stamina (`stam`, the early limiter): rings cut to 2 as their
  low-stamina signature (the endurance prop). Catch forgiveness (`fgive`): clubs +0.12 on
  off-Perfect, even in Purist. CONTEXT edges live in code, never flat fields, and only ever
  ADD: torches +`DARK_PROP_BONUS` (0.30) where the stage is dark (`is_dark_context`:
  Blackout, Stage Fright, the Midnight Show - all softened or late, so "only torches are
  juggleable" never lands before the player would own them), knives +`PICKY_PROP_BONUS`
  (0.30) before a hard-to-please crowd (`is_picky_crowd`: The Critic, The Hecklers) plus a
  weight-scaled `prop_thrill` patience feed on Perfect catches. Calib proof: a master earns
  monotonically more per weight step (torches x7 678k vs balls x7 399k), an uninvested
  player collapses on the same heavy props (torches x5 12k vs balls x5 239k), 3 balls stays
  locked out of venue 5, dark/picky A/B edges land on +17.6%/+19.3%. `--maxstats` (dev)
  models a fully invested master so a heavy-prop calib is fair (a bare-Strength one is not).
- **UI look (2026-07-26 polish pass):** the shared `soft_card` primitive (StyleBoxFlat:
  rounded corners, soft drop shadow, faint top sheen) is THE card now - `hud_card`,
  `hud_panel`, `draw_meter`, and every big screen container route through it, so depth is
  consistent and the old flat-rectangle "cheap" look is gone. When adding a panel, use
  `soft_card`, not a bare `draw_rect`. The shop gained a detail strip that names the
  selected prop's signature edge and a "pays xN.NN" line per card (the reward, legible at
  the point of choice).
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
  **PARTLY VERIFIED (2026-07-26):** parse-check passes, and `--daily --demo --booking`
  resolves a whole seeded act end to end with no script error (prints a normal `ACT ...`
  line - venue seeded off the date, goals/pay/rep/records all fire). The error-scan
  across day/results/booking/daily also came up clean. What is still NOT done is a real
  HANDS-ON human pass over a couple of calendar-seeded venues and a check that the shared
  result line actually lands on the clipboard - do that before calling it shipping-ready.
- **EXPERIMENTS panel** (2026-07-25): F9, from anywhere, opens a small
  debug-only overlay (`debug_panel_open`, `draw_debug_panel`) listing named toggles
  (`experiments`, a `Dictionary`, defined in `EXPERIMENT_DEFS`) that switch an
  alternate version of a screen on or off live, no restart and no code edit - the
  point being to compare two real implementations side by side rather than guess from
  a description. **2026-07-26: the reworked variants were all polished and three
  (`talent_tree`, `settings_cards`, `pause_cards`) now DEFAULT ON - they are the shipped
  look, F9 toggles each OFF to compare with the classic. `slot_cards` (Save files as
  portrait cards) is a fourth, added the same day, default OFF for Louis to choose.** Persisted in the settings file so a choice survives a relaunch, but
  the PANEL that can ever flip one is gated behind `OS.is_debug_build()` like every
  other dev surface here, so a release export always runs every experiment at its
  shipped default. Adding a second experiment later is one `EXPERIMENT_DEFS` entry
  plus whatever `if experiments.get("id", false):` branch it actually switches -
  `talent_tree` below is the template.
- **TALENT TREE stat screen** (2026-07-25, **UNVERIFIED**, behind the `talent_tree`
  experiment, off by default): an alternate version of the character sheet (Tab) -
  the classic four-card version (`draw_sheet`) is untouched and stays the default.
  `draw_sheet_screen` is now the one call site every screen uses to open "the sheet";
  it routes to `draw_talent_tree` when the experiment is on, `draw_sheet` otherwise.
  Both draw functions share `sheet_sel`/`sheet_input`/`invest()`/`_adjust()` completely
  unchanged - the tree is a different PICTURE of the same four stats, spending the
  same points against the same caps through the same keys, never a second stat
  system. What it adds over the cards: a hub with four lane-branches (one per stat,
  fixed rows inside the panel so nothing can ever draw outside it, regardless of
  angle math), each branch's nodes pulled from the REAL thresholds `PATTERNS`/
  `TRICKS` already gate on that stat (`talent_nodes` - e.g. Columns at Accuracy 8,
  Overthrow at Strength 10), so a node names the actual skill your next point buys
  instead of just a bigger number. Endurance and Speed gate no skill directly, so
  their branches get three even milestones instead, purely to keep all four branches
  looking alike - the real value is still exactly what the classic sheet shows.
  **FULLY REDESIGNED 2026-07-26 (Louis: the old node-graph "looked horrible").** The
  sparse horizontal wiring diagram is gone. `draw_talent_tree` is now four vertical
  GROWTH COLUMNS: each stat is a tall rounded card whose track fills from the bottom up
  to value/cap, milestone pips sit at the real thresholds (the next one pulsing), the
  value is big, what the next point buys is spelled out (a real skill for acc/str, the
  live effect for end/spd), and an invest plate sits at the foot. Active branch tinted +
  brighter-bordered. Same sheet_sel/invest()/caps. Verified on screen. It now reads as a
  genuine upgrade over the classic four-card sheet, not a downgrade.
- **SETTINGS (cards) and PAUSE (cards)** (2026-07-26, **UNVERIFIED**, behind the
  `settings_cards` and `pause_cards` experiments, both off by default): two more
  EXPERIMENTS-panel alternates, same shape as the talent tree - `draw_settings_screen`
  and `draw_pause_screen` are now the one call site each of their screens uses, routing
  to the card version or the untouched original. Settings was the plainest menu in the
  game (bare `draw_string` rows, no card box at all, unlike the shop/sheet/slots screens
  that already use the Balatro-card look) - the alternate gives it the same `hud_card`/
  `draw_meter`/toggle-plate language those screens already established, one card per
  row, the same rows and the same `settings_input` untouched. Pause got the same
  treatment for its three options, colour-coded by what each one actually does (calm
  green to resume, warm amber to step out, warning red to quit) instead of plain
  centred text. Neither touches its screen's input handling at all - `settings_input`
  and `pause_activate` (`pause_sel` 0..2) are exactly what they were; only the drawing
  differs. **FULLY REWORKED + VERIFIED 2026-07-26 (Louis: both "looked horrible").**
  Settings cards are grouped into AUDIO / GAME FEEL / MORE sections with headers, a
  coloured accent tab per row, title-over-subtitle spacing, and real sliding PILL toggles
  (`draw_pill_toggle`) instead of ON/OFF plates. Pause cards get an icon disc per option
  (play / back-arrow / X) and a soft-glow selected state. IMPORTANT invariant: both
  `draw_settings` AND `draw_settings_cards` must carry the SAME nine rows in the SAME
  order `settings_input` drives (`menu_sel` 0..8) - a row added to one must be added to
  the other or the cards view's selection silently desyncs from what it toggles.
- **Professionalism pass (2026-07-26, all VERIFIED on screen):** five small
  legibility/accessibility wins from a review, none touching the sim or balance.
  (1) **Reduce Motion** setting (`reduce_motion`, persisted, a Settings row in both
  the classic and cards views): suppresses screen shake, cuts every hit-stop `freeze`
  to a single tick, and halves particle bursts at the `spawn_parts` choke point. It
  deliberately does NOT touch slow-mo - that stretches the catch window, so it is a
  gameplay aid, not a flourish. (2) **Skills gate badges name the real blocker:**
  `skill_gate_badge` shows the FIRST unmet axis (e.g. "Acc 8" for Columns, "Str 10"
  for Overthrow) instead of always the level - a level-9 player no longer sees "Lv 4+"
  on a wall they cleared five levels ago. (3) **Venue-picker hint:** the day hub's
  footer gains a "Left/Right (Dpad) stage" hint, but ONLY while PERFORM is the selected
  row (the one row where those keys do anything) - the `< venue >` arrows were the only
  cue before. (4) **Cash-in shows the gamble:** the goal bar reads "risking N" (score
  above the last banked goal) so the push-your-luck choice is legible; the old "every
  point is yours" was wrong, since a collapse strips back to the last goal even after
  all three. (5) **Coaching line on a survived act** (`coach_text`): the same generosity
  `fail_text` gives a lost night, extended to a won one - one honest line drawn from the
  night's real numbers (drops resetting the streak, or the load being the next rung),
  in the results card's closing-word slot.
- **The day loop:** day segments spent on perform/practice/eat/sleep/shop/skills.
  Stamina persists; sleep/meals restore it. Practice grants XP (per catch and a
  completion bonus banked even when leaving via Enter). The Energy-Drink Helmet
  (2026-07-19, ENERGY_HELMET_COST, 10,000g gear) is the alternative: buying it
  tops stamina up on the spot, and Energy Drinks bought after (ENERGY_DRINK_
  BATCH_COST, a bulk-only buy - 10 for 40g, cheaper than one at a time) sit in
  reserve and auto-pour through `spend_stamina` the instant stamina would
  actually hit empty, `+ENERGY_DRINK_STAMINA_PCT` (10%) each - a stocked player
  never sees EAT or SLEEP's gate (`too_tired`) at all, by design. **EAT a raw egg**
  (2026-07-25, UNVERIFIED - see Still open's old "Eating eggs" entry) is a third,
  smaller option beside a hot meal and the inn: it spends one OWNED egg (props are
  already owned by quantity, eggs included) for a flat `EGG_EAT_STAM` (10) stamina -
  no gold, no Strength tick, and the egg is gone either way (it already broke for
  good on a drop; now it can also just be eaten) - the real tradeoff is the egg you
  no longer have in hand to juggle for score.
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
- **F9** (a real key, not a `--` dev flag - works in any debug run, editor or export)
  opens the EXPERIMENTS panel from anywhere and pauses the sim while it's up, same as
  the pause menu. Toggle `talent_tree` there, then open the sheet (Tab) to compare it
  against the classic cards live, no relaunch. Debug builds only, per `OS.is_debug_
  build()` - see the EXPERIMENTS panel entry above.
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
  `--demowall` (2026-07-25, unverified - see the scoped free demo entry above)
  flips `in_demo_build()` true for the session without needing a real "demo"-tagged
  export: pair with `--debug` and an F-key venue jump (F1..F7) to push Reputation
  past `DEMO_MAX_VENUE`, then `--booking` a real act and let it resolve - the demo
  wall should fire exactly as it would in the real export.
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
- ~~Eating eggs~~ - **built 2026-07-25, UNVERIFIED** (see the Day loop entry below):
  eggs already juggled and already broke for good on a drop (`PROP_EGGS`) - this adds
  the other half, a day-hub row that spends one OWNED egg for a flat `EGG_EAT_STAM`
  (10) stamina, no gold, no Strength tick. Not yet confirmed the flat number actually
  feels worthwhile early and irrelevant late the way it was intended to.
- ~~Rep pressure by difficulty~~ - **largely addressed 2026-07-26** (see PROP IDENTITY
  above): --maxstats calib confirms 3 balls is locked out of venue 5 (count pressure
  works) and heavier props now pay monotonically more for a player who can sustain them,
  while collapsing an uninvested one. Still worth a hands-on pass to confirm the FEEL, and
  the highest counts (8-15) were not swept - only 3/5/7.
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
  difficulty presets alongside hard-mode collisions still open. **Per-channel sliders
  (catch/crowd/ambient), looked into 2026-07-25, PLANNED NOT BUILT:** the premise
  doesn't match what actually exists any more. There is no crowd or ambient audio bed
  to split out - `gen_sfx`'s own header is explicit that the crowd-murmur bed was cut
  2026-07-18 in favour of zero ambient noise, tonal stingers only (`draw_crowd` is
  purely visual). Building sliders for categories with no content behind them would
  be misleading UI, not depth. What COULD split cleanly, if it's still wanted: catch
  feedback (`perfect`/`good`/`late`/`whiff`/the `c_*` prop sounds - by far the most
  repeated SFX in a real set) versus everything else (UI blips, coin/money, streak
  stingers). That split is real and would need one new persisted slider var plus
  swapping roughly a dozen `play_sfx(...)` call sites (several inside `on_catch`,
  recently touched by The Critic/streak-escalation work) to a `play_catch_sfx(...)`
  twin that reads it - a bigger, more scattered diff than anything else on this list,
  so it was deliberately left as a plan rather than guessed at blind. Needs Louis's
  call either way: is "catch vs everything else" the split he actually wants, or does
  he want the crowd bed rebuilt first so the original three-way split has real content
  to attach to?
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
  **The Critic** (2026-07-25, UNVERIFIED) is a first concrete example: only a Perfect
  catch scores, Good and Late pay nothing - gated inline at `on_catch`'s two non-
  Perfect score lines (never through `pm`/`encore_score_mult()`, since that multiplier
  is shared with the Perfect branch and zeroing it there would have muted Perfect too,
  which is exactly backwards for this one). Streak, applause, XP, and the catch popup
  are all untouched - only the score line is gated. No exclusion rule of its own
  (unlike "fire"), so it can roll at any venue past the Backyard like most of the deck.
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
- ~~A scoped free demo~~ - **built 2026-07-25, UNVERIFIED, and the export preset is
  still an open step (see below):** `venue_index()` now caps at `DEMO_MAX_VENUE` (a
  tunable `const`, currently 1 - Backyard + Street Corner) whenever `in_demo_build()`
  is true, which reaches every real gate for free (`play_venue`, the hub's venue
  picker, `daily_venue`, a skill's own venue requirement) since they all read
  `venue_index()` and not the raw Reputation math. Reputation itself is never capped
  - only the venue tier it can spend - so the moment it would have bought a venue past
  the cap, `resolve_act()` sets `pending_demo_wall` once (mirrors `pending_win`'s own
  shape) and the results card rolls into `ST_DEMO_WALL` (`draw_demo_wall`) instead of
  the day: a stat recap, "WISHLIST IACTO ON STEAM", then back into the SAME career -
  never a lockout, since this is the last impression a demo player gets before
  deciding whether to buy (the calm-first-impression pillar applies here too).
  `demo_wall_seen` persists so it never shows twice. **`in_demo_build()` is the one
  choke point every check reads - never `OS.has_feature("demo")` directly** - because
  that engine call only ever sees a REAL export's `custom_features` tag, which cannot
  be faked from an editor or `--headless` debug run; the dev-only `--demowall` flag
  sets `_force_demo` instead, so the whole path is actually exercisable before a real
  export exists (see Verification workflow). **What's still missing, and NOT
  something this session could safely do by hand:** the fourth export preset itself.
  `export_presets.cfg` is Godot-editor-generated config that a blind hand-edit risks
  malforming in a way that would only surface at export time, with nothing here able
  to catch it - Louis needs to do this step himself: Project > Export > Add... > pick
  a platform (or duplicate an existing preset) > Options > Features > add the custom
  feature tag `demo`, and set a distinct `export_path` (e.g. `export/demo/...`) so it
  never collides with the real Windows/macOS/Linux presets already there.

## Gotchas that keep biting

- Godot user args need `--` (see above).
- Never accumulate a long-running phase in a PackedFloat32Array (loop clicks).
- Array-indexed numeric literals infer Variant: type the array or cast.
- `cine_tick` runs at 120/s: halve intuitive sin rates.
- Screenshot captures of BACKGROUND windows can show a stale render: foreground the
  window, or capture early frames.
- The IACTO juggler figure (stance, proportions) is settled: never reshape it as a
  side effect of a mechanics fix.
