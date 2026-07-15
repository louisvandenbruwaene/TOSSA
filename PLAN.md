# JUGGLE: the execution plan

Written 2026-07-14. This is the build order for the design in EXPANSION.md,
plus Louis's two asks from the same conversation:

- **every unlock should teach itself**, in slow motion, with clear "press this
  button now" prompts (a trick, a new ball count, a new prop)
- **every performance should have a reachable goal**

Each phase below is meant to be one focused session. Read the phase's
"Prerequisites" before starting it. Every function name, constant, line number
and save key in here was checked against the real Game.gd on 2026-07-14, so a
next session can execute from this file without re-deriving the codebase.

Line numbers drift as soon as anything is inserted. Treat them as "search
near here", not as gospel. Function names are stable and are the real anchor.

---

## Two corrections to EXPANSION.md, read these first

**1. The fail state already exists. I got this wrong in EXPANSION.md.**

`drop_ball()` (near line 3795) already contains:

```gdscript
if mode == MODE_PERFORM and applause <= 0.0 and not collapsing:
    collapsing = true
    # whatever is still held slips from the hands too: you watch it all fall
```

and `_physics_process` (near line 776) ends the run once everything has landed.
The crowd can already walk out on you, the hands already give up, the props
already fall. **The collapse is fully built and is simply never reached**,
because grepping every write to `applause` shows it only moves on events (drop
-0.26, whiff -0.04, late -0.02, Perfect +0.05, Good +0.025, trick +0.03 to
+0.09) and **never decays with time**. Starting at 0.7, and with catches pushing
it back up, a competent player never gets near zero.

This makes Phase 2 much cheaper than EXPANSION.md implies. We are not building a
fail state. We are adding a decay term to a fail state that already works, and
putting a target in front of it.

**2. `seen_tuts` is not persisted, which is a real bug and blocks Phase 1.**

`var seen_tuts: Array[String] = []` (line 467) is appended to by
`offer_prop_tutorial()` and `start_slot()`, but it appears in neither
`save_progress()` nor `load_progress()`. So "this lesson has already been shown"
is forgotten on every restart. Nobody noticed because the only lessons today
fire on a fresh slot or on a prop purchase. The moment lessons fire on level-up
unlocks (Phase 1), a player would be re-taught High Toss every session. **Fix
this first, inside Phase 1.**

---

## Phase 0. Prerequisites (do not skip)

Nothing below is worth building on a broken geometry.

**0.1 Fix ROADMAP item 12.** The over-the-top collision regression (12a), the
Columns hand jitter (12b), and the C-cancels-a-toggle report (12c). ROADMAP.md
already documents these at length with the `--collcheck` methodology, the
measured overlaps (Half Shower -14.0px, Shower -22.0px), and three ranked fix
directions. Do not duplicate that analysis here, just execute it.

One instruction to add to it: **write the 12a fix so it generalises.** Phase 5
(siteswap) replaces every hand-rolled pattern branch with one derived geometry.
If the 12a fix is another special case bolted onto Half Shower and Shower, Phase
5 throws it away. If instead the over-the-top standoff is expressed once, as a
function of the throw's height and destination, Phase 5 inherits it. Prefer fix
direction 1 (a small fixed standoff on the landing point) over direction 2 (a
bespoke dodge), for exactly this reason.

**0.2 Replace the Suno track.** `Juggling Game.mp3` is still the free-tier
non-commercial render. This blocks shipping to anybody, it is a single file
swap plus a reimport once the paid render exists, and it is not a coding task.

---

## Phase 1. The Lesson system (Louis's first ask)

**Goal: nothing in this game ever unlocks without teaching itself, and every
lesson runs slow, with the exact key to press floating over the hand that should
press it.**

### 1.0 Fix the persistence bug first

In `save_progress()`, alongside the other `prog` keys:

```gdscript
cf.set_value("prog", "seen_tuts", seen_tuts)
```

In `load_progress()`:

```gdscript
var st: Variant = cf.get_value("prog", "seen_tuts", [])
if st is Array:
    seen_tuts.clear()
    for v in (st as Array):
        seen_tuts.append(String(v))
```

In `reset_new_game()`, add `seen_tuts.clear()` so a fresh slot re-teaches.

Verify: buy rings, quit, relaunch, buy rings again. The lesson must not re-fire.

### 1.1 Lessons run in slow motion

`slow_target()` (line 3312) already sums every slow-motion source and clamps to
1.0, and `_physics_process` already advances the sim by fractional ticks. So a
lesson gets slow motion for free by adding one source.

New constants near the other slow-motion constants (around line 273):

```gdscript
# --- lessons (Louis): a lesson is taught in thick time, so a beginner can SEE
# the arc and the window. It starts nearly frozen and speeds up as the lesson
# goes on, so the last step of a lesson is close to real speed and the player is
# never dumped from a slow world straight into a fast one.
const TUT_SLOW_START := 0.62   # the first step of a lesson: 62% slow
const TUT_SLOW_END := 0.20     # the last step: nearly real time
```

Then in `slow_target()`, before the final clamp:

```gdscript
if tut_active:
    a = maxf(a, tut_slow())   # a lesson sets a FLOOR on slowness, never a sum
```

Use `maxf`, not `+=`. A lesson should not stack with a Pie into a frozen world.

New function near the other tutorial functions:

```gdscript
func tut_slow() -> float:
    # the lesson's own slow-motion floor, easing from thick to real across the
    # lesson's steps so the player is handed back to full speed gradually
    var steps := tut_lesson(tut_id)
    if steps.size() <= 1:
        return TUT_SLOW_START
    var f := float(tut_step) / float(steps.size() - 1)
    return lerpf(TUT_SLOW_START, TUT_SLOW_END, clampf(f, 0.0, 1.0))
```

A per-step override is worth supporting too, because a trick lesson wants to be
slow on the step that teaches the trick and normal on the drill step. Read an
optional `"slow"` key from the step dictionary and prefer it when present.

**Watch out:** `SLOW_RAMP` is 0.0025 per frame, so easing from 0.0 to 0.62 takes
about 250 frames, which is four seconds. That is far too slow to enter a lesson
with. When `begin_tutorial()` runs, snap `_slow_cur` directly to `tut_slow()`
rather than letting it ramp:

```gdscript
_slow_cur = tut_slow()   # a lesson opens ALREADY thick, it does not ease in
```

### 1.2 Key prompts floating over the hands

This is the "clear buttons to press popups" ask, and it is the heart of the
phase. `draw_keycap(font, x, y, label)` already exists (line 4669) and already
returns its width, and `k_catch()` / `k_throw()` / `k_trick()` / `k_cycle()`
already resolve the player's live bindings into glyph strings that respect a
remap and a gamepad. So the drawing primitive is done.

Add one function:

```gdscript
func draw_key_prompt(font: Font, at: Vector2, keys: Array[String], label: String,
        urgency: float, col: Color) -> void:
    # a floating "press THIS now" bubble: a keycap plus a word, pulsing harder as
    # the moment approaches. urgency 0 = far off (calm, faint), 1 = press NOW
    # (bright, large, pulsing). Drawn ABOVE the hand it belongs to, never over it.
```

Behaviour it needs:

- scale from about 0.85 at urgency 0 to 1.25 at urgency 1
- alpha from about 0.45 to 1.0
- a soft pulse via `sin(tick * 0.18)` at high urgency only, so a calm prompt sits
  still and an urgent one throbs
- draw at `at + Vector2(0, -64)` so it floats clear of the hand sprite

Then add the prompt logic, called from `_draw()` only while `tut_active`:

```gdscript
func draw_tut_prompts(font: Font, s: Vector2) -> void:
    # THE lesson affordance: the key you should press, over the hand that should
    # press it, at the moment it should be pressed.
```

Three cases it must cover:

**A catch prompt.** For each ball in `STATE_FLIGHT`, compute
`d = b.land_tick - tick`. When `0 < d <= PROMPT_LEAD` (a new constant, start at
90 ticks, which at 62% slow is about two real seconds), draw a CATCH prompt over
`outer_pos(b.to_hand)` with `urgency = 1.0 - float(d) / float(PROMPT_LEAD)`.
This is the single most valuable thing in the phase: a beginner literally watches
the CATCH key light up as the ball comes down.

**A throw prompt.** When a hand holds a prop and the step's goal wants a throw,
draw a THROW prompt over that hand at a steady urgency of about 0.7. If the step
wants a HELD throw (a High Toss lesson), draw a small hold meter under the
keycap so "hold it longer" is visible rather than described.

**A trick prompt.** When a trick lesson's step wants Space, draw the TRICK
prompt over the juggler's head (`stage_center()` plus an offset), not over a
hand, since it is not a handed action.

Suppress every prompt while `tut_advance_at >= 0` (the step is already cleared
and is just letting the last throw land), so the screen goes quiet on success
rather than nagging.

**Also show the timing window.** A beginner cannot see why a catch failed. While
`tut_active`, draw a small arc or ring around the target hand that tightens as
`land_tick` approaches, and flashes gold at the exact Perfect window
(`perfect_window()`, 7 ticks). This turns an invisible probability into a visible
target, and it is the single best teaching tool available in a timing game. It
should appear ONLY in lessons, never in a real set, or it defeats the skill
model.

### 1.3 Every unlock queues a lesson

Today `announce_new_tricks()` (line 3205) fires a banner and silently selects the
trick. `announce_new_patterns()` sets a one-line message. Neither teaches.

Add a queue, because an unlock happens mid-performance (inside `add_xp()`) and
you must not hijack a live set:

```gdscript
var pending_tuts: Array[String] = []   # lessons queued by an unlock, taught at the hub
```

Persist it in `save_progress()` / `load_progress()` under `prog`, exactly like
`seen_tuts`, so a queued lesson survives quitting.

Add:

```gdscript
func queue_lesson(id: String) -> void:
    # an unlock during a live set cannot interrupt it, so the lesson waits at the
    # hub. Queued once, taught once, then remembered forever.
    if seen_tuts.has(id) or pending_tuts.has(id):
        return
    pending_tuts.append(id)
```

Wire the three unlock sources:

**Tricks.** In `announce_new_tricks()`, keep the existing banner and the
auto-select (both are good), and add `queue_lesson("trick_%s" % TRICKS[i]["id"])`.

**Patterns.** In `announce_new_patterns()`, add
`queue_lesson("pattern_%s" % PATTERNS[i]["id"])`.

**Ball count.** This one has no announcement at all today, which is a genuine
content hole: `max_balls()` (line 2424) silently grows at Strength 12, 20 and 30
and nothing tells the player. Detect the crossing where Strength is spent, which
is `invest()` (line 3585) and `_adjust()` (line 3648, the debug path):

