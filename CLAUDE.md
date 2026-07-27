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
- **NO TEXT EVER LEAVES ITS CONTAINER** (2026-07-27, Louis, a standing rule). Three
  primitives, and the reason they exist: `draw_string`'s `width` argument does NOT
  shorten text, it CLIPS it mid-glyph, which is how a hub card came to read "LEARN -
  Overthrow (ne", and `draw_multiline_string`'s `max_lines` silently DROPS whatever did
  not fit. So: `fit_text` / `draw_fit_string` shorten one line to a width and mark the
  trim; `draw_wrap_fit` wraps into a BOX and stops at its height, marking the last line;
  `fit_size` picks the largest font size that fits, for titles built by joining two
  names ("TORCHES  REVERSE CASCADE") where an ellipsis would eat one of them. **Rule of
  thumb: anything whose length is DATA (a venue, prop, trick, pattern, Encore or lesson
  name, a commafied number, a description from a table) goes through one of these; fixed
  strings the layout was built around do not need to.** Fixed that pass: the F9
  descriptions, the results card's closing word, the sheet cards' blurbs, the Skills
  detail box (its 2-line cap dropped a third line), the shop's gear text (it wrapped
  down THROUGH its own price plate), the establish card's Encore text, the Records
  screen (both cards were a fixed 300px and drew their last row through their own
  bottom border - the venue board grew a seventh row and the career list a ninth), the
  live goal-bar label (a goal notch drew a white line through the lettering; it is
  `draw_text_shout` now, outlined), and the lesson/toast/slot/settings/records names.
- **UI look (2026-07-26 polish pass):** the shared `soft_card` primitive (StyleBoxFlat:
  rounded corners, soft drop shadow, faint top sheen) is THE card now - `hud_card`,
  `hud_panel`, `draw_meter`, and every big screen container route through it, so depth is
  consistent and the old flat-rectangle "cheap" look is gone. When adding a panel, use
  `soft_card`, not a bare `draw_rect`. The shop gained a detail strip that names the
  selected prop's signature edge and a "pays xN.NN" line per card (the reward, legible at
  the point of choice).
- **THE HAT** (2026-07-27, `draw_money_hat`, verified on screen empty, part-filled, brim-
  full and overflowing): the act's score requirement is a busker's top hat, turned over
  the way a busker leaves it, filling with the night's take. It replaced the horizontal
  goal meter in the left rail's SCORE card (now 196px tall, two columns: the numbers left,
  the hat right; the crowd and Encore cards moved down to 286 and 364 to suit). Louis
  asked for exactly this - "a sort of hat of money being filled (and special effects for
  overfilled)" - with **Balatro named as the bar for the whole game, visually, musically
  and for enjoyment**, so when a number drives tension here, prefer a drawn OBJECT that
  fills, glints and overflows to a rectangle with a percentage.
  It rises on `goal_bar_pos`, the same concave curve the old meter used, so no act's
  PACING changed, only the picture: the earlier goals are marks on the crown (lit once
  passed), the mouth lights gold at the brim, and past the final goal the take heaps up
  out of the opening, coins tumble down both sides on a loop, sparks ring it and a warm
  glow sits behind - the payoff for pushing on instead of cashing in.
  What it took to make it read as a HAT and not a jar: the crown is a SOLID body with a
  visible felt thickness and a cutaway interior (a thin outline with a transparent middle
  read as a glass jar with a lid); the interior is LIGHTER than the card behind it, or it
  reads as a hole cut in the rail; the venue's colour is a ribbon round the brim, pulled
  40% toward the house gold so a cool venue palette does not put a green stripe on a gold
  hat, and NOT a band across the crown, which reads as a lid over the cutaway. Two Godot
  traps met on the way, both now shared helpers: `draw_arc`'s radius is circular, so a
  "highlight along the brim" ballooned into a 66px dome out through the top of the card
  (`ellipse_outline`), and two crossed equal lines read as a plus sign, not a sparkle
  (`draw_star4`).
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
  a description. **2026-07-26: the reworked variants were all polished and four
  (`talent_tree`, `settings_cards`, `pause_cards`, `performer_polish`) now DEFAULT ON -
  they are the shipped look, F9 toggles each OFF to compare with the classic.
  `slot_cards` (Save files as portrait cards) is default OFF for Louis to choose.**
  Debug choices persist
  across debug relaunches, but load/save of experiment state is itself gated behind
  `OS.is_debug_build()`, so a release export always uses its shipped defaults. Adding
  another experiment later is one `EXPERIMENT_DEFS` entry
  plus whatever `if experiments.get("id", false):` branch it actually switches -
  `talent_tree` below is the template.
