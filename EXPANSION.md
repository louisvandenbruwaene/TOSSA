# JUGGLE: how this becomes a game people buy

Written 2026-07-14. This is not a task queue (that is ROADMAP.md) and not a
spec of what exists (that is README.md). This is a design argument about what
the game is missing structurally, and the concrete additions that would close
the gap, ordered by how much each one changes the game per unit of work.

> **CORRECTION, 2026-07-14.** Part 0 below overstates one thing. It claims a set
> cannot be lost. In fact `drop_ball()` already triggers a full collapse when
> applause reaches zero: the hands give up, every prop falls, the round ends.
> That machinery is complete and simply never reached, because applause only
> moves on events and **never decays with time**, so a competent player is never
> near zero. The argument of this document survives unchanged (a set still has no
> target and no real cost to a drop) but the work is cheaper than described: we
> are adding a decay term and a target to a fail state that already works, not
> building one. See PLAN.md, which is the executable version of this document and
> supersedes it where they differ.

Everything here is measured against one question: **why would a stranger pay
ten dollars for this, and why would they still be playing it in week three?**

---

## Part 0. The diagnosis

The juggling itself is genuinely good. The catch-timing model (Perfect at 7
ticks, Good at 10 on a probability roll, Late at 28, a committed miss at 52)
is a real skill system with real texture, and the variable-height throw is the
best thing in the codebase. That part is done and it is not the problem.

The problem is that **nothing is at stake, ever.**

Read `on_round_end()` honestly. A performance ends when the player decides it
ends. Dropping a prop breaks `streak` and nudges `applause` down. That is the
entire consequence of failure in the whole game. There is no target to clear,
no clock running out, no crowd that walks. A player cannot lose a set. They
can only choose to stop having one.

This has three downstream effects, and they are the three reasons the game
currently feels like a very polished toy rather than a game:

1. **The economy has nothing to push against.** Gold buys rings, clubs, knives,
   torches, glasses, pies. All of those are strict upgrades toward "juggle
   more comfortably." None of them are answers to a *problem*, because there
   is no problem. A shop is only interesting when you walk into it needing
   something.

2. **The skill ceiling is invisible.** A player who is very good at JUGGLE and
   a player who is mediocre at it have the same experience: they juggle, they
   stop, they get paid. The good one gets a bigger number. Nothing in the run
   *acknowledges* the difference in the moment, because there is no bar to
   clear and therefore no moment of clearing it.

3. **There is no reason to play a second run differently from the first.**
   Which is the actual definition of replayability. Balatro is not replayable
   because it has a big ladder. It is replayable because the jokers you are
   offered on run 40 force you to play a fundamentally different game than the
   ones you were offered on run 39.

The good news is that almost every mechanism needed to fix this is already
built and is currently doing nothing. `applause` is computed, decayed, drawn,
and then used for almost nothing. `finish_performance()` already exists as a
voluntary bank-your-score button and is one constant away from being a
push-your-luck decision. `purist` is already a full "harder rules, better pay"
toggle and is a working prototype of an entire build system with exactly one
item in it.

The three parts below are, in order: give the run a shape, give the run a
build, and give the game an infinite content source.

---

## Part 1. The Booking (give the run a shape)

**This is the highest-value change in the document and everything else depends
on it.**

Today a night at a venue is one open-ended set. Replace it with a **booking**:
three sets at the same venue, each with a rising score target, ending in an
Encore with a named condition attached. This is the small blind / big blind /
boss blind skeleton, but expressed in juggling's own vocabulary, and it turns
the six venues from a cosmetic backdrop into an actual difficulty curve.

### The three resources of a set

The set becomes a contest between three numbers that already exist in the
code, or nearly do.

**The target (the gate).** Every set demands a score. Clear it and you get
paid, gain reputation, and move to the next set. Fail it and the booking ends
early: you keep a fraction of the gold, you *lose* reputation, and you are
back in the day hub with a bad night behind you.

The target should be derived, not hand-authored, so it stays honest as the
player's tools change:

```
target(venue, set_index) =
    VENUE_BASE[venue] * SET_STEP[set_index] * (1.0 + 0.15 * ante)
```

where `ante` counts how many bookings you have already cleared at this venue.
Crucially, the target must NOT scale off the player's own record (which is what
`on_round_end()` currently does for the reputation swing) because that punishes
improvement. It scales off the venue and the ante, so getting better feels like
getting better.

