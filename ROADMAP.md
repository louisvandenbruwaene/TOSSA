# JUGGLE: Roadmap to a sellable 1.0

STORY CUT 2026-07-11: Louis chose to remove the narrative entirely (full
Balatro pivot). All items below about cutscenes, the story cast, and the
endgame chapters are now historical — that content was deleted from the game.
The six venues remain as pure escalating stages; the win is a record at the
World Arena. A new SKILLS hub screen and a slimmed, controls-in-Settings HUD
landed the same day. See STORY.md (retired) and the memory log for detail.

SHIP BLOCKER, checked 2026-07-11: Juggling Game.mp3's file date and its git
history both still say 2026-07-10, the day it was added as a free-tier Suno
NON-COMMERCIAL render (item 5). Nothing suggests the paid-tier re-render has
happened yet. Do not export a build for anyone outside Louis's own testing
until that file has been replaced. Game.gd carries the same warning next to
MUSIC_PATH.

REGRESSION FLAGGED 2026-07-13, not yet fixed: Louis's playtest after commit
ddbd706 found real physical/visual collisions on over-the-top throws (Half
Shower and Shower confirmed broken with the game's own --collcheck audit),
jittery Columns hands, and C appearing to cancel a running trick toggle. Full
investigation and concrete fix directions are in item 12 below. Fix this
before any further feature work.

Work queue agreed 2026-07-10, ordered by how much each item matters to a ten
dollar Steam release. Each item is meant to be a self-contained session or less.
Strike items through as they land on main.

Status 2026-07-10: items 1, 3, 4, 6 and 8 are BUILT and pushed, plus the
focus-loss pause from item 7. Item 1 landed as the ST_DAY hub (three segments a
day, persistent stamina, eat and sleep, venue choice with tiered pay, busking
floor) and awaits Louis's playtest. Still open: item 2 (content depth), item 5
(audio breadth), and the rest of item 7 (export presets, capsule art,
Steamworks).

Louis playtest feedback 2026-07-10 (evening) added as items 9 to 11 below.
These are direct player notes, so they outranked the older open items. All
three are BUILT and pushed (same night) and await Louis's next look: the
cutscene pass by eye, the music rework by ear, the trick powerup in hand.
Still open from the older queue: item 2 (content depth), item 5 (audio
breadth, partly reshaped by item 10), and the rest of items 3 and 7 (remap
screen, export presets, capsule art, Steamworks).

## 1. The day/life loop (the big missing piece) - BUILT 2026-07-10

The GDD (Section 4.5) promises a light juggler's life between performances and
none of it exists yet. Gold accumulates with almost nothing to spend it on, so
the career sim half of the game is hollow. Build the day rhythm: a soft day
clock advanced by actions, EAT (spends gold, feeds Strength, stops decay),
SLEEP (ends the day, resets Stamina, inn versus sleeping rough), TRAVEL between
venues, and street busking as the guaranteed income floor so debt is tension
rather than a dead end. Keep it light and forgiving per the GDD guardrails: a
rhythm and a set of stakes, never a spreadsheet chore. This is the one item the
game should not ship without.

## 2. Content depth - MOSTLY BUILT, one piece still open (checked 2026-07-11)

Most of what this item asked for is already in Game.gd and this entry was
stale: five learnable patterns (cascade, fountain, columns, half shower,
shower, unlocking by level, PATTERNS table), eight tricks across three input
grammars (arm one-shots, the live Spin, and toggles like Columns/Waterfall/
Reverse Cascade/Tennis), the Purist boards (a separate best_scores_purist
table, stat mitigation stripped in eff_accuracy/catch_chance/perfect_window),
and per-venue records that flash NEW RECORD mid-run. Six playable venue tiers
(Backyard through World Arena), each with its own palette and costume, plus
three endgame story chapters (rival, record, finale) layered on top by
reputation once the arena is reached.

Still genuinely open: no repeatable challenge format exists yet (no daily
seed, no rotating routine-of-the-day) to make the per-venue records a LIVE
goal rather than a personal best you set once and rarely revisit. This is the
real remaining ask from this item. Mills Mess, sketched as an example trick in
GDD 6.3, was never built either, if a learned multi-throw sequence still
sounds worth adding.

## 3. Controller support and key remapping - FULLY BUILT 2026-07-10 (remap screen landed same day)

Keyboard only today, with hardcoded physical keycodes. Steam buyers expect a
pad and the GDD already sketched the mapping: left catch L1, left throw L2,
right catch R1, right throw R2, trick on a face button. Add gamepad input
alongside the keys, a simple remap screen (or at least a config file), and make
every hint in the HUD show the right glyphs for the active device. This also
matters for Steam Deck visibility.

## 4. A real typeface - BUILT 2026-07-10 (Nunito, OFL)

Everything renders in the engine fallback font. One clean humane sans with good
numerals (a single licensed or OFL .ttf loaded once as the theme default) would
lift every screen more than any single drawing change. The code-only art rule
bends for exactly one font file. Candidates: Nunito Sans, Inter, Outfit.

## 5. Audio breadth - RESCOPED 2026-07-10: Louis's own track is the music now

Louis produced his own background song (Juggling Game.mp3, in the repo) and the
procedural music generation was removed in its favour. LICENSING: the current
file is a free-tier Suno render, non-commercial only. Louis has decided to
re-render it under a Suno Pro subscription (which grants commercial rights to
songs made while subscribed), ideally at a slightly slower, more relaxed tempo.
Until then the current file is a DEV PLACEHOLDER and must not ship. Swapping
in the re-render is just replacing the file with the same name and reimporting.
What remains of this item: the record-attempt near-silence and the finale
payoff are now simple volume states over the one track, and the gasp and groan
stingers stay as procedural SFX work. Per-venue variety returns if Louis makes
more tracks, a per-venue track table is trivial to add.

The synthesis system is solid but the palette is thin: sine bells over one
shared two-chord loop. Wanted: a distinct motif per venue tier that still
shares one musical family (the ART doc calls it one piece of music growing up),
the record-attempt near-silence with only the count and the crowd, a proper
finale payoff when the full theme returns, and a couple more stingers (gasp on
a risky high throw, groan on a drop). Louis still needs to judge the current
mix by ear before deep retuning.

## 6. Endgame wrap - BUILT 2026-07-10 (slow motion BUILT 2026-07-11: Speed stat,
Uncle Dan's Pie, Amazing! bursts and ten-Perfect chains, stacking per ideas.rtf)

The three endgame cutscenes exist but nothing follows the finale. Build a
credits screen (code-drawn, same royal style, reachable from the menu after the
finale has been seen), and a small post-finale state so the world acknowledges
the record: a FINALE banner on the save slot, maybe a golden tint on the arena.
Slow motion as the reward state stays deferred.

## 7. Steam packaging - export pipeline verified end to end 2026-07-11, Steamworks still open

Landed: export_presets.cfg with macOS, Windows and Linux presets, real icons
at export sizes (export/icons: 1024 png, .icns, a properly multi-resolution
.ico), the 4.7 export templates installed, and the ETC2/ASTC project setting
the macOS universal build needs. All three platforms now export cleanly with
zero warnings, verified by actually running the exports, not just reading
the presets. Checked what actually ships: only compiled bytecode (Game.gdc)
is packed, never the readable .gd source, and none of GDD/STORY/ROADMAP/
tasks.md/ideas.rtf get bundled in either - confirmed by inspecting the real
pack file listing.

One real fix landed here too: every `--demo`/`--debug`/`--sheet`/`--shop`/
etc. dev flag is now gated behind `OS.is_debug_build()` in `_ready()`, so a
release export (what actually ships) ignores all of them unconditionally -
before this, `--debug` on the shipped game would have granted free stat
editing and F1-F10 story-jump shortcuts to anyone who tried it. Editor runs
and debug-template exports (Louis's own screenshot/testing workflow) are
unaffected, since `is_debug_build()` is true there.

macOS is not code-signed or notarized (needs an Apple Developer account,
$99/year) and Windows is unsigned too (SmartScreen will warn on first run,
self-resolving with enough downloads or fixable with a paid cert) - neither
blocks export or Louis's own testing, both are packaging polish for public
distribution. Louis's Suno cover jpeg could seed the Steam capsule art.
Still open: Steamworks (achievements, cloud saves, leaderboards for the
Purist boards).

Export presets for macOS, Windows and Linux. Pause when the window loses
focus. Capsule and library art (this realistically cannot be code-only).
Steamworks later: achievements, cloud saves, leaderboards for the Purist
boards. Start with the parts that need no SDK: presets, focus-loss pause, a
proper app icon at export sizes.

## 8. Dev hygiene: give --demo its own save - BUILT 2026-07-10

The --demo auto-player plays on real save slot 0, so screenshot and test runs
can nudge a genuine career. Point it at a scratch save the way --debug already
uses juggle_debug.cfg.

## 9. Cutscene animation pass (Louis playtest note, 2026-07-10) - BUILT 2026-07-10

The cutscenes read as weirdly animated: the motion is too fast overall, and
some shots show ugly juggling or ugly ball holding. Work to do: slow every
scene's oscillation clocks (the ct multipliers in the scene tableaux and the
demo_juggle cadence when it plays inside a cutscene), then audit each shot for
prop placement so held balls sit convincingly IN the palm (the reach_hand and
hand offset math) and the juggled arcs look like real cascade timing rather
than floaty loops. Check every beat with windowed --cutscene <id> --csn <n>
screenshots, shot by shot. The Ken Burns camera and typewriter captions are
fine, it is the FIGURE motion that needs the pass.

## 10. Music rework: enthusiastic, Balatro-like, less noise (Louis, 2026-07-10) - BUILT 2026-07-10

The current background music has too much white noise in it and feels a bit
too sad. Louis wants an enthusiastic, Balatro-like melody, still tailored per
stage. Concrete direction: hunt down every noise component in the beds (the
crowd murmur bed and any noisy synthesis in the loops) and either remove or
heavily darken them, move the harmony from sparse melancholy bells to an
upbeat major hook with a groove (Balatro's trick is a short catchy loop with
a relaxed swing and a warm bass pulse, energetic without being busy), add a
light rhythmic layer that can fade in with the applause energy, and keep the
per-venue tailoring (root, tempo, brightness per tier) on top of the one
shared hook so the climb still reads as one piece of music growing up. The
adaptive volume-automation architecture stays, only the material changes.

## 11. Trick input redesign: Space as a one-shot powerup (Louis, 2026-07-10) - BUILT 2026-07-10

Replace the permanent arm-trick toggle. Louis wants the trick button to feel
like a POWERUP: pressing Space empowers the throw made at the same moment, so
space plus catch-throw produces exactly one trick shot. C (or the pad's Y)
still cycles WHICH trick is selected, the selection persists after use, but
every single use requires its own Space press. So: press Space, the very next
throw (or the simultaneous one) becomes the selected trick, then the system
disarms itself while remembering the selection. Spin fits the same grammar:
with Spin selected, Space performs the spin. Update the trick HUD, the
trick-unlock banner text, and the tutorialised hints to teach the new model,
and make sure the demo auto-player (--demo --trick) still exercises it.

## 12. URGENT REGRESSION: over-the-top landings collide, Columns hands jitter, C cancels a running toggle (Louis, 2026-07-13)

**STATUS 2026-07-15 (Phase 0 of PLAN.md):** 12a RESOLVED for every confirmed case,
12c RESOLVED, 12b DIAGNOSED and awaiting Louis's choice of fix direction. Details
inline at the head of each subsection below. The `--collcheck` audit is now
headless-capable and batchable (a parallel sweep of all 13 patterns/tricks at 3/4/5
balls runs in ~2 min), and a new `--handlog` flag dumps hand x per tick for 12b.

Three bugs reported after the fifth-batch session (commit ddbd706, see the memory
log and this file's history) that reworked hand choreography and scoring. Do
this session BEFORE any further feature work - it is a regression, not new
content, and item 2's remaining "content depth" ask can wait another round.

### 12a. Over-the-top throws now visually and physically collide with the low weave

**RESOLVED 2026-07-15.** Fix (two parts, both in Game.gd):
1. `over_top_land_slot(t)` lands an over-the-top throw on the COMPLEMENT of hand t's
   own launch slot (INNER when t launches OUTER as in reverse cascade, OUTER when t
   launches INNER as a low hand). A landing can then never sit on a launch, which was
   the -14px Half Shower / -22px Shower regression. It is a structural guarantee, not
   a tuned gap, so Phase 5 inherits it. `catch_slot` and `do_throw` both read it, so
   the ball's landing and the receiving hand's rest pose come from one source.
2. A late-flight `land_dodge` (Ball field, set in `do_throw`, applied in `flight_pos`)
   bows an over-the-top ball's DESCENT outboard when its landing hand throws low, so
   the high road comes down outside the corridor that hand's crossing low throw rises
   through. Gated structurally on `not next_throw_over_top(b.to_hand)`, which keeps the
   reverse cascade (all hands high, no low weave) untouched.

Verified by the parallel `--collcheck` sweep at 3/4/5 balls: Half Shower +25/+25/+8.2,
Shower +24/+24.5/+24.5, Waterfall +26.6/+16.5/+8.3, Overthrow +11.7 all, Reverse
Cascade +16.2 all. **One residual: Tennis at 4 balls, still -16px.** Tennis-4 rides a
fountain (same-hand) base, so its low hand catches its OWN low balls at OUTER, the very
slot the over-the-top ball lands on - a genuine same-tick, same-slot conflict that no
dodge separates. It is the lowest-priority case this section flagged ("conflict window
inherently smaller") and is left to the Phase 5 siteswap rework that replaces this
hand-picked geometry with one derived from the pattern, rather than special-cased at
the cost of the cases that now work. Tennis at 3 and 5 balls (cascade base) is clean.

---
Original analysis below (kept for the Phase 5 rework's reference):


**Root cause, confirmed empirically.** ddbd706 changed an over-the-top throw's
landing point (`b.to_pos` in `do_throw`'s `elif over_top:` branch) from
`outer_pos(to_hand) + wide(40px)` to plain `inner_pos(to_hand)`, to satisfy
Louis's ask that reverse cascade "cross closely." That succeeded at closing the
gap, but it also means the over-the-top ball now lands at EXACTLY the same x
as `inner_pos(h)`, which is also where a NORMAL (non-over-top) throw on that
same hand launches from (`b.from_pos = inner_pos(h)` in the `else` plain
branch) and where a normal throw's OWN catch carries the held ball while
waiting to throw (`throw_slot(h)` resolves to `HAND_INNER` there too). Any
pattern/trick where ONE hand does over-the-top catches while that SAME hand
ALSO does normal low throws now has two independent things wanting to occupy
`inner_pos(h)` at arbitrary, uncoordinated moments - the incoming high ball's
landing and the outgoing low ball's release. There is no dodge/offset logic
protecting this the way `incoming_low()`/`bulge`/`windup` already protects the
OUTER launch corner for the mirror-image case.

**Verified with the game's own `--collcheck` audit** (`godot --path . --
--demo --pattern <id>|--trick <id> --collcheck --shot <tmp.png> --shotat
6000`, then read stdout for `collcheck min clearance`). A NEGATIVE number
means real overlap. Needs a shotat of several thousand (1600 was too short to
reliably hit the bad-timing window even when it exists - use 6000+, it takes
real wall-clock time in windowed mode, don't headless it, get_viewport().
get_texture() is null under `--headless`):

| Pattern/trick | Result |
|---|---|
| Cascade | clean, 16.2px (matches the pre-existing historical number, unaffected) |
| Fountain | clean (no over-the-top throws at all) |
| Columns (3-ball, 5-ball) | clean (lanes never route through `inner_pos`/`outer_pos`) |
| Reverse Cascade | clean - BOTH hands are over-top on every throw, so neither hand ever does a normal low throw to conflict with |
| **Half Shower** | **-14.0px overlap**, tick 190: a normal ball (h=0.16) and an over-top ball (h=0.50) essentially coincide near (615, 312) |
| **Shower** | **-22.0px overlap**, tick 252: a fresh low-feed throw (p=0.00, just launched) and an arriving over-top ball (p=1.00, just landing) sit at the EXACT same point (582, 458) - the smoking gun, launch and landing coinciding |
| Waterfall, Tennis, Overthrow, Columns-as-toggle | all clean in this run, full 6000-tick sweep - but read the caveat below before trusting that as proof, especially for Waterfall |

So confirmed broken: **Half Shower and Shower only**, both base patterns
(not toggle tricks). Every toggle-driven trick (Reverse Cascade, Waterfall,
Tennis, Overthrow, Columns-as-toggle) came back clean at this cadence. That
narrows the fix, but read the Waterfall caveat below before treating it as
provably safe - the geometry is the same shape as the two confirmed failures.

**Caveat on the "clean" results, read before trusting them:** `--collcheck`
zeroes jitter/drift/wobble (see `_collcheck` branches in `do_throw`), so it
tests one fully deterministic geometry, but that geometry is driven by the
`_demo_step` metronome's FIXED 28-tick (`DEMO_BEAT`) cadence. A pattern that
looks clean under that one rhythm is not proven clean under every rhythm a
real player's hands can produce - Half Shower and Shower's failures ARE at
this same fixed cadence, so the underlying spatial conflict is real and not a
timing fluke. A "clean" result for Waterfall or the untested tricks just means
this one cadence didn't happen to line up the two events on the same tick,
not that it structurally can't. Reason about the GEOMETRY (does hand h do
both an over-top catch and a normal-inner throw?), don't just trust one
audit run.

**Where the same risk structurally exists, work it out with pen and paper
first, `--collcheck` second:**
- **Half Shower / Shower**: the LEFT hand (Half Shower) or the LEFT feed hand
  (Shower) catches the RIGHT hand's over-top ball at `inner_pos(LEFT)` AND
  launches its own normal throws from `inner_pos(LEFT)`. Confirmed broken.
- **Waterfall**: same shape, LEFT catches RIGHT's over-top ball at
  `inner_pos(LEFT)` and throws its own (WATERFALL_LOW-capped, short/low)
  throws from `inner_pos(LEFT)` too. Audited clean at the demo's default
  cadence. The geometry says it shouldn't necessarily stay clean under a
  different one (the LOW cap on the non-over-top hand may be what saves it in
  practice, by making that hand's throws short enough to rarely coincide - if
  so that's a lucky side effect of an unrelated tuning knob, not a guarantee).
  Retest with `--hold` set to a few different values (dev flag, forces the
  demo's throw-hold ticks) to sample other rhythms before trusting this.
- **Tennis**: only the ONE marked ball rides over-top at a time, alternating
  hands via `stack(h).has(tennis_ball)` in `next_throw_over_top`, so the
  conflict window is rarer. Audited clean this session at the default cadence,
  same "don't fully trust one cadence" caveat applies, lower priority than
  Waterfall since the conflict window is inherently smaller.
- **Overthrow**: a rare one-shot, over-top only for the single primed throw.
  Audited clean this session. Lowest priority - rare by construction.
- **Columns-as-toggle** (`--trick cols`, `TR_COLS` layered on a non-Columns
  base pattern): the columns branch in `throw_slot`/`catch_slot` takes
  precedence over the over-top branch, so this is unaffected the same way the
  Columns base pattern is. Audited clean this session, matches the reasoning.

**Concrete fix directions to try, in order of how well they fit the existing
architecture** (pick one, verify with `--collcheck` across EVERY pattern/trick
at 3, 4, 5 balls before calling it done - the fifth-batch session's mistake
was shipping the landing-point change without rerunning this audit at all):

1. **Give the over-the-top landing a small standoff, not the old 40px, not
   zero.** Change `b.to_pos = inner_pos(b.to_hand) + Vector2(drift, 0.0)` in
   the `elif over_top:` branch to add a modest fixed offset (signed toward
   whichever side keeps it clear of that hand's own launch corner - probably
   outward, same sign convention as the deleted `wide` variable, just much
   smaller). The measured failures were -14.0px (Half Shower) and -22.0px
   (Shower), so a real fix needs to close at least a ~25px gap to turn the
   worst case positive with some margin - start around 20-25px (roughly half
   the old 40px) and iterate against `--collcheck` at 3/4/5 balls on EVERY
   pattern/trick, not just the two that failed, until all report positive
   clearance again, ideally in the same rough neighbourhood as the historical
   numbers noted in the table above (single digits to low twenties). This
   keeps Louis's "cross closely" ask (a small standoff still reads as close)
   while restoring a hard geometric guarantee instead of hoping timings don't
   collide.
2. **Reuse the existing `incoming_low()`/`bulge` dodge pattern but mirrored
   onto the LANDING side.** The launch side already has exactly this
   protection (`if over_top and incoming_low(h): b.bulge = 34.0`, bowing the
   flight path outward early). Add the mirror check on landing: if the
   receiving hand is about to (or just did) launch a normal throw around the
   same tick, bow or offset the incoming ball's final approach so it doesn't
   share the exact pixel with the departing one. More surgical, more code,
   fits the existing "read BEFORE popping the ball" style used elsewhere in
   `do_throw`.
3. If neither is enough on its own, combine both: a small fixed standoff
   (option 1) as the baseline guarantee, plus the dodge (option 2) only for
   the genuinely tight, coincident-tick cases the fixed offset alone doesn't
   cover.

Do NOT just revert wholesale to the pre-ddbd706 `outer_pos + wide(40)`
landing - that is what caused the ORIGINAL "arms too long" complaint this
whole rework was for. The fix needs BOTH properties at once: close/crossing
AND non-overlapping, which is exactly why it needs a small deliberate offset
or a dodge, not either extreme.

### 12b. Columns hands are jittery, not settled at their two fixed points

**DIAGNOSED 2026-07-15 with the new `--handlog` flag - it is BOTH hypotheses, and the
fix direction is Louis's call (this section already said so).** Measured with
`--demo --handlog --pattern columns --balls 5`, logging each hand's x per tick:
- Hypothesis 2 CONFIRMED (the tremor): the LEFT hand oscillates between x=582 (INNER,
  its catch/wait slot) and x=616 (VERY_INNER, its throw slot) EVERY throw-catch cycle,
  and never settles - it reaches 583.7, reverses, climbs to 613.3, reverses again,
  continuously, because the two slots are only 34px apart and the cadence retargets
  before the 0.22 lerp arrives. A hand that holds WITHOUT throwing (RIGHT, parked at
  664 the whole window) is rock-steady - proving the tremor is specifically the
  catch/throw retarget, not general motion.
- Hypothesis 1 ALSO present (the disconnect): at 5 balls the LEFT hand serves two lanes
  (ball x = 552 and 596) but hovers at 582-616, so it sits 30-64px off the outer lane
  it is nominally catching.

Fix options for Louis to pick (this subsection explicitly asked to confirm before
coding the deeper one):
  A. Single rest point for Columns: make `catch_slot`/`throw_slot` return the SAME slot
     so the hand holds one x and only does the vertical throw-kick - kills the tremor,
     but the hand no longer visibly "loads" inward before a throw.
  B. Hand tracks its ball's lane x (a per-lane rest) - kills BOTH the tremor and the
     disconnect, but breaks Louis's "hands rest at fixed points, don't chase the ball"
     rule for Columns specifically (arguably fine, since real columns hands DO sit under
     their columns).
  C. Leave it: the tremor is largely a fast-`--demo`-cadence artifact; at a human
     cadence the hand has time to settle at each endpoint and reads as two held poses.

---
Original analysis below:


Reported after the same session. Not yet root-caused with certainty, since it
needs to be SEEN moving (a single screenshot cannot show jitter) and this
session only had static captures + the automated demo, whose fixed 28-tick
metronome is not how a real player's hands move either. Two candidate causes,
investigate both before touching code:

1. **Hand rest position doesn't match the ball's actual flight geometry.**
   `throw_slot`/`catch_slot` collapse EVERY lane ball on a hand to the same
   two fixed x's (`HAND_INNER` dx 58 catching, `HAND_VERY_INNER` dx 24
   throwing, see `slot_pos`), but the ball itself still flies to/from its own
   `lane_x` (`assign_lane`/`columns_x`, up to ~130px from centre for a wide
   columns spread) - `do_throw`'s `if lanes:` branch was deliberately left
   using `b.lane_x`, not the fixed hand slot, when ddbd706 was written (see
   that commit's reasoning in the memory log). For a hand juggling TWO lanes
   at once (5+ ball columns), the ball can be visibly 60-100px from where the
   hand sprite is sitting, and the hand may look like it's "reaching" or
   mismatched rather than parked - especially right at the catch/throw
   instant, which is exactly when a jitter would be most visible.
2. **The two fixed points are only 34px apart (58 - 24) and every single
   catch and throw retargets between them**, unlike other patterns where a
   catch and a throw can be much further apart (Cascade: 104 to 58, 46px, and
   the hand ALSO gets `HAND_SMOOTH` = 0.22 lerp ticks to settle before the
   next flip). At a normal juggling cadence this might read as a persistent
   small tremor rather than two calm, held poses, especially compounded with
   the post-throw "kick" (`hand_target`'s `-22px Y over 14 ticks`) firing on
   the same rapid cycle.

**How to actually diagnose it next session:** don't rely on `--demo` (the
28-tick metronome is not representative and may itself be part of what looks
"jittery" if that's even faster than intended) or single screenshots. Either
(a) run the game interactively with a keyboard and WATCH columns being
juggled at a natural cadence, or (b) take a burst of `--shotat` screenshots a
few ticks apart (e.g. every 3-4 ticks across one throw-catch cycle, several
in a row) and diff the hand's x position frame to frame to see whether it's
actually oscillating or just visually disconnected from the ball's lane. If
(1) is the cause, the fix is probably making the ball's OWN lane-based flight
geometry match the fixed hand slots too (i.e. have `lanes` throws also launch
from/land at the fixed `HAND_VERY_INNER`/`HAND_INNER` x instead of `lane_x`,
sacrificing the "each ball visibly owns its own vertical line" look in favour
of the fixed-hand promise Louis explicitly asked for) rather than trying to
chase the hand to match the ball. If (2) is the cause (or a real contributor
even when (1) is also fixed), consider whether Columns genuinely needs two
distinct rest points at all, versus a single point that just barely opens and
closes hclose-style without translating - that would be a further
simplification beyond what Louis originally asked for, so confirm with him
before doing it rather than assuming.

### 12c. Pressing C to cycle the trick selection appears to deactivate a running toggle

**RESOLVED 2026-07-15 - it was hypothesis 1, legibility.** Confirmed by reading:
`cycle_trick()` only ever writes `trick_sel`, never `toggle_on`, so a running toggle
keeps running after C. The old HUD, though, dimmed the whole trick card when the
selection differed from the running toggle and buried the still-ON toggle in a small
lowercase "(x on)" aside - which reads as "my trick switched off". Fix in
`draw_trick_hud`: when a toggle runs but a different trick is selected, LEAD with the
running toggle in the bright gold "hot" colour ("HIGH TOSS  -  ON   (Overthrow next)")
and demote the mere selection to the aside. What is ON now always wins the eye. No
state-management change was needed or made. Verified in a live screenshot.

---
Original analysis below:


Traced as far as static reading gets you. **Not reproduced interactively this
session**, and the code does not show an obvious cause, which itself is worth
recording so the next session doesn't re-derive it from scratch:

- `cycle_trick()` (bound to the `K_CYCLE`/`C` key at the `if kc == K_CYCLE:`
  check in the play input handler) only ever writes `trick_sel`. It never
  touches `toggle_on`.
- `toggle_on` is written in exactly two places: `on_trick()`'s toggle branch
  (Space explicitly turns the CURRENTLY SELECTED toggle on or off, comparing
  `toggle_on == trick_sel`), and `start_run()`'s reset (only clears it if the
  trick got re-locked, `not trick_unlocked(toggle_on)`, which shouldn't
  happen mid-session). Neither fires from a C press alone.
- The trick HUD (`draw_trick_hud`) DOES already correctly distinguish the two:
  if a different toggle is running than the one currently selected, it shows
  `"<selected name>   (<running name> on)"` in a dimmer colour rather than
  the bright "- ON" label. So by the code, cycling should leave the old
  toggle mechanically running (do_throw's shaping and the hand-choreography
  slot functions all key off `toggle_on`, never `trick_sel`, for toggle
  behaviour) and only change what the BIG label says.

Two live hypotheses, most likely first:
1. **Legibility, not a logic bug.** After C, the big "TRICK - X" label swaps
   to the newly selected trick's bare name (no "ON" suffix, since
   `toggle_on != trick_sel` now) and the still-running toggle only shows in
   the small "(Y on)" qualifier. If that's easy to miss at a glance during
   live play, it would read exactly as "my skill turned off" even though
   `toggle_on` never changed. If this is confirmed, the fix is a HUD change
   (make the qualifier louder, e.g. its own colour/position, or don't shrink
   the running toggle's name at all when it differs from the selection) not
   a state-management change.
2. **A genuine bug not yet found.** Possible if there's a path where pressing
   Space AFTER cycling (which a player instinctively does right after C, to
   see what the new selection feels like) reads as "turn on trick_sel" and,
   per `on_trick()`'s own documented behaviour ("Only one toggle runs at a
   time, switching replaces the old one"), REPLACES the running toggle. This
   is real, intentional, documented behaviour, but might be what Louis is
   actually describing if his test sequence was C then Space rather than C
   alone. Confirm which sequence he means before assuming it's a bug at all.

**Next step: reproduce interactively.** Turn a toggle on (Space), press C
ONLY (no Space), and read `toggle_on`'s actual value (add a temporary debug
print, or watch the HUD's small qualifier text closely) before concluding
anything. This cannot be verified through the `--demo` flag as-is - the demo's
own trick-priming logic in `_demo_step` doesn't replicate a manual C-then-
watch sequence, it drives its own toggle-selection choices.

### Suggested split

12a is the most urgent (it's a visible, physical gameplay bug affecting real
scoring/catching, not just cosmetics) and the most concrete to fix (a
--collcheck-driven numeric target, and the full pattern/trick sweep is
already done - just Half Shower and Shower need a code change, everything
else needs only a confirming retest after that change). Budget most of the
session there. 12b needs real interactive observation before any code
changes - don't guess at a fix without confirming which hypothesis is right
first. 12c needs five minutes of interactive reproduction to even confirm
it's a bug before deciding whether it's a HUD text change or something
deeper.
