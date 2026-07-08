# JUGGLE: Game Design Document

Version 0.2. Living document. Supersedes the strawman in the planning file for every area it
covers. Written after playtest 1 of the core-input spike, which validated the fundamental loop
("great so far, going to be really addictive") and produced the direction below.

Author note on scope: v0.2 introduces two big things. It refines the core juggling mechanic into a
catch-and-throw model, and it adds a juggler life-and-career meta layer (stats, stamina, money,
reputation, eat and sleep). The meta layer meaningfully expands the project. We still prove the
core loop first (see Section 9, Sequencing) before building the meta.

Companion documents: STORY.md works out the light story and the ten-venue climb
in detail, and ART_AND_MUSIC.md sets the visual and audio direction. Both defer
to this GDD for mechanics.

---

## 1. Locked vision recap

- Genre: highly skill-based arcade juggling, now wrapped in a light juggler life-and-career sim.
- Player mastery is the primary progression. Stats are supportive, never decisive (Section 4.1).
- Engine Godot 4.7, 2D, warm-theatrical aesthetic, a named performer with a light story, a
  polished 1.0. All art and audio produced in code (procedural, shader, generated).
- The career climbs a venue ladder from backyard to the world-record stage.

---

## 2. Core juggling mechanics (revised in v0.2)

### 2.1 Input model: catch and throw, one of each per hand

Real juggling is a catch and a throw, not a single tap. v0.2 splits them. Each hand has two
timed inputs.

- Left hand: CATCH and THROW. Right hand: CATCH and THROW. Plus one TRICK input (Section 3).
- Proposed keyboard: left catch `D`, left throw `F`, right catch `K`, right throw `J`, trick
  `Space`. Proposed controller: left catch `L1`, left throw `L2`, right catch `R1`, right throw
  `R2`, trick a face button. All remappable. A simplified two-button accessibility mode fuses
  catch and throw per hand and auto-picks height (Section 7 of the planning file).
- Both inputs must be good. A bad catch loses the ball. A bad throw is only punished under
  traffic (2.3).

### 2.2 Catch rules (strict, no more spamming)

Playtest 1 showed you could mash and survive. Catches are now strict and meaningful.

- A ball becomes catchable only in a window around its actual arrival at the hand. Press CATCH
  inside the window to secure it, with quality Perfect, Good, or Late.
- A mistimed catch (too early or too late) fails to secure the ball, and the ball drops. You lose
  it. This is the core strictness.
- Pressing CATCH with no ball arriving is a whiff: nothing is caught, and a small poise wobble
  discourages mashing. You cannot spam your way to safety.
- How long you hold the CATCH input does not matter. Catching is pure timing.

### 2.3 Throw rules (height by hold, punished only under traffic)

- After a catch the hand holds the ball. Press THROW to release it.
- Hold THROW longer to throw higher. A higher throw has more airtime (buys you time on that hand)
  but is more inaccurate: its landing point drifts and its arc wobbles, so the next catch is
  harder. This is a deliberate risk and reward. The Accuracy stat reduces the drift (Section 4.3).
- A late throw is only a problem when another ball is incoming to that same hand. If traffic is
  coming, you must throw (free the hand) before it arrives, or you fail the next catch and lose a
  ball. If nothing is incoming to that hand, you may hold as long as you like with no penalty.
  Pressure emerges from pattern density, not from an arbitrary timer.

This single rule is why more balls is harder in a juggling way rather than a twitch way: more
balls means tighter incoming traffic on each hand, which shrinks your throw windows, on top of
more catches to time. Throwing higher briefly thins the traffic (the classic reset), at the cost
of a harder, inaccurate catch later.

### 2.4 No-crossing hand choreography

Balls must never collide. We reproduce how real jugglers avoid it, exactly as you described.

- A hand catches on its OUTER side, carries the ball INWARD, and throws from its INNER position.
- Throws leave from inside and travel up the middle to the opposite hand's OUTER catch point.
- Because rising balls launch from the inside and falling balls descend to the outside, an
  outgoing and an incoming ball never share the same lateral space. No collisions.