- **PERFORMER WARDROBE** (2026-07-26, behind `performer_polish`, DEFAULT ON, verified
  on screen at three venues plus a Spin): the juggler in evening dress -
  `draw_performer_polish` (satin peak lapels, a filled shirt front, bow tie, breast
  pocket + square, trouser stripes, and a centre seam/yoke on the back for the Spin's
  reverse), `draw_face_polish` + `draw_brows` (a side-parted fringe and brows that
  follow the same `face_mood()` the mouth already used), and a shirt cuff drawn INSIDE
  `draw_arm`. The rules that made it work, after two passes Louis called awful:
  (1) filled SHAPES, not thin decorative strokes - a stroked cream V over the jacket
  reads as a necklace; (2) every mark either butts against something the base figure
  already draws (the collar wedges, the shoulder seam, the trouser taper) or rides a
  SOLVED joint - the old cuffs were placed body-relative and floated in mid-air nowhere
  near the moving arms, which is why the cuff now lives in `draw_arm`, the only place
  that knows where the wrist ended up; (3) every colour comes from the venue's own
  palette (`collar` for shirt/cuffs, `suit_dk` for lapel silk, `suit` for the trouser
  stripe) - `suit.lightened()` washes a crimson jacket out to pink, and a hard white
  cuff would light the Midnight Show's deliberately-vanishing costume straight back up.
  It is drawn above the jacket but BELOW the head and arms, so the arms still pass in
  front of the coat and a held Columns middle ball (which rests at `stage_center`, over
  the hip) is never painted over. Nothing in it touches the IK, hand targets, prop
  layering, hitboxes or any sim value.
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
  in the results card's closing-word slot. (6) **The Encore card sizes itself to its
  own description** (2026-07-26): it was a fixed 66px, which fits exactly two wrapped
  lines, so any three-line challenge had its last line drawn straight through the
  card's bottom border. `_wrap_lines` now does the wrapping without drawing, the card
  height comes from the line count, and `_wrap_text` draws from the same list.
- **THE DAY HUB, in three drawers** (2026-07-27, verified on screen): ten flat text rows
  was the crowding Louis flagged, so the actions live in `DAY_GROUPS` - TONIGHT (perform
  / practice / daily), REST (meal / inn / pie / egg), PREPARE (shop / skills) - and the
  top level shows one card each, at most four things including a pending LEARN. Actions
  are CARDS now, the same language as the pause and settings screens: accent colour,
  icon disc (`day_icon`), a chevron on a drawer. `day_group` is "" at the top level or
  the open drawer's id; `day_actions()` is every action with its drawer, `day_rows()` is
  what the cursor walks. Left/Right and Escape walk in and out like a folder tree
  (Escape inside a drawer means "out of this drawer", not "leave the day"), backing out
  lands the cursor ON the drawer just left, and arriving off a spent act opens REST with
  the affordable recovery already selected. Every id `day_activate` matches is unchanged
  - only which rows exist at a given moment is new. **The detached hover-explanation
  block under the list is gone** (Louis: those "look wrong / bad" - a bare wrapped
  paragraph on its own card, jammed against the bottom frame): each card carries its own
  explanation and reveals it when SELECTED, growing to fit it exactly
  (`day_card_height` measures what `day_draw_card` draws, so it cannot clip), with the
  stage picker, the record to beat, the next-stage gate and the reason-it-is-blocked all
  inside the PERFORM card. The ledger on the left is three cards with a real
  `draw_meter`, not bare text over a flat rectangle. `--day <work|rest|prep>` opens a
  named drawer for a screenshot.
