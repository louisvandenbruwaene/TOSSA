# JUGGLE: how the numbers actually work

A precise reference for every stat, formula, and probability in `Game.gd`, for
whoever wants to know exactly what a point of Accuracy buys or why a throw
just dropped. Companion to GDD.md (the design intent) and ROADMAP.md (what's
left) - this doc describes what the code actually does, with the real
constant values, not the aspirational numbers from early planning.

All timing is in ticks. The simulation runs a fixed 120 ticks per second
(`physics_ticks_per_second` in project.godot), so 12 ticks = 0.1 seconds.

---

## 1. The catch: strict timing, then a chance

Every flying prop has a `land_tick`, the exact tick it arrives at its target
hand. Pressing CATCH is compared against `abs(land_tick - tick)`, called `d`
below.

| band | window (ticks) | ~milliseconds | what happens |
|---|---|---|---|
| Perfect | `d <= perfect_window()` (7 by default) | ~58 ms | always secures, full score |
| Good | `d <= W_GOOD` (10) | ~83 ms | secures on a **chance** (see below) |
| Late | `d <= W_LATE` (28) | ~233 ms | secures on a smaller **chance** |
| Mistime | `d <= COMMIT` (52) | ~433 ms | a press this far off is a committed miss: the ball drops, no roll |
| Whiff | `d > COMMIT`, or no ball is near at all | - | nothing happens: no ball lost, a small Applause wobble (-0.04), a "whiff" sound. This is what stops mashing from working. |

`perfect_window()` is 7 by default and can widen with Focus (Section 4).
`W_GOOD` = 10, `W_LATE` = 28, `COMMIT` = 52, all in ticks, all in `Game.gd`
near the top of the file.

A ball also drops on its own if nobody catches it within `MISS_GRACE` (20)
ticks past its arrival.

### The off-Perfect catch chance

Good and Late catches are not guaranteed: `catch_chance(quality, height)`
rolls against a probability:

```
acc_norm = clamp(eff_accuracy() / 55.0, 0, 1)      # ACC_FULL = 55
base     = 0.50 if quality == Good else 0.30        # GOOD_BASE / LATE_BASE
p = base + acc_norm * 0.30                          # ACC_CATCH_BONUS
    - clamp(height, 0, 1.4) * 0.35                  # HEIGHT_CATCH_PENALTY
if not Purist:
    p += strength_catch_mod()                       # Section 4, Strength
    if has_glasses: p += 0.20                        # GLASSES_CATCH_BONUS
if a Spin trick is active:
    p -= 0.28                                        # SPIN_ACC_PENALTY
p = clamp(p, 0.06, 1.0)                              # MIN_CATCH_P floor
```

Read this as: **a standard-height throw (height 0), at 55+ effective
Accuracy, secures a Good catch 80% of the time and a Late catch 60% of the
time - bare-handed. Glasses (Section 7) add a flat +20 to both, which is the
*only* way to reach 100% on a Good catch or 80% on a Late one.** At 0
Accuracy those floors are 50% and 30% (before Glasses). The `- height * 0.35`
term means a maximum-height throw (height 1.4) can subtract as much as 0.49
from that chance, which is why a big reset throw is a real gamble even for a
maxed, bespectacled juggler. The 0.06 floor means no throw is ever *truly*
hopeless to catch, just very unlikely.

Note Perfect catches skip this roll entirely: hit the window, you keep it,
always.

---

## 2. The throw: height by hold, inaccuracy as the cost

Height is continuous, not tiered. Tapping THROW gives the lowest, snappiest
arc; holding it longer raises it, up to a cap.

```
air = BASE_AIR + HOLD_GAIN * hold_ticks        # BASE_AIR 84, HOLD_GAIN 1.9
hold_ticks caps at HOLD_MAX (44 ticks, ~0.37s of holding)
```