- The hand visibly moves outer to inner between catch and throw, then back out to receive the
  next ball. This movement is both the anti-collision mechanism and the thing that makes the
  hands look like they are juggling.
- Fountain (even counts): each hand keeps its own column and there is no crossing at all, so
  balls rise and fall in two lanes slightly to the outside.

### 2.5 Start: the player throws the first ball

No more starting mid-air. Balls begin held. For a 3-ball cascade the standard start is two balls
in one hand and one in the other. The run begins when the player makes the first THROW. Tempo is
set by the player from the first throw onward, which is more authentic and gives agency.

### 2.6 POISE, recovery, and failure

- POISE (the stability meter) rises on clean catches and good throws, falls on late or sloppy
  ones, and drops hard on a lost ball.
- A lost ball (bad catch, or throw-under-traffic failure) removes that ball. A run continues until
  you drop below a threshold, lose too many balls, or choose to take a bow. In performances a drop
  costs score and reputation but the set continues.
- Recovery: a deliberate maximum-height reset throw buys time to regroup, but because high throws
  are inaccurate, the reset is itself a risk you must then catch cleanly. Accuracy makes resets
  safer, which is a meaningful reason to train it.

### 2.7 Patterns and props

- Patterns: cascade (odd counts, crossing) and fountain (even counts, columns). Each count feels
  distinct through traffic density and throw height, not raw speed.
- Props unlock through stats (Section 4.6): balls from the start, then rings, clubs, knives and
  torches. Clubs add rotation timing, rings add orientation, knives and torches add real spectacle
  and risk. Which of these we fully simulate versus flavor is a Section 7 balance decision.

---

## 3. Tricks: zero to four equippable slots

Tricks are now an equip-and-activate system, which fits the loadout philosophy you liked.

- You have 0 to 4 trick slots. You start with 0 (basic juggling only) and earn slots through
  progression (level and reputation milestones).
- Tricks are equipped in a loadout screen when NOT juggling.
- During juggling, the TRICK input performs an equipped trick on your next throw. Selecting which
  of up to four: hold TRICK and choose with a direction (up, down, left, right map to slots 1 to
  4), or on keyboard tap `1` to `4` while TRICK is held. The chosen throw becomes that trick.
- Each trick modifies the throw and carries its own risk and reward. Examples: Columns (straight
  up, parallel rhythm), Reverse Cascade (over the top, inverted feel), Under-the-leg and
  Behind-the-back (single-throw flourishes, extra airtime, big style, high inaccuracy), Mills Mess
  (a short learned multi-throw sequence).
- Trick success depends on Accuracy plus timing. A failed trick destabilizes POISE rather than
  instantly dropping, unless catastrophic. Successful tricks grant style score and bonus XP, and
  raise the performance multiplier.
- Some tricks require a minimum stat (Accuracy or Strength) to attempt reliably, which is how the
  meta feeds expression without gating raw skill.
- Tricks vary in ROLE, in the spirit of Hollow Knight charms. Some are pure style and challenge
  with a modest payout. Others are revenue tricks: crowd-pleasers that multiply money and
  reputation, and those are the ones you covet. With only 0 to 4 slots, choosing your loadout is a
  real trade-off between safety, style, and earnings.
- There is an aspirational full build of high-value tricks that maximizes income, and you will want
  it, but you can perform a solid living without it. Base juggling always pays. The optimal build
  is an efficiency play, not a requirement, which keeps the game welcoming while giving optimizers
  something to chase.
- Like a new pattern, a hard trick is a wall when first learned and is tamed by leveling the
  relevant stat (mainly Accuracy) and repeating it, after which it stays only a bit harder than an
  easy trick but keeps paying more (see 4.8).

---

## 4. Progression and the stats meta layer (new in v0.2)

### 4.1 Design guardrails (read first)