- **SHOP** (upgraded 2026-07-27): the selected card LIFTS off the row and lights its own
  border instead of the old flashing rectangle drawn outside it, and every prop card
  carries a SET meter - you need one prop per object you juggle, so what matters at the
  counter is stock against YOUR count, not the raw number owned ("2 short of a set of
  7"). **`B` (pad X) buys the whole shortfall in one press** (`try_top_up`), or a spare
  set when the set is already fielded, stopping at what the purse can take rather than
  half-failing with a warning - it used to be one Enter per object, up to fifteen of
  them, and again after every broken egg. One confirmation for the whole basket. The
  strip at the foot shows the receipt in green (`shop_msg_warn` false) rather than the
  red it uses for problems. **Icons and layout, 2026-07-27** (Louis: "the icons of the
  objects and the layout mostly" were subpar - the selection and border designs he
  liked are untouched): a prop icon used to be the raw stage shape blown up 2.6x about
  the origin the SIM uses, which is a hand position and not the middle of the object,
  so a club floated high in its card, a torch sat low, and all six came out the same
  nominal size. `draw_prop_icon` now hangs each on its own centre (`PROP_ICON_OFF`) at
  its own weight (`PROP_ICON_MAG`, a shared optical size with a mild heavier-is-bigger
  hierarchy), tilts the spinning props the way they read in the air, lights a niche
  behind them and drops a contact shadow under, and BREATHES on the selected card. The
  club shape itself was fixed while there: at 7 units of head against 14 of body it was
  as wide as it was long above the grip and read as a LOLLIPOP, so the body runs longer
  and the head narrower (about 3:1 now, like a real club) - this shows on stage too and
  is the intended fix, no sim value touched. Gear got real objects instead of glyphs
  (`draw_gear_icon`): a pie slice with crust and steam where a bare triangle used to
  read as the torch card's flame, glazed lenses in a frame, the Kit's own halo on a
  prop, and the Helmet as the cap-with-two-cans-and-straws it actually is. **The TORCH
  and the KNIFE were redrawn 2026-07-27** (Louis): the flame is a real silhouette in
  three nested layers on two flicker rates plus a lean (`FLAME_PROFILE` / `flame_shape`),
  which writhes instead of pulsing, and it takes a `rich` flag - in play that is three
  polygons and a pool of light only where the stage is dark, on a shop card it adds the
  aura, the climbing embers and a bigger glow, since nothing there is moving. The knife
  went from 18 units of blade over 8 of grip (a stubby dagger) to 26 over 9, with a
  fuller, a ground edge, a guard and a pommel. Both changed `PROP_ICON_MAG`/`OFF`, which
  is where a prop's icon size and centring live. The gear
  CARD is laid out across now (object left, words right, price along the foot) instead
  of borrowing the tall prop template and leaving a third of itself empty.
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
- **Skills screen, and THE PREVIEWS** (rebuilt 2026-07-27, verified on screen for all
  ten entries): three zones now - TRICKS, PATTERNS, and a PREVIEW that is always
  showing, on a panel widened to the shop's own 1120. Before this, a trick had NO
  preview at all and a pattern's was two dots bouncing in a 176x130 box (Louis:
  "awful / wrong or not even there"). `draw_skill_preview` is one picture for both
  kinds: a miniature STAGE (spotlight cone, lit floor, the venue's own palette), the
  juggler on it at `PV_K` scale (draw_juggler's eight-head canon, and he really turns
  through the Spin preview), the flight ROADS drawn as ghost arcs so the shape reads
  in a still frame, and props running the skill's own choreography. It never touches
  `balls` / `pattern` / `tick`, so it is safe to animate from any screen, but every
  number in it is DERIVED from the sim: `PV_OUTER`/`PV_INNER` are outer_pos/inner_pos
  scaled, `PV_ARC` is one tap's true peak (BASE_AIR x ARC_PER_AIR), a leg's duration
  rides its height the way airtime does, and each pattern's legs are read off
  do_throw's real rules (plain = inner to outer, over-the-top = outer to
  `over_top_land_slot`, Shower's feed is SHOWER_FEED-flat, Columns rides `columns_x`
  lanes, Behind the Back releases from behind the FAR hip and is drawn behind the
  body for `_btb_behind`'s own 0.35). Two rules make it fit any box: the hand line is
  placed per skill from the tallest arc in it (so a low pattern is not stranded in the
  bottom third and a high one is not pushed through the ceiling), and anything that
  still would not fit FADES and hands over to a top-edge marker - which is exactly
  what a High Toss does anyway. `--skills [N]` opens it for a screenshot, optionally
  selecting entry N (0-3 tricks, 4-9 patterns in unlock order).
- **PERFORMANCE, and the one rule that came out of measuring it (2026-07-27).** Louis:
  "the game is a bit laggy right now". `--fps` is the probe that settled it, and it is
  now a permanent dev flag: it prints, once a second, microseconds spent inside
  `_draw`, microseconds per physics tick, real fps, and the engine's own draw-call and
  primitive counts. What it showed: the SIM is not the problem (a physics tick is
  ~100us of an 8.3ms budget at 120Hz), and neither is fill rate (quartering the window
  to 640x360 changed nothing). The cost is `_draw`, and inside `_draw` the cost is
  almost exactly **the NUMBER of draw calls times ~5us** - vertex counts barely
  register. So: **optimise by making fewer engine calls, never by making cheaper
  polygons.** That was learned the hard way - the first attempt replaced `draw_circle`
  with hand-built low-poly polygons and made the crowd 30% SLOWER, because a
  GDScript-built `PackedVector2Array` per shape costs more than the vertices it saves.
  Also beware `fps` as a metric: it is vsync-quantised (145, 72, 48...) and drifts with
  the machine's thermal state, so two runs minutes apart are not comparable - compare
  `DRAW us` and the call/primitive counts instead. What the pass did, at the
  Championship with seven props: draw calls 681 -> ~340, primitives 38.5k -> ~18.5k.
  The changes, each of which is just "one call where there were many": the prop HALO
  now only draws where the house is dark (`stage_darkness`, Louis's own diagnosis -
  "that should only be the case for in the dark juggling"); every soft light is one
  textured quad off a generated radial gradient (`draw_glow` / `glow_texture`) instead
  of a stack of flat discs, which also killed the visible ring banding that thinning
  the stack had introduced; a prop's comet TRAIL is one tapered `draw_polygon` with a
  per-vertex alpha ramp instead of one circle per sample (up to 112 calls a frame on a
  seven-prop set); the crowd's shoulders are one band per row instead of one shape per
  person, and its head count is capped; `soft_card` re-dresses two shared StyleBoxFlats
  instead of allocating two per card per frame; and the scoreboard/tiers/truss lost
  their excess detail. `soft_disc` survives only as an early-out wrapper for
  fully-transparent glows.
- **THE CROWD GAUGE and the DROP PIPS** (2026-07-27, Louis): the applause meter is a
  half-circle instrument now (`draw_gauge`), red through amber and yellow to green
  (`GAUGE_ZONES`), with a needle, ticks at every zone edge, a bright pin left standing
  at the act's PEAK, the percentage read out below the hub (the one spot the needle
  cannot sweep across), and a pulse on the red band when the room is walking out. The
  crowd's patience only ever falls unless it is fed, which is exactly what a fuel gauge
  means. The DROPS row is no longer three red triangles: each pip is a prop still
  falling, with the streak of the fall behind it, and a spent one is the dark smear it
  left on the boards - so "two catchable, one on the floor" reads without counting.