`height` (called `frac` in code, 0.0 to 1.8) is how far past the tap floor
the throw actually reached, normalized so 1.0 is a full HOLD_MAX hold. Plain
throws top out at 1.4 (only heavy props with surplus Strength get there);
tricks reshape `frac`: Overthrow and the toggle tricks force minimums, and
High Toss starts at 1.35 on a tap and climbs with the hold to 1.8 at a full
one, high enough to leave the frame for a beat (a chevron under the Applause
meter tracks it). Catch difficulty saturates at 1.4; only the placement
spread below keeps growing, and the trick's bonus grows with the climb.

### The over-the-top throw (a second kind of throw)

Normal throws catch OUTER, carry INWARD, and launch from the inner point.
An OVER-THE-TOP throw skips the carry entirely: the hand lobs straight from
the outer catch point, the ball rides a high road over the whole pattern,
and it lands 40px WIDE of the usual catch point (the empty hand drifts out
to meet it). Overthrow does this for one throw, Waterfall for the right
hand every throw (the left is forced low beneath it), Reverse Cascade for
every throw, Tennis for its one marked ball back and forth, and the Shower
and Half Shower patterns for their high hand. When low traffic is dropping
into the launch corner, the lob winds up 20px wider still and its early
flight bows outward around the incoming ball (`Ball.bulge`).

This geometry is what makes a PERFECT pattern collision-free: the dev
`--collcheck` flag (inaccuracy zeroed) measures the tightest edge-to-edge
clearance any two airborne props ever reach, and every pattern and trick
holds a positive margin. Sloppy heights are another story, which is what
the optional "Hard collisions" setting is for: two props that touch mid-air
are both marked `bumped` (warning halo, sparks), and a bumped ball is only
caught inside HALF the Perfect window, no Good/Late chance roll. A clean
juggler never meets the rule; a messy one drops what they clacked.

### What height costs you

Height buys airtime (more time before that hand needs to catch again, which
thins traffic) at the cost of precision. Three things scale with height and
with `inacc_factor()` (below):

```
jitter (arrival-tick uncertainty) = up to JITTER_MAX  (5 ticks)
drift  (lateral landing offset)   = up to DRIFT_MAX   (26 px)
wobble (in-flight arc wiggle)     = up to WOBBLE_MAX   (11 px)
```

All three scale by `spread * inacc_factor()`, where `spread` is normally just
the throw's height (0 to 1.8), floored by Strength deficit (Section 4).

`inacc_factor()` is what Accuracy actually buys on the throwing side:

```
inacc_factor() = lerp(1.0, 0.35, eff_accuracy() / 100)   # ACC_MIN_FACTOR 0.35
```

At 0 effective Accuracy your inaccuracy is full (factor 1.0). At 100 it's
down to 0.35, **never zero** - a maxed-out juggler's max-height throw is
still meaningfully harder to catch than their tap. That floor is deliberate:
timing must always matter, at every stat level.

---

## 3. The stats

All stats persist per save slot. Investing a point never touches the catch
or throw timing floor directly - every stat effect is capped, and the raw
window sizes above are the same for a level-1 and a level-99 character. What
changes is how forgiving the *dice* are, never the *clock*.

### Accuracy (1 to 250, invest with 1 in the sheet)

- Raises `eff_accuracy()`, which feeds directly into the off-Perfect catch
  chance (Section 1) and `inacc_factor()` (Section 2).
- `eff_accuracy() = clamp(accuracy * stamina_mult(), 0, 100)` - **the catch
  math itself caps at 100.** Anything past 100 becomes **Focus** instead
  (below), so raw Accuracy keeps being useful all the way to its 250 cap,
  just through a different channel.
- On a Purist booking, `eff_accuracy()` is forced to `5 * stamina_mult()`
  regardless of your real Accuracy - see Section 6.

#### Focus: Accuracy trained past 100

`focus() = max(0, accuracy - 100)`, so Focus runs 0 to 150 (since Accuracy
caps at 250).