These rules keep the life-sim from eroding the skill-first pillar. They are hard constraints on
every number below.

1. Two axes, and skill owns the one that ranks you. Stats govern ACCESS and COMFORT: they lower
   the effective difficulty of hard content so you can reach and sustain it, which is the career
   axis. Skill governs EXCELLENCE: score, style, records, and the high-numbers ceiling, which is
   the mastery axis. Stats never auto-play and never touch the raw catch-and-throw timing floor. A
   grinder can reach 5 balls comfortably, but a skilled player out-scores them at every count,
   reaches the true endgame (15-ball flashes) that stats alone cannot carry, and wins the Purist
   boards where stat mitigation is stripped away. Stats buy you a living, skill makes you great.
2. Stats are earned by skilled play. XP comes from juggling well for long stretches, not from
   idling or repeating a trivial action. No pay-for-power, ever.
3. The eat, sleep, money loop is light texture and stakes, not a punishing chore. It sets a
   day rhythm and gives performances meaning. It is forgiving, especially early.
4. Everything is introduced gradually. You begin with no tricks and almost no visible meta, and
   the systems unlock over the first hours so onboarding stays gentle.

### 4.2 Experience and level

- XP is earned from performances and practice, weighted by clean-catch rate, POISE held high,
  performance length, difficulty (ball count and prop), and successful tricks. Sloppy or short
  runs earn little.
- XP raises a character Level. Each level grants stat points to invest and, at milestones, a new
  trick slot, a new prop unlock, or access to a higher venue tier.
- Level curve escalates so early levels come fast (dopamine and teaching) and later levels are a
  long, respectable climb, matching the "respect each milestone" goal.

### 4.3 The stats and what they do

Values on a 1 to 100 scale. Effects are capped so timing always matters.

- Accuracy. Reduces the drift and wobble of high throws and widens trick success windows. This is
  the stat that most directly helps the skill core, so its cap is strict: even at 100, a
  max-height throw still demands a good catch. Accuracy is the master stat for precision play and
  tricks.
- Strength. Unlocks and eases clubs, and adds a little height precision (a strong juggler controls
  big throws), complementing Accuracy. Strength is fueled by eating (Section 4.5) plus training.
- Endurance. Unlocks demanding props (clubs, knives, torches) and raises maximum Stamina. Grown
  through XP and training.
- Stamina. A within-day resource. It drains as you perform and practice. When Stamina is low your
  Accuracy drops (throws get wild), which is the game telling you to rest. Maximum Stamina scales
  with Endurance (proposal: max = 50 + Endurance, so 51 to 150). Sleep resets it.

### 4.4 The economy: money and reputation

- Reputation. Higher reputation means more money per performance and unlocks better venues. Earned
  by good performances (score, difficulty, crowd reaction). This is the career-climb currency.
- Money. Earned from performances, scaled by Reputation and performance quality. Spent on food
  (eat, raises Strength), lodging (sleep, resets Stamina), props and gear, and travel between
  venues. Debt is allowed: you can go negative, which creates stakes. To prevent a death spiral,
  street busking is always available as a small guaranteed income floor, so debt is tension, not
  a dead end.

### 4.5 Life actions and the day loop

Between performances the player lives a juggler's life through a small set of actions, each of
which spends time (advancing a soft day clock) and some spend Stamina or Money.

- Perform (at an available venue): the core juggling game. Earns Money, Reputation, XP. Spends
  Stamina.
- Practice: a lower-stakes juggling session. Earns XP and hones consistency. Spends Stamina, earns
  little or no Money.
- Eat: spends Money, raises Strength a little and stops Strength decay. Light survival texture.
- Sleep: ends the day, resets Stamina to full, spends lodging Money. Sleeping rough is cheaper but
  restores less.
- Travel: move to a new town or venue tier, spends Money and time.
- Shop: buy props and gear as they unlock.