```gdscript
func check_ball_unlock(prev_max: int) -> void:
    var now := max_balls()
    if now > prev_max:
        queue_lesson("count_%d" % now)
```

Call it after any Strength change, passing the `max_balls()` value read before
the change.

**Props.** `offer_prop_tutorial()` (line 1524) already does the right thing and
fires immediately on purchase, which is correct because a purchase happens at the
hub where interrupting is safe. Leave it, but route it through `queue_lesson` too
for uniformity, and have the hub drain the queue.

### 1.4 The hub drains the queue

In `enter_day()` (line 1144), after the existing setup:

```gdscript
if not pending_tuts.is_empty() and day_anim == "":
    var id: String = pending_tuts[0]
    pending_tuts.remove_at(0)
    seen_tuts.append(id)
    save_progress()
    begin_tutorial(id)
    return
```

Do NOT auto-start it silently. Better: show a hub row, so the player has agency
and never gets yanked into a lesson they did not ask for. Add to `day_rows()`
(line 1159), at the TOP of the list when the queue is non-empty:

```gdscript
if not pending_tuts.is_empty():
    out.append({"id": "learn", "name": "LEARN  -  %s" % lesson_title(pending_tuts[0]),
        "cost": "", "ok": true, "why": "",
        "sub": "something new. Taught slow, one step at a time. Costs no time."})
```

and handle `"learn"` in `day_activate()` (line 1253) by draining the queue as
above. A lesson must cost no day segment, because punishing a player for learning
is exactly backwards.

`tut_finish()` (line 1717) already returns to the day and sets a message, so the
loop closes itself. It also force-resets `prop_type = PROP_BALLS` after a
non-prop lesson, which will be wrong for a trick lesson that was taught with
clubs. Guard that line so it only fires for the `"balls"` basics lesson.

### 1.5 The new lesson content

`tut_lesson(id)` (line 1542) is already a clean dispatcher returning an array of
step dictionaries. Extend it with three new id families. Keep the existing step
dictionary shape (`prop`, `balls`, `hand`, `goal`, `need`, `text`, `sub`) and add
these optional keys:

| key | meaning |
|---|---|
| `slow` | override the lesson's slow-motion floor for this step |
| `prompt` | which key prompt to show: `"catch"`, `"throw"`, `"hold"`, `"trick"` |
| `trick` | the trick index to force-select for this step |
| `pattern` | the pattern index to force for this step |

**Trick lessons (`trick_<id>`).** Three steps, and they should mirror the three
input grammars the game actually has (toggle, arm, live), because the grammar is
the thing that confuses people, not the trick.

For a toggle trick, for example High Toss:

```
step 1  goal "trick_on"    need 1
        text "High Toss: switch it ON"
        sub  "Press SPACE. Every throw will fly high until you press it again."
        prompt "trick"   slow 0.62

step 2  goal "catch"       need 3
        text "Now throw, and catch them coming down"
        sub  "They hang much longer up there. Wait for it. Do not reach early."
        prompt "catch"   slow 0.55

step 3  goal "trick_off"   need 1
        text "And switch it OFF"
        sub  "Press SPACE again to go back to a normal weave. That is the whole toggle."
        prompt "trick"   slow 0.35
```

For an arm trick (Overthrow, the only one), the lesson is: press Space, then
throw, and the ONE next throw is empowered. Emphasise the one-shot, because that
is the model Louis specifically redesigned toward in ROADMAP item 11.

For the live trick (Spin), the lesson is: get everything airborne, then press
Space, and catch blind. Force `slow` high on that step, because catching blind at
full speed is not a beginner lesson.

**Ball-count lessons (`count_<n>`).** Two steps: a slow drill at the new count on
the pattern that suits its parity, and then a normal-speed drill. The text should
say what actually changed:

```
step 1  balls n   slow 0.60   goal "catch"  need 6
        text "Five balls now"
        sub  "Your Strength carries a fifth. It is faster and higher than four. Throw a touch higher than feels right."
step 2  balls n   slow 0.25   goal "catch"  need 10
        text "Again, closer to real speed"
        sub  "Same pattern, less thick time. Land ten."
```

**Pattern lessons (`pattern_<id>`).** Force the pattern via the new `pattern` key
in `tut_setup_step()`, run it slow, and use the PATTERNS table's own `desc` field
as the `sub` text so there is one source of truth for what a pattern is. Then
drill it. Columns in particular badly needs this, since it is the one pattern
with its own hand positions (`HAND_VERY_INNER`).

### 1.6 Changes to the existing tutorial plumbing

`tut_setup_step()` (line 1590) needs to honour the new keys:

- if the step has `"trick"`, set `trick_sel` to it and clear `toggle_on` and
  `trick_primed`, so the lesson starts from a known state
- if the step has `"pattern"`, set `pattern` and `pattern_sel` rather than the
  current hardcoded `pattern = CASCADE if num_balls % 2 == 1 else FOUNTAIN`
- the `fresh` check (`balls.is_empty() or prop_type != want_prop or balls.size()
  > want_n`) is good and should be kept, because it is what lets a competent
  player flow through a whole lesson unbroken

`tut_check()` (line 1670) needs the new goals. It currently matches on
`"throw_r"`, `"throw_l"` and falls through to a catch count. Add:

```gdscript
"trick_on":  done = toggle_on == int(step.get("trick", -1))
"trick_off": done = toggle_on < 0
"trick_use": done = tut_tricks >= int(step["need"])   # arm/live: count reward_trick calls
```