- **Stage 1, Focus 0-100:** discounts the Stamina cost of every action.
  `focus_stam_mult() = lerp(1.0, 0.25, focus / 100)` - at Focus 100, every
  catch and throw costs a quarter of its normal Stamina (see `energy_mult()`
  in Section 3, Stamina).
- **Stage 2, Focus > 100:** once the Stamina discount has bottomed out,
  further Focus widens the Perfect window itself. Every 10 Focus above 100
  adds 1 tick, capped at +6: `bonus = min(6, floor((focus - 100) / 10))`,
  `perfect_window() = min(W_GOOD, W_PERFECT + bonus)`. Because that result is
  clamped to `W_GOOD` (10), a standard-height throw's Good band fully
  disappears into Perfect once Focus reaches 130 (Accuracy 230): every catch
  that isn't a genuine miss becomes a Perfect from there up. This never
  applies on a Purist booking (`perfect_window()` returns the base 7 there,
  unconditionally).

### Strength (1 to 100)

- Raises `max_balls()`: 4 from the start, 5 at Strength 12, 6 at 20, 7 at 30
  (`next_ball_strength()` tells you the next threshold in the sheet).
- Each prop has a Required Strength (Section 7). Strength does **not** make
  your throws go higher - height is purely how long you hold THROW. What
  Strength controls is what happens when you're **under** a prop's
  requirement (`prop_deficit()`, 0 when at or above the requirement, up to 1
  when badly under it):
  - `DEFICIT_BASE` (0.4): drags the tap-height floor down.
  - `DEFICIT_HEIGHT` (0.5): lowers the ceiling a hold can reach.
  - `DEFICIT_INACC` (1.1): roughly doubles inaccuracy at a full deficit.
  - `DEFICIT_FLOOR` (0.85): even a *low* under-strength throw keeps some
    minimum wobble, so you can't cheese a heavy prop by tapping it low.