The loop: perform for Money, Reputation, and XP, then invest XP into stats, spend Money on food
and rest to keep Stamina and Strength healthy, unlock heavier props and better venues, and climb
toward the world stage. The day rhythm gives pacing and makes each performance a considered choice
rather than an infinite grind.

### 4.6 Props gated by stats

- Balls: from the start.
- Rings: require a minimum Accuracy.
- Clubs: require Strength (and some Endurance).
- Knives and Torches: require Endurance and a safety floor of Accuracy. Highest risk, highest
  spectacle and reward.

Gating by stat means the meta unlocks new skill challenges (the real reward), consistent with the
skill-first pillar, rather than just bigger numbers.

### 4.7 First-pass balance framework (provisional, tune with telemetry)

Illustrative starting values, to be corrected by playtest data. Not final.

- Stamina drain: a full performance costs roughly 15 to 30 Stamina by length and prop. Practice
  costs about 10. Low-Stamina Accuracy penalty ramps in below 25 percent, up to a 50 percent
  Accuracy reduction at empty.
- Money: street busking earns about 5 to 20 scaled by Reputation. A theatre set earns about 50 to
  200. Food about 10, cheap lodging about 15, good lodging about 40.
- XP: a clean performance grants roughly 50 to 250 by difficulty and quality. Early levels need a
  few good performances, later levels many.
- Stat effect caps: high-throw drift at Accuracy 1 is large enough to punish careless height, at
  Accuracy 100 is small but nonzero. Trick windows widen by at most a bounded amount with Accuracy
  so timing is never trivialized.

These numbers exist so we can start tuning, not because they are right. Section 7 owns balancing.

### 4.8 The taming curve: difficulty, stats, mastery, and reward

The heart of how progression feels, in your words: a new pattern is hard at first, and once you
level it up it is only a bit harder than an easier maxed pattern, but it pays more.

Two mitigation sources pull difficulty down.
- Global stats (Accuracy, Strength, Endurance, Stamina) apply across all play.
- Per-pattern mastery: every count and prop has its own mastery level, earned by practicing and
  performing that specific pattern. A freshly unlocked pattern starts at mastery zero.

Effective difficulty of a pattern = its Base difficulty, minus global stat mitigation, minus that
pattern's mastery mitigation. Base difficulty rises steeply with count and prop (3 below 4 below 5
below clubs below a 15-ball flash), which is the "respect each milestone" curve. Effective
difficulty then compresses as you invest.
- Freshly unlocked: low mastery against a high base, so effective difficulty is a hard wall. This
  is the exciting spike you feel every time you reach new content.
- After leveling: mastery and stats pull it down, so the wall becomes a slope. This is the feeling
  of becoming a genuinely better juggler.
- Fully maxed: a hard pattern lands only a bit above an easier maxed pattern in effective
  difficulty. The residual gap is real but small.

Reward runs on Base difficulty, not effective difficulty. Money and reputation from a pattern scale
with how intrinsically hard it is, so a tamed 5-ball routine still pays far more than a tamed
3-ball one. That is the efficiency incentive: once you can handle it comfortably, harder content is
simply more lucrative, which is why an ambitious player climbs.

Why this does not flatten the game into boredom at the top.
- The residual per-step difficulty still compounds toward the high-numbers super-endgame (a
  15-ball flash is genuinely hard even fully maxed).
- Score and style still separate a Perfect run from a merely surviving one, so the mastery axis
  never caps.
- Purist boards strip stat and mastery mitigation, giving a pure-skill ladder for those who want
  it.

So stats and mastery tame the survival wall while the excellence ceiling stays open forever.

---

## 5. Characters and visuals (new and expanded)

### 5.1 Hands that look like hands

Replace the placeholder circles with stylized 2D hands. Each hand opens to receive, closes around
the caught ball, carries it inward, and extends to throw, then reaches back out for the next catch.
Even simple vector hands (palm plus a few fingers) animated by procedural transforms will read
clearly and will make the no-crossing choreography visible. Approach: procedural or lightly rigged
2D, no hand-drawn frames, so it fits the code-only production model and scales across props and
counts.