Add `var tut_tricks := 0` and reset it in `tut_setup_step()`, incremented from
`reward_trick()` (line 3131) when `tut_active`.

`tut_maintain()` (line 1685) already tops the hands back up after a fumble, which
is the single most important beginner-friendliness feature already in the file.
Keep it exactly as is.

### 1.7 Making it EASIER, which was the actual ask

Concrete softenings, all lesson-only, none of which touch real play:

- **Widen the catch window during a lesson.** In `perfect_window()` (line 3407),
  add `if tut_active: return W_LATE` so that during a lesson literally any
  in-window press is a Perfect. A beginner should never fail a catch they
  reasonably attempted. The real windows come back the moment the lesson ends.
- **No chance rolls during a lesson.** In `catch_chance()` (line 3349), add
  `if tut_active: return 1.0`. A lesson must never punish a player with a dice
  roll they cannot see. Note `drop_ball` is still reachable via MISTIME and
  MISS_GRACE, which is correct, since a lesson should still teach that missing
  entirely loses the ball.
- **No stamina drain during a lesson.** `energy_mult()` already halves it in
  training. Zero it outright when `tut_active`.
- **Lower the catch counts.** The existing three-ball step wants six catches. For
  a first-ever cascade that is a lot. Drop to four.
- **Never fail a lesson.** There is no fail path today and there must not be one
  after Phase 2 either. Whatever the Booking's drop limit becomes, it must be
  inert while `tut_active`.

### 1.8 Verification

- `--tutorial balls` from a fresh slot, all the way through, watching that the
  world is visibly thick and the CATCH keycap lights up over the right hand
- buy each prop and confirm its lesson fires once and only once, across a restart
- force a level-up (`--debug` grants stat editing) across a trick gate and confirm
  the lesson queues to the hub rather than interrupting the set
- raise Strength across 12 and confirm the `count_5` lesson queues
- confirm no prompt, window ring, or widened catch window appears in a real
  performance

---

## Phase 2. The Booking (Louis's second ask: a reachable goal every performance)

**Goal: a performance is a contest you can win or lose, and you always know
exactly how close you are.**

### 2.1 The shape

A booking is three sets at one venue, played back to back without returning to
the hub:

1. **The Warm-up.** A modest target. Teaches the room.
2. **The Set.** A real target.
3. **The Encore.** The biggest target, plus a named condition drawn from a deck.

Clear all three and the booking is complete: full pay, a real reputation gain,
and (Phase 3) a shop between each set. Fail any set and the booking ends there:
partial pay for what you cleared, and a reputation loss.

### 2.2 The three resources

**The target (the gate).** New constants:

```gdscript
# --- the Booking: every set is a contest with a number to beat, so a performance
# always has a reachable goal (Louis). The target scales off the VENUE and the
# ante, never off the player's own record, because scaling off your own best
# punishes you for improving.
const SET_WARMUP := 0
const SET_MAIN := 1
const SET_ENCORE := 2
const SETS_PER_BOOKING := 3
const VENUE_BASE := [1200, 2600, 5200, 9500, 17000, 30000]   # the Warm-up target per venue
const SET_STEP := [1.0, 1.9, 3.2]     # Warm-up, Set, Encore
const ANTE_STEP := 0.15               # each cleared booking at this venue raises the bar
```

```gdscript
func set_target() -> int:
    var base := float(VENUE_BASE[clampi(run_venue, 0, VENUE_BASE.size() - 1)])
    var step := float(SET_STEP[clampi(set_index, 0, SET_STEP.size() - 1)])
    var a := 1.0 + ANTE_STEP * float(ante[run_venue])
    var enc := encore_target_mult()   # 1.0 unless the Encore condition says otherwise
    return int(round(base * step * a * enc))
```

**These numbers are placeholders and the whole phase lives or dies on them.**
Budget real time for tuning. The calibration target, stated as a testable claim:

> A flawless three-ball ball cascade must clear the Warm-up at the Backyard and
> must fall roughly 40 percent short of the Warm-up at the Championship.

That is the mechanism that finally enforces ideas.rtf's "make it near impossible
to unlock high venues with only 3 ball juggling". `object_mult()` already makes
heavy loads score more. A target makes them mandatory, which is a completely
different kind of pressure, and it is the reason this phase matters more than any
other.

To calibrate, use the existing `--demo` autoplayer, which juggles at a fixed
28-tick metronome and is a decent proxy for a strong player: run it at each venue
with each prop and ball count, dump the score at 60 seconds, and build the table
from real numbers rather than guesses. Add a `--calib` dev flag that runs this
sweep and prints a matrix.

**Applause (the clock).** This is the one-line change that activates the collapse
machinery that already exists.

```gdscript
const APPL_DECAY := [0.00035, 0.00045, 0.00055, 0.00070, 0.00085, 0.00100]  # per tick, per venue
```

In `update_sim()` (line 3805), only while performing and running:

```gdscript
if mode == MODE_PERFORM and not tut_active:
    applause = maxf(0.0, applause - APPL_DECAY[clampi(run_venue, 0, 5)] * encore_decay_mult())
    if applause <= 0.0 and not collapsing:
        start_collapse()   # factor the existing block out of drop_ball into this
```

Factor the collapse block out of `drop_ball()` into `start_collapse()` and call it
from both places, since it now has two triggers.

