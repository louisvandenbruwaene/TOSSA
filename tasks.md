# TOSSA tasks

Louis's brief of 2026-07-29, written down in full before any code moves. Every item
below is his request, in his words where the wording matters, with the current state of
the code noted so nothing has to be rediscovered. Items marked **ASK** need his answer
before implementation. Items marked **SUGGEST ONLY** are explicitly not to be built yet.

Status key: `[ ]` not started, `[~]` in progress, `[x]` done, `[?]` blocked on an answer.

---

## 1. The logo

- [ ] **The mark reads as props, not as the word TOSSA.** Louis: "it seems a bit
  disconnected, and it might be hard for people to see the word tossa, especially with
  the torches not coming together to form the top of the A."
- Current state: `capsule_mark` (Game.gd ~17321) draws the whole name in props and no
  lettering at all. T is two knives, O is a ring, each S is fourteen balls on two arcs,
  A is two torches leaning together "with nothing across them", and the gap between them
  at the top is meant to be the apex. `draw_wordmark` is a thin wrapper over the same
  function, so the title screen, the key art, the credits and the five store capsules all
  share one mark and a fix lands everywhere at once.
- Named faults to solve: the A has no apex and no crossbar, so it reads as two torches,
  the letters do not sit on a shared optical baseline, and the two S's are the noisiest
  and least legible glyphs in the set.
- **ASK** which of the proposed fixes to take (see the decision list at the foot of this
  file).

---

## 2. Landing drift and arrival jitter

- [ ] **Explain both to Louis in plain words, then cut what is not earning its place.**
  He believes they are "excessive and unneeded".
- Current state, both set in `do_throw` (Game.gd ~7194):
  - `JITTER_MAX` 5 ticks. A random shift of the moment the prop arrives, up to about
    42 ms either way. This is the one that changes the timing the player has to hit.
  - `DRIFT_MAX` 26 px. A random sideways shift of the landing point. Purely cosmetic on
    the catch, because the catch is resolved on the TIMING of the key press, not on where
    the hand is. It survives only as a look: the prop lands off the palm's centre line.
  - Both scale with the throw's height and with inaccuracy, so a tap is placed cleanly
    and a full-height throw is the wild one.
- Decision to take: cut drift entirely (it is decoration that makes the picture look
  sloppy for no gameplay), and cut or shrink jitter.

---

## 3. Strength

- [ ] **Strength no longer touches the catch at all.** Remove `strength_catch_mod` from
  `catch_chance`. Strength's only job is unlocking what you can throw.
- [ ] **New requirement rule.** Per prop, the Strength cost of ONE object:

  | prop | balls | eggs | rings | clubs | knives | torches | chainsaws |
  |------|-------|------|-------|-------|--------|---------|-----------|
  | cost | 1     | 1    | 3     | 4     | 6      | 8       | 13        |

  To throw `n` of a prop you need `n x cost`. So 15 chainsaws needs 195 Strength, 7
  torches needs 56, 5 clubs needs 20, 3 balls needs 3.
- [ ] The same wall applies to **starting a pattern that requires n props, and to making
  any throw under it**. Not just to the act's opening.
- [ ] This replaces `BALL_GATES` (the flat 4:16, 5:33 ... 15:200 table) and the `req`
  field in `PROPS`, both of which go.
- [ ] **The final 5 points of Strength give one extra Perfect frame** (196 to 200, so the
  top of the track is not dead once every count is open).
- [ ] **Adding a Perfect frame shifts the Good, Late and whiff frames by the same one, and
  removing one shifts them back.** The bands keep their widths, the whole ladder moves.
  Currently `W_PERFECT` 7, `W_GOOD` 10, `W_LATE` 28, and only the Perfect band moves,
  which eats the Good band. That is wrong and is being fixed everywhere a frame is added
  or removed (Focus, clubs, chainsaw, Cold Hands, the Strength capstone).

---

## 4. Accuracy

- [ ] **1 to 100: catch odds**, as now, minus the Strength term (see item 3).
- [ ] **101 to 150 is Focus.** Cuts stamina cost linearly from full to a quarter, with a
  floor of 1 stamina per throw. Currently that ramp runs 100 to 200, so it is compressed
  into half the space.
- [ ] **151 to 200 gives one Perfect frame per 10 points, five in total.**
- [ ] **Accuracy caps at 200.** `ACC_CAP` comes down from 250.
- [ ] Frames granted here obey the band-shifting rule in item 3.

---

## 5. Levels

- [ ] **Levels arrive twice as fast, and everything is unlocked at about level 100, which
  is today's level 50.** Target: 10 to 20 hours of play to that point.
- Current state: `xp_to_next(lv) = 60 * lv^1.4 + 40 * lv`, and a level pays
  `POINTS_PER_LEVEL + level / 12` stat points. Reaching every stat wall costs about 250
  points, which lands near level 50 today, at roughly 350k XP.