### 5.2 The juggler on screen

A stylized 2D performer stands behind and around the hands: the named character from the light
story. The figure is a 2D skeletal rig (Godot Skeleton2D with polygons or cutout parts) driven
procedurally by the juggling state. Arms follow the throws, the body sways with tempo, flourishes
on streaks, winces on drops, and animates for under-the-leg and behind-the-back tricks. Because
the rig is procedurally driven, we do not hand-animate every trick by every prop by every count,
which keeps the animation budget sane (this is the R6 mitigation from the planning file). Warm
theatrical lighting, spotlight, and crowd complete the stage and escalate with venue prestige.

---

## 6. Interfaces (wireframes)

Clear, controller-first, Steam-Deck-legible. Sketches below are layout intent, not final art.

### 6.1 In-performance HUD

```
+----------------------------------------------------------------------+
|  SCORE 12,480        [======= POISE =======----]        STREAK x18    |
|  venue: STREET CORNER        prop: 3 BALLS      [== STAMINA ===-----]  |
|                                                                        |
|                          (  the juggler  )                            |
|                       o                     o    <- balls in flight    |
|                        \                   /                          |
|                     [L hand]           [R hand]                        |
|                                                                        |
|  TRICKS:  [1 Columns] [2 Rev.Cascade] [3 Under-leg] [4 --- ]           |
|  hold TRICK + 1..4 to arm            money: 128 gold    day: morning    |
+----------------------------------------------------------------------+
```

### 6.2 Character sheet

```
+-------------------------- JUGGLER --------------------------+
|  Name        Level 7    XP [==========------] 6,200 / 9,000 |
|                                                             |
|  ACCURACY    [===============-----]  62   precision, tricks |
|  STRENGTH    [=========----------]   41   clubs, big throws |
|  ENDURANCE   [============--------]   50   heavy props, stam|
|  STAMINA     max 100 (from Endurance)   now [====----] 44   |
|                                                             |
|  Unlocked props: balls, rings, clubs                        |
|  Next unlock: knives at Endurance 60                        |
|  [Invest 3 stat points]                                     |
+-------------------------------------------------------------+
```

### 6.3 Trick loadout (equip when not juggling)

```
+------------------------ TRICK LOADOUT (3 / 4 slots) -----------------+
|  EQUIPPED                        LIBRARY                              |
|  1 [ Columns        ]            ( ) Shower        req Acc 45         |
|  2 [ Reverse Cascade ]           ( ) Half Shower   req Acc 55         |
|  3 [ Under-the-leg  ]            (x) Mills Mess     req Acc 70 (locked)|
|  4 [ empty          ]            ( ) Behind-back    req Acc 50         |
|                                                                      |
|  Selected: Under-the-leg   style +++   risk high   XP bonus +20%     |
|  effect: single high flourish throw, inaccurate, big crowd reaction  |
+----------------------------------------------------------------------+
```

### 6.4 Life and day management

```
+-------------------------- A DAY IN THE LIFE -------------------------+
|  Money 128 g     Reputation 340 (Rising Talent)     Day 14, morning  |
|  Stamina [====------] 44 / 100                                        |
|                                                                      |
|  > PERFORM   Street Corner   earn ~15-40 g, XP, rep     -20 stamina  |
|    PERFORM   Small Theatre   req Rep 300   ~80-200 g    -28 stamina  |
|    PRACTICE  hone consistency, XP only                  -10 stamina  |
|    EAT       +Strength, stops decay          -10 g                    |
|    SLEEP     reset stamina, end day       inn -15 g / rough -3 g     |
|    TRAVEL    next town / venue tier          -time, -g               |
|    SHOP      props and gear                                           |
+----------------------------------------------------------------------+
```

### 6.5 Performance results