At 0.00035 per tick and 120 ticks per second, a Backyard crowd empties in about
24 seconds of doing absolutely nothing, and a World Arena crowd in about 8. Every
Perfect catch adds 0.05, which is roughly 140 ticks of patience back, so a player
landing a catch every 40 ticks gains ground comfortably and a player who freezes
loses the room. Tune from there.

Feed the crowd more generously than today, because applause is now a resource
rather than decoration:

- height should feed it, so a big throw excites a crowd and a low safe weave
  bores it. Add a small applause gain in `do_throw()` scaled by `b.height`.
- tricks already feed it (+0.03 toggle, +0.09 one-shot at line 3150) and this is
  now the real reason to press Space, which finally makes the trick system load
  bearing.

**Drops (the damage).** Add a hard limit:

```gdscript
const DROP_LIMIT := 3   # three drops and the crowd turns. The Encore may lower this.
```

In `drop_ball()`, after `dropped += 1`:

```gdscript
if mode == MODE_PERFORM and not tut_active and dropped >= drop_limit():
    start_collapse()
```

`drop_limit()` returns `DROP_LIMIT`, adjusted by the Encore condition and later by
Flourishes (The Understudy forgives one, Daredevil makes a high-throw drop cost
two). This one line is the single highest-value change in the entire plan. It is
what makes every throw carry a real, legible, escalating cost.

### 2.3 Bank or push

`finish_performance()` (line 1071) already ends a set gracefully with the props
still up and is explicitly documented as "so a strong set can be banked on a high
note". Give it teeth.

```gdscript
const OVERTIME_PER_CATCH := 0.02   # each catch past the target grows the walk-off bonus
const OVERTIME_MAX := 2.5
```

Once `score >= set_target()`, the set does not end. Instead:

- the HUD switches from "TARGET" to "CLEARED. Walk off, or keep going."
- every subsequent catch grows `overtime` by `OVERTIME_PER_CATCH`, capped
- pressing the finish key banks `score * (1.0 + overtime)` and moves to the next set
- **if the crowd walks or the drop limit lands, the overtime is lost entirely**
  and the player banks only the bare target

So: clear it, then choose. Walk now with a safe payout, or stay out for the
multiplier and risk the night. That is the emotional shape of a real juggling act,
it is push-your-luck, and it is about forty lines on top of what already exists.

### 2.4 The Encore deck

Each is a toggle on a constant that already exists. Store as a table:

```gdscript
const ENCORES := [
    {"id": "hecklers", "name": "The Hecklers",
     "desc": "The crowd is impatient. Their attention drains twice as fast."},
    {"id": "fright", "name": "Stage Fright",
     "desc": "The lights are in your eyes. No landing markers."},
    {"id": "draft", "name": "The Draft",
     "desc": "A wind through the tent. Every throw drifts."},
    {"id": "blackout", "name": "Blackout",
     "desc": "Only the top of each arc is lit. Catch what you cannot see."},
    {"id": "fire", "name": "Fire Only",
     "desc": "This crowd came for danger. Balls and eggs score nothing."},
    {"id": "purist", "name": "The Purist's Night",
     "desc": "No gear, no stats, no help. Only hands."},
    {"id": "onehand", "name": "One Hand Tied",
     "desc": "Your left hand may catch, but never throw."},
    {"id": "long", "name": "The Long Set",
     "desc": "Twice the target. Twice the patience."},
    {"id": "cold", "name": "Cold Hands",
     "desc": "The Perfect window is two ticks tighter."},
    {"id": "understudy", "name": "The Understudy",
     "desc": "One drop and it is over."},
]
```

Implementation, each of these is genuinely a couple of lines:

| id | hook |
|---|---|
| hecklers | `encore_decay_mult()` returns 2.0 |
| fright | skip `draw_targets()` (line 4407) |
| draft | scale `inacc_factor()` (line 3343) by 2.0 |
| blackout | in `draw_prop()` (line 4495), skip when the ball is below its arc crest |
| fire | in `on_catch()`, zero the score when `prop_weight() < 3` |
| purist | set `purist` for the set (the whole machinery already exists) |
| onehand | ignore the LEFT throw edge in `_edge()` (line 2203) |
| long | `encore_target_mult()` returns 2.0, `encore_decay_mult()` returns 0.5 |
| cold | `perfect_window()` returns 2 fewer ticks |
| understudy | `drop_limit()` returns 1 |

Note how many of these you already designed and then filed under "cosmetic" or
"optional". The GDD's glow-in-the-dark cosmetic is Blackout. The Purist toggle is
The Purist's Night. Hard Mode's mid-air collisions are a good eleventh Encore.
You have been designing boss blinds for months with nowhere to put them.

Draw the Encore's name and description on the existing establishing card
(`ST_ESTABLISH`, `begin_performance()` at line 1082), which is already a
"here is where you are about to play" beat and is the perfect place for "and here
is what they want from you".

### 2.5 New state and the save

```gdscript
var set_index := 0            # 0 Warm-up, 1 Set, 2 Encore
var booking_score := 0        # banked across the booking's sets
var booking_pay := 0
var overtime := 0.0           # the walk-off multiplier, earned past the target
var encore := -1              # index into ENCORES for this booking's Encore, or -1
var ante: Array[int] = [0, 0, 0, 0, 0, 0]   # bookings cleared, per venue
var set_cleared := false      # this set's target has been beaten
```

Persist `ante` under `prog`. The rest is per-booking and does not need saving,
unless you want mid-booking quit-and-resume, which I would skip for now: a booking
is short, and losing it on quit is a fair price for a much simpler state model.

### 2.6 The HUD

