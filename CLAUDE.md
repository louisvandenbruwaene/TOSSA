# TOSSA

A skill-based juggling game with a light performer-career sim around it. Godot 4.7, 2D,
GDScript, one self-contained file (`Game.gd`), code-only art and mostly code-rendered
audio, aimed at a polished $10 Steam release. This file is THE working document: the
old GDD/STORY/ROADMAP/PLAN/ART docs and ideas.rtf were distilled into it (2026-07-17)
and deleted. History lives in git.

**THE NAME** (2026-07-28): the game is **TOSSA**. It was IACTO before that and JUGGLE
before that, and it lives in exactly two constants - `GAME_TITLE` ("TOSSA") and
`TITLE_MARK` ("TOSS", the name minus the letter a real juggling ball stands in for in
the wordmark). Everything downstream - every readout, the wordmark, the credits, the
daily share line, the demo wall's call to action, the capsule lettering - reads those,
so a fourth name is a two-line edit. The repo folder, the Godot project name, the
bundle id (`eu.vandenbruwaene.tossa`), the export paths and the icons all moved with it.
**Save files moved too, and that is the part with teeth**: `user://iacto_*.cfg` became
`user://tossa_*.cfg`, so `migrate_old_saves()` runs before anything reads a save and
COPIES (never moves) each old file to its new name if the new one is absent. Copying
means an IACTO build still on the machine keeps working and the two diverge, which is
the safe direction to fail in. Delete that function only once no IACTO build exists
anywhere - "nobody could still have one" is a guess, not a fact.

## THE REVAMP (2026-07-29) - read this before touching score, stats or Encores

Louis rewrote most of the game's numbers in one brief. The individual changes are
documented at their own constants in `Game.gd`; this is the map, and `tasks.md` holds the
brief itself with every item ticked off.

**THE SCORE IS SEGMENTS.** An act is a series of segments; a segment is a stretch of
consecutive catches with the same load, ended only by a DROP. Its worth is

    s  x  PRODUCT over tricks i of (ti ^ mi)  x  x ^ (n * p)

x is the weighted catch count (Perfect 3, Good 2, Late 1), n the object count, p the
prop's `PROP_SIG`, s the pattern multiplier, mi how many times trick i landed. The act's
score is the sum, and there is nothing else in it. Gone with the old model: per-catch
points, the Perfect chain and its saturating multiplier, the ball-count bonus, the prop
score multiplier, the trick context scaling, and `run_mult`. **A Good catch no longer ends
anything** - it is worth two instead of three, which is a slope where the old chain reset
was a cliff.

**A SUM OF EXPONENTIALS IS ITS LARGEST TERM.** At the Arena's exponent of 21 a segment 20%
shorter than your best contributes about a hundredth of it. So "the score" means "your one
best clean run" in practice, and every goal, every calibration and every balance argument
has to be read that way. It is why `goal_for` is expressed in CATCHES.

**GOALS ARE A RUN LENGTH.** The load moves a score by thirty-odd orders of magnitude, so
one flat number per venue cannot work - it is unreachable with three balls and already
banked in four catches with seven torches. `GOAL_CATCHES` is what a house asks for in
catches and `goal_for` raises it by the load in hand. `VENUE_BASE`/`GOAL_STEP` are deleted.
Run `--ladder` after touching any of it: the tool now shares `goal_for` and `safe_pow` with
the game instead of reimplementing the scoring, so it cannot drift.

**NOTHING MAY ASSUME A SCORE FITS IN AN INT, OR IN A FLOAT'S RANGE.** `safe_pow` decides
in logs and clamps at `SCORE_CEIL` (1e300) because `pow` reaches INF long before that, and
an INF poisons every goal check, record and pay downstream in a way that is very hard to
trace back. Everything that prints a score goes through `score_text`.

**STRENGTH IS A WALL, NOT A PENALTY.** `PROP_STR_UNIT` per object times the count: 15
chainsaws asks 195, 7 torches 56, 3 balls 3. This replaced BOTH `BALL_GATES` and the `req`
field. Two whole systems died with it - the under-Strength DEFICIT family (sagging, wobbly
throws) and the Strength catch bonus - because you can no longer make a throw you are not
strong enough for. The last five points of Strength buy a Perfect frame, since every count
of everything is open at 195.

**ONE OFFSET MOVES ALL THREE CATCH BANDS.** `frame_bonus()` is added to Perfect, Good AND
Late together (`perfect_window()` / `good_window()` / `late_window()`); never compare a
press against the raw `W_*` constants. The old code widened Perfect alone into a fixed Good
boundary, so earning frames quietly ATE the Good tier until at the cap it vanished.

**ACCURACY 101-150 IS STAMINA, 151-200 IS TIMING, and the cap is 200.** The two Focus
stages used to overlap for a hundred points.

**SPEED IS 10 POINTS PER 1%, TO 20%**, and the Pie and the two earned bursts are 10% each,
so the four sources sum to exactly the 50% cap instead of overshooting it by 20.

**DRIFT AND JITTER ARE GONE.** Drift moved a landing sideways and a catch is decided on
TIMING alone, so it never made anything harder. Jitter moved the arrival tick by up to 5
against a 7-tick Perfect window, which is most of a band decided by dice.

**HEIGHT IS MEASURED FROM THIS COUNT'S OWN TAP FLOOR** (`Ball.over_tap`), not absolutely.
`count_air_scale` lifts the tap floor with the load, so a TAP already read as 0.60 at seven
objects and past the old 1.4 clamp at twelve - every throw at the top counts was taking the
maximum penalty. The penalty now prices the CHOICE to throw higher than needed, runs to 1.8
(what a held High Toss really reaches), and the 90%/70% promise is true at every count.

**THE ENCORE IS A LIST** (`encores`), not an index, because the four Purists combine:
`purist_slots(venue)` allows one at the Circus, two at the Championship, three at the World
Arena, four at the Midnight Show. Read them through `encore_on()` as before. Close Quarters
is replaced by two crowd tastes (Scared, Fancy) mirroring For the Danger, and The Critic
split in two - both END THE SEGMENT on a bad catch, which is a far heavier thing than the
old "it does not score" now that a segment is an exponential.

**GLOWING PROPS ARE STOCK** (`glow_count`, bought with G in the shop, `GLOW_PROP_MULT`
times the plain price), not one 34,000 switch that lit the whole collection. Blackout makes
an ordinary prop **completely invisible** now, which is only fair because `encore_pool`
will not roll it until you own three glowing balls or torches.

**LEVELS COME TWICE AS FAST AND ARE WORTH HALF.** Same XP for the same build, twice as many
level-ups: ~252 points by level 100 (every stat wall in the game), ~884 by level 230 (all
four caps). Halving `xp_to_next` WITHOUT halving `POINTS_PER_LEVEL` would have doubled the
build for the same hours.

**TOMATOES ARE OFF ONCE THE ROOM HAS BEEN GREEN** (`won_the_room`, a one-way latch per act).

**STILL OPEN, deliberately:** nothing caps how many times a trick may land in one segment,
so ti^mi is unbounded and cheapest to farm at the LOWEST load. Louis asked for a suggestion
rather than an implementation - see the foot of `tasks.md` for the two candidates.

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
  toward 1.4 (1.8 for a held High Toss). Height buys airtime, costs catch odds.
  There is no under-Strength throw any more: Strength is a hard wall (see THE REVAMP
  below), so a prop you cannot lift is a prop you cannot pick up.
- **Catch model:** Perfect always secures; Good/Late are a chance that rises with
  Accuracy and falls with how much HIGHER than the tap floor the throw went. At
  Accuracy 100 with no gear and no extra height that is 90% and 70% exactly. Focus
  (Accuracy 101-150) cuts stamina costs; Accuracy 151-200 buys five catch FRAMES.
- **PROP IDENTITY, second edition (2026-07-29).** The 2026-07-26 version gave every prop
  four levers - a Perfect-window shift, its own score multiplier, a stamina rate, a catch
  forgiveness nudge - plus two context bonuses in code (torches scored more in the dark,
  knives before a picky crowd). It was verified, it was balanced, and Louis replaced it,
  for a reason worth keeping: **weight was being charged for three or four times over.** A
  heavy prop cost more Strength AND scored more AND caught worse AND tired you faster, so
  no single number could be reasoned about and the only honest way to know whether a prop
  was worth it was to run the calibration. Now:
  - what it costs to THROW: `PROP_STR_UNIT` per object, times the count. One rule.
  - what it costs in STAMINA: `stam`, unchanged. Rings stay cheap for their weight.
  - what it is worth in SCORE: `PROP_SIG`, and it is an EXPONENT, not a multiplier.
  - what it does to the TIMING: `pwin`, and it is only ever +1 (clubs), 0, or -1
    (chainsaw) - and it now moves the Good and Late bands with it, not just Perfect.
  - and two things that are not numbers: knives and torches buy crowd patience
    (`prop_thrill`), and torches glow.
  `smult`, `fgive`, `req`, `DARK_PROP_BONUS` and `PICKY_PROP_BONUS` are all deleted. The
  situations the two context bonuses rewarded are still real and both props still answer
  them - a torch is the only thing you can SEE in a Blackout, and knives hold a restless
  room - which is a better reward than a number, because the player watches it happen.
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
  **AND A NUMBER SHRINKS, IT NEVER TRIMS** (2026-07-27). The rule above says data goes
  through one of the three primitives and stops there, which is one distinction short:
  `fit_text` ELLIPSISES, and an ellipsised number is not a number. The rail's takings
  read `draw_fit_string(... commafy(run_flowers), 74.0, 24)`, so a good night at the
  Arena (measured: a real seeded act paid 3,212, and 12,400 is 77px against that 74)
  would have printed "12,4..." where the player expects their money. `fit_size` is the
  right primitive for anything the player has to READ AS A VALUE: it hands back the
  largest size that fits and the digits stay whole. Same reasoning gave the crowd's mood
  line a floor of 10pt instead of a trim, because "throwing flow..." loses the only word
  in it that means anything. **When a string is a number, an amount, or a phrase whose
  last word carries the sense, reach for `fit_size`, not `fit_text`.**
- **UI look (2026-07-26 polish pass):** the shared `soft_card` primitive (StyleBoxFlat:
  rounded corners, soft drop shadow, faint top sheen) is THE card now - `hud_card`,
  `hud_panel`, `draw_meter`, and every big screen container route through it, so depth is
  consistent and the old flat-rectangle "cheap" look is gone. When adding a panel, use
  `soft_card`, not a bare `draw_rect`. The shop gained a detail strip that names the
  selected prop's signature edge and a "pays xN.NN" line per card (the reward, legible at
  the point of choice).
- **THE COIN** (2026-07-27, `draw_coin`): one money mark shared by the hub's PURSE card
  (`day_icon "coin"`) and every spending screen's readout (`draw_purse`), so gold looks
  like one currency everywhere. Was a flat disc with a white blob; now a struck coin -
  darker rim, raised face, a thin shadow crescent low-right and a light one up-left
  hugging the face's edge, a specular cap top-left. **Detail is a function of radius**
  and getting that wrong is what makes small icons muddy: milling and the struck star
  only appear at `r >= 9`, because at the hub card's 7px they crowd into a gear. Milling
  is MANY SHORT teeth barely proud of the rim (20, to 1.05r) - fewer and longer made a
  little sun. The strike is DARKER than its face: a lighter mark reads as something
  stuck on the coin rather than pressed into it.
- **Comet trails must be SPACED, not just sampled** (`TRAIL_STEP_SQ`, the sampler in
  `update_sim`). `draw_trail` builds one tapered ribbon by offsetting each sample
  sideways; an offset that outruns the gap between two samples folds the ribbon through
  itself, and Godot's triangulator refuses a self-intersecting polygon - the long-
  standing "Invalid polygon data, triangulation failed" spam (51 of them in a single
  lesson run before this). Two causes, both fixed: crowded samples (a prop at its apex,
  or one sitting past its arrival in the MISS_GRACE beat, where `flight_pos` clamps and
  repeats exactly) are now refused below a 6px spacing floor; and a path that genuinely
  DOUBLES BACK - a Column goes straight up and down the same line - falls back to a
  plain `draw_polyline`, still one draw call.
- **...AND NOTHING PER-FRAME MAY BE MEASURED OFF THAT TRAIL** (2026-07-27, `flight_vel`).
  The corollary nobody drew at the time, and it cost the round props their whole look.
  `draw_prop`'s squash/stretch took velocity as `pos - b.trail[last]`. Because samples
  are spaced 6px apart ON PURPOSE, that difference ramps from ~0 up to 6px and SNAPS
  BACK each time a new one lands: the stretch sawtoothed at the sampling rate, and right
  after each snap `vel.angle()` is the angle of a near-zero vector, i.e. noise. Measured
  on a real throw the prop's ORIENTATION was moving up to **72 degrees in one frame**
  (44 mean). That was the "jittery in the air" Louis reported - not the shading, which
  is where three sessions would have looked first. `flight_pos` is a closed-form
  parabola, so `flight_vel` differentiates it instead: worst case 2.4 deg/frame. **Rule:
  a decimated buffer is not a motion source. If the sim has closed-form position,
  differentiate it.**