- **THE DOMINANT HAND** (2026-07-27, Louis): a Settings row (LEFT / RIGHT, persisted as
  `dominant_hand`) that decides which hand holds the extra prop on an odd count and
  which one the demo starts from. Every juggler deals the odd ball to their strong
  hand, so a left-hander should not have to play mirrored. It is a tenth Settings row,
  which is why both settings views were re-spaced - remember the standing invariant
  that `draw_settings`, `draw_settings_cards` and `settings_input` must carry the same
  rows in the same order, since `menu_sel` is a bare index into all three.
- **THE STAGES, dressed (2026-07-27, verified on screen at all seven):** the Circus was
  the only venue with a real set - the other six were a tinted void with a spotlight
  cone and a crowd (Louis: "all the stages except circus could use some attention").
  Two rules kept it safe: everything new is edge-weighted and out of the juggling
  window, and there are now TWO passes, because the old one-pass dressing sat behind
  draw_backdrop's 0.42 veil and anything near the act came out muddy. `draw_venue_
  dressing` is still the far field (behind the veil); `draw_venue_foreground` is the
  NEAR field, drawn after the veil and the stage floor, for the handful of things the
  act stands among. What each venue got: **Backyard** a dusk horizon glow (the one move
  that turned a dark field into evening), a hedge, the washing still out on a line
  strung tree-to-post (both ends TIED to something - a rope beginning in mid-air read
  as two grey boxes), a porch light on the house, grass and fireflies. **Street Corner**
  a shuttered shopfront under a striped awning, the busker's crates, a lamp post moved
  clear of the HUD rail and given a colour that silhouettes against the night, a kerb,
  and the busker's own hat with coins in it on the pavement. **Small Theatre** a hung
  velvet back wall with folds (its middle was a flat void) and a gilded proscenium arch
  with studded piers. **Championship** raked stands, a lighting truss, and the score
  board hung off that truss on two visible hangers. **World Arena** deeper stands, a
  truss, and two big screens flanking the top centre at x 0.31/0.69 - the only band
  wide enough to clear both HUD rails and the props. **The Midnight Show** stays
  deliberately dark (the Glow Kit must keep its job): the house clock reading midnight,
  the two candles the room is lit by, mist on the boards, and (2026-07-27) a tall
  arched WINDOW with the moon behind it, laying a pale slab of light across the floor -
  the one source in that room that is not a flame. Its alphas are tuned to survive
  draw_backdrop's 0.42 veil, and it sits at x 0.30 to clear both the left HUD rail and
  the juggling window.
- **THE VENUE EXTERIORS** (the establishing card and the day hub's backdrop; reworked
  2026-07-27, Louis: "the stages' preview need more attention, the midnight show is
  literally just black"). `draw_arena_bowl` was one huge trapezoid with an ellipse on
  top, which at 96% of the screen width read as a featureless grey hill for BOTH the
  Championship and the World Arena. It is a building now: three tiers stepping back,
  ribs down the face, lit boxes between them, a roof lifting off with light under its
  lip, and floodlight masts either side throwing real beams. `ext_midnight` was that
  same shape in near-black, which is a dark blob that says nothing; it is now the thing
  the venue actually is - the last room, the one that opens after everyone has gone
  home - drawn as a narrow door down an alley: one green lamp, a marquee with blinking
  bulbs, a clock striking twelve, the moon, and three silhouettes who waited.
- **Arms reach exactly two points, `inner_pos` and `outer_pos`** - the same two the
  3-ball Cascade always used, and now with NO exceptions at all (2026-07-27). Every
  plain throw leaves inner and lands outer, INCLUDING the even-count Cascade's
  same-hand face, because that is what a fountain looks like (Louis: "it should go to
  the same hand yes, but not straight up, they should go from the inside throw to the
  outside position"). The straight vertical columns-style lane that used to carry a
  second ball on one hand's own road is DELETED, along with `road_lane`,
  `same_hand_lane_pool`, `toward_center_x` and `Ball.road_lane_idx` - it read as a
  Columns lane bolted onto a fountain, and it dragged the receiving hand toward centre
  too, since `hand_target` follows the incoming ball's real `to_pos`. Columns' own
  lanes (`lane_x`, `assign_lane`) are a separate, older thing and are untouched.
  **Two measured facts worth not rediscovering.** (1) A taller ARC cannot separate two
  balls sharing one road: one is ahead and one behind, so their height curves must
  CROSS somewhere, and at that crossing their separation is exactly the x gap again
  whatever their arcs. (2) Pulling the extra ball's landing INWARD makes it worse, not
  better - 6 balls measured 17.9px before and 3.3px after - because two diverging roads
  simply meet at some other phase. So the pure road is the best geometry available, and
  the daylight it leaves is just `(outer - inner) / (count/2)`: ~27px at four objects,
  ~19px at six, ~16px at eight, against a 22px drawn ball. Heavy props at high even
  counts therefore DO brush through each other for a frame, which is the accepted cost
  of the road Louis wants.
- **`prop_hit_scale`: the hitbox is the difficulty knob** (reworked 2026-07-27 with
  Louis's explicit authorization to use it, "not drawn size"). It used to collapse to
  6% of drawn size the instant a fourth object appeared, so 4 through 15 objects were
  all equally and completely collision-proof while 3 was not: a cliff, not a curve.
  Three shrinks now, each with its own job. (1) A big prop sheds most of its EXTRA bulk
  over a ball's by four objects (`HIT_EXCESS_KEEP`), so a club's hitbox walks toward a
  ball's while the club still LOOKS like a club. (2) The whole set eases with the count
  along the curve the pattern geometry itself follows, `HIT_ROOM/count - HIT_TRIM`
  (~1/count, because that is how the road's own crowding falls), which keeps roughly
  the same px of daylight at every count and makes each count read as a little harder
  than the one below. (3) It scales by the room THIS pattern leaves, `PATTERNS`' new
  `"room"` field, measured with `--collcheck --latecatch 4 --maxstats`: Columns leaves
  ~40px where Tennis and Half Shower leave ~2px (both fly an over-the-top road straight
  through the weave they cross), so no single count-only hitbox can be fair to all six.
  Half Shower's and Tennis's 0.05 is the honest reading of a pattern whose roads
  genuinely intersect under real timing - a long-standing residual the game must not
  punish the player for. Measured after: every prop and every pattern clears at 4 and 6
  objects under `--latecatch 4`, except Tennis at 5-6, which is that pre-existing
  zero-room geometry. Three of anything still collides at exactly the size it is drawn:
  at the beginner count, what you see is what hits.
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
  miming Enter/R/P; a `--demo` lesson run never quits by itself, so give it a
  `--shotat` or it hangs); `--remap` (add `--pad` for the gamepad column) opens the
  Controls screen; `--fps` prints the performance probe once a second (see the
  PERFORMANCE entry: draw microseconds, physics microseconds, draw calls, primitives -
  fps itself is the least useful number on that line, being vsync-quantised);
  `--wallcard` and `--legend` (2026-07-27) jump straight to the
  scoped demo's wishlist card and the Purist Legend payoff card - the two end
  screens previously reachable only by completing the run that triggers them, so
  neither had a capture path at all; `--capsule` renders pure key-art (no UI) for Steam store
  assets - capture at native 1280x720 (`--shot <path> --shotat 30`), then
  `sips --cropToHeightWidth 706 1232 <path>` for a distortion-free 2x Main
  Capsule, `sips -z 353 616 <path>` to the real 616x353; `--glow` owns the
  Glow-in-the-Dark Kit for the session (no save touched) - pair with
  `--booking --encore blackout` to screenshot it. `--day <work|rest|prep>` opens the
  hub with that drawer already open, and `--f9` opens the EXPERIMENTS overlay (both
  added 2026-07-27: the drawers and the F9 panel had no capture path at all otherwise,
  since F9 is a real keypress). Windowed
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
  **And it is not even reliable for plain SYNTAX** (found 2026-07-27): an edit that
  left `if x:` with no indented body printed NOTHING from `--check-only` and only
  showed up as `SCRIPT ERROR: Parse Error` when the game was actually launched. Treat a
  real run (`godot --path . -- --day --shot ...`, grepping for `SCRIPT ERROR|Parse`) as
  the parse check that counts.
- Dev flags parse only in debug builds (`OS.is_debug_build()`); release exports
  ignore them all.
- **ALWAYS TEST MUTED AND IN THE BACKGROUND** (Louis, 2026-07-27: sound suddenly playing
  while he works "disturbs me a lot"). Put `--audio-driver Dummy` BEFORE the bare `--`:
  `godot --path . --audio-driver Dummy -- --demo --booking --venue 2 --shot /tmp/x.png
  --shotat 700`. It is an engine flag, so no game code is involved and it cannot leak
  into a build. Launch the run detached and kill it after, rather than waiting on it in
  the foreground.
- A `--booking --demo` run QUITS when the act resolves, so a `--shotat` past the resolve
  never captures anything (silently: no error, no file). If a capture comes back missing,
  check the log for the `ACT ...` line before assuming a draw bug.
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
- **Cosmetics:** the Glow-in-the-Dark Kit is built (60,000g gear, GLOW_KIT_COST) and
  so is The Midnight Show, the bonus post-game venue it's really for (see the
  Records/pay/rep bullet above); player/prop skins beyond those two still open.
  **BLACKOUT rendering, rebuilt 2026-07-26 (verified on screen for torches, balls,
  eggs and the Kit):** past `BLACKOUT_CUT` (0.68 of the flight, just past the apex)
  the OBJECT is gone - no shape, no rim, no comet trail, no miniature stand-in.
  What replaces it splits two ways, and that split IS the Encore:
  - a **torch** keeps its flame and nothing else. `draw_torch_flame` was split out of
    `draw_torch` so the dark stretch draws the very same flame the lit torch does -
    same size (it used to be hand-written at roughly half scale and visibly shrank at
    the cut), same tumble via the shared `prop_spin_angle`, same flicker - plus the
    pool of light the fire throws, centred on the prop's true position so the catch
    point stays legible while the flame itself rides out on the tumble. Only the
    handle and the trail go dark. Bring torches to a Blackout night.
  - **everything else** becomes a `draw_blackout_afterglow`: light with no object in
    it. A smooth eight-shell radial bloom (a couple of low-alpha discs read as a dim
    OBJECT - it is the falloff with no visible rim that reads as light), trailed by
    the few positions it just came from, spreading and dimming down the fall but
    never going out, because catching a genuinely invisible prop is a coin flip, not
    a challenge. The **Kit** shows up inside that same visual language rather than as
    a second halo over the top: it scales the fade down to ~a quarter, so the glow
    barely decays across the fall, and `draw_glow_in_dark` adds a small bright centre
    that says exactly WHERE - still never a shape or an outline.
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

- Godot user args need `--` (see above). And in ZSH, an unquoted `$var` holding
  `--day work` is passed as ONE argument, not two, so `ua.find("--day")` misses it and
  the run silently lands wherever `skip_menu` sent it (usually ST_PLAY). A two-word dev
  flag that "does nothing" is nearly always this, not a game bug - pass the words as
  separate arguments.
- Numbers a player reads are DATA: run them through `commafy` (a five-figure pay read
  "+15602" beside a score reading "951,875"), and never write a figure out in words in
  a description - the pie's hub line still said "a quarter slower" long after PIE_SLOW
  was nerfed to 0.15. Interpolate the constant.
- Never accumulate a long-running phase in a PackedFloat32Array (loop clicks).
- Array-indexed numeric literals infer Variant: type the array or cast.
- `cine_tick` runs at 120/s: halve intuitive sin rates.
- Screenshot captures of BACKGROUND windows can show a stale render: foreground the
  window, or capture early frames.
- The IACTO juggler figure (stance, proportions) is settled: never reshape it as a
  side effect of a mechanics fix.