The whole point of this phase is that the goal is **reachable and legible**, so
the HUD is not an afterthought here, it is the feature.

`draw_hud()` (line 4695) already draws the applause bar at 4754. Add:

- **A target bar**, the most prominent element on screen. Score against target,
  filling. It should feel like it is filling. When it crosses, it should flash
  gold, the crowd should roar (`play_sfx("cheer")`), and the label should change
  to the walk-off prompt.
- **Drop pips.** Three dots. They go dark as you drop. This is the single most
  important new pixel on the screen, because it is what makes a throw feel
  dangerous. Make them large and unmissable.
- **The set counter**, "SET 2 of 3", and the Encore's name when it is running.
- **The overtime multiplier**, once earned, growing visibly next to the score.

The applause bar should be re-read as "the crowd's patience" now that it decays,
so relabel it and let it visibly fall, which it never did before.

### 2.7 Flow changes

`begin_performance(n)` sets up the booking (roll the Encore, reset `set_index`,
`booking_score`, `dropped`). A new `next_set()` advances between sets without
returning to the hub: re-establish the card, `start_run()` again, keep
`booking_score` accumulating.

`on_round_end()` (line 3229) is where most of the surgery lands. Today it scores,
pays, swings reputation, writes records and opens the results card, all in one
pass. It needs to split into a per-set resolution and a per-booking resolution:

- **per set**: did we clear the target? If yes, bank `score * (1 + overtime)` into
  `booking_score` and call `next_set()`. If no, the booking is over.
- **per booking** (all three cleared, or a set failed): now do what
  `on_round_end()` does today, but off `booking_score` rather than `score`. The
  reputation formula at line 3251 currently divides by the player's own record,
  which should be **replaced** by "how much of the booking did you clear", which
  is fairer and much easier to reason about.

Records (`best_scores`, `best_scores_purist`) should now key off `booking_score`,
so a record means a complete great night rather than one long grind.

`too_tired()` and stamina still gate whether you can take a booking at all, which
is correct and unchanged.

### 2.8 Verification

- clear a full booking at the Backyard with three balls and confirm it is
  achievable but not trivial
- attempt a booking at the Championship with three balls and confirm it is clearly
  impossible, then confirm five clubs clears it
- confirm the crowd genuinely walks if you stand still for 25 seconds
- confirm three drops ends the set, and that the collapse animation (which already
  works) plays
- confirm the overtime multiplier is lost on a failed push, which is the entire
  tension of the mechanic
- confirm no drop limit, no decay, and no target appear during a lesson or in
  practice

---

## Phase 3. Flourishes (the build layer)

Only start this once Phase 2 is tuned and fun, because a build layer on top of a
game with no tension is just arithmetic.

### 3.1 The shape

Three slots at the start, expandable to five. Between sets of a booking, a shop
offers three Flourishes drawn from a deck, for gold. A Flourish is a passive rule
that changes scoring or risk. They persist across bookings, so a career
accumulates an identity.

**The rule that makes or breaks this:**

> A Flourish must change what the player is trying to do in the next sixty
> seconds. It must never merely add a number to a total.

"+10% score" is a bad Flourish. "Catches score 1.75x while your rhythm stays even"
is a good one, because it changes how the player physically plays.

**The hard guardrail, from the GDD's own philosophy:** a Flourish may change
scoring, risk and rules. It must **never** raise `catch_chance()`. The moment
items start catching balls for the player, the skill-first promise is dead.
Flourishes make you braver, not better.

### 3.2 The starting deck

```gdscript
const FLOURISHES := [
    {"id": "metronome", "name": "Metronome", "cost": 600,
     "desc": "Catches score x1.75 while the gap between your last three catches stays even."},
    {"id": "daredevil", "name": "Daredevil", "cost": 700,
     "desc": "Throws above head height score x2.5. Dropping one costs two drops."},
    {"id": "allin", "name": "All In", "cost": 900,
     "desc": "Everything scores x4. The set ends on your first drop."},
    {"id": "understudy", "name": "The Understudy", "cost": 500,
     "desc": "Your first drop each set is forgiven."},
    {"id": "butterfingers", "name": "Butterfingers' Charm", "cost": 650,
     "desc": "Every drop adds +0.5x to this set's multiplier. Fall apart beautifully."},
    {"id": "fireeater", "name": "Fire Eater", "cost": 850,
     "desc": "Torches score x3. Balls and eggs score nothing."},
    {"id": "eggman", "name": "Egg Man", "cost": 400,
     "desc": "Eggs are free and score x4. A broken egg costs a drop."},
    {"id": "showman", "name": "Showman", "cost": 700,
     "desc": "Every trick landed adds +0.2x for the rest of the set."},
    {"id": "weight", "name": "Weight Class", "cost": 750,
     "desc": "Score scales with the weight in the air rather than with your streak."},
    {"id": "blindspot", "name": "Blind Spot", "cost": 800,
     "desc": "Props vanish at the top of the arc. Everything scores x2."},
    {"id": "onehanded", "name": "One-Handed", "cost": 900,
     "desc": "Score x2.5 for as long as your left hand never throws."},
    {"id": "deadpan", "name": "Deadpan", "cost": 600,
     "desc": "Score x2 while the crowd is above nine tenths."},
]
```

### 3.3 Where they hook