- **THE ROUND PROPS ARE FLAT** (2026-07-27, Louis: "get rid of the 'light' and 'shadows'
  of both"; F9 `round_v3`, ON). Two relight attempts were rejected. The reason to stop
  trying: a painted highlight is a claim about where the light is, and this stage's
  lighting genuinely changes (venue palettes, Blackout, the Glow Kit, the spotlight
  pool), so the claim is wrong most of the time - and both attempts built that claim out
  of 1-2px features (a crescent that is the GAP between two near-equal circles, a 1px
  seam, a 1.3px hot point), which shimmer on a moving object however well drawn. Now:
  one flat disc of the prop's own colour inside a rim that is darker THE WHOLE WAY ROUND
  (`ball_rim`, floored at 1.6px so it never enters the shimmering band). A concentric rim
  has no direction, so it states a solid edge without claiming a light source, and it
  survives every palette. Same rule on the egg's ovoid. `glow_silhouette` no longer
  routes through either shape - its contract is one flat phosphor tone, and a dark rim
  on a charged prop read as a hole punched in the bloom.
- **AN OBJECT AT REST DOES NOT TURN** - a whole bug CLASS, found twice in one pass, so
  check it whenever anything tumbles. Both were accumulators keyed on a clock that never
  stops: a thrown flower's `rot` grew with `tick - born`, so a settled pile on the boards
  was a field of pinwheels (Louis), and an eggshell shard kept revolving about seven
  times a second where it lay for the rest of its 150-tick life. `draw_thrown` now
  clamps the accumulator at the landing tick and `step_effects` only turns a shard while
  it is still moving; the falling props already had it right (they skip the whole update
  once `rest` is set) and are the pattern to copy. **The same mark may still turn where
  it is a UI ICON rather than an object** - `draw_coin_mark(..., turning)` is opt-in, on
  for the purse and the shop's price plates, off everywhere a flower is a thing lying on
  a stage.
- **THE MARK IS THE UNIT** (2026-07-27, Louis: "the currency in shop should not be f but
  the flower icon"). Prices and purses draw `draw_coin_mark`, never a letter. The shop
  used to print "50,582 f" NEXT TO a flower, naming the currency twice and abbreviating
  it the once. `coin_short()` is deleted. `draw_price_plate` takes the bare number and
  places the mark off the MEASURED digit width, since a price is data ("60,000").
  **AND THE WORD IS `coin_word()`, EVERY TIME** (swept 2026-07-27). Six player-facing
  strings still had "gold" typed into them while the purse beside them read "57,546
  flowers": the Records screen's "gold earned on stage" and "mastery points turned to
  gold", the save-slot card's purse line, the demo wall's "all of it spent" line, the
  MASTERY level-up popup, and the sheet's "New levels now pay gold". They are all
  interpolated now. The rule this entry already stated is the right one, it just has to
  be applied at the point of writing: `money` is one variable and only its NAME changes,
  so a literal "gold" anywhere outside a `const` identifier is a bug waiting for the
  switch to be flipped. `coin_word_one()` (the singular) was deleted, unused.
- **A SELF-INTERSECTING POLYGON DRAWS NOTHING, SILENTLY** - and the error names no line,
  so here is how to find one. The shop logged "Invalid polygon data, triangulation
  failed" on every frame for an unknown length of time. Capturing at three different
  `--shotat` values gave counts of exactly N-1 each time, which pins it to a STATIC
  shape (an animated one would vary) drawn ONCE per frame - that is most of the search
  done before reading any code. It was the Energy-Drink Helmet's brim: four corners
  listed out of perimeter order (2nd and 4th swapped) so edge 0 crossed edge 2. It had
  therefore never rendered, and the hat had been missing the part its own comment calls
  the thing that makes it a cap. **Watch for collinear points on one edge too** - that is
  why the softened spotlight's base is bowed rather than flat.
- **THE SPOTLIGHT HAS EDGES** (2026-07-27, F9 `soft_light`, ON): the title/key-art beam
  was one flat polygon at a single alpha, so the light stopped dead along two straight
  lines and read as a wedge laid over the picture; its half-width was a hard 300px, so
  the beam changed proportion with the window instead of with the stage. It is
  `draw_polygon` with PER-VERTEX ALPHA now - transparent at the two lower corners, warm
  down the middle - which is still ONE draw call. That matters given the `draw_glow`
  finding that stacking low-alpha shapes to fake a gradient measured 30% slower and
  banded once thinned. Width is `s.x * 0.234` (the old 300px at the 1280 it was picked
  for). Shared by the menu, the key-art and the venue backdrop, so all three improved.
- **A DARK SCENE NEEDS A VALUE LADDER, not less light** (2026-07-27, Louis: some stages
  are "some blurry line in the dark ... most stages do fine: like the circus. but some
  don't; like the midnight event"). Two separate causes, and the first is the one to
  check FIRST on any venue that reads as a smudge. (1) `draw_backdrop` washes a flat
  dark veil over the set dressing to push it behind the props. On a bright set - the
  Circus canopy, the Arena bowl - that is exactly right; on an already-dark set it is
  applied to dressing with no brightness to spare and simply erases it. The Midnight
  Show's clock, moon window and candles were all being drawn and then wiped off. The
  veil is a per-venue `veil` field now (default 0.42, the Midnight Show 0.10). (2) In
  `ext_midnight` every structural tone sat between 0.014 and 0.09 - a band far too
  narrow for sky, alley wall and facade to separate from each other. **Brightening them
  all equally only makes grey fog; what a night picture needs is SPREAD**: sky darkest,
  walls above it, facade clearly lighter than both, light sources well above all three,
  and the silhouettes left near-black because they are read against the lit doorway, not
  against the sky. Same lesson on the stage's own scattered house lights: at 0.24 peak
  alpha on a 2.8px square a light is below the size/brightness threshold where it reads
  as a light at all, which is what left the house looking merely under-exposed rather
  than dark. A lamp needs a halo or it is just a brighter rectangle.
- **THE GLOW KIT RECOLOURS THE COSTUME, it does not paint over it** (2026-07-27, Louis:
  "it should be a costume that is pretty much completely glow in the dark"). It used to
  be six strips of tape on a near-black suit, which said "this juggler has some tape on
  him". `draw_juggler` now swaps its four costume colours (`suit`/`suit_dk`/`vest`/
  `collar`, plus the polish `accent`) at source when `glow_kit_lit()`, so every piece
  the wardrobe already draws - lapels, cummerbund, buttons, cuffs, tails - comes out in
  phosphor, in its right shape, for free. **Drawing a second glowing figure on top was
  the obvious move and the wrong one**: two copies of the same costume to maintain, and
  a standing rule that the figure's stance and proportions must never drift as a side
  effect. Keep the swapped values a LADDER (deep suit, brighter vest, near-white collar)
  or the costume flattens into a silhouette, and leave skin and hair alone - the man is
  not glowing, his clothes are. A bloom under the body is what makes the recolour read
  as EMITTING rather than as a man in a green suit: a lit thing spills onto its
  surroundings, and without that spill any colour is just paint. Of the old tape only
  the trouser outseams survive; the horizontal runs were struck across the figure rather
  than along a seam, and the arm runs were drawn shoulder-to-HAND as one straight chord
  while the arm bends at the elbow, so they left the sleeve and crossed open air.
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
- **FLOWERS, the crowd's own currency** (2026-07-27, Louis; F9 `flowers`, ON by
  default). The crowd pays you in front of you: play deep in the green and the room
  throws flowers at your feet on its own beat (`throw_step`, every `FLOWER_BEAT`, one
  roll per `FLOWER_THROWERS[venue]`), and the PILE ON THE BOARDS is the read on how the
  night is going - no meter, a look down tells you. Tiers: flower 1, posy 5, gold rose
  25, and `flower_tier_roll` only offers the rare ones deep in the green AND with drops
  at or near zero, so the pile's COLOUR says what its size cannot. Lose the room
  (`applause <= TOMATO_RED`) and they throw TOMATOES instead: worth nothing at the
  counter, eaten later in the hub for stamina, kept only when the act actually failed
  and capped at `TOMATO_MAX_KEPT` so a disaster stays a consolation and never a
  strategy. The night's pay is simply `run_flowers` - no end-of-act formula, because it
  was already earned in front of the player. `money` is the same variable either way;
  only how it is earned, drawn (`draw_coin_mark`) and named (`coin_word`) changes.
  **THE MONEY HAT COMES OFF when this is on**: its job was making the goal read as a
  thing that fills, and the stage does that better now, so the rail keeps a slim
  `draw_goal_stem` (a growing stem, a notch per goal, a bud that blooms past the last),
  tonight's takings, and one word for the room's mood.
- **A DECORATION THAT LEAVES ITS BOX IS A LAYOUT CONSTRAINT, so write the number down**
  (2026-07-27, Louis: "the flower overlaps with 'tonight' when performing"). The goal
  stem's bud opens past the final goal into a tier-2 flower at scale 3.2 and then up to
  4.4, and `draw_flower` puts petals out to 1.24 times its radius, so the celebration
  reaches 38.3px from the stem's centre line out of a box only 34px wide. It was
  therefore eating the first 11px of the word TONIGHT, but only from the moment the act
  went past its final goal, which is why an ordinary screenshot of the rail looks fine
  and the report still stands. The takings column is anchored at
  `stem centre + STEM_BLOOM_REACH + 7`, and STEM_BLOOM_REACH is COMPUTED from the same
  `STEM_BLOOM_SC`/`STEM_SHED_R`/`FLOWER_REACH` constants `draw_goal_stem` draws with,
  so making the bloom bigger later moves the text instead of colliding with it. **The
  general rule: when one thing is drawn deliberately outside its own rect, the amount by
  which it overhangs belongs in a named constant next to the shape, not in the head of
  whoever placed the neighbour.** Verified by forcing `over = 1.0` in a scratch copy of
  the project rather than hunting the one frame a `--demo` act spends past its final
  goal (the autoplayer cashes in the instant the third goal falls, so `over > 0` is
  effectively unreachable through the harness). The bloom does still open up THROUGH the
  top of the SCORE card and over the venue card above it. Left alone deliberately: it
  clears that card's own lettering, and a flower growing up out of the rail is the
  picture the feature is going for.
- **PAY, rebalanced** (2026-07-27, Louis: "20000 gold is just insane for the theater").
  `pay_mult` was an UNBOUNDED `1 + rep/400` - a fifteenfold multiplier by mid-career,
  sitting on top of a score that already scales with venue, prop, count and streak.
  Four compounding curves is three too many: it is capped at `REP_PAY_CAP` (3.5) off a
  gentler `REP_PAY_DIV`, and `BOOK_PAY_PER_SCORE` came down with it. Measured: a strong
  Theatre act pays ~200 flowers or ~500 gold, against costs that did not move.
- **THE ART RULE, restated** (2026-07-27): the torches and knives set a bar the rest of
  the props were below, so balls, eggs and rings were relit on ONE rule - key light up
  and left, a broad soft highlight on that shoulder, a tight specular inside it, a
  shaded crescent opposite, a thin bounce along the lower-left rim from the boards.
  Four marks and a silhouette is all a round thing needs to stop reading as a disc. The
  egg is a true ovoid (pinched at the top only - a symmetric ellipse is a pill), the
  ring has a rounded cross-section and its own inner-hole rim. The GLOW KIT went from
  two flat circles to real phosphor: a bloom, the prop's own silhouette in charged
  green (`glow_silhouette` - deliberately NOT `draw_club`/`draw_knife`, which paint
  their own reds and steels), a hot core, and glow tape on the PERFORMER
  (`draw_glow_strips`) so the figure is legible in the dark instead of a hole in it. It
  now lights on any dark stage (`glow_kit_lit`), not only inside a Blackout.
- **THE SMALL THEATRE** had drapes and an arch and nothing else while the Backyard next
  door has a tree, a fence, a house and a washing line. It gained the furniture a real
  little theatre has: `draw_theatre_boxes` (a box either side, lit velvet back, gilded
  rail, silhouetted heads leaning on it, a sconce burning on the pier) and
  `draw_footlights` along the lip - all at the EDGES, because the middle belongs to the
  props. Two traps: a box interior must be LIGHTER than the curtain behind it or it is
  a hole, and anything drawn AT the floor line is buried under the boards, which are
  painted after the dressing.
- **EVERY GATE IS ON ONE EVEN LADDER** (2026-07-27, Louis: "isn't evenly spread...
  right now it looks bad on the stat menu"). `BALL_GATES` ran 9/15/23/33/60/90/125/165/
  175/183/191/200 - four gates crammed into the bottom fifth, a canyon, then four more
  crammed into the top - which as a row of pips was unreadable and as a curve was three
  different games. Twelve counts across 200 points is one step of 16.7, so every count
  costs the same distance of work. Accuracy's skill walls moved onto its own 50-point
  ladder (Columns 50, Half Shower 150) beside the two Focus stages (100, 200) and the
  cap. **TRICKS ARE STAT-WALLED NOW**, one per stat, so they arrive spread out instead
  of all at once on a fresh save: Behind the Back Acc 50, High Toss Str 50, Spin Spd 40,
  Overthrow Str 100. `skill_req_met` / `skill_req_text` / `skill_gate_badge` learned
  "end" and "spd", which they never checked. The venue-arrival gift survives on the
  PATTERNS (Shower/Reverse Cascade/Tennis), so moving up a stage still always pays.
  Prop `req` values are deliberately NOT drawn on the Strength track - four more pips in
  the bottom quarter is the crowding this pass exists to remove, and every shop card
  already prints its own "Str 12". The track sits at 32% across its column, not
  centred, because centred left every pip label less than half the width and ellipsed
  the useful half away.
- **A STYLE LESSON ONLY COUNTS ITS OWN STYLE** (`tut_on_catch`). The guided passes
  enforce the order by construction; the free pass is where a player falls back into
  the rhythm they already know. The tell is not the keypress order - that is gone by
  the time a catch resolves - it is HOW FULL THE AIR IS as the prop lands: an advanced
  juggler caught from a sky holding everything, so `num_balls - 1` are still up; a
  beginner threw first from a holding hand, so one fewer is. `--demo` drives lessons off
  `tut_due_actions` for the same reason, so the harness always plays the taught style
  (and must use `do_throw`, not `on_throw_press`, since outside a hold a press only
  starts the charge and the autoplayer has no release).
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
- **ONE LOGO, EVERYWHERE** (2026-07-28, Louis: "the tossa logo on the welcome screen
  should use the same logo to depict tossa as the picture you made before"). There were
  two marks doing the same job: the store capsules spelled TOSSA entirely in PROPS - two
  knives for the T, a ring for the O, lines of balls for the S's, two burning torches for
  the A - while the title screen, the key art and the credits drew the WORD in the UI font
  with a single ball standing in for the final letter. `draw_wordmark` is now a thin
  wrapper over `capsule_mark`, so there is one logo and it cannot drift.
  **Two things had to be solved to get there.**
  (1) **THE MARK FADES AS ONE THING.** It is sixty-odd shapes with their own alphas, and
  the credits fade it in and out. Rather than thread an alpha argument through every prop
  and every highlight, `capsule_mark` sets `_cap_a` for the duration of one mark and every
  colour passes through `ca()`. It is draw-time only and always restored, so nothing drawn
  afterwards inherits a half-faded mark. Verified by forcing alpha 0.35 and confirming
  every part - knives, ring, balls, flames, embers, glows - fades together.
  (2) **THE PICTURE IS TALLER THAN ITS LETTERING, so the overhang is a named number.** The
  A's torch handles hang below the baseline and its flames climb well above the cap line,
  which is why the title's divider was drawn straight through the torches on the first
  try. `MARK_RISE` / `MARK_DROP` / `mark_height()` are computed from the same values the
  drawing uses, and every caller places what sits underneath off `mark_height()` rather
  than off a hand-picked offset - the same rule the goal stem's bloom already established.
  **The menu's little juggling cascade came off** while doing this: the mark is alive now
  (torches burning, embers leaving) and a second animated ornament directly above it
  competed for the same attention - and at title size there was no room left for it
  anyway, so it was being clipped by the top edge. `draw_menu_cascade` survives on the key
  art and the credits, where the mark is smaller.
- **THE EXPERIMENTS ARE ALL SHIPPED** (2026-07-28, Louis: "you may remove the F9 options
  - not the idea itself, that i will reuse. they should all be ON and that is the way i
  like it"). `prop_art`, `round_v3`, `soft_light` and `flowers` are simply how the game
  looks now, and their OFF branches were **deleted**, not left stranded - along with
  `draw_money_hat`, `draw_coin` and `_hat_vessel`, which were what the flower economy
  replaced. `flowers_on()` is gone and `coin_word()` returns "flowers" unconditionally.
  The panel was left with ONE entry, `face_v2` - since shipped, and the list has turned over
  again: as of 2026-07-30 it carries `fire_motion`, `club_v2`, `card_v2` and `shop_v2`. It also
  left one new rule behind, to stop the bug the old
  dictionary invited: **every experiment is read through `exp_on(id)` and nowhere else**,
  because a reader with its own hand-written fallback can disagree with the declaration
  (`flowers_on` said `false` against a declaration of `true` for a while), and one
  accessor cannot disagree with itself. The panel's row height now divides a fixed budget
  by the entry count, so a short list explains itself properly.
- **THE JUGGLER'S FACE** (2026-07-28, F9 `face_v2`, ON; Louis: "a nicer mouth and hair.
  right now they just look too artificial"). What was artificial was not the amount of
  detail, it was three specific marks. HAIR was `draw_circle(head + up, r * 1.12)`: a
  brown disc behind a tan one. A haircut is a SILHOUETTE - a crown that is not round,
  temples down past the eye line, a hairline that parts on one side - and none of that is
  a strand (strands at 21px land in the same sub-pixel shimmer band the round props were
  flattened to escape). The MOUTH was a three-point polyline of even thickness, and Godot
  has no round caps, so it had square ends: a drawn line lying on a face. Every mouth is
  a filled shape from `mouth_shape` now - four numbers (corner lift, top bow, bottom bow,
  width) shared by the lips, the opening and the lower-lip highlight so they cannot come
  apart. EYES were two dots and a speck; what makes an eye read at this size is the BROW
  above it, and the brow is also what closes on a wince.
  **Two things went wrong on the way and both are worth keeping.** (1) The first pass
  drew an upper lid AND put the brows at -0.22r; a near-black lid on a near-black eye
  does not read as a fold, it just makes the eye taller, and together the two merged into
  one dark block. The lid is gone, the brows are at -0.30r in HAIR's colour rather than
  the pupil's, and the eye is slimmer. (2) The pleased mouth dropped the jaw and showed
  teeth, and Louis called it correctly: "the smile is a bit creepy, go easy on that part".
  **A face this simplified has no eyes doing the other half of the work, so the mouth
  carries the mood alone - and a mouth carrying it alone must stay small.** Lifted corners
  and a barely parted lip is a smile; teeth make it a rictus.
  `draw_head` is the ONE head now: the Skills preview used to draw its own second face
  (two dots and an arc, no fringe, a mouth that never changed with the mood) and simply
  passes a smaller `r`. Detail thresholds are radius-gated the way `draw_coin` learned to
  do it - brows and nose at r >= 10, since the preview's head is 11.5px against the
  stage's 21.
- **A CRESCENT IS THE DIFFERENCE OF TWO CIRCLES** (2026-07-28, Louis: "improve the rest
  icon, it's just a C right now" - and that is the geometry, exactly). The moon was
  `draw_arc` at width 3.2, and **an arc has CONSTANT width**, so it is a ring with a gap
  cut in it: the same thickness at the horns as at the belly, finished with two square
  caps. That is the letter C at any size, however it is coloured. A crescent has no
  constant width anywhere, so no arc can ever be one. `crescent_points` intersects the
  two rims properly and walks the outer arc outside the bite, then the biting arc inside
  the disc, which gives real horns and a limb that tapers. Both the REST drawer and the
  SLEEP row use it. The obvious alternative - draw the disc, overdraw the bite in the
  background colour - is wrong here because these icons sit on cards that do not share
  one background, so the hole has to be honestly absent.
- **THE CHAINSAW** (2026-07-28, Louis: "make it actually move around and work"): the
  seventh prop and the deliberate end of the ladder - weight 6, Str 70, 9,000, `pwin` -4,
  `smult` 2.10, and the only prop that is RUNNING while it flies. The chain really
  travels round the bar (each link walks the perimeter on a phase that advances with
  `cine_tick`), and it lands on `c_saw`, a two-stroke bite rather than a chime.
  **What it cost, measured at seven saws at the World Arena, because Louis asked:**
  eleven immediate-mode shapes each = 449 calls / 3.0ms; batched into a soup but rebuilt
  per prop = 383 calls / 3.0ms; batched AND baked once per frame = 383 / 2.6ms. The
  middle row is this file's own flower-pile lesson walked into a second time - batching
  wins on calls, but building triangles in GDScript costs about what the calls cost, so
  doing it per PROP hands the saving straight back. **Every saw is the same local
  geometry at a given tick** (the transform is the only difference), so `_saw_bake()` is
  shared and the per-prop work is one emit. `draw_set_transform` applies to
  `canvas_item_add_triangle_array` too, which is what makes that possible.
- **A SEVENTH PROP WALKED INTO SIX HARD-CODED LENGTHS**, and that is the real finding
  (2026-07-28). `prop_count` was a 6-literal (`Out of bounds get index '6'`); the shop's
  prop/gear boundary was `shop_sel <= 5` in four places, so the chainsaw's card ran
  `try_buy_glasses`; the row width was `(innerw - gap * 5) / 6`, so the seventh card drew
  out through the panel border and off the screen; and the gear cards' printed buy keys
  were `7 + i`, so every one of them advertised a key that now bought a prop. All of it
  derives from `PROPS.size()` now (`sync_props`, `shop_gear0`, `shop_cards`, `SHOP_KEYS`),
  so an eighth prop is one `PROPS` row and no other edit. **The shop row is also the
  honest argument for prop CATEGORIES** (Louis's own instinct): past about eight cards
  there is no width left in a single row, whatever the arithmetic says.
- **BOUQUETS, and the two factors that decide a tier** (2026-07-28, Louis: "bigger stages
  should throw bouquets instead of just a couple of special flowers - mix the concepts").
  `flower_tier_roll` multiplies the player's night by the ROOM: how deep in the green and
  how many drops still gates the top of the ladder exactly as before, and
  `venue_generosity()` (0 at the Backyard, 1 at the top) both widens those odds and lifts
  the plain-stem floor. A bouquet (tier 3, worth 60) is drawn as THREE blooms recursing
  through `draw_flower` at lower tiers plus a wrap of florist's paper - never one big
  flower, because "somebody bought this" is a read a scaled-up single bloom cannot give
  at any size. Neither factor can carry the roll alone, which is what stops a big stage
  paying out for a bad act.
- **THE STANDING OVATION** (2026-07-28, Louis: "ending a perfect performance (no drops)
  should get a standing ovation and a rain of flowers (bonus)"). Not one prop dropped,
  not a collapse, at least one goal banked: the room stands, `OVATION_TICKS` of flowers
  come down from ABOVE (`rain_flower` - an ovation is the whole room at once and reads as
  weather, where `throw_from_crowd` arcs one person's tribute up out of a seat), and only
  then does the results card appear. `results_open` is deliberately set true throughout,
  so every guard that already stops play during the results also covers the ovation -
  only the card's DRAWING and its keys wait on `ovation_left`. The bonus is
  `OVATION_BONUS_PCT` of what the night already earned, added to `run_flowers` BEFORE the
  pay is taken off it, so it flows through the purse, the ledger and the record like any
  other flower and the rain itself adds nothing more (or the night would be paid twice).
  **`--demo` now waits for the ovation before quitting**: it used to quit the frame the
  act resolved, which made the one path only a perfect act can reach impossible to test
  or screenshot at all.
- **CAN A FULL HAND CATCH? A SETTING NOW** (2026-07-30, Louis: "make it toggleable: whether it's
  possible to catch an object when you already have one in your hand. for now turn it off").
  `set_catch_full`, in Settings under GAME FEEL, **default OFF**. It shipped as always-YES for a
  while - "traffic is now the player's own problem, and holding two is a legitimate rescue" - and
  this puts the older rule back as a choice. The two are different games at the top counts: catching
  into a full hand lets a player bail out of a mess by stacking, which is forgiving but also lets a
  bad pattern be survived rather than fixed; OFF means every catch has to be paid for with a throw
  first, which is what the beginner cascade teaches in the first place. Checked BEFORE the ball is
  chosen, so a refused press is not a whiff and costs nothing - reaching with a full hand is not a
  mistimed catch, it is an impossible one. **`sure` is exempt**, and must be: a guided lesson beat
  freezes the world to demand a press, so a rule that could refuse it would deadlock the lesson.
  **AND A NON-DETERMINISTIC HARNESS WILL LIE TO YOU ABOUT WHICH CHANGE DID WHAT.** The first
  `--demo --booking --venue 2` run after this change collapsed at 0 where the previous run had
  scored 364,451, and flipping the default back to ON scored 585,980 - which looks exactly like
  proof. It was not: `--demo` seeds its rng per run, and three more runs with the toggle OFF all
  came back 3/3 with no collapse. Instrumenting the refusal branch printed **nothing at all**,
  because the autoplayer's own catch loop has always skipped a hand that is not empty, so it never
  reaches this rule. **One A/B pair of a randomised run is not a measurement** - the same trap the
  fps note in this file already records, met from the gameplay side.
  Adding the row also fixed a latent out-of-range: `draw_settings_cards`' `sections` listed rows
  [7, 8, 9] while `rows` only ran to 8, so `rows[9]` was an out-of-bounds read inside `_draw` -
  which this file's own note says silently abandons the rest of that draw pass. `settings_input`'s
  `n`, the `rows` array and the `sections` indices have to be edited in one go; the comment on `n`
  now says so.
- **THE CATCH GUARD: A BEGINNER CANNOT DROP WHILE BEING HELPED** (2026-07-30, Louis: "The tutorial
  is still not pausing when it should ... it should pause the game when the thrown ball comes near
  the perfect catch timing; that makes sure the beginning player doesn't drop during the tutorial").
  The bug was real and the log pins it exactly. `tut_do_step()` returns false while
  `tut_advance_at >= 0` - the window where a beat's goal is MET and the banner is asking for Enter -
  so instrumenting the guard printed `tick=649 step=8 goal=throw_r adv=629`: a ball arriving during
  a satisfied throw beat, with nothing frozen, while the player reads the line. **That is where the
  balls were going.** A catch beat was no better: it held at `tick >= b.land_tick`, so the world ran
  at full speed for the whole flight and every press a beginner made on the way in was read as an
  ordinary catch - a whiff, or a mistimed one that dropped the prop.
  `tut_catch_hold()` stops the world whenever a prop is inside `TUT_CATCH_GUARD` (14 ticks, the same
  number the older lessons' guided beat already uses, so two mechanisms cannot pause at different
  distances) **during a HELPED stretch** - `tut_helped()`, which is every beat except a `free` one,
  because a free beat is exactly where Louis wants dropping to be possible. It is deliberately not
  gated on `tut_advance_at`. A press on the guarded hand is `sure`, like the other two frozen paths.
  **AND A HELPED CATCH IS GRADED PERFECT.** `sure` already skipped every branch that could lose the
  prop, but the catch was still graded on raw timing - so freezing 14 ticks early put "LATE" over a
  beginner's hand for a press the game had stopped itself to demand. Pulled to 1, not 0: zero is the
  frame-perfect tick that pays an Amazing! burst, and that is a thing to be earned.
  **THE PEAK HOLD IS FINALLY READ.** The `peak` flag has ridden on the three-ball step since the
  script was written and nothing looked at it. Without it that beat froze the instant it began,
  which is the wrong instant: it asks for the second ball to go UNDER the first and the first has
  only just left the hand, so the game was teaching both at once - and contradicting its own line.
  `tut_at_peak()` reads the apex off the sim (half way between launch and arrival is the top of any
  parabola), so it is true for the throw the player actually made rather than a scripted one.
- **EVERY LESSON SPEAKS NOW** (2026-07-30, Louis: "fix the 'learn something new' tutorials, which
  should be given in the same style and layout as the actual tutorial"). The basics were rewritten
  into a conversation in July; the trick, pattern, prop, count and advanced lessons kept the old
  presentation for another day - a full-screen intro card, the three-pass slow-motion ladder, a
  paragraph of `sub` under a top banner. The reason they could not follow was missing plumbing:
  `tut_say` is a line and Enter, `tut_do` a line and one named key, `tut_free` a line and a count,
  and none of them can express "a line, and the goal `trick_on`". **`tut_beat(line, goal, need, n,
  extra)` is that missing builder**, and `say` is the single flag that switches the whole HUD over
  (see the early-out in `draw_tutorial_banner`), so one helper converted all five families.
  Every goal, need, count, prop, pattern and reward is unchanged - only the presentation moved. The
  drills run ONE honest pass at the need the ladder's LAST pass asked for, so nothing got easier,
  only shorter. **`tut_paced`, `tut_pace_line`, `tut_intro` and `TRICK_TUT_SLOW` are deleted** with
  the banner's pace pips, which drew a picture of a system that no longer exists. `draw_tut_intro_card`
  and the rest of the banner are unreachable while every step carries `say` and are kept as the
  fallback for a step that somehow carries none.
- **THE PROSCENIUM DRAPES** (2026-07-30, Louis: "remove the little decor window on the left and
  right along with that little light. You are supposed to add the curtains of the theater podium on
  the left and right top instead" - then, of the four passes that followed, "**they look ai made and
  horrible**"). `draw_theatre_boxes` was framing the title screen with two lit windows out at the
  edges, which pull the eye AWAY from a wordmark in the middle - the one thing that screen exists to
  show. What replaced them went through a fan of wedges, then a stack of `draw_circle`s down each
  edge with a `draw_arc` tracing every rim, and Louis's verdict on the second is the finding worth
  keeping: **what makes code-drawn art look generated is that the PRIMITIVE is visible instead of
  the object.** Six discs and six circular outlines, alternating tones picked per shape rather than
  by any light, and not one vertical line in a thing that hangs. `menu_swags` is deleted and
  `menu_drapes` is a real proscenium - a swagged pelmet with braid and fringe, and two tied-back
  legs falling to the boards.
  **A FOLD IS A GRADIENT ACROSS CLOTH, NEVER AN OUTLINE AND NEVER A FLAT WEDGE.** A hanging drape is
  a corrugated sheet, so its surface normal swings inward and outward with every fold and
  `sin(phase)` IS how much of the stage light that patch is facing. `drape_velvet` is that one
  function and EVERY value in both legs, the pelmet, the heading and the swags comes out of it -
  which is why they read as one cloth hung in one room, where `velvet if k % 2 == 0 else velvet_lo`
  reads as a stack of coins. Two things about it are load-bearing: the lit term is gamma-biased
  (`pow(.., 2.0)`) because velvet SWALLOWS light, so the trough is broad and the crest a narrow rise
  out of it - a plain `0.5 + 0.5 * l` gives corrugated plastic; and the sheen exponent is 12, so
  widening it turns the velvet to satin.
  **THE CORRUGATION IS NOT A HORIZONTAL DISPLACEMENT**, which is worth saying because displacing it
  is the obvious move. A fold runs in DEPTH, toward the viewer, and depth projects to nothing in a
  flat front view - so the folds live entirely in the shading, and they still gather correctly,
  because a fold sits at a fixed fraction ACROSS the panel while the panel's own width changes down
  its length. `DRAPE_SILHOUETTE` is that width as a table (pinned full under the pelmet, billowing,
  pulled back at the tieback, falling free to the boards), so where the tie pinches the cloth the
  folds crowd together on their own, for the reason real ones do, without a single line placed by
  hand. It is the single source for the shape: `DRAPE_TIE_KEY` names the tieback row and the bow,
  the strap and the strap's LENGTH are all read off `drape_width`/`drape_sway` at that row. Left
  inline once and the strap overhung the cloth by 7px into open air, reading as a gold rod poking
  out of the curtain - the goal stem's bloom eating the word TONIGHT, met again.
  **THE GRADIENT IS FREE, SO SPEND IT.** `_soup_quad` (four corners, four colours) and
  `_soup_fan_lit` (a fan with its own centre colour) are the two new soup primitives, and between
  them the whole proscenium is one `canvas_item_add_triangle_array`. It is also entirely STATIC -
  it depends on the viewport and on nothing else - so `drape_bake` runs once and every later frame
  costs one call and no GDScript at all. That is the chainsaw's finding applied where it actually
  pays: batching only wins if the triangles are not rebuilt each frame. Measured on the title
  screen: 1.0-1.2ms draw, 280 calls, ~9k of the 24k primitives.
  **A FLAT FILL IS WHAT GIVES A SMALL OBJECT AWAY.** The bow proved it twice. Four flat tan polygons
  at 34px read as cardboard; the two loops merged into one lopsided egg because nothing separated
  them; and the strap ran straight through the middle like a stick through it. In order of what each
  fix bought: shade the loops from the centre out, push them apart so a notch of velvet shows
  between them, and stop the strap AT the knot. Its gold is also its own (`DRAPE_BOW`, far brighter
  and more saturated than `DRAPE_GOLD`) - the braid's gold is deliberately faint because it is a
  thread on cloth, and a solid 40px shape filled with it came out tan.
  **A TRIANGLE ARRAY GETS NO ANTIALIASING**, so every free-standing curved edge needs a FEATHER:
  one extra column (or row) of the same colour at alpha 0, two pixels out. The leading edge of a leg
  is a long near-vertical curve and came out visibly stair-stepped - the one thing left on the
  finished screen that still said programmer art. Two triangles a row buys what hardware AA would
  have. Same treatment on the swag hem.
  **THE FRINGE IS A SILHOUETTE, NOT A TEXTURE.** At 1.8px and 30% alpha it was invisible at any
  size: a strand that faint is below the threshold where the eye assembles a row of them into an
  edge - the Midnight Show's house lights ("a lamp needs a halo or it is just a brighter
  rectangle"), from the other direction.
  **They draw AFTER the veil and the spotlight**: they are the nearest thing in the room, so the
  wash that pushes the back wall behind the mark must not also wash them out.
  **The mark is placed off the MENU now, not the other way round** (Louis: "move it down a little,
  so it's centered between the top of the screen and the Play button. There shouldn't be much room
  between the yellow thin line and the play button itself"). The rows come off the stage lip, the
  mark is centred in the space above them, and the divider sits `MENU_ORN_LIFT` above the first card
  instead of hanging off the mark's bottom. The order is the fix: the mark could not be centred
  against rows that were positioned from the mark.
- **THE A IS TWO CLUBS, AND NOTHING IN THE MARK BURNS ANY MORE** (2026-07-30, Louis: "change the
  two torches into clubs and change to four balls to the two middle balls for the dash of the A").
  Say the consequence out loud, because it is the largest single change the logo has had: **the
  fire is gone.** The A was two torch shafts with a flame at the apex, and the flame is what the
  letter kept being read as - a bonfire, then a campfire, across three passes and two rebuilds.
  `CAP_TORCH_SHAFT`, `CAP_TORCH_SC` and `CAP_A_FIRE_SC` are deleted with it. A torch is 19 units
  of handle under 22 of fire, so the strokes could never be lengthened without the flame growing
  with them; a club is all stroke and has a NOSE where a torch has a wick, so the apex is a POINT
  and `CAP_A_CLUB_SC` is SOLVED rather than tuned - `CLUB_LEN * cos(CAP_A_LEAN) * 0.0277 = 1.000`,
  the strokes reach the cap line exactly. The lean is unchanged, which is why the letter's
  proportions did not move when the object inside it did. If a flame is ever wanted back it is one
  `cap_torch` call at the apex.
  **THE DASH IS THE TWO MIDDLE BALLS OF THE FOUR.** Four spanning stroke to stroke made a solid
  bar wedged into the letter; two leave daylight either side, which is what a stencilled A's
  crossbar looks like. Done by dropping the first and last of the row rather than by placing two
  balls at hand-picked fractions - the same trick each S loop uses on its tips - so the count still
  comes off the gap and the dash cannot drift into the strokes at another size.
  **AND THE MARK GOT HALF AGAIN AS BIG FOR FREE.** `MARK_RISE` fell from 2.45 letter heights to
  1.06: a flame at its flicker peak reached 1.42 above a wick already a letter height up, so for
  three passes the picture reserved two and a half letter heights for something whose LETTERS only
  filled one. Everything places the mark off `mark_height()` - the title screen, all five capsules,
  the credits, the key art - so the whole composition tightened the moment that number came down,
  which is exactly why those callers were made to read it. `MENU_MARK` went 108 -> 168 and the
  capsule's own size 112 -> 185 with its block CENTRED off `mark_height()` instead of a
  hand-picked 0.30, and **the capsule's little juggling cascade came off**: on a still storefront
  thumbnail it read as three stray balls and a brown streak over the word, which is
  indistinguishable from a rendering fault.
  **A WORDMARK NEEDS A WIDTH CLAMP, and this is how that got found.** Every caller sized the mark
  off the frame's HEIGHT, which is fine at 16:9 and wrong the moment a slot is portrait: the
  600x900 store capsule, rendered at 840x1006, put an 865px word through an 840px frame and cut
  the T and the A off at the edges. **Nothing about that slot had changed** - the letters had grown
  (a wider S) and a width nobody measured went over. `mark_width()` is the layout loop factored
  out so a caller can ASK, and `mark_fit_size()` returns the largest letter height that fits, which
  is exact rather than a search because width scales linearly with size. All five capsules, the key
  art and the title screen go through it now.
  **The S's carry one more ball each and a bigger loop** (Louis: "You can add one extra ball to
  each S, in order to make it smoother and slightly larger"), and the two halves of that note are
  one change: the extra ball is what buys the room to grow the loop without the balls parting
  company. The spacing is arithmetic - a loop carries its balls over a 1.5PI arc, so the gap
  between neighbours is `1.5 * PI * CAP_S_R / (CAP_S_BALLS - 1)` against a ball `2 * CAP_BALL_R`
  across: at 6 and 0.245 that is 0.231 against 0.238, a 3% overlap, where the old 5 and 0.225 gave
  0.265 against 0.238 and a visible gap between every pair. Seven was tried once and closed the
  stroke into a solid ring.
- **THE TITLE SCREEN IS A ROOM** (2026-07-30, Louis: "Make the title screen look better!, perhaps
  just add some of your own ideas in the concepts folder, next to the rest"). Two halves, and the
  first is not taste. **THE MENU WAS THE LAST BARE `draw_string` LIST IN THE GAME.** Settings and
  Pause were both rebuilt off centred text rows into the shared card language in July for the
  reason written down there - a flat row of text reads as cheap beside the shop and the sheet -
  and the TITLE screen, the one that makes the first impression, was still doing it. `menu_rows`
  gives the three options the pause menu's own language: an icon disc saying what the row does,
  the name, a line under it saying where it goes, the lit one raised on its own colour. Nothing
  about the list moved: `menu_options()` still decides what the rows ARE and `menu_input` still
  drives `menu_sel`, so the dressing is a lookup keyed on the option's name and a name it does not
  know simply draws plain.
  **THE ROWS STAND ON THE BOARDS.** `oy` used to be a flat fraction of the screen with a
  `mark_height()` floor under it; the cards are now laid so their FEET land just above the stage
  lip (`MENU_FLOOR`), which is what makes them furniture in the room instead of text floating over
  a picture of one. Clear of the lip by 16px on purpose - it is a bright 3px line with the
  footlights burning right above it, and a card crossing it gets a hot line and a row of bulbs
  showing through its own bottom edge.
  **FOUR PICTURES WERE BUILT AND ONE SURVIVES** (`menu_backdrop`). They were `--menu N` variants
  rendered to `store/concepts/`, only the SET changing between them - mark, rows and frame
  identical in all four, the same discipline the five store capsules follow, so the choice was
  about the picture rather than about four layouts. Louis picked **THE HOUSE**: hung velvet, a box
  either side with heads on the rail, footlights along the lip, boards for the menu to stand on. A
  title screen's job is to say what the game IS before a word is read, and this game is a
  performer walking out in front of a room - the old picture was a gradient, one cone and a row of
  bulbs floating at the bottom edge attached to nothing, which is a lit VOID rather than a
  theatre. FIRELIGHT, NIGHT and THE CURTAIN, CLOSED **were deleted with the selector** (Louis:
  "remove the concepts except the current one"), the same rule the F9 panel follows - an
  experiment that wins leaves the panel and the version it beat is deleted rather than stranded
  behind a switch nobody will flip. They are in git, with their renders, in the commit that added
  them. Every one was built out of furniture the stage already owns, which is the point: the title
  screen should be a room this game already has, not a fifth art style.
  **Three things went wrong on the way and all three are this file's own lessons, met again.**
  (1) The curtain went in at 0.255 red with no veil, so the S's warm balls sat on warm cloth of
  nearly their own value - the wordmark, the one thing that has to read instantly, had the least
  contrast on the screen. It takes the same veil `draw_backdrop` washes over a venue's set
  dressing, for the same reason: cloth behind the mark has to lose to it. (2) FIRELIGHT centred
  `capsule_embers` on the mark and scattered thirty sparks THROUGH the lettering, where they read
  as stray balls among the S's - the one thing a mark made of balls cannot afford. Dropped: the A
  already sheds real embers off its own torches, placed by the fire that makes them. (3) NIGHT's
  roofline was near-black on a sky that gets DARKER toward the horizon, so the bottom third went
  to one flat black and only the lit windows showed, floating like tan bricks. That is the
  Midnight Show's value-ladder rule and it is a LADDER: a wash of town light just above the
  roofline first so the sky is brightest exactly where the roofs cut into it, then roofs clearly
  above the sky's value, then windows well above both - and each window gets a halo, because a
  lamp without one is just a brighter rectangle.
- **THE WORDMARK READS AS A WORD** (2026-07-30, Louis: "move the letters closer together to seem
  more like the word tossa; remove the middle torch at the end (in A); replace the horizontal
  club with a ball; the middle ball in both s's are missing; remove 'a juggler's climb'"). Five
  notes, and two of them were bugs rather than taste.
  **THE S's WERE CUT IN HALF.** Each S is two loops of balls, and each loop dropped its FIRST and
  LAST ball - right at the outer tips, where an S doubles back and the balls crowd, which is
  correct. But the top loop's last ball and the bottom loop's first ball are not tips at all:
  they are THE SAME POINT, the waist where the two loops meet, and dropping both left a hole in
  the middle of the letter. The top loop runs to its end now (`range(1, nb)`, angle -1.5PI, which
  is exactly `s_r` below `c1` and therefore the waist) and the bottom still starts at 1, so the
  waist gets one ball and never two.
  **THE A HAD A THIRD TORCH IN IT.** The apex fire was a whole extra `cap_torch`, placed so its
  own wick landed where the two strokes meet - which hung a complete upright HANDLE down the
  middle of the letter between the two leaning ones. `cap_torch` grew a `handle` flag (the mirror
  of the `flame` flag it already had), so the apex draws fire and nothing else.
  **AND THAT UNLOCKED THE LETTER.** `CAP_TORCH_SC`'s own comment had been calling this the number
  the A lives or dies on, because a torch is 19 units of shaft under 22 of fire and the two want
  opposite things: the strokes want to reach the cap line, the flame gets away with overshooting
  it. At 0.044 the strokes stood at 0.75 of a letter height, so the A read as a bonfire. With the
  fire no longer needing a handle it can be drawn at its OWN scale, so `CAP_TORCH_SC` went to
  0.058 (strokes at 19 x cos(0.46) x 0.058 = 0.99, i.e. exactly the cap line) and `CAP_A_FIRE_SC`
  0.72 keeps the flame the size it already was (0.058 x 0.72 = 0.0418 against 0.044). `MARK_RISE`
  is recomputed from the same arithmetic that is written out beside it - the two terms moved in
  OPPOSITE directions and the total still grew, which is exactly why that block is arithmetic and
  not a nudge.
  **THE CROSSBAR IS BALLS**, which is the right object by the game's own naming: the mark is TOSS
  plus the letter a real juggling ball stands in for, which is what `TITLE_MARK` has said from the
  start. It also solves what a club could not - a club is a LONG thing laid across two strokes, so
  it had to be scaled to the gap, angled to the strokes and centred on its own balance point, and
  it still read as a stick resting against the letter. **And it is the S's ball at the S's size,
  as many as it takes** (Louis, same day: "the ball between the torches should have the same size
  as the other balls in the s, if it's too small to bridge the gap, just use more balls"). The
  first version sized ONE ball to the gap, which made it far and away the biggest ball in the
  picture - and a wordmark built out of props has to be built out of the SAME props, or the eye
  reads the odd one as a different object rather than as the same material spelling a different
  letter. So the radius is `CAP_BALL_R`, exactly what each ball in an S gets, and the COUNT does
  the bridging: four at every size the mark is drawn. **The count is intervals PLUS ONE** - sizing
  n to the span and then spreading n balls across it divides the span into n-1 gaps, each wider
  than a ball, which laid three balls with daylight between them. `CAP_A_BALL` went with that, and
  so did the whole `CAP_CLUB_KNOB/_TIP/_LEN/_MID` block: it existed only because the LAYOUT needed
  the club's extent out there, and the club's own measurements are `CLUB_BUTT_Y` / `CLUB_NOSE_Y`
  beside the profile that draws it.
  **`CAP_GAP` is 0.045**, down from 0.20 then 0.13. Third time on the same note, so a decisive
  cut rather than another shave: `cap_letter_width` measures each letter's real extent, so a gap
  here is true daylight between two objects rather than slack in a bounding box, and a word is
  letters that nearly touch. **The tagline is off both screens** - it came off the title screen
  first and the capsule was left for one commit on the argument that a storefront capsule wants a
  line under the logo. It does not want THIS one (Louis: "storefront capsule : jugglers climbs
  remove it"), and the mark is the same mark in both places. **`store/` was re-rendered**, because
  removing a string from the code does not change a PNG somebody uploads: `./render_store.sh` is
  the whole set in one command and it must be run after anything that changes the key art.
- **THE STAT MILESTONES ARE THINNED FOR DISPLAY, AND THAT IS A SECOND FUNCTION** (2026-07-30,
  Louis: they "look ugly and cramped ... you are allowed to change the tricks actual location,
  the rest you should choose what to show or not, don't move other stats around"). Strength
  offers one threshold per count from 3 to 15 of the prop in hand, so with clubs that is thirteen
  pips inside the bottom 30% of the track: measured on screen, a solid smear of white dots with
  four labels beside it. **The drawing already had a 15px spacing floor for LABELS and none at
  all for the pips it drew them next to** - the screen was admitting the list was too dense for
  the space and then drawing it anyway, which is the whole bug.
  `stat_pips()` is the drawn ladder and `stat_milestones()` stays the complete truth. **Two
  functions, not a filter, and the reason matters: a thinned list must never answer "what does my
  next point buy".** With clubs at Strength 20 the true next threshold is 24 for a sixth club,
  and a thinned list would report 28 for a seventh - so the "next: X at N (+M)" line reads the
  full list and only the pips are thinned. The pulsing pip is the next unreached one on the DRAWN
  ladder, which is not always the same threshold; it is not labelled "next", it only shows which
  way the track is heading, and the exact figure sits immediately under it.
  What survives a thin, in priority order: anything naming a SKILL (that is what a player is
  climbing toward, where "+3 catch frames" is one rung of five), the TOP milestone so the ceiling
  always has a mark, a full set of the prop in hand, then whatever clears `STAT_PIP_GAP` (0.075
  of the cap, which is the label's own 15px floor promoted to where the pips are CHOSEN). A
  forced row that would crowd the previous one replaces it unless that row names a skill.
  **STRENGTH NEEDED CONTENT, NOT JUST THINNING.** The count ladder for the prop in hand covers
  the bottom of the track and nothing else - fifteen clubs is 60 of 200, fifteen balls is 15 - so
  however the pips were thinned it stayed a cluster at the foot with one mark at the ceiling. The
  reason to push Strength past a full set of what you hold is to hold something HEAVIER, and it
  is the same rule (`PROP_STR_UNIT` x count), so one row per heavier prop at its FULL set is as
  real as the rows below it: with clubs in hand that is 15 knives at 90, 15 torches at 120, 15
  chainsaws at 195, and with balls the track becomes a genuine ladder of props end to end. No
  prop, count or pattern requirement moved.
  **THE THREE TRICK WALLS MOVED, and they are the only walls that may** - a pattern's gate and a
  prop's Strength requirement are both balance. Behind the Back acc 50 -> 25 (it sat on Columns,
  also acc 50, so one pip read "Columns, Behind the Back" and the bottom half of the track was
  bare; moved DOWN on purpose, since it is the first trick and earlier is the safe direction to
  move a gate someone is already climbing toward), High Toss str 50 -> 75 (out of the count
  crowd), Spin spd 40 -> 75 (it sat between the 2% and 5% slow pips; 75 is the empty stretch
  between 5% and 10%, and a mid-track wall reads right for the biggest multiplier in the game).
  `prop_plural()` also arrived, because six of the seven prop names are already plural and the
  Strength track was printing "15 chainsaw" beside "15 torches".
- **THE CLUB IS ONE PROFILE TABLE** (2026-07-30, F9 `club_v2`, ON. Louis asked for the club,
  the trick/pattern cards and the shop to be improved, with the originals kept behind F9).
  Three functions draw a club - `draw_club` on stage and as the wordmark's crossbar, `cap_club`
  on the shop card, `glow_silhouette` in the dark - and each carried its own copy of the shape.
  So each carried the same leftover mark: `draw_circle(Vector2(0, -16.5), 6.0)`, a disc as wide
  as the whole body. **In `cap_club` it sat 2 units PROUD of the tapered bulb whose own comment
  says it replaced the old cone, so the careful profile underneath was never the silhouette
  anybody saw** - what read was a fat head on a stick, i.e. the mallet. Deleting a duplicated
  mark in one of three copies fixes one picture in three, so the shape is a table (`CLUB_PROF`)
  and the three are one. Every mark on a club now comes out of `club_shape(y_hi, y_lo, inset,
  x0f, x1f)`, a closed polygon between two heights and two FRACTIONS of the club's own
  half-width: the silhouette is (-1, 1), the shop's shaded side (0.30, 1), its lacquer stripe
  (-0.80, -0.42). None of them can cross the outline because all of them are measured off it,
  and since a half-width is a function of height the polygon is simple by construction - it
  cannot self-intersect, the failure this file has now paid for three times.
  **The numbers that make it a club:** the body runs collar (+2) to nose (-22.5), 24.5 long by
  4.1 half-width, so 3:1 - the old bulb was 2.5:1 with the disc on top. The width HOLDS from
  -14 to -17 instead of peaking, because the first pass at the table peaked at -15 and fell
  away over four units and came out a bullet: what makes the top of a club read is a dome, i.e.
  full width and then a quick round-off. 4.1 is also a deliberate 0.7 clear of the knife's 3.4,
  since the two heavy props are told apart in the air by mass as much as by shape.
  **The ends carry the rest:** a knob is a bulb with a WAIST under it, and the nose is a
  rounded point. The stage version is flat per the round-props rule (one body inside a rim dark
  all the way round, `inset`), but the club gets what a ball cannot: a two-tone silhouette. A
  pale handle against a coloured body says "club" before any shading, and survives every venue
  palette because neither tone pretends to be light. **The handle takes no rim** - at 1.42
  half-width a rim thick enough not to shimmer eats it from both sides - and the decorated band
  is scale-gated like `draw_coin`'s milling.
  **CAP_CLUB_KNOB / CAP_CLUB_TIP ARE UNCHANGED ON PURPOSE**: they place the A's crossbar in the
  wordmark, so holding the length and balance point exactly lets the shape change without
  moving the logo. Verified on the capsule.
  **AND INTERPRETED GEOMETRY MUST BE BAKED.** Measured, seven clubs at the World Arena, same
  seeded act, back to back on a quiet machine: the old club **4.5ms** a frame, this one
  **4.7ms with the `_club_cache` and 7.8ms without it**. Five slices per club at ~186 `club_hw`
  samples each is ~12,000 GDScript loop iterations a frame. The chainsaw's `_saw_bake` is the
  same lesson from the hard side, where the geometry changes every tick and must be rebuilt. A
  club's never changes at all, so the first club of the session pays for all of them. The cache is keyed on
  the arguments, bounded at 64 entries, and **hands back the stored array, not a copy** - no
  caller may mutate it.
- **THE TRICK AND PATTERN CARDS** (2026-07-30, F9 `card_v2`, ON). Four things, and the first is
  the one that was doing the damage. (1) **THE PICTURE HANGS IN A FRAME.** The illustration was
  drawn straight onto the paper, so the art had no edge to be read against and the empty
  corners of the art box looked like unfinished card rather than deliberate margin. It sits in a
  recessed plate now (`draw_card_art_window`) with a pool of the kind's colour behind it - and
  no drop shadow, because the plate is sunk INTO the card and a shadow would claim it was lying
  on top. The art is drawn INSIDE that window (`box = r.grow(-5.5%)`), since a framed rect has
  rounded corners and the Shower's water and the Temple's floor are full-width blocks that ran
  visibly through the curve of the bottom two. (2) **A CARD HAS AN INDEX IN ITS CORNERS** - a
  four-point sparkle for a trick, a ring for a pattern, the same marks the backs are built
  round, so nothing is given away. That is the mark the eye uses to decide it is holding a card
  rather than looking at a panel with a picture on it. `CARD_PIP_KEEP` is a named constant
  because the Skills screen prints the skill's name across the foot of its card and "REVERSE
  CASCADE" at full width ran into the bottom-right pip. Pips are skipped below `r.size.x <
  r.size.y * 0.45`, or the unlock card's flip would collide them over the middle of the card.
  (3) **A CARD IS MOSTLY PICTURE.** The art was 250 of 520 (48%) and the words needed ~100,
  leaving a THIRD of the card empty in the worst place - bare paper between the description and
  the footer. 292 (56%), and the description is CENTRED in what is left, measured with the same
  `_wrap_lines` that draws it, so a one-line skill and a three-line one both sit in the middle
  of the same block. (4) **A BEAM STARTS BEHIND THE CARD AND DIES TO NOTHING.** The old rays
  were twelve `draw_line`s of CONSTANT width 6 from radius 0.42cw to 0.92cw - the card's own
  half-width is 0.5cw, so at the sides every ray BEGAN in mid-air, and a constant-width line
  with square ends that starts nowhere and never dims is a stick. Twelve brown sticks scattered
  round a card was the ugliest thing in the frame. Each is now one `draw_polygon` wedge from the
  card's CENTRE (so its base is hidden behind the thing emitting it) with per-vertex alpha to
  zero at the tip. **The first pass overshot and that is worth keeping**: 18 wedges at 0.17
  alpha, 1.1cw long, stopped being backlight and became a cartoon explosion, drawing the eye
  off the picture the card exists to show. Twelve at 0.10.
  **The backs got the same materials** (`draw_skill_card_back_v2`): the field is that same
  recessed plate, and the rosette is struck three times down it, big in the middle and small
  above and below - one mark at three sizes, which is how an ornamental back has always filled
  its height. **And the lattice was leaving the card**: its odd rows sat at
  `x = -0.315 + col * 0.21 + 0.105` in units of min(w, h), reaching 0.52 of a card whose
  half-width is 0.5 - measured 7px out through the right border. Rows come off the PLATE now.
  They were also nine-point polylines with square ends alternating up and down, meeting at
  visible kinks, so what read was five rows of wavy line with chevrons punched in them rather
  than a weave. One continuous sine per row with the phase flipped row to row gives the
  interlock honestly and has no joints to show. The plate's two ends are inset by DIFFERENT
  amounts, because the kind pill rides the top edge and "press any key to turn it over" sits at
  the foot, and a symmetric inset put the prompt down on the field.
- **THE SHOP IS A GRID** (2026-07-30, F9 `shop_v2`, ON). What was wrong was the ROOM, not the
  card. `shop_gear()` returns an empty array permanently now (the clothes went to the tailor,
  the glow tape became per-prop stock), so the panel's whole lower half was dead **by
  construction**: seven cards squeezed across the top, ~300px of nothing, then the detail strip.
  Seven cards in 1,040px gives each 141, so the object you are buying was drawn at about 60px in
  the top fifth of a tall card - the smallest thing on a screen whose entire job is to make you
  want it. Two rows of four make that 251 and turn the dead band into goods. At that width the
  card reads ACROSS: a big portrait NICHE on the left (the same recessed plate the skill cards
  hang their picture in, because a prop drawn on bare card has no edge and no reason to be where
  it is), the numbers in a column beside it, the price along the foot. Every fact that was on it
  is still on it. A short last row is CENTRED - three cards left-aligned under four reads as a
  card having failed to draw.
  **`shop_grid_on()` requires the gear row to be EMPTY**, so if gear ever returns (prop
  CATEGORIES is the accepted next piece and `shop_gear` is the seam it reopens at) the old
  single row draws exactly as it did rather than a grid quietly stealing the space gear needs.
  `shop_grid_cols()` is read by the drawing AND by `shop_input`'s up/down, because a grid whose
  cursor disagrees with its layout is precisely the failure this file already records for the
  seventh prop's buy keys. **Up/down is the one input change**, and it fixes a dead key: with
  gear empty the old branch computed `7 + sel * 1 / 7` = 7 for every prop and clamped it to 6,
  so both arrows simply jumped to the last card from anywhere.
  **A NICHE DOES NOT CLIP, SO IT HAS TO BE GIVEN HEADROOM.** The torch is drawn with its halo
  and rising embers, and those are placed relative to the PROP, which knows nothing about the
  window it stands in: at the first centring its embers came up out of the niche and printed
  themselves across the "own 15" above it. The stock line moved into the right-hand column and
  the air above the niche is now deliberately empty and belongs to whatever a prop throws off -
  which also looks right, a lit thing in a case ought to spill. Anything added to a prop that
  reaches higher than a torch's embers has to be checked here again.
- **EXPERIMENTS panel** (2026-07-25): F9, from anywhere, opens a small
  debug-only overlay (`debug_panel_open`, `draw_debug_panel`) listing named toggles
  (`experiments`, a `Dictionary`, defined in `EXPERIMENT_DEFS`) that switch an
  alternate version of a screen on or off live, no restart and no code edit - the
  point being to compare two real implementations side by side rather than guess from
  a description. **AN EXPERIMENT THAT WINS LEAVES THE PANEL** (the shape this settled
  into, written down 2026-07-27): `talent_tree`, `settings_cards`, `pause_cards`,
  `slot_cards` and `performer_polish` were all toggles here, Louis picked them, and
  their entries came out of `EXPERIMENT_DEFS` while the losing version was deleted, so
  a switch never survives the thing it used to switch to. What is left is what still
  has two real sides: `prop_art`, `round_v3`, `soft_light`, `flowers`, all defaulting
  ON. The retired ones left `draw_sheet_screen`/`draw_settings_screen`/
  `draw_pause_screen`/`draw_slots_screen` behind as one-line pass-throughs, and those
  are KEPT on purpose: they are the single call site each screen is opened through, so
  a future second picture is one line rather than a hunt. Debug choices persist
  across debug relaunches, but load/save of experiment state is itself gated behind
  `OS.is_debug_build()`, so a release export always uses its shipped defaults. **The
  dictionary literal on `var experiments` IS that shipped default, so every reader's
  `experiments.get("id", <fallback>)` must repeat the same value** - `flowers_on()`
  read `false` against a declaration of `true` for a while, which is harmless only for
  as long as nothing ever rebuilds the dictionary without that key. Adding another
  experiment later is one `EXPERIMENT_DEFS` entry plus whatever
  `if experiments.get("id", ...):` branch it actually switches.
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
- **THE DRAW WAS ON THE PHYSICS CLOCK, and that is the whole lag (2026-07-28, Louis: "the
  F10 button says i have 10 or even 12 ms draw time. and i feel the lag even at 40% slowmo,
  which should even help").** Every `queue_redraw()` in the game sat in `_physics_process`,
  which runs at 120Hz - and `queue_redraw()` is not a request to the renderer, it is a
  deferred callable pushed onto Godot's MessageQueue. `Main::iteration()` flushes that queue
  INSIDE its physics-step loop, so the callback fired, `NOTIFICATION_DRAW` was dispatched, and
  **`_draw()` ran 120 times a second whatever the display was actually showing.** On a 60Hz
  panel that is every other frame thrown away; at fifteen torches it was 116 of every 120.
  The fix is one line moved: the draw is driven from `_process`, which Godot calls exactly
  once per presented frame. Nothing else had to change - `_draw` reads live state, so it is as
  smooth at 60 draws a second as at 120, and the sim still steps 120 times regardless.
  **Measured at 1920x1016 with fifteen torches and the whole wardrobe worn:**
      before   5.2ms draw   551 calls   draws/s 122   engine fps 4.3
      after    2.8ms draw   533 calls   draws/s 100   engine fps 99-100
  **AND THE PROBE HAD BEEN PRINTING THE ANSWER FOR TWO SESSIONS.** `draws/s` sat pinned at
  120-127 in every run while `engine fps` tracked the load exactly - 4.3 fps at fifteen
  torches, 94.9 with nothing in the air, same window, same second. A previous pass concluded
  from that disagreement that `engine fps` was a macOS background-window artefact and
  dismissed it, and wrote that into this file. **When two counters disagree, the one that
  RESPONDS TO LOAD is the real one**: a windowing throttle does not care how many props are on
  stage. `draws/s` was measuring the physics rate wearing a renderer's name. macOS does
  throttle an unfocused window, so a backgrounded `engine fps` is still a soft number - but it
  is not a fabricated one. Do not put a `queue_redraw()` back into `_physics_process`; a paused
  screen already gets a frame from `_process` every frame.
- **...and the second cut was `_torch_bake`, the saw's own trick applied to the heaviest prop.**
  The torch handle was twenty-three immediate-mode shapes - haft, lit side, twelve cord
  hairlines, two ferrules with highlights, wick, four char lines - i.e. 345 draw calls of a
  600-call frame at fifteen torches. It bakes HARDER than the chainsaw's chain does, because
  the handle is the same local geometry at every tick as well as for every torch: nothing in it
  flickers, leans or turns, only the fire above it. So it is built once for the session and
  every torch is a transform and an emit. It also fixed a look problem - those cord lines were
  0.55 and 0.35 units wide, well under a pixel at the size a torch flies, so they shimmered on
  every tumble. `ca()` is deliberately not used inside a bake: `_cap_a` is a per-drawing fade,
  and folding it into shared vertex colours would let one faded torch fade all of them.
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
- **THE FLOWER PILE, and the batching primitive that came out of it (2026-07-27).**
  Louis: "the game is lagging again with all the flowers". The same probe, at the World
  Arena with seven torches: as the boards filled, draw calls went **331 -> 1140** and
  the frame went **2.1ms -> 6.3ms**, while primitives only went 16k -> 29k. That ratio
  is the rule above restating itself - the +810 is exactly 90 flowers (`FLOWER_PILE_MAX`)
  times the ~9 calls `draw_flower` makes (five petal ellipses, a centre, a stem, a leaf).
  The fix was available only because the flowers had just been made to STOP TURNING: a
  pile that never moves is static geometry. It is baked into one indexed triangle soup
  and re-emitted with a single `RenderingServer.canvas_item_add_triangle_array`, and the
  airborne ones - which do move - are rebuilt each frame into a second soup and emitted
  the same way. **Result: 1140 -> 368 calls, 6.3ms -> 2.55ms**, i.e. a full pile now
  costs ~0.45ms where it cost 4.2ms, and 368 is barely above the 331 an EMPTY stage
  draws. Measured after: the venue and the prop count barely move the call count at all
  (324 at the Backyard with 3 balls, 329 at the Arena with 7 torches), so props and
  crowd were never the lag - the flowers were.
  **The two things to copy, and the one trap.** Copy: `_soup_fan` / `_soup_ellipse` /
  `_soup_line` / `_soup_emit` are general - anything that draws many small shapes of the
  same kind can go through them. And a bake must be THROTTLED (`PILE_REBAKE`, 10 ticks):
  building 90 flowers of triangles in GDScript costs about as much as the draw calls it
  replaces, so re-baking every frame wins nothing - the whole gain is in not rebuilding.
  The trap: with a throttle, anything landing between bakes would be invisible until the
  next one, so the per-frame path draws everything whose land tick is newer than
  `_pile_bake_tick`. That predicate, not a flag, is what makes the split exact - every
  item is drawn once and nothing pops. The pile is also explicitly cleared with `thrown`
  at `start_run`, or last night's flowers draw under tonight's feet.
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
- **COLUMNS: EVERY OBJECT GOES STRAIGHT UP AND COMES DOWN WHERE IT LEFT** (2026-07-28,
  Louis, and the whole pattern's geometry now follows from that one sentence plus "for
  many objects you should figure out a solution that doesnt collide nor does it widen the
  arms positioning (wider looks bad)"). Three things were breaking it and all three had
  the same root, which is that a column's x was being decided by something other than the
  column.
  **(1) `drift`.** The inaccuracy term moved the LANDING sideways, so a prop came down a
  few px off its own line and was then thrown from the line again. It is dropped for lane
  throws, and it cost nothing to drop: `on_catch` judges a catch on TIMING, so a crooked
  column never bought a grain of difficulty. Accuracy still lands on the throw through
  `jitter`, which is timing.
  **(2) The centre column was a diagonal.** On an odd count the middle prop launched from
  the HAND and landed at centre, and `--collcheck` at 3 torches measured that as a real
  overlap of **-29.8px** with the prop in the neighbouring column. Every odd count carried
  the same signature (n=5 +1.6px, n=7 +8.6px) while every even count was comfortable
  (+24 to +37): the middle prop's diagonal WAS the collision. It is a column now, thrown
  from the centre line it lands on. **After: n=3 is +33.5px, n=5 +29.1px**, and no count
  from 3 to 15 is under +7.6px with the biggest-hitbox prop.
  **(3) The lane band grew with the count instead of fitting the stance.** Lanes were a
  flat 40px apart, so seven objects already reached 120px past centre and fifteen reached
  280, and since the hand stands under the column it is about to throw, the arms had to
  follow it out there. The band is now fixed by what the stance already reaches:
  `COL_LANE_IN` (44, outside the torso) out to `HAND_OUT_DX` (100, the outer catch x), and
  one side's lanes spread evenly inside it (`columns_step`, capped at `COL_LANE_STEP`).
  Measured lane sets: 3 objects sits at ±72 and the middle, 6 at ±44/±72/±100, 15 at ±44
  through ±100 in steps of 9.3 plus the middle. **Nothing ever passes ±100.**
  **The reason the tight end still clears:** a fixed band with N lanes crowds like
  `1/count`, which is the same curve `prop_hit_scale` already shrinks the hitbox on, so
  the clearance stays roughly flat (16.5px at 6 objects, 11.4 at 8, 7.9 at 15) instead of
  running out. That was luck the first time and is written down now so it stays true.
  **Two invariants that come with this.** The hand-to-centre floor (`COL_HAND_MIN`) is
  GONE, because no lane can sit inside the torso any more, and it was the thing making a
  prop leap sideways out of the hand on release. If a lane is ever allowed inside
  `COL_LANE_IN` again, that guard has to come back with it. And the centre column is
  DEALT (to the dominant hand, in `start_run`) rather than claimed by whoever threw
  first: on an odd count that hand holds one prop more than its side of the stage has
  columns, so the count only works out if its extra one is the centre. When the other
  hand claimed it, the dominant hand ran out of lanes and `assign_lane`'s fallback put
  two props in ONE column, which is a head-on collision by construction. That fallback is
  now the centre line, never an occupied lane.
- **THE LOW ROAD IS A MULTIPLE OF THE TAP, NEVER THE TAP PLUS SOMETHING** (2026-07-28,
  Louis on Half Shower: "for many objects, you throw the lower throw so high, that it
  collides with the upper throw, although the fysics don't measure the collisioin"). Both
  halves of that sentence were exactly right. The cap was `base_air + 0.2 * a full hold`,
  and `base_air` scales with the count (`count_air_scale`, 1.0 at four objects up to 2.8
  at fifteen), so the constant part stopped mattering: the "low" road peaked 379px against
  the high road's 433px at nine objects, 88% of the height of the throw it exists to duck
  under. Measured in the audit's own words, the low prop at the closest pass was being
  thrown at height fraction **0.83 at seven objects, 1.12 at nine and 1.40 - the ceiling -
  at eleven**. A MULTIPLE of `base_air` holds its proportion at every count, which is what
  the Shower's feed always did, and is why Louis could see that "shower does a perfect
  half shower". `HALFSHOWER_LOW` is `SHOWER_FEED * 1.3` now (his +30%), so the low road
  sits near half the high road's arc from three objects to fifteen. **After: the low prop
  is thrown at 0.24 and 0.43, hitbox clearance goes 1.8 to 11.9px at seven objects and
  0.9 to 6.8px at nine, and the closest pass is no longer a low-versus-high pair at all**
  (it is either two props nose to tail on the SAME high road, or the hand corner where one
  prop lands as the next leaves). The general rule, worth applying to any future pattern
  with two roads: **express one road's height as a fraction of the other, or of the tap
  both are built on, never as an offset from a base that itself moves with the count.**
- **HOW MUCH A PROP TURNS IS HOW BIG THE THROW WAS** (2026-07-28, Louis: "the low arc
  should only make the clubs, knives and torches turn once - that should be standard for
  low throws"). `prop_spin_angle` was `p * TAU * 2.0`: a flat two tumbles on EVERY throw,
  tap or full lob. That is why the LOW throws were the ones that read as spinning wildly,
  which is the opposite of what you would expect and the opposite of what a club does:
  the same two turns were being crammed into a fifth of the airtime. It is
  `1.0 + b.height` turns now, so a tap-floor throw turns once, a full-height throw turns
  twice as it always did, and the rotation finally tells you how big the throw was.
- **A PASS IS NOT A THROW** (2026-07-28, and the reason the Shower needed a new field on
  `Ball`). Louis's shower is: the dominant hand holds everything but one and throws them
  all high in the usual big arc, and the other hand sends its one prop back on "a very low
  (-80% lower than the shower before) arc ... the height should be almost zero", with
  clubs, knives and torches "not turning at all for the shower: just a horizontal throw
  with a vertically positioned object". `b.flat` marks that pass. Two things follow from
  it and only those two: `prop_spin_angle` returns 0 (so a club crosses standing upright)
  and the arc is scaled by `SHOWER_FEED_ARC`. **The airtime is deliberately untouched.**
  Height and airtime are otherwise ONE number here (`arc = ARC_PER_AIR * air`), so
  flattening the pass by shortening it would have sped the whole pattern up, and Louis had
  already played the current rhythm and called it fine. The arc is the only half that can
  move alone, and a horizontal pass is exactly the case where it should: same time to
  cross, almost no rise. **`b.flat` is reset at the top of every `do_throw`**, next to
  `b.bumped`, or a prop that fed once would stay flat for the rest of the run and its next
  HIGH throw would come out as a pass.
- **THE SHOWER PATTERNS FOLLOW THE DOMINANT HAND** (2026-07-28). Both showers hard-coded
  the high hand as RIGHT in four places while the DEAL had just been made to follow
  `dominant_hand`, so a left-hander would have had the whole load dealt into the left hand
  and every high throw demanded of the right. `next_throw_over_top`, the over-the-top
  branch, the two height floors and the feed's own test all read `dominant_hand` now,
  which is a no-op for a right-handed save and the difference between working and broken
  for a left-handed one. **Whenever a pattern has an asymmetric role for one hand, that
  role belongs to `dominant_hand`, never to a literal RIGHT.**
- **TENNIS's marked prop lobs 20% higher** (2026-07-28, Louis), `TENNIS_MIN` off
  `OVER_TOP_MIN`: it is the one prop crossing over a full weave rather than over a single
  road. Worth knowing before tuning it further: Tennis measures about zero clearance
  either way (+0.3px before, -0.7px after) and the closest pass is NOT the lob against the
  weave, it is the hand corner where an arriving prop sits on the point the next one
  launches from. That corner is the long-standing zero-room residual this file already
  documents for Tennis, and the lob's height does not move it.
- **A SHOWER IS DEALT ONE-HANDED** (2026-07-28, Louis: "you should make the shower have
  all objects in the dominant hand except one"). `deal_side` is pattern-aware now: under
  SHOWER the whole load starts in the dominant hand and exactly one in the other, which
  is both how a shower is picked up and what the pattern IS (one hand makes every high
  throw, the other only passes back), so an even split was always the wrong opening
  position for it.
  **It immediately exposed a real geometry bug, and the codebase had already written down
  the rule it broke.** "A landing never sits on a launch" is stated for over-the-top
  throws (`over_top_land_slot` picks the complement of the receiving hand's own launch
  slot), and the Shower's FEED was the one throw in the game breaking it: the feed landed
  OUTER, which is exactly where that same hand's high throw leaves from, so an arriving
  prop and a departing one sat on one point. It measured as the tightest pass in the
  pattern (-10.5px at five objects), and the one-handed deal made it far worse rather than
  causing it, because a throwing hand that owns the whole load catches and throws on
  nearly every beat instead of every other one. The feed lands INNER now and the hand
  carries it out to throw, which is the scoop a shower's hand actually makes.
  **Measured: -10.5 to +21.7px at five objects and -6.3 to +21.8 at seven, with the drawn
  gap going -38.5 to -6.3** - better than the even-deal original (+17.4) ever was. The
  closest pass is now two props crossing at the top of the same high road, which is what
  a shower IS. **The bug underneath it is worth remembering on its own:** `land_slot` sets
  `hand_catch_rest` (where the empty hand waits) while the plain-throw branch hard-coded
  `outer_pos` for the ball, so the two could disagree and a change to one silently did not
  move the other. The plain throw reads `slot_pos(b.to_hand, land_slot)` now, which is the
  same outer_pos for every other pattern. **STILL OPEN, and it needs Louis's call rather than a guess:** he also
  asked for the shower's throws to be "almost vertical for all balls, so way less height
  ... -80% height". The height is what buys the AIRTIME that lets count-1 objects be up at
  once, and the two do not both fit: at five objects the high road's arc is 334px over 155
  ticks of flight, so -80% leaves 67px and 31 ticks, which would need the throwing hand to
  release about fifteen times a second to keep four props up. A literal -80% therefore
  only works if the shower stops holding its load in the AIR and instead feeds it from a
  stack in the dominant hand (one or two flying, the rest waiting in the hand), which is a
  real reading of "all objects in the dominant hand except one" but makes the pattern much
  easier and would want its score multiplier revisited. The alternative is a shower whose
  height is only as much as the count genuinely needs, which is far lower than today at
  low counts (today's `SHOWER_MIN` forces a 280px arc on a three-object shower) but cannot
  reach -80% at high ones.
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
- **THE PACE LADDER, in every lesson (2026-07-27, Louis).** Every DRILL in every
  lesson runs three times over: `TUT_PHASES [0.5, 0.25, 0.0]` - half speed, quarter
  speed, full speed - built by the one helper `tut_paced(base, needs, after)`, which
  also strips `juggle` from the slow passes (they deal their own beats, so scolding
  the player for the script's rhythm is nonsense) and writes the Enter label. This
  replaced an ADAPTIVE ladder [0.5, 0.25, 0.15, 0.0] that sped up every 4 clean
  catches and slowed on a drop: it taught the rhythm by attrition, and a beginner who
  never found the first beat never saw the second. Only one-off KEY-teaching steps
  (`trick_on`/`trick_off`/`press_r`/`press_p`/`read`) sit outside the ladder, once
  each, at their own pinned `slow` - freezing the world to demand a key that is
  already named dead centre teaches nothing.
- **THE GUIDED BEAT** (the two slow passes; `tut_hold` and friends). Not a prompt: the
  world STOPS DEAD at every action the drill asks for, names the key - or the keys in
  their order, "J then K" - hears nothing else, and makes the press land. Sits in
  `_physics_process` next to the `freeze` hit-stop (input polled, hands ease, the sim
  clock does not move) but holds indefinitely; `cine_tick` keeps running so scenery,
  pulse and music breathe through it, because a stopped sim must never read as a hung
  game. What it asks for is READ OFF THE LIVE SIM, never scripted, so it works for one
  ball, a five-ball fountain, a Shower or a trick lesson (`tut_due_actions`):
  1. the step's own key first (`tut_due_key`, `trick_use` only) - an arm trick has to
     be armed BEFORE the throw it shapes;
  2. a prop within `TUT_EXCHANGE_LEAD` (14 ticks) of landing: a hand still HOLDING one
     is asked to throw and then catch - that exchange, repeated, IS the cascade - an
     empty hand only to catch;
  3. otherwise, if `balls_airborne() < tut_air_target()`, the hand whose turn it is
     feeds another prop up (turns alternate off `tut_last_throw`, which is what makes
     a cascade cross). `tut_air_target` is `num_balls - 1` at three or more (so every
     catch satisfies `juggling_catch` by construction) but `num_balls` at one and two,
     because two IS Louis's "throw, throw, catch, catch" drill.
  Ranks order the beat (trick 0, throw 1, catch 2) and an out-of-turn press is
  swallowed silently - never a whiff, never a wrong throw. A guided throw fires on the
  PRESS (a stopped clock cannot read hold-for-height, so it is always the tap the drill
  teaches) and a guided catch skips every failure branch in `on_catch` (`sure`). Three
  things clear a stuck beat: a drop (`drop_ball`), an R re-deal, and the step's goal
  being met (`tut_check` calls `tut_hold_abort`, so a WON step is free play again).
  `TUT_HOLD_GAP` (8) gives the world a breath of motion after each beat so the throw
  and catch are seen; `TUT_STEP_READ` (30) does the same at the top of a step.
  Prompt: `draw_tut_hold_cue`, in the same central bottom slot as the Enter callout,
  with a dark wash laid over the STAGE first (before the lesson's own furniture, so the
  HUD explaining the pause is not dimmed along with the scenery); pressed keys go green.
  `draw_tut_prompts` draws only the hands the beat names while one is open.
  `--demo` performs beats itself (`tut_hold_autoplay`), one rank a frame.
- **Tutorial (the basics):** one ball, two balls (both stacked in one hand, forced
  cascade so throws cross), three balls - each down the full ladder, so nine drill
  steps - then the R key and the full key legend. Eleven steps.
  Trick/pattern/prop/count lessons queue at the hub's LEARN row on unlock.
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
  A SECOND, unrelated Spin-lesson bug (2026-07-27, Louis: "I do it but it won't
  register") was that the lesson could not be completed at all: a `trick_use` step
  counts through `reward_trick`, which is only ever reached from a catch whose BALL
  carries a trick tag - and nothing but an ARM trick tags one - and which returns
  early on a zero bonus, which Spin's is by design (its reward is the x2 catch
  multiplier). Two closed gates, so the counter could never move however many perfect
  Spins were performed. A LIVE trick has no shaped throw to land later: it IS the
  press, and is now banked in `on_trick` the moment it fires.
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
  the pause menu. Toggle `flowers` there, then look at the rail and the boards to hold
  the flower economy against the gold one live, no relaunch. Debug builds only, per
  `OS.is_debug_build()` - see the EXPERIMENTS panel entry above.
- `--demo` autoplays; `--collcheck` audits mid-air clearance (self-drives now: it
  implies `--demo`, so a bare `--collcheck` actually juggles instead of reporting the
  1000000 px sentinel - and a run that still measured nothing prints a WARNING rather
  than a false all-clear); `--calib N` prints the
  robot's score at tick N and **implies `--demo` too, as of 2026-07-27 - it did not,
  and a bare `--calib` was a silent infinite hang** (it never entered `skip_menu`, so
  the run sat at the main menu where `tick` does not advance, and the `tick >=
  _calib_ticks` quit it waits on could never come. A bare `--calib 3` was left running
  for 24 minutes and printed nothing. Every past calib sweep must have been passing
  `--demo` by hand). Note N is a TICK COUNT floored at 120, not a number of balls;
  `--booking` runs a real act end to end and prints `ACT ...` on
  resolve; `--tutorial <id>` jumps into a lesson (the demo walks lessons end to end,
  miming Enter/R/P; a `--demo` lesson run never quits by itself, so give it a
  `--shotat` or it hangs); `--remap` (add `--pad` for the gamepad column) opens the
  Controls screen; `--fps` prints the performance probe once a second (see the
  PERFORMANCE entry: draw microseconds, physics microseconds, draw calls, primitives -
  fps itself is the least useful number on that line, being vsync-quantised);
  `--wallcard` and `--legend` (2026-07-27) jump straight to the
  scoped demo's wishlist card and the Purist Legend payoff card - the two end
  screens previously reachable only by completing the run that triggers them, so
  neither had a capture path at all; `--capsule` renders pure key-art (no UI) for Steam
  store assets - **and as of 2026-07-27 it is resolution-independent, so do NOT crop it
  out of a 720p frame any more.** Its positions were always relative to the viewport but
  its logo, ornament, subtitle, frame and bulbs were absolute pixels, so a bigger render
  used to give a big backdrop with a postage-stamp wordmark - which is the only reason
  the old instruction here was "capture at 1280x720 and crop", i.e. upscale, for the one
  job (a storefront thumbnail) where softness costs most. Everything now scales off
  `k = min(s.x/1280, s.y/720)`; the min, not the max, so a PORTRAIT render for the
  600x900 library capsule cannot push the wordmark out through the sides. Render each
  slot at ITS OWN aspect with the engine flag `--resolution WxH` (before the bare `--`)
  and then resample: `scratchpad/capsules.sh` does the whole set into `store/`.
  **The one hard constraint:** macOS clamps a window to the usable desktop (measured
  1920x1016 here) and Godot cannot screenshot headless (no viewport texture), so asking
  for 3840x1240 silently returns a clamped, WRONG-ASPECT frame that `sips` then squashes
  to size - distortion, the thing the capsule brief rules out. Ask only for boxes that
  fit AND match the target aspect. Everything up to the 600x900 vertical downsamples
  crisply; the 3840x1240 library hero is the one slot that must be upscaled 2x, and it
  is the one most tolerant of it (a wide atmospheric banner Valve overlays the logo on).
  `--glow` owns the
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
- **New dev flags, 2026-07-28 (evening).** `--wardrobe` wears all five costume pieces, which
  cost 28,500 between them - without it the finished figure has no capture path at all and
  every piece can only be judged alone. `--ucard trick:<id>` / `--ucard pattern:<id>` now deal
  the card ALREADY TURNED OVER (inspecting a face is what the flag is for), and
  `--ucard back:trick` / `--ucard back:pattern` deal the face-down side, which needs its own
  path because a real card waits for a keypress and a headless run presses nothing. Note that
  `ucard_flip` is an atick STAMP and **any negative value means face down**, so a fake stamp
  in the past cannot pre-flip it - that cost one wasted capture round.
- **F10's readout and `--fps` now agree with `engine fps`, and if they ever diverge again
  something has put a `queue_redraw()` back on the physics clock.** See the PERFORMANCE entry.
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
- **TWO MECHANICAL SWEEPS worth re-running after any big pass**, both a few seconds of
  shell over the one file and both of which found real things on 2026-07-27. (1) THE
  UNCALLED-FUNCTION SCAN: list every `^func name`, count references to `name(`, and
  report the ones whose only mention is their own definition. It found six dead
  functions left behind by features that had moved on (`coin_word_one`,
  `draw_letterbox` from the cut cutscenes, `draw_stat_track` and
  `stat_next_milestone` from the deleted classic sheet, `slot_summary` from the classic
  save list, `incoming_low` from the deleted sideways-dodge, `tut_sure_catch` whose job
  `on_catch`'s own `sure` took over). Expect Godot's own callbacks (`_ready`, `_draw`,
  `_physics_process`, `_input`, `_process`, `_notification`), the signal-connected
  `_on_joy_connection`, and the deliberately-kept `_click`/`_mix_into` audio helpers in
  the output every time. **A dead function is worse than clutter here: its comment goes
  on describing a mechanic that no longer exists**, which is how `incoming_low` was
  still explaining a dodge that the arms-reach-two-points pass deleted. (2) THE
  SAVE/LOAD KEY DIFF: pull every `set_value("sec", "key"` out of `save_progress` /
  `save_settings` and every `get_value` out of their loaders, and diff the two sets in
  both directions. Both came back symmetric, which is the answer you want and takes ten
  seconds to confirm.
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
  **IT REPORTS TWO NUMBERS NOW (2026-07-28), and the second one exists because of a real
  gap Louis named:** "the fysics don't measure the collisioin". `min clearance` is the
  hitbox (`prop_hit_scale`, which shrinks as the count climbs), and `min drawn gap` is the
  same closest pair judged at DRAWN size (`prop_scale`), which is what the player is
  actually watching. The two diverge hugely at high counts, so a change can look clean to
  the hitbox audit while the props visibly pass through each other. The drawn number is
  NOT a pass/fail gate the way the hitbox one is - at high counts every pattern's drawn
  props brush, which is the accepted cost of a stance that never widens - but it is the
  honest before/after for any change claiming to separate two roads. Both lines name the
  pair with `ot=` (which road each prop was on), `h=` (the height fraction it was thrown
  at) and `p=` (how far through its flight it was), and reading `h=` off the LOW prop is
  what proved the Half Shower diagnosis above.
  It found real overlaps the frame-perfect
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

## The idea review (2026-07-28) - what was accepted, and the test that decided it

Louis brought a long list of future ideas and asked which were worth building. The list is
in the session log; what matters here is **the test that sorted it**, because it will sort
the next list too. An idea is in if it passes all three pillars, and the one that rejects
the most is the first:

1. **Skill first.** A miss must always be the player's fault. Anything that perturbs a
   flight path the player cannot read - magnetism, wind, bounce randomness - is out, not
   because it is hard to build but because it breaks the contract the whole game rests on.
   Same for anything that catches FOR you (an "assistant" that saves one drop a show is
   the stats-auto-play failure the two-axis guardrail exists to prevent; Energy Drinks are
   the acceptable shape - a resource that buys stamina, never a catch).
2. **Juggling is real.** The sim has ONE gravity and `flight_pos` is a closed-form
   parabola every other number derives from. Zero-g, planets, black holes and boomerang
   props are not content, they are a second physics model.
3. **The first impression is calm.** Warm, theatrical, Balatro-grade. A rubber chicken at
   the World Arena undercuts the thing the climb is for. One or two joke props as a late
   unlock is a real juggler's joke routine; a joke CATEGORY is a different game.

**ACCEPTED, roughly in order of value per unit of work:**
- **PROP CATEGORIES, and the shop rebuilt around them** (Louis's own instinct, and the
  strongest item on the list). A CATEGORY - balls, rings, clubs, knives, torches, eggs,
  chainsaw - owns the mechanics that already live in `PROPS` (spin, stam, pwin, smult,
  fgive). A VARIANT inside it owns one modifier and a look: glass balls (harder to see,
  shatter on a drop, pay more), small rings (tighter catch, bigger multiplier), giant
  rings (slower and dramatic), double-spin clubs. The shop becomes a row of CATEGORY
  cards that opens into variants - the same drawer pattern the day hub already uses.
  **This is not only a content idea, it is a fix**: the prop row physically ran out of
  width at seven cards on 2026-07-28, and no arithmetic saves it at ten. It also turns
  "one more prop" from a balance problem into a variant within a known family.
- **AUDIENCE TASTE per venue**, extending a system that already exists rather than
  inventing one. `is_picky_crowd` already pays knives more before The Critic and The
  Hecklers, and `is_dark_context` already pays torches more where the stage is dark.
  Making that explicit and per-venue - a children's party loves big and funny, a
  connoisseur crowd pays for the hard pattern, a rich room pays for the expensive prop -
  makes the prop CHOICE matter more, which is exactly the balance goal, at the cost of
  one field and one multiplier.
- **A NAMED RIVAL per venue**: a score to beat with a face and a name, escalating up the
  ladder. It is a leaderboard the player can see, it gives the mid-game a shape the
  record boards alone do not, and it is nearly free - the number already exists.
- **MORE ENCORES.** Half the "random events" on the list (rain, a famous juggler in the
  room, a child on stage) ARE Encores, which is the cheapest content lever in the
  codebase: one `ENCORES` entry plus usually one `if encore_on(...)`. **Shadows only** is
  the good version of "invisible props" - the Blackout work already found that removing
  the shape entirely is "way too difficult", and a shadow tells you the x honestly.
- **TWO OR THREE MORE VENUES** mid-ladder (a children's party, a festival, a royal
  palace are all real gigs). Pure content: a `VENUES` row and its dressing.
- **VERIFY AND SHIP THE DAILY CHALLENGE.** It is built and still UNVERIFIED, and it is
  the best marketing hook on the whole list. A shareable result image would extend it.
- **GHOST REPLAYS**, medium-term and unusually feasible here: the sim is deterministic on
  a fixed 120Hz tick, which is the hard prerequisite most games lack.

**REJECTED, with the reason:**
- **Bouncy / magnetic balls, wind, environmental hazards that push a prop.** Pillar 1.
  A hazard that changes TIMING deterministically is fine and is really an Encore.
- **An assistant that auto-catches.** Pillar 1, most directly of anything on the list.
- **Zero-g, planets, black holes, clones, boomerang clubs.** Pillar 2.
- **Rubber chickens, fish, bananas, toilet rolls as a category.** Pillar 3. Note that
  **hats and plates are real juggling props with real technique** and would be welcome.
- **Heavy clubs, fireballs, sword clubs.** These are the weight axis `PROPS` already has;
  a heavier club is the stat re-skin the 2026-07-26 prop-identity pass explicitly
  rejected. Fireballs are torches.
- **Explosive balls, meteorites.** Tone.
- **Stacking rings.** Not juggling.
- **A full roguelike restructure and a prestige reset.** The career already supplies the
  run structure, and a prestige wipe throws away the RECORDS, which are the long-term
  hook. The cheap version of the same payoff is already built (the Purist Legend chase).
- **"Flaming knives: +100% flowers, -20% catch window".** Not rejected as an idea - it is
  already IMPLEMENTED, as `smult` and `pwin`. What is missing is that the shop states the
  reward ("pays x1.55") far more loudly than the risk. That is a UI beat, not a feature.
- **A crowd meter with faces.** `draw_gauge` already does this better.

**MILLS MESS is its own case and worth stating plainly.** It is the most famous pattern
not in the game and the one most worth having - and it is the most expensive thing on the
list, because arms currently reach exactly two points (`inner_pos`, `outer_pos`) with no
exceptions at all, and Mills Mess is *defined* by the arms crossing. It is an
architecture change, not content. Do not let it be scoped as "one more pattern".

**Claude's own additions, for whenever these come up again:**
- **A ROUTINE, BUILT IN ADVANCE** - the highest-value structural idea available. An act
  currently picks one prop, one pattern, one count and holds it. Letting the player build
  a routine of segments (3 clubs Cascade, then 5 balls Shower, then 7 torches) and having
  the crowd pay for VARIETY would use everything already built - patterns, props, counts,
  the applause clock - and give an act the shape it currently lacks.
- **THE SAVE SHOULD BE THE BIGGEST NUMBER IN THE GAME.** A drop costs a pip; a near-miss
  recovery pays nothing special. Balatro is the stated bar, and in Balatro the largest
  number comes from the most desperate moment. A prop caught late and low, below the
  normal line, is the most exciting thing that happens on this stage and the scoring is
  currently silent about it.
- **A RHYTHM READOUT in practice.** The game is entirely about timing and gives no direct
  timing feedback beyond PERFECT/GOOD/late. A metronome or a beat trace in practice would
  teach the thing the game is actually asking for.

## BUILT 2026-07-28 from Louis's own choices - all of it, including the wardrobe

The costume, the two-room shop and the glow split are in, and **the five pieces are now
DRAWN ON THE PERFORMER** (the one part that was still open at the end of the first pass).
See THE WARDROBE, ON THE MAN below for what each piece is and what the two on-screen passes
corrected. The wardrobe pass's own rules held throughout and are the ones to keep applying:
filled SHAPES not decorative strokes, every mark butting against something the base figure
already draws or riding a solved joint, and every colour taken from the venue's own palette.
Do not reshape the figure to fit a hat.

## THE 2026-07-28 (evening) PASS - Louis's own list, and what each item taught

- **THE LARGEST PERFORMANCE FINDING IN THE PROJECT'S HISTORY IS ONE LINE, and the previous
  two passes had the evidence and read it backwards.** See the PERFORMANCE entry above,
  which is rewritten: `queue_redraw()` lived in `_physics_process`, and because Godot flushes
  its MessageQueue INSIDE the physics-step loop, `_draw()` ran 120 times a second whatever
  the display was showing. Measured at fifteen torches, 1920x1016: **4.3 engine fps before,
  99-100 after.** The `draws/s` counter this file trusted was measuring the physics rate
  wearing a renderer's name.
- **THE WARDROBE, ON THE MAN** (`draw_top_hat`, `draw_stage_boot`, the tails and sequins in
  `draw_performer_polish`, the glove in `draw_hand` via `glove_cloth`, `vest_shape` shared so
  the plain and spangled waistcoats cannot drift). `--wardrobe` wears all five for a capture,
  which mattered more than it sounds: they cost 28,500 between them, so without the flag the
  finished figure had no capture path at all and each piece would only ever be checked alone -
  which is how a hat and a tailcoat end up fighting. **Two rounds of on-screen correction, and
  both faults were the same fault - a mark that was geometrically right and pictorially wrong.**
  (1) The tails hung straight down from the hip flare, which is where a tailcoat's tails
  attach - and read as a dressing gown, because measured against the leg block they were ON
  the leg for their whole length (thigh outer face 0.63h, calf 0.49h, tail 0.34-0.74h). They
  FLARE now, hem swung out to 0.86h, well clear of the leg and also what tails do on a man in
  motion. (2) The sequins were tinted toward `accent`, which at the Small Theatre is the same
  orange as the waistcoat under them - fifteen drawn, none visible; under the Glow Suit it was
  0.70/1.0/0.80 on 0.78/1.0/0.86, the same colour twice. **Metal reads by LIGHTNESS, never by
  hue**: they are pale house gold on a field pulled down a fifth. The boots made the third
  version of the same mistake in the other direction - a dark brown boot on near-black boards
  is not a dark boot, it is an absence - and were lifted by MULTIPLYING channels, never
  `lightened()`, which lerps toward white and turned the same brown into concrete.
- **ONLY A FLAME GLOWS, AND IT GLOWS AT THE FLAME** (Louis: "remove the glow from the objects
  except the torch, whose glow should be centered around the flame"). The dark-stage halo was
  on every prop in that prop's own colour - a claim that a lacquered club emits light - and it
  was centred on `pos`, the SIM origin, which for a torch is the grip about 25 units below the
  fire. So the one prop that genuinely glows was the one whose glow was in the wrong place.
  `torch_fire_center` is now the single answer to "where is the fire", shared by the stage
  halo, the Blackout flame and the shop card, and it only PARTLY rotates its offset - the same
  `CAP_FLAME_UPRIGHT` compromise the flame layers are drawn with, because a fully rotated
  offset swings the pool of light out sideways past the fire on every tumble.
- **THE GLOW LEGS, and the arms' own mistake made twice** (Louis: "make the glow in the dark
  legs look better"). Two causes. (1) The trousers were drawn in `suit_dk`, which is the
  JACKET's shadow, so under the Kit the man's whole lower half sat at 0.10/0.42/0.24 against a
  vest at 0.78/1.0/0.86 - the darkest thing on a costume whose selling point is that it glows.
  The recolour ladder covers suit/vest/collar and never had a trouser rung; it does now.
  (2) The outseam was hip-to-floor as ONE STRAIGHT CHORD over a leg that is two tapering
  capsules with a knee between them - measured, it started 0.13h inside the thigh and finished
  0.03h OUTSIDE the calf. That is exactly the fault this file already records for the old arm
  runs, repeated on the legs. `draw_glow_seam` takes a POLYLINE now (three passes, one call
  each, so a bent seam costs what a straight one did) and both the phosphor seam and the satin
  trouser stripe read their three x values off the leg block's own capsule geometry. A TURN-UP
  at the hem is the other half: a single stripe down a limb reads as a stick, a band across
  the hem reads as a trouser over a shoe - and it sits at the boot's shaft top when a boot is
  there, because a band across the middle of a boot is a band on the wrong garment.
- **THE SKILL DECK** (Louis: "hide the tricks and patterns until they are unlocked ... put a
  randomiser on it also ... make a design for the trick card (in general) and the pattern card
  (in general) and then for each trick and pattern a personal design card: the same way
  balatro has its jokers"). The architecture change is that **a wall and a skill are no longer
  the same thing**: `skill_gate_cleared` says you have earned A CARD, `owned_skills` (persisted
  as `gifted`, the old pity-director list) says what you HAVE, and `deal_skill_card` rolls one
  you do not own with flat odds. The PACING is untouched by construction - `skill_earned_count`
  counts cleared walls, so the same gates deal the same number of cards at the same moments -
  and only the identity behind each is a surprise. The card arrives FACE DOWN and turns over on
  the first press (`ucard_flip`, drawn as a horizontal squash: `cos(angle)` is the projected
  width, the same 2D pirouette `draw_juggler` uses on the body). The roll happens at DEAL, not
  at flip, because a reveal has to be the moment the player finds out rather than the moment
  the game makes up its mind.
  **THE FACES ARE PUNS, AND THAT IS THE POINT.** `draw_skill_preview` still draws each skill's
  true choreography off the sim's road data and is still what the Skills screen shows once a
  skill is yours - it is the better answer to "how does this work". But it is a diagram, and
  every diagram of a juggling pattern looks like every other one: arcs over a little man. A
  card you are DEALT has to be worth turning over and recognisable across a room. So: Spin is
  a ballerina, Behind the Back is two people talking behind your back, High Toss is a throw
  that leaves the top of the card, Cascade is a waterfall and Reverse Cascade is that same
  waterfall drawn upside down (one negative y scale, so improving one improves both), Columns
  is a Greek temple, Shower is a shower, Half Shower is the same shower at 0.34 scale with a
  rubber duck for size, Tennis is a tennis racket. Three rules for adding one: unit space
  inside the dispatcher's transform (art functions must NEVER call `draw_set_transform` - Godot
  REPLACES rather than composes, so an inner call throws the card's scale away), no text inside
  the art, and no feature under ~1.5px at the smallest size the card is drawn.
  **What the on-screen pass corrected, all four the same class of error - a shape that was
  correct and unreadable.** The racket's `ay` was the +90 perpendicular, so every offset built
  off it ran up-left and the racket came out held upside down with its grip clipped (one sign
  flip fixed six offsets, which is why they are all expressed off one axis vector). The
  waterfall's three streams included a dark one at almost exactly the pool's own tone, so it
  vanished into the water it fell into and the card read as two falls - falling water is the
  BRIGHTEST thing in a waterfall, so all three tones are now brightnesses of white-blue and
  the rock is the darkest thing on the card. The waterfall's cliff was a straight edge with
  0.05 notches in it, i.e. a plank; the jag is 0.13 on an irregular rhythm and the flat
  highlight strip across the top - which was doing most of the sawn-timber work - is gone.
  And the gossips were small enough behind the big figure's shoulders to read as two purple
  lollipops with their whisper merged into them.
- **OVERTHROW IS REMOVED** (Louis). It was the last "arm" trick and the odd one out for a real
  reason: what it DID - send one prop over the top - is what Reverse Cascade, Tennis, the
  Shower and the Half Shower already are, and selling the same road twice is the "heavier club"
  mistake this file already rejected for props. The over-the-top MACHINERY stays, because those
  patterns are built on it; the `pin_kind == "arm"` branch in the autoplayer stays too, with a
  note, since an arm trick is a plausible thing to add back.
- **THE SAVE MIGRATION IS THE PART WITH TEETH.** Until this pass a skill was unlocked by
  STANDING PAST ITS WALL - nothing was written down, and every launch recomputed it from the
  stats. Ownership is explicit now, so loading an old save without a migration would silently
  strip a mid-career juggler of every trick and pattern they had ever earned, with the save
  file looking perfectly intact. `skill_ver` seeds `gifted` from every wall the save has
  ALREADY cleared - exactly the set that was unlocked a moment before the update - once, per
  save. Overthrow was the LAST index in TRICKS, so unlike the pattern fold nothing shifted and
  a clamp plus two `erase` calls is that whole migration.
- **THE BACK ROOM IS A CARD** (Louis: "i find the button c hard to intuitively use to unlock
  the backroom of the shop. I'd like you to create a button for that (in the shop itself, where
  you need to press enter, like buying something)"). He is right and the reason generalises:
  **the back room is a PURCHASE** - it has a price, it takes a day segment, it asks for a
  confirmation - and every other purchase in this game is a card you walk onto and press Enter.
  A hotkey with no object behind it was the only thing in the shop you had to be told about,
  which is the definition of unintuitive. `shop_through_curtain` / `shop_leave_back_room` are
  the one implementation; C survives as a shortcut into the same functions, so the two routes
  cannot charge different fees. Once paid the card becomes the DOOR (cost 0, and
  `draw_price_plate`'s new `free_word` prints "walk through", because "0" beside a flower mark
  is not free, it is a price of nothing and reads as a bug).
- **THE HAT AND THE DRINKS ARE TWO OBJECTS** (Louis: the "energy drink hat ... should be
  distinct from energy drinks, which can be bought in the resting area"). They were ONE shop
  card that shape-shifted - the Helmet until owned, Energy Drinks forever after - sharing an id
  and therefore an ICON, so the thing you buy once and the thing you buy ten of were the same
  picture. Two rows now, the drinks row appearing only once there is a hat to pour them into,
  with their own three-can icon. And since he describes them as bought in the resting area,
  there is a REST-drawer row for them too (`try_buy_drinks` owns the whole transaction, so the
  hub and the counter cannot charge differently for the same case of cans); it costs no day
  segment, because a case of cans is not an evening out.
- **THE PRICE PLATE NOW KNOWS HOW MUCH ROOM IS LEFT.** The key was placed from the left edge
  and the price from the right with nothing measuring the gap, which worked only while the
  plate was wide. The eighth gear card took a card to 121px and "12,000" at 16pt drew straight
  through the keycap: the shop printed "7|12,000" as one run of digits. `kw` is measured now
  and the price SHRINKS through `fit_size` - this file's own rule, and a price is its purest
  case, since "12,0..." is not a price.
- **THE BALL, THE EGG AND THE CLUB, and the argument the last two passes were having.** THE
  ROUND PROPS ARE FLAT (2026-07-27) banned painted highlights for a good reason; RICH PROPS
  (2026-07-28) put the shop's lush version on stage and brought all of them straight back - a
  shaded disc, a bounce arc, a white ellipse, a 1.2px hot core, two 0.6px seams and a warm rim
  WEDGE (a thick partial arc, which this file says never to shade with). The way out was
  neither more shading nor less: it was a different SUBJECT. A juggling ball is a matte sewn
  ball, so it is one flat body, ONE curved seam as a tapered band, one broad dim sheen and a
  concentric rim. (The first attempt drew three panels meeting at an off-centre hub - correct
  for a three-panel ball, and on screen a propeller. **Three chunky spokes on a disc is a
  windmill long before it is a ball.**) The egg lost eleven 0.5px speckles for five real
  mottles. The club's body ran 15 units by 11.6 - 1.3:1, an onion - and is 2.3:1 now, longer
  AND narrower, because lengthening alone just makes a bigger onion; **a prop's silhouette and
  its two `PROP_ICON_MAG`/`OFF` numbers are one edit**, since the longer club would otherwise
  hang high in its card again and run past the hairline.
- **A DROPPED PROP IS THE SAME OBJECT IT WAS IN THE AIR** (Louis: "when the chainsaw drops, it
  should stay a chainsaw"). `draw_falling` was a `match` on the kind with a case per prop and a
  `_:` default that drew a BALL, so the seventh prop - added long after that function - fell
  out of the sky as a ball. That is precisely the failure this file already records for
  `draw_glow_in_dark`: a second renderer for an existing prop is easy to write without ever
  asking what the prop is, and **the only durable fix is not to have a second renderer.** It
  routes through `draw_prop_rich` now, so an eighth prop needs no edit there. Its fade rides
  `_cap_a`, because half these props paint their own reds and brass inside their own functions
  and multiplying the one colour the loop knew about faded a ball and left a chainsaw at full
  strength. `FALLEN_LINGER` is 360 ticks (three seconds, his number) against the old 70, which
  is barely long enough to look down and see what you dropped - **and that change exposed a
  latent bug**: the collapse gate waited on `falling.is_empty()`, i.e. "nothing dropped is
  still being DRAWN", which would have become a three-second stall before the results card.
  `still_dropping()` asks the question that was always meant.
- **ONE PROP IN A HAND ENDS THE ACT, GOAL OR NO GOAL** (Louis: "the game should automatically
  stop, finish, when the player has only one object and he is holding it. since he can't
  score"). His reasoning exactly: pillar two says a catch only scores with something still in
  the air, so a performer holding his last prop cannot earn another point however long he
  stands there. The existing empty-air rule required `goals_hit >= 1`, which is right for an
  ordinary bow and wrong here because there is nothing left to bank it with. Reachable at low
  counts specifically - three props and two drops leaves one, and two is under `DROP_LIMIT`, so
  nothing else was watching. It resolves as a graceful FINISH with its own `fail_text`
  ("stranded"), and `resolve_act`'s default to "bow" now only fires when no closer code already
  said why - otherwise the player is told they chose a bow they never chose.
- **THE DEBUG PURSE, held** (Louis: "make the debug money up button (m) and down, be able to
  held to rapidly increase amounts (toggle by the thousand)"). M/N join the stat keys on
  `sheet_repeat`. The step changes with the GESTURE: a tap is still `MONEY_TAP` (50), because
  "give me exactly 50 more" is a real thing to want at a counter, and a hold switches to
  `MONEY_HOLD_STEP` (1,000) and doubles on the same ramp. Two details worth keeping: the burst
  is folded into the AMOUNT rather than looped, since a purse has no cap and the loop would be
  64 `save_progress()` calls a tick; and the save is owed ONE write, on release
  (`_repeat_dirty`). The legend names the hold, and says `coin_word()` - it read "M/N gold"
  beside a purse reading "flowers".

## THE 2026-07-29 PASS - the second half of Louis's list

- **THE SHOWER'S RETURN PASS WAS A SECOND THROW** (Louis: "the bottom arc of the shower
  pattern goes way too slow, the time in the air is more than triple what it should be").
  `SHOWER_FEED` was 0.5 of a tap - 55 ticks at five objects, 67 at seven, i.e. most of half a
  second for a prop to cross 154px between two hands. 0.16 is his "more than triple" taken at
  its word. **The height is held where he already approved it**: arc = ARC_PER_AIR x air, so
  cutting the airtime to a third would have dragged the arc from 23px to 7 and made the pass
  read as the prop sliding sideways, so `SHOWER_FEED_ARC` is raised to compensate exactly.
  **It improves the geometry as well as the feel** - measured before/after at five and seven
  clubs with `--latecatch 4`: clearance -10.2 -> -6.2 and +7.5 -> +18.6, drawn gap -21.5 ->
  -6.4. A prop that crosses back quickly spends less time in the zone the high road uses.
  **And `HALFSHOWER_LOW` stopped being `SHOWER_FEED * 1.3`**: that expression was true and
  tidy right up until the moment the Shower was retuned, when it would have silently dragged
  a separately-tuned pattern down with it. **A constant derived from another constant is a
  coupling; between two things that are tuned independently it is a bug waiting for a retune.**
- **SWITCHING TO A SHOWER RE-DEALS THE LOAD** (Louis: "when i switch from one pattern to
  shower, the objects should switch hands, right now it starts with almost equal amounts in
  both hands"). `deal_side` already knew a shower is dealt one-handed and only ever ran at
  `start_run`, so the rule applied to an act BOOKED as a shower and not to one switched into
  with P - which is how a player actually reaches it. `redeal_for_pattern` moves everything
  but one into the dominant hand, and only props IN HANDS: anything already in the air keeps
  its own path, the same contract every other part of a live pattern switch honours. Verified
  in a scratch copy by constructing the exact state he describes - **3 left / 2 right becomes
  1 left / 4 right** the instant the pattern changes.
- **THE SHOP'S DOORS ARE PLACES, NOT GOODS** (Louis: "the buttons for front room and back room
  of the shop, should be placed not as an item, but on the right and left side of the screen
  respectively (going to the back feels like stepping to the right on the screen), and it
  should be the form of a triangle / arrow"). That sentence is a better design than the gear
  card it replaces, and the reason generalises: **a card in a row of goods asks "will you buy
  this?" when the honest question is "will you go through?"** So the way in stands against the
  right edge and the way out against the left, each a big arrow pointing the way it takes you -
  the POSITION is the information, before any lettering. `SHOP_DOOR_GUT` is reserved at BOTH
  edges in BOTH rooms: reserving it only where a door actually is would make the whole shop
  jump sideways every time you walked through one, and reserving nothing is what put the first
  bar straight through the last gear card.
- **THE CARDS ARE IN THE MENU** (Louis: "you should show the trick and pattern cards in the
  trick and pattern menu"). The Skills screen shows the dealt card beside the choreography
  preview, and the two are doing different jobs on purpose: the card is the OBJECT (the pun,
  the frame, the thing you would know across a room) and the preview is the DIAGRAM (the real
  roads, off the sim's own numbers). The card had only ever been seen for the few seconds of
  its own unlock, which is a lot of drawing for a moment that passes. **What paid for the
  space was deleting the "ready" badge**: it existed to tell an owned row from a locked one
  back when both printed a real name, and a locked row is now visibly a face-down card, so it
  was printing on every other row to say what the absence of a card back already said. The
  76px it occupied is why "Reverse Cascade" fits in a 196px column where it ellipsised at 268.
- **THE TAILOR** (Louis: "where is my tailer room where i can dress my juggler with the
  equipment i have gathered (also include standard equipment, which unlocks for each stage)").
  A PREPARE-drawer room, free and segment-less, with a mirror on the left and two columns on
  the right: THE SUIT (one standard costume per stage reached, plus "follow the stage", which
  is what the game did before this existed) and WHAT YOU WEAR (every bought piece, on or off).
  **Wearing is COSMETIC; the bonuses follow OWNERSHIP** - a top hat you own goes on lifting the
  room's generosity whether or not it is on your head, and the screen says so. The alternative
  makes it a loadout, and a loadout that looks like a dressing-up screen is a trap: a player
  would come to change how he LOOKS, take the hat off, and quietly lose money for the rest of
  the career without ever connecting the two. The Glow Suit is the one exception, because its
  whole effect IS being seen.
  **ONE WARDROBE, TWO SIZES.** `draw_mini_juggler` now runs the same `wearing()` tests and the
  same `draw_performer_polish` / `draw_top_hat` / `draw_stage_boot` the stage figure does - so
  the tailor's own mirror cannot show a man who owns a top hat standing there bare-headed. It
  takes a `k` SCALE PARAMETER rather than being wrapped in a transform, and that is not a
  style choice: `draw_stage_boot` and the spin branch call `draw_set_transform` themselves and
  Godot REPLACES rather than composes, so an outer scale is thrown away by the first boot drawn.
- **EVERY PATTERN x TRICK STATE, MEASURED** (Louis: "i want you to dissect the possibilities of
  patterns and tricks, since multiple can be active at the same time. are all of these valid
  states?"). The live state is one PATTERN (6, exactly one at a time by construction), at most
  one TOGGLE (Behind the Back / High Toss - `on_trick` replaces rather than adds), and a Spin,
  which can overlap either. Spin touches no throw geometry at all (it is a score multiplier, a
  catch penalty and a turning body), so the interesting space is 6 x 3 = 18. All eighteen were
  run through `--collcheck --latecatch 4` at five clubs.
  **THREE WERE BROKEN BY ONE ROOT CAUSE, AND IT WAS MINE FROM THE DAY BEFORE.** Three guards
  read `this_trick` to mean "an armed one-shot is riding this throw, so no pattern may flatten
  it into a low pass that would collect the full bonus anyway" - a real exploit, correctly
  guarded, back when Overthrow was the only thing that could set `this_trick` without a toggle.
  Removing Overthrow left those guards firing for TOGGLES, which are on for EVERY throw - so
  "do not flatten this one special throw" quietly became "this pattern's low road does not
  exist". Half Shower + High Toss measured +4.2px where the pattern alone measures +28.3.
  `armed_trick` is now the one an exploit could ride and `this_trick` stays what shapes the
  throw. **Measured after: Half Shower + High Toss 4.2 -> 38.1, Shower + Behind the Back
  -7.5 -> +2.5.** The general lesson: **when a feature is deleted, the guards written around it
  do not become dead code - they start guarding the wrong thing.**
  **THREE STATES REMAIN CONTRADICTORY AND ARE NOT BUGS.** Behind the Back x Columns (-13.6),
  Behind the Back x Reverse Cascade (-9.8), High Toss x Shower (-4.4). The first is the purest:
  a column is DEFINED by coming down where it left and Behind the Back by releasing from across
  the body, and no constant reconciles two definitions. The game WARNS as the toggle goes on
  (`trick_pattern_warning`) rather than refusing - it is the player's press, and "Behind the
  Back during Columns" is a reasonable thing to want to try - but props passing through each
  other with no explanation reads as a broken game, and one line of text turns it into a stunt.
  Tennis's own -0.4 baseline is the long-standing residual this file already documents.
- **A DEV FLAG THAT QUIETLY DOES SOMETHING ELSE IS WORSE THAN ONE THAT ERRORS**, and the audit
  above is what caught it. `dev_meet_req` floors the stats to satisfy a skill's wall - which
  USED to be the unlock. Since the deck change, clearing a wall only earns a card, so every
  `--pattern tennis` run was flooring stats, failing `pattern_unlocked`, and being silently
  snapped back to Cascade by `start_run`. The tell was Tennis's three audit rows coming back
  byte-for-byte identical to Cascade's. It grants ownership now. **Any tool that reads a gate
  needs re-checking whenever the meaning of "unlocked" moves.**
- **THE MECHANICS PDF IS REGENERATED FROM A COMMITTED SOURCE** (`docs/mechanics.html` ->
  `TOSSA_mechanics_reference.pdf`). The old PDF was built from something that was never
  committed, so updating it was archaeology; it is one file edit and one command now:
  `"/Applications/Brave Browser.app/Contents/MacOS/Brave Browser" --headless --disable-gpu
  --no-pdf-header-footer --print-to-pdf="$PWD/TOSSA_mechanics_reference.pdf"
  "file://$PWD/docs/mechanics.html"` (Brave is the only Chromium on this machine - there is no
  pandoc, wkhtmltopdf or weasyprint). It documents RULES only, never implementation: the throw
  and catch models, all four stats and exactly what each point buys, every prop's four levers
  and its signature edge, the six patterns, the three tricks, the combination table above, the
  score formula, the act, the crowd, the day, the shop, reputation and pay, all eleven Encores,
  and how the deck deals skills. **Forced page breaks were removed after the first render left
  three pages half empty** - a reference document that wastes a third of its paper reads as
  unfinished.

## THE 2026-07-29 (evening) PASS - exponential scoring, and the tailor as a shop

- **THE SCORE IS EXPONENTIAL AND AN ACT IS A SERIES OF RUNS** (Louis: "i'd also like balatro
  like scoring system: exponential ... doing x amount of tricks with difficulty value p during
  a performance multiplies the current score (since last drop) with p^x"). A run is the stretch
  since the last drop; raw points accumulate linearly inside one and a landed trick multiplies
  the WHOLE run, so x landings give p^x with no special case. A drop banks the run and opens
  the next at x1 - which turns a drop from "your streak resets" into "your exponential ends",
  and that is the tension the system exists for. `score` is a float: 64-bit ints stop at 9.2e18
  and this prints 1e40 on a good night. `score_text` switches to E notation past a million,
  because past that digits are scenery.
  **THE LINEAR HALF HAD TO COME DOWN AS THE CEILING CAME OFF.** He asked for the max multiplier
  gone AND for linear play to be a far worse way to reach a goal, and those pull opposite ways:
  an uncapped streak length is the steepest linear curve there is. `CHAIN_STEP` is 0.05, so
  sixty straight Perfects multiply by 4 rather than by sixty. Good catches now reset the chain
  too, which is what makes an all-Perfect act worth many times a merely clean one.
  **A TOGGLE'S p IS PER CATCH AND A LIVE TRICK'S IS PER PRESS**, which is why their numbers look
  nothing alike and is the single most important thing to remember when adding a trick. Measured:
  Behind the Back at diff 1.55 cleared all three goals of the Small Theatre in 3.2 seconds and
  scored 791,803, because a toggle shapes every throw, so x is the length of the run and p^60 of
  anything near 1.9 is not a game. At 1.055 the same toggle over sixty catches is x100.
- **TRICKS ARE CASCADE-ONLY EXCEPT HIGH TOSS AND SPIN**, which is the previous day's combination
  audit turned from a warning into a rule. Cascade is the only pattern with no shape of its own
  to protect; every other one IS a fixed geometry that a shaping trick contradicts.
- **THE SPIN HAS NO COOLDOWN AND A FULL LOCKOUT** (Louis: "change the spin cooldown to zero but
  make it impossible to catch or throw while spinning"). This is a better limiter than a timer
  for a reason worth keeping: a cooldown is a RULE, the lockout is a COST paid out of the same
  resource the pattern already spends. At three balls 44 blind ticks are free; at fifteen they
  are three missed catches. **The prop count polices the Spin by itself**, and buying the airtime
  to survive one (a High Toss first) becomes real play. The autoplayer needed `demo_spin_room`
  or `--demo --trick spin` deleted its own set in 202 ticks.
- **ONE HITBOX** (Louis). Three shrinks used to multiply together - per prop, per count, per
  pattern - so no two situations shared a collision rule and "does this work" had 6 x 13 x 7
  answers that moved each other. It is `HIT_FLOOR` for everything now, sized for the tightest
  real geometry in the game (fifteen chainsaws in Columns, ~9px of daylight).
- **THE TAILOR IS THE CLOTHES SHOP, AND A REAL LOADOUT** (Louis, reversing yesterday's
  cosmetic-only call: "I'd rather the tailor be a real loadout: buffs follow wearing"). Every
  garment is bought PER HOUSE - eight pieces in seven cuts, `owned_wear` keyed "<piece>:<stage>"
  so a ninth garment needs no migration - and worn from a rack that is a grid: garment down the
  side, house across the top. A piece cut for tonight's stage pays (`SET_PIECE_BONUS`), the full
  matching set pays more than the sum of its parts, and the header shows the count and the live
  multiplier BEFORE the act. The trap I was avoiding when I made it cosmetic is real, so the
  screen states the rule rather than hiding it.
  **THE LEGACY SAVE KEYS ARE WRITTEN FROM OWNERSHIP, NOT FROM WHAT IS WORN**, and that
  one-word difference is a save-eating bug if it goes the other way: the pre-tailor migration
  reads them as "bought", so a hat taken off for one act would come back as a hat never bought.
- **THE SHOP IS ONE ROOM AGAIN.** Clothes to the tailor, pie and drinks to REST, glow tape kept
  (it is about the props). The two rooms and the 16+ curtain existed to solve a layout problem -
  seven prop cards would not fit beside eleven gear ones - and with eight cards they fit. A gear
  card also has a MAXIMUM width now: at one item `innerw / 1` stretched it across the whole panel.
- **SLEEVES RUN TO THE WRIST** (Louis). A performer in evening dress has no bare forearm, and
  two skin capsules read as rolled-up shirtsleeves under a tailcoat.
- **THE DECK IS STILL, AND EVERY FACE WAS REDRAWN TO LOUIS'S OWN BRIEF.** Ballerina alone;
  temple without props or motion; a duck and a DUCKLING for Shower and Half Shower (the joke is
  the proportions, not the size - a scaled-down duck is a distant duck, a duckling has a bigger
  head on a shorter neck with a stubbier bill); an upright racket with a still ball; the Leaning
  Tower for High Toss; a fan of cards held behind the back for Behind the Back. **No card
  animates any more** - a still illustration reads as a printed card and an animated one reads
  as a screen.
  **LIMBS ARE CAPSULES, NOT HAND-WRITTEN OUTLINES.** The ballerina's arms were eight-point
  outlines - out along the top edge, back along the bottom - and at the shoulder the two edges
  CROSSED (measured: the outgoing edge at y -0.153 where the returning one was at -0.136, order
  flipping by x -0.044). Godot refuses a self-intersecting polygon silently, so the arms did not
  draw at all and the log filled with one triangulation failure per frame - the exact signature
  this file already records for a static shape. `draw_capsule` cannot fold through itself.
- **A DOTALL REGEX DELETED 16,099 LINES OF Game.gd**, and the recovery is the lesson.
  `re.search(r"const SHOP_DOOR_W := .*?walk through\n", src, re.S)` looks bounded and is not:
  with DOTALL, `.` crosses newlines, so it matched from that constant to the LAST "walk through"
  in the file. The work was recovered by restoring HEAD and re-applying every edit from the
  session transcript, and it cost about an hour. **Never use re.S on this file to delete a
  range.** Cut with `src.index(start)` / `src.index(end, i)` - two explicit anchors that fail
  loudly - and commit before any structural edit, which is the other half of why the loss was
  survivable at all.

- **THE LAST FOUR ICONS, and one rule that covers all of them** (2026-07-29, Louis: "The
  tailor icon ... look bad", "make the boots and gloves look better tho", "i want there to be a
  good looking visible icon of the pie"). Every one failed the same way: **the silhouette was
  doing none of the work and the details were being asked to carry it.**
    * THE TAILOR was a coat hanger, and the comment I wrote for it said the read "depends on
      that little question-mark of wire above the shoulders" - which is a confession, because a
      hanger at 18px is a triangle with a wire on it. It is a DRESS FORM now: a torso, so it is
      instantly a human shape and instantly about clothes, and nothing else in the game looks
      remotely like one.
    * THE PIE was a flat wedge with two lines across it. A slice of pie is not a flat shape -
      what makes one recognisable is the CUT FACE, the tall filled side you see because
      somebody took it out of a pie. Golden crimped top, dark filling below it, pastry base,
      steam.
    * THE BOOT had all the right parts and still read as a lump, because **it had no ankle**:
      every shape was a straight-sided slab stacked on the next. A real boot pinches at the
      ankle and swells again at the calf, and that single waist is what the eye reads as "boot"
      before it reads any detail. Plus a turned-down cuff, a stacked heel and a welt.
    * THE GLOVE had a scalloped hem and one seam, which at 23px is a pale blob with a frill.
      What was missing is the THUMB - the one shape a glove has that a bare hand does not - so
      it is drawn even though the bare hand deliberately has no fingers at all, because here it
      is the identifying mark rather than a detail.
- **EVERY RACK ROW CARRIES ITS OWN OBJECT** (Louis: "it's not obvious what the glowsuit button
  does"). He is right, and a NAME is a poor answer for a garment: eight text labels is a list,
  and a list is the one thing a wardrobe should never be. `draw_gear_icon` already draws each of
  these as the thing it is - it was built for the shop cards these rows replaced - so the
  picture costs nothing and the two cannot drift. Scaled 0.42 and sized by the WIDEST icon
  rather than the average: the glasses span 28 units either side and the helmet 40, so at 0.62
  they ran through the label beside them and the screen read "Energy Helme" with a can on the t.

## THE ANTE LADDER, and the two arithmetic errors it took to find it (2026-07-29)

Louis: "i want both exponential scoring and ante's. just like balatro", with hard pacing floors
("at least 15 seconds for the first reward and at least 60 seconds for the biggest ... no 5
second first reward possible at all"), and then, after seeing the first attempt: "the scoring
should feel normal and not exponential in the beginning ... The backyard should stay below 1000
as final score ... different stages scale exponential, but each stage has linear scoring", and
finally "you are out of whack". He was right, twice, and both faults were arithmetic rather than
taste.

- **A SCORE BAR CANNOT ENFORCE A TIME.** The score is exponential, so a run carrying a x500
  multiplier passes any fixed number in a handful of throws: whatever the bar, some player
  clears it in four seconds. The only thing that enforces a minimum time is a minimum time. A
  goal now banks on TWO gates - a number and a clock (`GOAL_MIN_S_LOW/HIGH`, 8/16/30 seconds at
  the Backyard rising to 15/32/60 at the last house). The number is what makes a weak setup
  struggle; the clock is what stops a strong one finishing early. Tricks move you from
  number-gated to clock-gated, which is a large improvement if you were slow and a marginal one
  at the wall - exactly what he asked for. **And a hidden gate must be shown**: the moment the
  score passes the bar the target line becomes a countdown, because a full bar that does nothing
  reads as a broken game.
- **ERROR ONE: THE CHAIN MADE THE SCORE QUADRATIC IN TIME.** `1 + 0.05 x chain`, uncapped,
  sounded like the answer to "remove the max multiplier" and summed over k catches to ~0.025k^2 -
  so a sixty-second act scored FOUR times a thirty-second one. "Each stage has linear scoring" is
  impossible under that however the constants are set, and it is the root of the first
  calibration being out of whack. `chain_mult` saturates now: `1 + 3 x c/(c+40)`, x1 cold, x2.5
  at forty, approaching x4 and never reaching it. A limit, not a wall - nothing "maxes out" on
  screen - and the total is linear in time again.
- **ERROR TWO: I SET THE LADDER FROM A CEILING INSTEAD OF FROM A CLIMB.** He named E50 as an
  upper BOUND, so I put the top rung near E48 and divided down: 152x a rung. No build in this
  game bridges 152x. **A ladder is measured from the climbing.** A real build gains ~6x a rung
  early and ~20x late (count +12% a prop, prop x1.0 to x2.1, pattern x1.0 to x1.5, costume to
  x1.78, plus p per trick activation which is itself scaled by all three). The rungs follow that:
      Backyard 800 | Street 5,100 | Theatre 35,200 | Circus 198k | Champ 2.4M | Arena 40M |
      Midnight 992M
  E notation now begins around the World Arena, an expert at the top house measures near E17,
  and both sit far inside the E50 he named. **The goal is the bar; the number you leave on the
  board is the flex.**
- **EVERY TRICK PAYS PER ACTIVATION, NOT PER CATCH**, and this is what actually makes "linear
  within a stage" true. A toggle shapes every throw while it runs, so paying it per catch made
  x the length of the act - an exponential in TIME. Paid per press, x is a thing the player
  chooses, bounded by attention and risk. Score inside a run is then (linear in time) x (a
  multiplier you built), which is Balatro's shape exactly.
- **MEASURED, first act, ante 0, frame-perfect bot:**
      Backyard, 3 balls, no tricks             803, all three goals, 38.6s
      Theatre, 5 clubs, no tricks           20,900, TWO of three goals, 372s
      Theatre, 5 clubs, ONE Behind the Back 35,212, all three goals, 206s
  The middle line is the design working rather than failing: the top rung of a house is not
  reachable by playing longer, only by bringing more, so a trickless act stalls at the second
  goal and cashes in. The third line is the same act with a single trick activation, and it
  clears the final goal (35,200) almost to the point. **The bot only ever activates a toggle
  once**, so 206s is the ONE-activation figure and a floor, not a ceiling: three activations is
  2.46^3 = x14.9 and lands the same act near 42 seconds, which is where the clock floor for
  that house sits (40s). That is the intended shape - build, and the clock becomes the wall.
- **`--ladder` IS THE ANSWER TO A LADDER THE BOT CANNOT MEASURE**, and building it immediately
  found two rungs I had wrong. It prints every house's expected build, its base rate, its goals,
  how many trick activations the final goal actually needs, and how long that build takes -
  computed from the live constants, in one second. `LADDER_BUILD` holds the build each house
  assumes, as DATA: until it existed the derivation lived in my head and in prose, which is how
  a ladder ends up with assumptions nobody can check. **Arithmetic in a comment rots; arithmetic
  in a tool gets re-run.** Run it after touching VENUE_BASE, GOAL_STEP, CATCH_PTS, CHAIN_GAIN,
  any trick's `diff`, or the set bonus.
  **What it found on its first run:** the World Arena and the Midnight Show each needed ONE MORE
  activation than the build they were supposedly derived from, and took 162 and 201 seconds
  against floors of 55 and 60. Their bases came down from 1.25e7/3.1e8 to 4.1e6/9.2e7. Every
  rung is now clock-gated at its own build - the wall a well-built act meets is the clock, and a
  weaker one is held by the number, which is the whole design:
      Backyard 0 acts, 22s vs 30s floor    Circus 3, 35s vs 45s      Arena 4, 53s vs 55s
      Street 1, 14s vs 35s                 Champ 4, 32s vs 50s       Midnight 5, 60s vs 60s
      Theatre 2, 39s vs 40s
- **A HIGH-THROWING PATTERN IS WHAT MAKES A SPIN POSSIBLE AT HIGH COUNTS**, and this fell out of
  the measurements rather than being designed. At seven objects a plain Cascade tap gives a
  catch every 19 ticks and a Spin needs 52 clear - it can never fit. Half Shower's high road is
  176 ticks and leaves gaps of about 50, which is why `--trick spin` scored 27,410 under Half
  Shower and exactly 0 under the same count in Cascade. **Pattern choice and trick choice are
  therefore coupled through airtime**, which is a real piece of depth and worth protecting: any
  future change to pattern heights changes which tricks are usable at which counts.
- **THE BOT CANNOT MEASURE THE TOP HOUSES, AND THE REASON IS ARITHMETIC RATHER THAN A
  BALANCE FAULT.** `--demo --trick spin` at seven torches scored ZERO and took no goals in 338
  seconds, which looks like a broken ladder and is not. At seven objects the tap airtime is 134
  ticks, so a catch arrives every 19; a Spin blocks catching for 44 and `demo_spin_room` wants
  52 clear. **There is never a 52-tick gap at that count**, so the autoplayer lands no
  activations at all, and with `p^0 = 1` the run never leaves its base rate (~200/s against a
  750,000 first goal). A HUMAN buys the gap - a High Toss first, then Spin - which is precisely
  the interaction the lockout exists to create. The bot only ever throws taps, so it cannot.
  **Consequence to remember: every rung above the Small Theatre is calibrated by arithmetic and
  has never been measured.** The assumed activation counts are 2-3 at the middle houses and 4+
  at the top, and the ladder is very sensitive to that guess - each activation is worth about
  x4 at the Championship, so being wrong by two activations is a 16x error. This is the first
  thing to check with a controller in hand.
- **AND THE THEATRE MEASUREMENT ONLY BECAME POSSIBLE AFTER FIXING THE HARNESS, which is the same
  finding as `dev_meet_req` the day before wearing a different disguise.** `--trick btb` scored
  20,900 - byte for byte the trickless number - because `_demo_step` assigned `toggle_on`
  DIRECTLY. That was harmless while a toggle's only effect was to reshape throws, and became a
  silent lie the moment the PRESS is what multiplies the run, since `apply_trick_mult` lives in
  `on_trick` and `on_trick` was never reached. It calls the real handler now. **A dev flag that
  quietly does something else is worse than one that errors** - and when a measurement comes
  back suspiciously equal to its control, suspect the harness before the model.
- **THE ANTE IS GENTLER THAN THE RUNGS.** 1.25^n capped at 6, so four acts at a venue make it
  2.4x and eight make it 6x. At my first guess (1.45 capped at 12) the SECOND act at a house was
  already harder than the house above it, which does not push a player up the ladder, it strands
  them - and reputation comes from goals, so a stranded player cannot earn their way out.
- **A BANKED GOAL IS PAID IN FLOWERS, ONE FROM EACH WING** (Louis: "subgoals should flower small
  flowers, one on each side"). `throw_from_crowd` takes a `side` now. Two stems arriving together
  from opposite sides reads as a GESTURE; the same two from random seats read as one more gust of
  the ordinary drift and the moment is lost.
- **THE WARDROBE IS PRICED BY HOUSE** (Louis: "backyard should be cheap, midnight expensive").
  `WEAR_STAGE_COST` runs 0.35 to 3.60, so a Backyard top hat is 1,400 and a Midnight one 14,400.
  One flat price made the seven cuts interchangeable, which is exactly wrong when the whole point
  of a per-house wardrobe is that the grand houses are an aspiration.

## MINIMUM REQUIREMENTS (2026-07-28) - derived from measurement, not guessed

Louis asked for a guess at the minimum spec. It is better than a guess, because the numbers
below are measured on this machine and the shape of this game's cost is unusual enough to be
worth stating plainly.

**What it actually costs.** MacBook Air M5, 1920x1016, full wardrobe worn, at the absolute
ceiling the game can reach (fifteen torches at the World Arena - Strength 200 and 9,000
flowers a prop, so almost nobody will see it):

      draw time      2.85 ms per frame        draw calls   ~533      primitives  ~26k
      physics        ~100 us per tick at 120/s (about 1.2% of one core)
      total          45.5% of ONE core at 100 fps
      memory         ~415 MB resident (a debug editor run; an export is lower)
      renderer       gl_compatibility - OpenGL 3.3 / ES 3.0. **No Vulkan required.**

A typical player at five props measures 1.7 ms, i.e. under half of that.

**The binding constraint is single-thread CPU, and nothing else is close.** The draw is
immediate-mode 2D on the main thread; the sim is a closed-form parabola per prop. Core count
barely matters and clock/IPC is everything, which is an unusual shape: **a modern 4-core beats
an old 8-core here comfortably.** The GPU bar is almost nothing - fill rate was measured as
irrelevant (quartering the window changed nothing) and the compatibility renderer asks for
2010-era OpenGL.

Holding 60 fps needs the frame under 16.6 ms against a worst case of 2.85, so there is ~5.8x
of headroom. A CPU with roughly a fifth of the M5's single-thread performance is the floor;
the spec below sits a notch above it so the floor is a floor and not a cliff.

      MINIMUM (60 fps at 1280x720, up to about seven props)
        OS        Windows 10 64-bit  /  macOS 11 Big Sur  /  Ubuntu 20.04
                  (these are Godot 4.7's own floors, not ours)
        CPU       dual-core x86-64 with SSE4.2, ~2.4 GHz, 2013 or later -
                  Intel Core i3-4130 / AMD FX-6300 or better. Any Apple Silicon.
        GPU       anything with OpenGL 3.3 and 256 MB - Intel HD Graphics 4000 (2012) up
        RAM       4 GB
        Storage   250 MB
        Display   1280x720

      RECOMMENDED (120 fps at 1920x1080 with a heavy set of torches)
        CPU       quad-core, 3.0 GHz, 2017 or later - Intel i5-8400 / Ryzen 5 1600 up
        GPU       any dedicated card, or Intel Iris Xe / Apple M1 up
        RAM       8 GB
        Display   1920x1080; a 120 Hz panel is what the 120-tick sim was built for

**Before shipping these, do the one thing this machine cannot do: run it on something slow.**
Every number above is from a 2025 Apple laptop, and the honest use of it is as a RATIO
(2.85 ms of a 16.6 ms budget), not as evidence about a 2013 i3. An old Windows laptop for an
afternoon would turn the arithmetic above into a fact.

## AGREED (2026-07-28, Louis chose these explicitly)

Three decisions taken with him rather than guessed, so a later session builds what he
picked and not what seemed reasonable at the time.

- **FIVE COSTUME PIECES, one buff each.** Every one is drawn on the performer by
  `draw_performer_polish` (which already paints lapels, cummerbund, buttons and cuffs in
  the venue's own colours) and every buff sits on the COMFORT/REWARD axis - none of them
  touches the catch timing, which is the guardrail that makes the stats safe.
      SILK GLOVES       2,500   off-Perfect catches get the clubs' own `fgive`
                                forgiveness, on every prop
      STAGE BOOTS       3,500   every throw costs 1 less stamina, floored at 1
      TOP HAT           4,000   the room throws a better TIER more often
                                (lifts flower_tier_roll, posies where it was stems)
      TAILCOAT          6,000   the crowd warms 15% faster (applause gain)
      SEQUIN WAISTCOAT 12,000   +20% flower throw RATE - the late-game money piece
- **THE BACK OF THE SHOP, behind a one-off 16+ fee** (500, and a day segment the first
  time, like any errand). FRONT: balls, eggs, rings, clubs, and the safe gear. BACK:
  knives, torches, the chainsaw, Uncle Dan's Pie and the glow gear. It is a joke and it
  is also the fix for the thing that broke on 2026-07-28 - a single row of prop cards ran
  out of screen width at seven props, and no arithmetic saves it at eleven.
- **THE GLOW KIT SPLITS IN TWO** (Louis: "the glow in dark kit should be able to sell it's
  individual props also - keep the kit in case someone wants to buy it all at once, but
  also sell the individual parts"): GLOW TAPE (the props carry phosphor) and the GLOW SUIT
  (the performer does), with the Kit kept as a discounted bundle that sets both.
  `glow_kit_lit()` has to split into a props test and a suit test to match.
- **THE FILL-RATE "CLIFF" WAS A MEASURING ERROR - and so was the correction. READ THE
  `queue_redraw` ENTRY ABOVE BEFORE THIS ONE.** What follows was written on 2026-07-28 and its
  diagnosis is half right: there was no fill-rate cliff, and `engine fps` from a backgrounded
  window is indeed a soft number. But the conclusion it drew - that `draws/s` is the real frame
  rate and `engine fps` means nothing - is **wrong**, and believing it hid a tenfold frame-rate
  loss for a whole session. `draws/s` was pinned at 120 because the draw was on the physics
  clock, not because the game was presenting 120 frames. The 15-prop numbers quoted below
  ("3.2ms of draw time and 122 draws a second") are therefore a measurement of 120Hz redrawing,
  not of 120Hz display. Kept, corrected in place, because the reasoning error in it is the most
  instructive thing in this file. A pass concluded that rich props collapsed the game from 145 fps to
  15, blamed translucent overdraw, and wrote that into the code. It was wrong. Every one
  of those numbers came from a BACKGROUNDED window, and macOS throttles the presentation
  of an unfocused window - `Engine.get_frames_per_second()` collapses while the game goes
  on drawing perfectly happily. The probe's own `draws/s` counter, incremented inside
  `_draw`, read ~120 in the very same runs that reported 15, and nobody compared the two.
  Re-measured at 1920x1016 with FIFTEEN rich props and a full flower pile: **3.2ms of draw
  time and 122 draws a second.** `--fps` now prints `draws/s` first and labels the engine
  number `engine fps`. **Treat `engine fps` as meaningless unless the window has focus.**
  The wider lesson is the one this file already half-knew ("beware fps as a metric") and
  did not apply: when a metric disagrees with every other metric, suspect the metric.
- **RICH PROPS SHIP ON.** Louis's call, made against the numbers below - he wants to judge
  it by feel and F9 it off if a heavy set drags. **The optimisation is the open follow-up:**
  batch `cap_ball` into one draw call the way `_saw_bake` already does for the chainsaw,
  then re-measure. Measured at 15 balls with a full flower pile, World Arena:
      rich OFF   364 calls   2.32ms   49-64 fps
      rich ON    650 calls   3.20ms   27-30 fps
  The cost is ~10 extra shapes per ball, four of them wide translucent arcs.

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
  **BLACKOUT rendering, rebuilt AGAIN 2026-07-27 - the cut is GONE (Louis's own call,
  chosen over a cross-fade and over a dimming glow).** The rule now is one sentence:
  **the house lights are out, so in the air a prop is only the glow it carries, from
  throw to catch.** No threshold, no cross-fade, nothing to tune. What this replaced:
  the lights were cut at `BLACKOUT_CUT` (0.68 of the flight) and a full-colour prop
  became a shapeless afterglow in a single frame. Louis: the object "changes color into
  glow in the dark ... i want the glow in the dark to fade in and out, not that sudden.
  Perhaps you should even just make the challenge entirely: the objects are hard to see,
  because it is dark." He picked exactly that. **The lesson worth keeping: any threshold
  mid-flight is a cliff, and there is no good place to put one - the fix was to delete
  the state change, not to smooth it.**
  - **The clubs used to stop turning, and it was a one-argument bug.**
    `draw_glow_in_dark` called `glow_silhouette(pos, kind, sc, 0.0, ...)` - a hard-coded
    angle - while that function has always taken one and used it for the three spinning
    props. So the instant the lights took a club it snapped upright and froze for the
    rest of the fall. It takes `prop_spin_angle(b)` now. Check this whenever a second
    renderer is added for an existing prop: the silhouette path is easy to write without
    ever asking what the prop is doing.
  - **The SHAPE is kept for everyone, deliberately.** Handing a non-Kit player a
    shapeless glow for a WHOLE flight would be juggling blind, which was tried and
    rejected once already as "way too difficult" - and was only survivable before
    because the rise stayed fully lit. `draw_blackout_afterglow` is deleted.
  - **The Glow Kit is now brightness, not mercy** (`BLACKOUT_UNLIT` 0.55 against 1.0):
    the difference between a prop you can READ and one you can only find. That is a
    better thing to sell than a special case on one Encore.
  - a **torch** is still the exception the Encore is built around: it keeps its flame.
    `draw_torch_flame` was split out of `draw_torch` so the dark draws the very same
    flame the lit torch does - same size (it used to be hand-written at roughly half
    scale and visibly shrank at the cut), same tumble via the shared `prop_spin_angle`,
    same flicker - plus the pool of light the fire throws, centred on the prop's true
    position so the catch point stays legible while the flame rides out on the tumble.
  - **Still true, and a known inconsistency:** a HELD prop is drawn by the hand code, not
    by `draw_balls_in_flight`, so it keeps its normal colours through a Blackout. The
    Encore text says "in the air" for exactly that reason. Worth revisiting if it ever
    reads wrong.
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
  the day: a stat recap, "WISHLIST TOSSA ON STEAM", then back into the SAME career -
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

- **THE THING THAT BREAKS ON A RENAME LIVES OUTSIDE THE REPO.** Louis plays by clicking
  `/Applications/TOSSA.app`, which is not an exported game at all - it is a wrapper whose
  entire payload is `exec godot --path <folder>`. That path is hard-coded, it sits outside
  the project, and it is therefore invisible to every grep, rename and commit made inside
  it. Renaming the folder on 2026-07-28 broke both launchers instantly and SILENTLY:
  Godot exits immediately when `--path` points at nothing, so the icon bounces once and
  stops, with no error printed anywhere. `install_apps.sh` rebuilds both from the repo -
  **run it after moving or renaming the project folder**, and remember the general shape
  of the mistake: when renaming anything, ask what refers to it from OUTSIDE the thing
  being renamed. Here that was three places, and only one of them was in the repo (the
  save files' folder, the GitHub remote, and these launchers).
- **THE APP ICON WAS A BAD EXPORT, not a bad drawing** (found the same day). `icon.svg` is
  a clean 128x128 tile filling its whole viewBox, but `export/icons/icon_1024.png` had the
  art rendered at ~440px in the TOP-LEFT corner of a 1024 canvas with the rest
  transparent - so the Dock drew it at under half size, tucked into a corner, and had done
  for as long as the icons existed. Rebuilt on Apple's actual grid (an app tile occupies
  824 of 1024, a 100px margin all round) by rendering the SVG through **headless Brave**,
  which is the only image tool on this machine - there is no ImageMagick and no PIL. The
  `.icns` comes from `iconutil` over a generated `.iconset`; the Windows `.ico` is packed
  by hand (an ICO is just a 6-byte header, 16 bytes per size, and embedded PNGs). macOS
  caches icons hard, so `lsregister -f` plus `killall Dock` is part of installing one.

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
- **The shutdown noise every run prints is benign, and here is what it actually is** so
  nobody has to wonder again (checked 2026-07-27 with `--verbose`, which is what prints
  the detail): "6 ObjectDB instances were leaked at exit" and "2 resources still in use"
  are the two music `AudioStreamMP3`s (`Juggling Game.mp3` and the Chill Trio Mix), their
  two playbacks, and a generated `AudioStreamWAV` with its playback. They are held by
  live `AudioStreamPlayer`s at the moment `get_tree().quit()` runs, which is exactly what
  a player that is still playing looks like. Nothing is accumulating and nothing is
  unfreed per act. Only worry if the COUNT grows with the length of a run.
- The TOSSA juggler figure (stance, proportions) is settled: never reshape it as a
  side effect of a mechanics fix.