```
+----------------------- PERFORMANCE COMPLETE ------------------------+
|  Small Theatre                                                       |
|  Score 24,900     Best streak 62     Clean catches 91%              |
|  Tricks landed: Columns x4, Under-the-leg x2                         |
|  ---------------------------------------------------------------    |
|  XP earned      +180        Reputation   +25  -> "Rising Talent"     |
|  Money earned   +140 g      Stamina used  -28                       |
|  Unlocked: Trick slot 4                                             |
|  [Continue]                                                         |
+---------------------------------------------------------------------+
```

---

## 7. Balancing plan and risks

- Skill-first integrity (top risk). Stat effects must pass the guardrail test in 4.1. Mitigation:
  cap every stat effect, source all stat growth from skilled play, and A-or-B test that a skilled
  low-stat run beats a sloppy high-stat run. If it ever fails, cut the offending effect.
- Chore risk. Eat, sleep, and money can feel tedious. Mitigation: keep them light, forgiving, and
  rhythmic, with sensible one-tap defaults and no harsh early fail states. The survival layer
  should add flavor and pacing, not spreadsheet management.
- Economy spiral. Debt could trap a struggling player. Mitigation: street busking income floor,
  cheap sleep-rough option, and gentle early costs.
- Complexity and onboarding. Many systems at once could overwhelm. Mitigation: unlock the meta
  gradually, start at 0 tricks with minimal visible stats, teach one system at a time.
- Balancing needs data. Provisional numbers in 4.7 must be tuned with the dev telemetry from the
  planning file (drop points, quit points, income and stamina curves). We balance with evidence,
  not guesses.
- Scope growth. The meta roughly doubles the game's system count. We sequence it (Section 9) so
  the core is proven before the meta is built.
- Economy inflation. If money scales with base difficulty, players may farm the hardest tamed
  pattern endlessly. Mitigation: crowd-boredom and diminishing returns for repeating the same
  routine, reputation and venue gating that reward variety, and cost scaling so higher living
  standards absorb higher income. Net income should rise with ambition without runaway.
- Endgame sameness. If stats flatten difficulty, the top could feel flat. Mitigation: the residual
  per-step gap, the high-numbers super-endgame, and the score and Purist ceilings from 4.8.
- Grind-to-tame. Taming a wall must require skilled play, not idle grinding, because XP and mastery
  come only from juggling well. A player cannot buy their way past a wall without getting better at
  it, which preserves the skill-first spirit.

---

## 8. Open questions for Louis (not blocking, answer anytime)

- Time model: are days discrete action menus (as sketched) or a softer free clock?
- Debt consequences: at deep debt, is it just busking your way back, or is there a soft fail or
  story beat?
- Survival intensity: is the eat and sleep loop light texture (recommended) or a more central
  management challenge?
- Career persistence: one continuous career save, or the option to start fresh runs (roguelike
  career) for replay?
- Trick activation: is hold-TRICK-plus-direction the scheme you want, or a simpler one trick at a
  time?

---

## 9. Sequencing: what we build next

We keep proving before expanding.

- Prototype 1.1 (core mechanic revision, next up). Rebuild the spike with: catch and throw split
  (four inputs), strict catches that lose the ball on bad timing, the throw-under-traffic rule,
  height by hold with inaccuracy, the no-crossing inward-hand choreography, and the
  throw-to-start. Add stylized hands and a first simple juggler figure. Re-test the feel. No meta
  yet. This answers whether the deeper input model is still fun and readable.
- Prototype 2 (tricks and first stat). Equip-and-activate tricks, and the Accuracy stat affecting
  high-throw inaccuracy and trick windows, to test that the meta supports rather than replaces
  skill.
- Prototype 3 (life loop, small). One town, perform and practice and eat and sleep and a money and
  reputation loop, to test that the survival texture is pleasant and not a chore.
- Then full meta build-out, the venue ladder, and the interfaces in Section 6.

The Phase 1 go or no-go gate still stands: if any prototype says the loop is not fun or the meta
dilutes the skill, we fix that before building further.