Almost every one of these is a multiplier read inside `on_catch()`, which already
computes `var pm := pattern_mult() * object_mult()`. Extend that to
`var pm := pattern_mult() * object_mult() * flourish_mult(best, best_d)`. Keep
`flourish_mult()` as the single chokepoint so the scoring path stays readable and
so Purist can strip them if you decide it should.

The risk-side ones hook into `drop_limit()` and `drop_ball()`. The perception ones
(Blind Spot) hook into `draw_prop()`, exactly like the Blackout Encore, so build
Blackout first in Phase 2 and reuse it here.

Metronome needs a small ring buffer of the last three catch ticks, which is four
lines.

### 3.4 Save and shop

Persist `flourishes: Array[String]` and `flourish_slots: int` under `prog`. The
between-set shop reuses the existing shop overlay pattern (`shop_open`,
`shop_input()` at line 1379), which already draws a list, handles a cursor and
confirms a spend via `confirm_spend()`. This is the cheapest part of the phase.

---

## Phase 4. The meta layer

Cheap, and each is independently worth doing. Do these before Phase 5, since they
are what make people open the game on a Tuesday.

**4.1 The Daily Booking.** One fixed seed per day, shared by every player: the same
venue, the same Encore, the same Flourish offers, the same prop prices. One
attempt. `rng.seed = hash(date_string)` is essentially the whole implementation,
since the sim already runs off a seeded `RandomNumberGenerator`. This is ROADMAP
item 2's remaining open ask, and it is the cheapest retention mechanic available.

**4.2 Ghosts.** The sim is tick-based and deterministic given inputs, so a run is
fully described by a list of `(tick, action)` pairs, which is a couple of bytes
each and a few kilobytes for a whole set. Record them, store the best run per
venue in the save, and draw the record holder as a translucent second juggler
beside you, catching and throwing in real time. Racing a ghost is one of the most
reliably motivating mechanics ever invented, this engine gets it almost for free,
and it makes a spectacular trailer shot.

The one caveat worth checking: `drop_ball` and `catch_chance` consume `rng`, so a
replay must re-seed identically and must not be perturbed by cosmetic randomness.
The code already carefully separates the sim `rng` from cosmetic `randf()` calls
(see the comments in `spawn_falling`), so this should hold, but verify it before
building on it.

**4.3 Leaderboards.** Already specced in tasks.md, blocked only on the Steam App
ID. `best_scores_purist` is the right board to publish.

**4.4 Passing (two players).** Local co-op, two jugglers, six clubs, every fourth
throw crosses to the partner. The input split already exists (D/F is one juggler,
J/K is the other). Shared score, shared drop counter. This is the feature most
likely to get the game streamed, and streamed is how skill games get sold.

---

## Phase 5. Siteswap (the long project)

Do this last. It is the largest change, it touches the most fragile code, and it
should not begin until Phase 0 has produced a geometry you trust.

### 5.1 What it replaces

Five hardcoded `PATTERNS` and the pattern branches inside `do_throw()`,
`throw_slot()`, `catch_slot()` and `assign_lane()`. Every new pattern today is a
bespoke branch, which is exactly why ROADMAP 12a exists: Half Shower and Shower
collide with the weave because each pattern hand-rolls its own geometry and nobody
proved them consistent with each other. **The content system does not scale and it
is already generating bugs.**

### 5.2 The mapping

A siteswap digit says how many beats until that object is thrown again. Odd digits
cross hands, even digits stay. The average of the digits is the object count. A
string is valid if and only if no two objects ever land on the same beat, which is
a fifteen-line check.

The engine already gives every ball a `land_tick`, a `to_hand`, and a continuous
`height` in `0..1.4`. A siteswap is precisely a function from `(beat, hand)` to
`(height, destination hand)`, which is exactly those two things. And the height
scale you tuned by feel already lines up:

```
siteswap_height(n) = clamp((n - 2) / 3.0, 0.0, 1.4)
    3 -> 0.33   the standard cascade throw
    4 -> 0.67
    5 -> 1.00   the five-ball height, already the game's "held" throw
    7 -> 1.40   the ceiling, already what a maxed hold produces
    2 -> a hold, no throw
    1 -> a fast flat pass across
    0 -> an empty hand
```

That is not a coincidence. It lines up because you tuned the height model against
real juggling.

### 5.3 What it buys

Patterns become data, not code: adding `441` is adding a table row. Difficulty
becomes derivable rather than five hand-picked multipliers you re-guess forever:

```
difficulty = objects + 0.4 * (max_digit - 3) + 0.3 * distinct_digits
```

The geometry unifies, which is the durable fix for the whole class of bug that
ROADMAP 12a is one instance of. Patterns become collectible content for the Skills
screen you already built. And a player who gets good at JUGGLE learns real
siteswap, which they can take to an actual juggling club, which is the honest
answer to "why is this the juggling game" and the thing that gets it recommended
in places advertising cannot reach.

### 5.4 Migration

Keep `PATTERNS` as a table of named siteswaps so nothing breaks: cascade is `3`,
fountain is `4`, columns is `50505` (or `(4,4)(4,0)` in the two-handed notation if
you want to be precise), half shower is `52`, shower is `51`. Then the existing
five patterns become the first five rows of a table that can grow forever, and
every pattern lesson from Phase 1 keeps working unchanged.

---

## Suggested session order

1. **Phase 0**, the ROADMAP 12 fixes, written to generalise.
2. **Phase 1**, the Lesson system. Self-contained, high value, and it is what
   Louis asked for first.