- Plan: halve the XP per level and halve the points per level, so the same work buys the
  same build and only the level NUMBER doubles. Level-ups land twice as often, which is
  better feel at no balance cost.

---

## 6. Height penalty and the catch odds

- [ ] **Answer Louis's question: is the penalty zero at tap height?** Yes at 3 and 4
  objects, and no beyond that. `count_air_scale` lifts the tap floor from 5 objects up, so
  a tap already reads as height 0.60 at 7 objects and past 1.4 at 12 or more. At the top
  counts every throw, tap or hold, is already taking the maximum height penalty.
- [ ] **Extend the penalty to 1.8**, which a held High Toss really reaches, instead of
  clamping at 1.4. Add roughly 0.5 total penalty at the top.
- [ ] **Retune the base odds so that, with no glasses and no gloves, at Accuracy 100 and
  no height penalty, a Good catch is 90% and a Late catch is 70%.** Today the same case
  gives 80% and 60%, so `GOOD_BASE` and `LATE_BASE` each rise by 0.10.
- Note for Louis: because of the tap-floor finding above, the 90/70 promise is only true
  at low counts. At high counts the height penalty is always on. Flagged as a separate
  decision at the foot of this file.

---

## 7. Speed

- [ ] **Speed gives 20% slow motion at most, 10 points per 1%.** Today it is 8 points per
  1%, so 25% at the cap.
- [ ] **Every other slow source gives 10%, not 15%**: Uncle Dan's Pie, the Amazing! burst,
  the fifty-Perfect burst.
- [ ] Total stays capped at **50%**, the hard ceiling, which the four sources now sum to
  exactly.

---

## 8. The score system, replaced entirely

- [ ] **The score is the sum of segments.** A segment is a stretch of consecutive catches
  with no drop. Good and Late catches do NOT end a segment. Only a drop does, and only a
  challenge that explicitly says so may also end one.
- [ ] **One segment is worth**

  ```
  s * PRODUCT over tricks i of (ti ^ mi) * x ^ (n * p)
  ```

  where
  - `x` is the weighted catch count in the segment: a Perfect counts 3, a Good 2, a Late 1
  - `n` is the number of objects
  - `p` is the prop's signature value
  - `s` is the pattern multiplier
  - `ti` is trick i's multiplier and `mi` is how many times it landed in this segment

- [ ] **Prop signature `p`:**

  | balls | eggs | rings | clubs | knives | torches | chainsaws |
  |-------|------|-------|-------|--------|---------|-----------|
  | 1     | 1.2  | 1.4   | 1.6   | 2      | 3       | 5         |

- [ ] **Pattern multiplier `s`:** Cascade 1, Columns 1.2, Half Shower 2, Reverse Cascade
  1.5, Tennis 1.5. (Shower is not in Louis's list and needs a value, see the decisions.)
- [ ] **Trick multipliers `ti`:** Spin 2, High Toss 1.1, Behind the Back 1.2.
- [ ] **There is no Perfect-catch streak any more.** The whole idea of a Perfect chain is
  gone, replaced by Perfect simply being worth three of the weighted catches.

### What comes out with it

- [ ] `chain_mult()` and the whole chain, `CHAIN_GAIN`, `CHAIN_HALF`, the on-screen chain
  readout.
- [ ] `CATCH_PTS` / `CATCH_PTS_GOOD` per-catch points, `object_mult`, `OBJ_BALL_BONUS`,
  `prop_score_mult`, the `smult` field in `PROPS`.
- [ ] `DARK_PROP_BONUS` (torches score more in the dark) and `PICKY_PROP_BONUS` (knives
  score more before a hard crowd). Both are score multipliers and neither fits the new
  scheme. Torches keep glowing and knives keep buying patience, as flat prop character.
- [ ] `trick_difficulty`'s context scaling (weight, count and pattern inflating a trick's
  base) and `apply_trick_mult`'s running `run_mult`, replaced by the per-segment product.
- [ ] The fifty-Perfect slow-motion burst is keyed on `perfect_chain`, which no longer
  exists as a concept. It needs a new trigger or it goes.

### Still to design

- [ ] **SUGGEST ONLY, do not implement: how to stop trick spamming early.** Louis wants a
  proposal, not code. Candidates are in the decisions section.

---

## 9. Prop character, rewritten

- [ ] **Clubs:** one extra Perfect frame. Nothing else.
- [ ] **Knives:** the crowd is more patient. Nothing else.
- [ ] **Torches:** more patience, and they glow in the dark. No multiplier.
- [ ] **Chainsaw:** one fewer Perfect frame.
- [ ] **Balls, eggs, rings:** no special lever beyond their `p` value and their stamina
  cost. Eggs keep shattering on a drop.