- Being well **over** a heavy prop's requirement helps in two ways: it lofts
  height a little higher per held tick (`STRENGTH_LOFT`, scaled by the
  prop's weight), and it eases the off-Perfect catch chance directly via
  `strength_catch_mod()`, both scaled by `strength_surplus()`:
  `ratio = clamp((strength - req) / (100 - req), 0, 1)`, effect =
  `ratio * (weight - 1) * 0.05` (`STRENGTH_CATCH`) added to `catch_chance()`.
  Balls and eggs (weight 1) are untouched either way. This ratio is scaled
  against the stat's real ceiling (100), not a fixed multiple of the prop's
  requirement, specifically so no prop makes Strength go fully dead before
  the stat itself caps - a Torch (req 48) still saturates sooner in absolute
  terms than a Ring (req 12), but every point up to 100 keeps paying out
  something for whatever you're carrying.

### Endurance (1 to 100)

- The only mechanical effect in the current code: raises max Stamina,
  `stamina_max = 50 + endurance` (51 to 150). GDD.md describes Endurance as
  also gating heavy props; as implemented, prop access is gated purely by
  Strength's `req` field (Section 7) - Endurance's whole job right now is
  Stamina headroom.

### Stamina (a resource, not invested directly)

- Drains on every catch and throw: `STAM_DRAIN_CATCH` (0.4) and
  `STAM_DRAIN_THROW` (0.3) ticks of Stamina, each multiplied by
  `energy_mult()` and by `1 + WEIGHT_STAM * (weight - 1)` (`WEIGHT_STAM`
  0.25 per weight-step over a ball).
- `energy_mult() = base * focus_stam_mult()`, where `base` is 0.5 while
  training or `1.0 + 0.15 * (num_balls - 3)` while performing - performing
  costs more, bigger routines cost more still.
- Below `STAM_LOW` (25% of max), `stamina_mult()` drags `eff_accuracy()`
  down toward `STAM_MIN_MULT` (0.5 at empty): `lerp(0.5, 1.0, clamp(f /
  0.25, 0, 1))`. This is the game telling you to rest, not a hard stop.
- Stamina now persists across the whole day (only sleep, or a meal, restores
  it), so a third booking in one evening is genuinely harder than the first.

### Speed (0 to 100, `SPEED_CAP`)

- Every 4 points is a permanent 1% of slow motion, always contributing to
  the stack in Section 5, capped at 25% from this source alone (100 points
  / 4). The finer scale exists so Speed has the same roughly-100-point
  investment arc as the other stats instead of maxing out four times
  faster. Stripped
  entirely on a Purist booking.

---

## 4. Patterns: the reward for base difficulty

`pattern_mult()` scales every catch's score. Harder choreography pays more,
which is the whole point (grinding the easiest tamed routine should never be
the optimal way to earn):

| pattern | unlock level | multiplier |
|---|---|---|
| Cascade | 1 | 1.00 |
| Fountain | 1 | 1.10 |
| Columns | 3 | 1.15 |
| Half Shower | 5 | 1.25 |
| Shower | 8 | 1.40 |

Score per catch: Perfect = `round(100 * streak * pattern_mult)`, Good =
`round(50 * streak * pattern_mult)`, Late = `round(10 * pattern_mult)` (Late
also resets your streak to 0, same as a drop).

---

## 5. Slow motion: every source stacks, linearly, capped at 1.0

`slow_target()` sums whichever of these are currently active:

| source | amount | duration | notes |
|---|---|---|---|
| Speed stat | `min(speed, 100) / 4 / 100` | permanent | stripped on Purist |
| Uncle Dan's Pie | +0.25 | the whole day, until sleep | 1000g, stripped on Purist |
| "Amazing!" (a frame-perfect catch, `d == 0`) | +0.25 | `AMAZING_FRAMES` = 480 real frames (~4s) | earned, kept on Purist |
| 50 Perfects in a row (`CHAIN_NEED`) | +0.25 | `CHAIN_FRAMES` = 7200 real frames (~60s), then resets | earned, kept on Purist |

The live value (`slow_amount()`) eases toward that target at `SLOW_RAMP`
per tick (now 0.0025, slowed down from the original 0.005 so both entering
and leaving slow motion give real reaction time rather than a sudden gear
change). While any slow motion is active, simulation ticks advance by a
fraction of real time each frame, floored at 12% speed
(`max(1 - slow_amount, 0.12)`) - so it can get very thick, but never fully
freezes. None of this fires under three balls (`SLOW_MIN_BALLS`), so it
can't be farmed with a trivial two-ball juggle.

---

## 6. Purist bookings: the pure-skill ladder

Toggle with P in the day hub before you book a performance. A Purist set:

- Reads `eff_accuracy()` as if Accuracy were 5, no matter your real stat.
- Skips `strength_catch_mod()` and the Glasses bonus entirely in
  `catch_chance()`.
- Locks `perfect_window()` to the base 7 ticks - no Focus widening.
- Strips the Speed stat and the Pie from slow motion (the *bought* comforts)
  but keeps the *earned* bursts (Amazing!, the 50-Perfect chain), because
  those come from skill in the moment, not from a stat you leveled once.
- Writes to a separate `best_scores_purist` record table per venue, shown
  alongside the assisted board on the Records and History screen.
- **Pays a real premium**: both pay and reputation gain are multiplied by
  `PURIST_BONUS` (1.4). Without this a Purist set paid exactly the same as
  an assisted one for objectively harder execution, which meant there was
  no economic reason to ever book one. Because the catch odds are so much
  worse under Purist rules, the bonus is only actually profitable once your
  raw skill is good enough to keep the set clean anyway - it rewards
  mastery, it doesn't substitute for it.

---

## 7. Props

| prop | weight | Required Strength | cost | notes |
|---|---|---|---|---|
| Balls | 1 | 0 | free, unlimited | the only prop you don't need to own by quantity |
| Eggs | 1 | 0 | 1g | a drop breaks it for good, permanently reducing your stock |
| Rings | 2 | 12 | 200g | |
| Clubs | 3 | 22 | 500g | tumble in flight |
| Knives | 4 | 34 | 1000g | tumble in flight |
| Torches | 5 | 48 | 2000g | tumble in flight, the top prop |

Weight adds `WEIGHT_STAM` (0.25) times `(weight - 1)` extra fractional
Stamina cost per catch and throw, on top of the base drain in Section 3.
Being under a prop's Required Strength is what makes it sag and wobble
(Section 3); being at or over it, a heavy prop throws exactly as cleanly as
a ball.

Glasses (8000g, the single most expensive item in the shop) add a flat 0.20
to the off-Perfect catch chance (`GLASSES_CATCH_BONUS`), skipped on Purist
bookings. This is the only way to reach a 100% Good catch or an 80% Late
catch (Section 1) - without them
those ceilings sit at 80% and 60%. Uncle Dan's Pie (1000g)
buys 0.25 slow motion for the rest of the day, also skipped on Purist.

---

## 8. The economy: pay, reputation, XP

### Pay

```
diff        = 1 + 0.25 * (num_balls - 3)
venue_mult  = 1 + 0.35 * run_venue               # VENUE_PAY, venue index 0-5
purist_mult = 1.4 if purist else 1.0             # PURIST_BONUS
last_pay = round((caught * 1.2 + best_streak * 2.0) * run_clean() * diff
                 * pay_mult() * venue_mult * purist_mult)
pay_mult() = 1 + reputation / 400                # REP_PAY_DIV
```
If your purse is under 20 gold (`BROKE_GOLD`) and you caught at least one
prop, pay is floored at 8 gold (`BUSK_FLOOR`) - the busking floor that keeps
debt as tension rather than a dead end. That floor is not scaled by the
Purist bonus, so busking never becomes a Purist-farming exploit.

### Reputation

```
quality   = 0.7 * run_clean() + 0.3 * peak_applause
rep_delta = round((quality - 0.5) * 60 * purist_mult)   # REP_SWING, PURIST_BONUS
reputation = max(0, reputation + rep_delta)
```
A quality of exactly 0.5 (middling) is a wash. Above it you gain, below it
you lose, floored at 0. Reputation only ever affects `pay_mult()` above and
which venues/next-stage are unlocked (`VENUE_REP`: 0, 100, 300, 700, 1500,
3000 gold-door thresholds) - it never touches catching or scoring.

### XP and levels

```
xp_to_next(level) = round(60 * level^1.4) + 40 * level
```
Each level grants 3 stat points (`POINTS_PER_LEVEL`). XP comes from: 3 per
Perfect catch, 2 per Good, 1 per Late, plus a per-set bonus at the end:
```
bonus = round((best_streak * 4 + caught * 1.5) * run_clean() * diff)
```
Sloppy or short sets earn little, by design - XP tracks skilled play, never
idle time.

### The overall grade (S/A/B/C/D)

```
q = 0.55 * run_clean() + 0.28 * peak_applause + 0.17 * clamp(best_streak/25, 0, 1)
S >= 0.90, A >= 0.78, B >= 0.62, C >= 0.42, else D
```
Cleanliness dominates the grade, on purpose: a survived-but-sloppy set
should never outgrade a shorter, cleaner one.

---

## 9. The day loop

A day holds `SEG_PER_DAY` (3) action segments. Performing or practicing
spends one; eating, sleeping and shopping don't. Stamina persists across the
whole day and only sleep restores it.

- **Eat**: 10g (`EAT_COST`), +14 Stamina (`EAT_STAM`). Every third meal also
  grants +1 Strength (`MEALS_PER_STR`).
- **Sleep** (the inn, `INN_COST` 15g, full price always): resets Stamina to
  full and turns the day over. There is no cheaper "sleep rough" option -
  if you can't afford both the inn and a meal while too tired to work, the
  road ends (`check_dead_end()`), by design, so the stakes stay real.
- `too_tired()` is `stamina < TIRED_FLOOR` (12) - below that you cannot
  perform or practice, only rest.