3. **Phase 2**, the Booking. The big one. Budget a full session for the code and
   a second one purely for tuning `VENUE_BASE` and `APPL_DECAY` against real play,
   because the numbers are the feature.
4. **Phase 3**, Flourishes.
5. **Phase 4**, the Daily and ghosts.
6. **Phase 5**, siteswap, as the long project.

Phases 2 and 3 together are the difference between a game that reviews as "a
lovely little juggling toy" and one that reviews as "I have put sixty hours into
this". Both are mostly a matter of activating machinery that is already sitting in
Game.gd doing nothing.

---

## Phase 2 — DONE (2026-07-15)

Every performance is now a **Booking**: three sets at one venue (Warm-up / The Set /
The Encore), played back to back. Each set is a real contest — a target to beat, a
crowd whose patience drains, a hard drop limit — and clearing a target lets you WALK
OFF to bank it or push for a growing overtime multiplier and risk the night. The
whole thing sits on machinery that already existed (the collapse, the applause meter,
`finish_performance`, `purist`, `set_collide`, the record boards).

What shipped, against the plan:

- **The clock.** `applause` now decays every tick in `update_sim` (`APPL_DECAY` per
  venue). The collapse block was factored out of `drop_ball` into `start_collapse()`,
  now fired by an emptied crowd OR the drop limit. **A collapse is decisive**: a real
  bug surfaced in testing — with the sim halted, catching + re-throwing the still-
  airborne props let a player grind on with the clock off — so `on_catch`, `do_throw`
  and `on_throw_press` now early-return while `collapsing`.
- **The target.** `set_target()` scales off venue × set × ante × encore. Cleared state
  tracked by `set_cleared` / `check_set_cleared()`.
- **Bank or push.** `finish_performance()` only banks once cleared; overtime accrues
  per catch past the target; a collapse strips overtime (banks the bare target).
- **The Encore deck.** Ten conditions (`ENCORES`), each a toggle on an existing hook:
  hecklers/long → `encore_decay_mult`, long → `encore_target_mult`, fright →
  `draw_targets`, blackout → `draw_prop`, cold → `perfect_window`, understudy →
  `drop_limit`, purist → `purist_run`, draft → `inacc_factor`, fire → `encore_score_
  mult`, tight → the collision loop. **onehand was cut** (it jams the pattern — a hand
  that catches but never throws fills and dies; not survivable), replaced by Close
  Quarters (mid-air clacks).
- **Flow.** `on_round_end` splits into `resolve_set` (bank + advance, or fail) and
  `resolve_booking` (pay, rep, records, the win). Reputation now swings on **sets
  cleared** (`frac*1.5 - 0.5` × `REP_SWING`), not the old divide-by-your-own-record.
  Records and pay key off `booking_score`. "Go again" from the results card starts a
  fresh booking (new Encore), not a bare set.
- **HUD.** New top-centre dashboard: the set tag, the prominent TARGET bar (flips to a
  gold walk-off prompt when cleared), the drop pips, and the relabelled draining
  "THE CROWD" patience bar. The establish card names the set, its target, and the
  Encore from the first card. The results card reads the whole night.

### Calibration (the numbers are the feature)

Added a `--calib` dev flag that runs the autoplayer and prints the score reached
**before the crowd walks** (it quits AT the collapse, since a halted-sim autoplayer
zombie-feeds itself afterward). Also `--booking`, `--encore <id>`, `--set <n>`,
`--venue <n>`, `--prop <n>` for driving and shooting booking states. All dev-only,
behind `is_debug_build()`.

Two levers were mis-set in the plan and had to change:

1. The plan's `+0.05`-per-catch applause gain **swamped** the decay — the crowd never
   walked, so there was no clock. Per-catch gains are now small (`APPL_PERFECT 0.014`,
   etc.), deliberately below a set's decay bleed, so steady low play is a slow drain
   and reaching the target is a race. Spectacle (height, tricks) and **density** buy
   the time: more props in the air = more catches/sec = more patience fed, which is
   *why* heavy loads are needed at the top, not just that they score more.
2. Scoring is ~100× larger than the plan's placeholder targets assumed (a 3-ball
   cascade racks up hundreds of thousands). `VENUE_BASE` is now
   `[8000, 20000, 55000, 85000, 100000, 140000]`.

Measured autoplayer result (a "decent" fixed-metronome player, no tricks — a human
with tricks does better, so targets are conservative):

| Venue | 3 balls | intended heavy loadout |
|---|---|---|
| Backyard / Street / Theatre | 3/3 | — |
| Circus | 2/3 (fails the Encore) | 4+ props clear |
| Championship | 1/3 | 5 torches 3/3 |
| World Arena | **0/3 (−30 rep)** | 5 torches / 6 knives 3/3 |

This finally enforces ideas.rtf's "near impossible to climb the top venues on three
balls" as a hard gate, not a soft one.

### Follow-ups (a real tuning pass, with a human, is still owed)

- The autoplayer throws a fixed metronome and never uses tricks, so it *undersells*
  crowd management. Watch a human play the Championship/Arena and adjust `APPL_DECAY`
  and `VENUE_BASE` — especially whether the Arena feels brutal or fair.
- `BOOK_PAY_PER_SCORE` (0.0015) sets the economy; sanity-check it against prop/glasses
  prices over a full career.
- The `fire`/`purist` Encores are loadout-dependent (shown up front on the establish
  card); confirm that reads as fair rather than a coin-flip.
- Mid-booking quit still drops the booking by design (only `ante` persists). Revisit
  if it annoys.