- [ ] The `fgive` field (clubs' forgiving catch) and the graded `pwin` ladder both go,
  replaced by the plus-one and minus-one above.

---

## 10. Tomatoes

- [ ] **The crowd may only throw tomatoes if the performer never got the room into the
  green.** Louis: if they did get there, "the people already got what they came for and
  are happy enough not to throw tomatoes."
- Current state: tomatoes fly whenever `applause <= TOMATO_RED` (0.30). Green begins at
  `FLOWER_GREEN` (0.78). Needs a per-act latch: once the meter has touched green, tomatoes
  are off for the rest of the night.

---

## 11. Encores

- [ ] **Blackout.** Ordinary props go completely invisible, so juggling is possible but
  brutally hard. A torch's HANDLE is invisible but its flame and the flame's glow are
  visible. Glow-in-the-dark props are visible, and a glow-in-the-dark torch's handle is
  visible too.
- [ ] **Blackout may not be rolled before the player owns the props to survive it**: at
  least 3 glow-in-the-dark balls or torches. Same shape as the existing "For the Danger"
  ownership gate in `encore_pool`.
- [ ] **Cold Hands** removes one Perfect frame, not two.
- [ ] **The Purist's Night splits into four**, one per stat, and they combine in the late
  stages: 4 at once only at the Midnight Show, 3 at the stage before it, 2 the stage
  before that, 1 the stage before that. The first one must not land early.
- [ ] **Close Quarters ("props that clip mid-air") is replaced** by two crowd-taste
  challenges: **Scared Audience** (dangerous props do not score) and **Fancy Audience**
  (eggs do not score). Confirm this reading, see the decisions.
- [ ] **The Critic splits into easy and hard.**
  - Easy: a Late catch resets the segment. It must feel like a drop does to the score, but
    hurt nothing else: `x` resets, the object count and everything else carry on as if the
    performance were starting over for scoring purposes only.
  - Hard: both Late and Good reset the segment.
  - Neither zeroes the total. They end the exponential and open a fresh segment.

---

## 12. Decisions, answered 2026-07-29

1. **The logo.** DECIDED: fix the props themselves, stay with the all-props mark. The two
   torches lean in until they touch and their flames merge into one apex, a club lies
   across them as the A's crossbar, each S drops to five bigger balls in one warm colour,
   every letter sits on one baseline.
2. **The exponent.** DECIDED: keep the formula exactly as written, and make **the venue
   goal a demanded RUN LENGTH** instead of a flat number. The house asks for a clean run
   of roughly N catches and the goal is `s * N ^ (n * p)`, computed from the load actually
   being juggled. The demand is therefore the same whatever you bring, heavy props are
   purely a score and record play, and records stay raw score so the heaviest load a
   player can hold is what sets them. Target run lengths: Backyard 18, Street 26, Theatre
   34, Circus 44, Championship 56, World Arena 70, and the Midnight Show above that.
3. **Ball counts.** DECIDED: as specified, skill is the only gate. 15 balls at Strength
   15. Keeping fifteen balls in the air is the wall.
4. **The Shower's `s`.** Not answered, and it must have a value. Taking **1.8**, above
   Reverse Cascade and Tennis at 1.5 and below Half Shower at 2, which matches the order
   the old table already had. Say if it should be otherwise.
5. **Glow in the dark.** DECIDED: glowing props become their own **stock**, bought like
   any other prop, so Blackout is a real decision about what to bring. The single 60,000
   Glow Kit is replaced by cheaper per-prop purchases.
6. **The high-count height penalty.** Proceeding on the recommendation unless told
   otherwise: height is measured **relative to that count's own tap floor**, so a tap is
   always a zero penalty whatever the load, and the penalty only ever measures the choice
   to throw higher than needed. That makes the 90% and 70% promise true at every count.
7. **Nerfing early trick spam.** Suggestion still owed, nothing to be built. See below.
8. **The first single-stat Purist.** Proceeding with the Circus (venue 3) as the earliest,
   Championship for two at once, World Arena for three, Midnight Show for all four.

## 13. Trick spam, the suggestion (NOT to be built)

The exploit in `s * PRODUCT(ti ^ mi) * x ^ (n*p)` is that `mi` has no ceiling. Three balls
in a Cascade with a Spin landed on every single catch is `2 ^ mi`, which passes any number
in the game inside a minute, and it is easiest at the lowest count.

Two levers, either alone or together:

1. **A trick pays once per round of the pattern.** A trick's multiplier only counts if at
   least `n` catches have landed since the last one that paid. At three balls that is one
   trick every three catches, at fifteen it is one every fifteen. It is honest to real
   juggling (nobody spins on every throw), it needs no new number, and it scales itself.
2. **A trick is worth more under a harder load.** `ti` grows with `n * p`, so a Spin on
   three balls is worth much less than the same Spin on seven torches. The code already
   has this shape in `trick_difficulty`, which currently scales a trick by weight, count
   and pattern. Keeping a version of it is the smallest change of the two.

Recommendation: lever 1 alone. It caps the spam by construction rather than by tuning, and
it leaves `ti` as the flat, readable number Louis wrote down.