The single most important property of the target: **it must be unclearable with
three balls at the higher venues.** This is exactly the ask in ideas.rtf ("make
it near impossible to unlock high venues with only 3 ball juggling, you should
be using 3 clubs at least, preferably 5 clubs or 3 torches"), and a score target
is the mechanism that finally *enforces* it rather than merely incentivising it.
`object_mult()` already makes heavy loads pay more. A target makes them
**mandatory**, which is a completely different kind of pressure. Set the numbers
so that a flawless three-ball cascade at the Championship falls roughly 40
percent short of the target. The player will feel, correctly, that they have to
pick up the clubs.

**Applause (the clock).** Applause is currently a decorative meter. Make it the
crowd's patience, and make it the thing that ends the set.

- It decays continuously, faster at higher venues.
- Every catch feeds it a little. Every Perfect feeds it more.
- Every landed trick feeds it a lot (this is finally a real reason to press
  Space).
- Height feeds it: a big throw excites a crowd, a low safe weave bores it.
- **If it hits zero, the crowd walks and the set is over.**

This gives the set a soft timer that never shows an ugly countdown clock, and
it makes the game's own thematic logic into its core mechanic: a juggler who
plays it safe loses the room. It also finally makes the tricks system load
bearing, because tricks stop being an optional score bonus and become the only
way to hold an audience long enough to reach a big target.

**Drops (the damage).** Three drops and the set ends. Not the streak: the set.

This one line is worth more than any other single line in this document.
Currently a drop costs a combo the player was probably going to break anyway.
With a drop counter, every single throw the player makes carries a real,
legible, escalating cost, and the decision to attempt a five-club shower with
one drop left is the most interesting decision in the game.

### Bank or push

You have already built half of this. `finish_performance()` lets a player end a
set gracefully on a high note. Give that button teeth:

Once the target is cleared, the set does not automatically end. The player may
keep juggling, and every subsequent catch adds to an **overtime multiplier**
that grows the longer they stay out. But drops still count, applause still
decays, and if the crowd walks or the third drop lands, **the overtime
multiplier is lost entirely** and they bank only the base target.

So: clear the target, then decide. Walk off now with a safe payout, or stay out
for the multiplier and risk the whole night. That is a push-your-luck loop, it
is the exact emotional shape of a real juggling act (the performer who keeps
adding one more club), and it is maybe forty lines of code on top of what is
already there.

### The Encore (the boss blind)

The third set of every booking is an Encore, and it draws a named condition from
a deck. These are cheap, because each one is a toggle on a constant that already
exists:

| Encore | What it does | Implementation |
|---|---|---|
| **The Hecklers** | Applause decays twice as fast | one multiplier |
| **Stage Fright** | The landing markers are hidden | skip `draw_targets()` |
| **The Draft** | Every throw drifts, inaccuracy doubled | scale `inacc_factor()` |
| **Blackout** | Props are invisible below the crest of the arc | a clip in `draw_prop()` |
| **Fire Only** | Balls and eggs score zero | a check in the score path |
| **The Purist's Night** | No stat mitigation at all | set `purist` for the set |
| **One Hand Tied** | The left hand cannot throw | ignore one input |
| **The Long Set** | Target doubled, applause decays half as fast | two multipliers |
| **Cold Hands** | The Perfect window shrinks by 2 ticks | `perfect_window()` |
| **The Understudy** | Any drop ends the set immediately | drop limit = 1 |

Note how many of these are *already* things you built and then filed under
"cosmetic" or "optional difficulty." The glow-in-the-dark cosmetic in the GDD is
Blackout. The Purist toggle is The Purist's Night. Hard Mode's mid-air
collisions are an Encore. **You have been designing boss blinds for months
without a slot to put them in.**

---

## Part 2. Flourishes (give the run a build)

The Booking makes each run tense. It does not yet make each run *different*.
That is what a build layer does, and JUGGLE has none. `purist` is the entire
build system today: one binary flag.

### The proposal

The player has **slots** (start with three, buy up to five). Between sets, a
small shop offers three **Flourishes** drawn from a deck, for gold. A Flourish
is a passive rule that modifies scoring or risk for as long as it is equipped.
They persist across bookings, so a career accumulates an identity.

The design rule that makes or breaks this, and the one Balatro gets right and
most imitators get wrong:

> **A Flourish must change what the player is trying to do in the next sixty
> seconds. It must not merely add a number to a total.**

"+10% score" is a bad Flourish. "Catches score double, but only while your
throws land on a steady rhythm" is a good one, because it makes the player
change how they physically play.

And one hard guardrail, straight from the GDD's own philosophy: **a Flourish may
change scoring, risk, and rules. It must never quietly raise the catch
probability.** The moment stats or items start catching balls for the player,
the skill-first promise is dead. Flourishes make you *braver*, not *better*.

### The starting deck

Concrete, with real numbers, all implementable against existing state.

**Rhythm and control**
- **Metronome.** If the interval between your last three catches is within 5
  ticks of each other, catches score x1.75. Rewards machine-like, even juggling
  and punishes panicky rescue-throws. Reads beautifully, feels amazing to hit.
- **The Long Arm.** Late catches (`W_LATE` band) score full value instead of
  reduced. Turns a sloppy style into a viable one.
- **Deadpan.** Score x2 while applause is above 90 percent. Rewards a player who
  can hold a room, not just survive it.

**Risk and greed**
- **Daredevil.** Throws above height 1.0 score x2.5, but dropping one costs two
  drops instead of one.
- **Butterfingers' Charm.** Every drop adds a permanent +0.5x to this set's
  multiplier. The inversion card: turns a disaster run into a comeback run, and
  makes a player who is bleeding out want to keep going.
- **The Understudy.** Your first drop each set is forgiven. The safety valve
  that lets a greedy build survive.
- **All In.** x4 score, but the set ends on the first drop. The build-defining
  gamble.

**Props and patterns**
- **Fire Eater.** Torches score x3. Balls and eggs score zero. Forces an entire
  economy around one prop and makes the 2000-gold torch purchase into a
  strategic pivot rather than a linear upgrade.
- **Egg Man.** Eggs are free and score x4, but a broken egg costs a drop. The
  ideas.rtf egg design finally has a reason to exist: it is the high-variance
  build.
- **Showman.** Every landed trick adds +0.2x to the set multiplier, permanently
  for that set. Rewards stacking flourishes early and riding them.
- **Weight Class.** Score scales with total weight in the air (`prop_weight() *
  num_balls`) rather than with streak. The build for people who like heavy,
  slow, five-club sets.

**Perception**
- **Blind Spot.** Props are invisible at the crest of the arc. x2 score. A pure
  skill tax that a very good player will happily take.
- **One-Handed.** x2.5 score if the left hand never throws. Genuinely changes
  the physical game.

### Why this is worth the work

Three slots from a deck of twenty gives roughly a thousand combinations before
you count which ones synergise. Fire Eater plus Weight Class is a heavy build.
All In plus Metronome is a precision build. Butterfingers' Charm plus Daredevil
is a chaos build. **Players will talk to each other about their builds**, which
is the single strongest predictor of a skill game finding an audience, and it is
the thing JUGGLE currently gives them nothing to say about.

---

## Part 3. Siteswap (give the game infinite content)

This is the differentiator. The one that would make the game *notable* rather
than merely good.

### The situation

Content today is five hardcoded patterns (`PATTERNS`) and eight hardcoded tricks
(`TRICKS`). Every new pattern is a bespoke branch inside `do_throw()`, plus
bespoke hand-slot logic in `throw_slot()` / `catch_slot()`, plus bespoke landing
geometry. This is exactly why ROADMAP item 12 exists: Half Shower and Shower
collide with the weave because each pattern hand-rolls its own geometry and they
were never proven consistent with each other. **The content system does not
scale, and it is already generating bugs.**

### What siteswap is

Siteswap is the real notation juggling actually uses. Each digit says how many
beats will pass before that object is thrown again. `3` is the three-ball
cascade. `5` is the five-ball cascade. `441`, `531`, `423`, `633`, `97531`,
`50505` are all real, named, learnable patterns. The average of the digits is
the number of objects, which is a genuine theorem, and a string is valid if and
only if no two objects ever want to land on the same beat, which is a fifteen
line check.

Odd digits cross to the other hand. Even digits stay in the same hand. A `0` is
an empty hand. A `2` is a hold. That is the entire system.

### Why it fits this codebase almost eerily well

A siteswap is precisely a function from `(beat, hand)` to `(throw height,
destination hand)`. Which is *exactly* the two things `do_throw()` already
computes and the only two things it needs. The engine is already tick-based,
already gives every ball a `land_tick` and a `to_hand`, and already expresses
throw height as a continuous `0..1.4` float that maps naturally onto the digit:

```
siteswap_height(n) =  (n - 2) / 3.0    clamped to the 0..1.4 range
    so 3 -> 0.33 (a standard cascade throw)
       4 -> 0.67
       5 -> 1.0  (the five-ball height, already the game's "held" throw)
       7 -> 1.4  (the ceiling, already what a maxed hold produces)
       1 -> a fast flat pass across
       2 -> a hold, no throw at all
```

The height model you already tuned by feel turns out to be, near enough, the
siteswap height model. That is not a coincidence, it is because you tuned it
against real juggling.

### What it buys you

**Patterns stop being code and become data.** A routine is a string plus a name.
Adding `441` is adding a row to a table, not a branch in `do_throw()`.

**Difficulty becomes derivable rather than hand-tuned.** `pattern_mult()` is
currently five hand-picked numbers (1.0, 1.1, 1.15, 1.25, 1.4) that you will
have to keep re-guessing forever. With siteswap, difficulty falls out of the
notation itself:

```
difficulty = objects + 0.4 * (max_digit - 3) + 0.3 * distinct_digits
```

A three-ball cascade scores what it deserves, `97531` scores what it deserves,
and you never have to hand-balance a pattern again.

**The geometry unifies, which fixes ROADMAP 12 at the root.** Every throw in
every pattern becomes the same function of two numbers. The Half Shower and
Shower collisions exist because those two patterns have bespoke geometry nobody
proved consistent with the weave. One geometry, derived from the digit, cannot
collide with itself in the way three hand-written special cases can. **This is
not a detour around item 12, it is the durable version of the fix.**

**Patterns become collectible.** `441` bought in the shop. `531` awarded for
clearing the Circus. `97531` as the thing you flex at the World Arena. The
Skills screen you already built becomes a real collection to fill in.

**And a player who gets good at JUGGLE learns real siteswap.** They can walk
into a juggling club and say "let's run a 744." That is a genuine skill transfer
out of a video game and into the world, and it is the kind of thing that gets a
game recommended in places advertising cannot reach. It is the honest answer to
"why is this the juggling game."

### The risk, stated plainly

This is the largest change in this document and it touches the most fragile part
of the codebase (hand choreography, which is currently mid-regression). It
should not be started until ROADMAP 12a and 12b are fixed and the fix is
verified, because you need a working, trusted geometry baseline before you
generalise it. But the fix for 12 should be written with this generalisation in
mind, rather than as another special case bolted onto two patterns.

---

## Part 4. The meta layer (give players a reason to come back)

Cheaper than the above, and each is worth doing.

**The Daily Booking.** One fixed seed per day: the same venue, the same three
Encore conditions, the same Flourish offers, the same prop prices, for every
player in the world. One attempt. This is the missing item ROADMAP 2 correctly
identified, and it is what turns the per-venue records from a personal best you
set once into a live, dated, competitive goal. It is the single cheapest thing
in this document that materially increases retention.

**Ghosts.** The simulation is tick-based and deterministic given inputs. That
means a run is fully described by a list of `(tick, action)` pairs, which is a
couple of bytes each, which is a few kilobytes for a whole set. So: record them.
Then draw the world record holder's run as a translucent second juggler beside
you, catching and throwing in real time while you do. Racing a ghost is one of
the most reliably motivating mechanics ever invented, and this engine gets it
almost for free. It also makes a spectacular trailer shot.

**Leaderboards on the Purist boards.** Already planned in tasks.md and blocked
only on the Steam App ID. `best_scores_purist` is already the clean, stat-free
board. This is the right thing to publish.

**Passing (two players).** Juggling's real social form is two people passing
clubs. Local co-op on one keyboard is nearly free given the input split (D/F is
already one juggler, J/K is already the other): put two figures on stage, six
clubs between them, every fourth throw crosses to the partner. A shared score, a
shared drop counter, a shared disaster. This is the feature most likely to get
the game streamed, and streamed is how skill games get sold.

---

## Part 5. What I would actually do, in order

1. **Fix ROADMAP 12** (the collision regression, the Columns jitter). Nothing
   below is worth building on top of a broken geometry, and the fix should be
   written to generalise rather than to special-case.
2. **Replace the Suno placeholder track.** It is a licensing blocker on shipping
   anything to anyone, and it is a single file swap once the paid render exists.
3. **Build the Booking** (Part 1): the target, the three-drop limit, applause as
   the clock, bank-or-push, and about six Encore conditions. This is the change
   that turns the toy into a game, and most of its parts are already in the
   codebase doing nothing.
4. **Build Flourishes** (Part 2), starting with a deck of about twelve. This is
   the change that makes run 40 different from run 39.
5. **Ship the Daily Booking and ghosts** (Part 4). Cheap, and they are what make
   people open the game on a Tuesday.
6. **Then siteswap** (Part 3), as the long project that gives the game a
   permanent identity and an unbounded content pipeline.

Parts 1 and 2 together are, I would estimate, the difference between a game that
reviews as "a lovely little juggling toy" and one that reviews as "I have put 60
hours into this." They are also, between them, probably three or four focused
sessions, because the machinery is nearly all sitting there already, unused.
