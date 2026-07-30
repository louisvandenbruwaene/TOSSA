# TOSSA tasks

Louis's brief of 2026-07-29, written down in full before any code moves. Every item
below is his request, in his words where the wording matters, with the current state of
the code noted so nothing has to be rediscovered. Items marked **ASK** need his answer
before implementation. Items marked **SUGGEST ONLY** are explicitly not to be built yet.

Status key: `[ ]` not started, `[~]` in progress, `[x]` done, `[?]` blocked on an answer.

---

## 1. The logo

- [x] **The mark reads as props, not as the word TOSSA.** Louis: "it seems a bit
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

- [x] **Explain both to Louis in plain words, then cut what is not earning its place.**
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

- [x] **Strength no longer touches the catch at all.** Remove `strength_catch_mod` from
  `catch_chance`. Strength's only job is unlocking what you can throw.
- [x] **New requirement rule.** Per prop, the Strength cost of ONE object:

  | prop | balls | eggs | rings | clubs | knives | torches | chainsaws |
  |------|-------|------|-------|-------|--------|---------|-----------|
  | cost | 1     | 1    | 3     | 4     | 6      | 8       | 13        |

  To throw `n` of a prop you need `n x cost`. So 15 chainsaws needs 195 Strength, 7
  torches needs 56, 5 clubs needs 20, 3 balls needs 3.
- [x] The same wall applies to **starting a pattern that requires n props, and to making
  any throw under it**. Not just to the act's opening.
- [x] This replaces `BALL_GATES` (the flat 4:16, 5:33 ... 15:200 table) and the `req`
  field in `PROPS`, both of which go.
- [x] **The final 5 points of Strength give one extra Perfect frame** (196 to 200, so the
  top of the track is not dead once every count is open).
- [x] **Adding a Perfect frame shifts the Good, Late and whiff frames by the same one, and
  removing one shifts them back.** The bands keep their widths, the whole ladder moves.
  Currently `W_PERFECT` 7, `W_GOOD` 10, `W_LATE` 28, and only the Perfect band moves,
  which eats the Good band. That is wrong and is being fixed everywhere a frame is added
  or removed (Focus, clubs, chainsaw, Cold Hands, the Strength capstone).

---

## 4. Accuracy

- [x] **1 to 100: catch odds**, as now, minus the Strength term (see item 3).
- [x] **101 to 150 is Focus.** Cuts stamina cost linearly from full to a quarter, with a
  floor of 1 stamina per throw. Currently that ramp runs 100 to 200, so it is compressed
  into half the space.
- [x] **151 to 200 gives one Perfect frame per 10 points, five in total.**
- [x] **Accuracy caps at 200.** `ACC_CAP` comes down from 250.
- [x] Frames granted here obey the band-shifting rule in item 3.

---

## 5. Levels

- [x] **Levels arrive twice as fast, and everything is unlocked at about level 100, which
  is today's level 50.** Target: 10 to 20 hours of play to that point.
- Current state: `xp_to_next(lv) = 60 * lv^1.4 + 40 * lv`, and a level pays
  `POINTS_PER_LEVEL + level / 12` stat points. Reaching every stat wall costs about 250
  points, which lands near level 50 today, at roughly 350k XP.
- Plan: halve the XP per level and halve the points per level, so the same work buys the
  same build and only the level NUMBER doubles. Level-ups land twice as often, which is
  better feel at no balance cost.

---

## 6. Height penalty and the catch odds

- [x] **Answer Louis's question: is the penalty zero at tap height?** Yes at 3 and 4
  objects, and no beyond that. `count_air_scale` lifts the tap floor from 5 objects up, so
  a tap already reads as height 0.60 at 7 objects and past 1.4 at 12 or more. At the top
  counts every throw, tap or hold, is already taking the maximum height penalty.
- [x] **Extend the penalty to 1.8**, which a held High Toss really reaches, instead of
  clamping at 1.4. Add roughly 0.5 total penalty at the top.
- [x] **Retune the base odds so that, with no glasses and no gloves, at Accuracy 100 and
  no height penalty, a Good catch is 90% and a Late catch is 70%.** Today the same case
  gives 80% and 60%, so `GOOD_BASE` and `LATE_BASE` each rise by 0.10.
- Note for Louis: because of the tap-floor finding above, the 90/70 promise is only true
  at low counts. At high counts the height penalty is always on. Flagged as a separate
  decision at the foot of this file.

---

## 7. Speed

- [x] **Speed gives 20% slow motion at most, 10 points per 1%.** Today it is 8 points per
  1%, so 25% at the cap.
- [x] **Every other slow source gives 10%, not 15%**: Uncle Dan's Pie, the Amazing! burst,
  the fifty-Perfect burst.
- [x] Total stays capped at **50%**, the hard ceiling, which the four sources now sum to
  exactly.

---

## 8. The score system, replaced entirely

- [x] **The score is the sum of segments.** A segment is a stretch of consecutive catches
  with no drop. Good and Late catches do NOT end a segment. Only a drop does, and only a
  challenge that explicitly says so may also end one.
- [x] **One segment is worth**

  ```
  s * PRODUCT over tricks i of (ti ^ mi) * x ^ (n * p)
  ```

  where
  - `x` is the weighted catch count in the segment: a Perfect counts 3, a Good 2, a Late 1
  - `n` is the number of objects
  - `p` is the prop's signature value
  - `s` is the pattern multiplier
  - `ti` is trick i's multiplier and `mi` is how many times it landed in this segment

- [x] **Prop signature `p`:**

  | balls | eggs | rings | clubs | knives | torches | chainsaws |
  |-------|------|-------|-------|--------|---------|-----------|
  | 1     | 1.2  | 1.4   | 1.6   | 2      | 3       | 5         |

- [x] **Pattern multiplier `s`:** Cascade 1, Columns 1.2, Half Shower 2, Reverse Cascade
  1.5, Tennis 1.5. (Shower is not in Louis's list and needs a value, see the decisions.)
- [x] **Trick multipliers `ti`:** Spin 2, High Toss 1.1, Behind the Back 1.2.
- [x] **There is no Perfect-catch streak any more.** The whole idea of a Perfect chain is
  gone, replaced by Perfect simply being worth three of the weighted catches.

### What comes out with it

- [x] `chain_mult()` and the whole chain, `CHAIN_GAIN`, `CHAIN_HALF`, the on-screen chain
  readout.
- [x] `CATCH_PTS` / `CATCH_PTS_GOOD` per-catch points, `object_mult`, `OBJ_BALL_BONUS`,
  `prop_score_mult`, the `smult` field in `PROPS`.
- [x] `DARK_PROP_BONUS` (torches score more in the dark) and `PICKY_PROP_BONUS` (knives
  score more before a hard crowd). Both are score multipliers and neither fits the new
  scheme. Torches keep glowing and knives keep buying patience, as flat prop character.
- [x] `trick_difficulty`'s context scaling (weight, count and pattern inflating a trick's
  base) and `apply_trick_mult`'s running `run_mult`, replaced by the per-segment product.
- [ ] The fifty-Perfect slow-motion burst is keyed on `perfect_chain`, which no longer
  exists as a concept. It needs a new trigger or it goes.

### Still to design

- [ ] **SUGGEST ONLY, do not implement: how to stop trick spamming early.** Louis wants a
  proposal, not code. Candidates are in the decisions section.

---

## 9. Prop character, rewritten

- [x] **Clubs:** one extra Perfect frame. Nothing else.
- [x] **Knives:** the crowd is more patient. Nothing else.
- [x] **Torches:** more patience, and they glow in the dark. No multiplier.
- [x] **Chainsaw:** one fewer Perfect frame.
- [x] **Balls, eggs, rings:** no special lever beyond their `p` value and their stamina
  cost. Eggs keep shattering on a drop.
- [x] The `fgive` field (clubs' forgiving catch) and the graded `pwin` ladder both go,
  replaced by the plus-one and minus-one above.

---

## 10. Tomatoes

- [x] **The crowd may only throw tomatoes if the performer never got the room into the
  green.** Louis: if they did get there, "the people already got what they came for and
  are happy enough not to throw tomatoes."
- Current state: tomatoes fly whenever `applause <= TOMATO_RED` (0.30). Green begins at
  `FLOWER_GREEN` (0.78). Needs a per-act latch: once the meter has touched green, tomatoes
  are off for the rest of the night.

---

## 11. Encores

- [x] **Blackout.** Ordinary props go completely invisible, so juggling is possible but
  brutally hard. A torch's HANDLE is invisible but its flame and the flame's glow are
  visible. Glow-in-the-dark props are visible, and a glow-in-the-dark torch's handle is
  visible too.
- [x] **Blackout may not be rolled before the player owns the props to survive it**: at
  least 3 glow-in-the-dark balls or torches. Same shape as the existing "For the Danger"
  ownership gate in `encore_pool`.
- [x] **Cold Hands** removes one Perfect frame, not two.
- [x] **The Purist's Night splits into four**, one per stat, and they combine in the late
  stages: 4 at once only at the Midnight Show, 3 at the stage before it, 2 the stage
  before that, 1 the stage before that. The first one must not land early.
- [x] **Close Quarters ("props that clip mid-air") is replaced** by two crowd-taste
  challenges: **Scared Audience** (dangerous props do not score) and **Fancy Audience**
  (eggs do not score). Confirm this reading, see the decisions.
- [x] **The Critic splits into easy and hard.**
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


---

## 14. Where this stands, end of 2026-07-29

**Built and verified on screen or end to end:** the logo, drift and jitter, the whole
Strength rule, the frame ladder, Accuracy's two stages, the level curve, the height
penalty and the 90/70 odds, Speed, the segment score, the goals-as-run-length ladder, the
prop rewrite, tomatoes, glowing props as stock, Blackout's true invisibility, the four
Purists, the two crowd tastes and the two Critics.

**Verified how:** `--ladder` prints the whole goal ladder from the live constants; a full
Backyard act runs end to end (3 of 3 goals, pay, reputation, a record and an ovation); the
title screen, the key art, the credits, capsule 1, the shop, the play HUD, the character
sheet, the results card and the establishing card were all looked at.

**Two bugs found on the way, both fixed, both worth knowing about:**
1. `--demo` kept playing after the results card, and a throw restarts the act, so it
   re-armed the ovation every time it was about to end and hung forever. It only started
   firing on every run because the new goals make a flawless act normal rather than rare.
2. The establishing card printed all three goals and the record through `commafy`, whose
   argument is an integer, so every one of them read 9,223,372,036,854,775,807 and ran off
   the panel. Anything that came out of the scoring goes through `score_text`.

**Still open, and needing Louis:**
- **The balance numbers.** `GOAL_CATCHES` is set so a house's final goal is about one clean
  run of half the act's clock floor. That is arithmetic, not play. It is one array.
- **The Shower's `s`** is assumed at 1.8.
- **Trick spam** is unnerfed by design, suggestion at section 13.
- **The T of the logo** still reads as a dagger with a knife across it rather than as a T.
  Louis did not raise it, so it was left alone.
- **`docs/mechanics.html` and `TOSSA_mechanics_reference.pdf` are now stale** in every
  section that touches scoring, stats or Encores. They are generated, so they want a
  regeneration pass rather than an edit.








%%%%%%%%%% EDITS MADE BY LOUIS %%%%%%%%

Hi it's me, louis, i'm here to give you instructions and ideas for the game. 

idea: create bot jugglers in game to beat: 3 per stage. & also compare with your steam friend list records etc. 

idea: create a small overworld like in mario; the player just goes from stage to stage: can go back or forwards from node to node. (the input is binary: back or forward, so the movement commands etc should be simple to implement.)

idea: Is it possible to hire an artist that makes custom drawings? which parts of the game could be hand drawn? which would profit the most by not looking AI made? How would that go: drawings on paper or some kind of tablet? 

idea: make the title screen after loading show a "bucket" of juggle props fall over and out comes the juggle props that make up the TOSSA name in the props. It should be cleanly animated / perhaps drawn by the artist (which would need an example such as ai drawings). 

idea: I'd like to rework the tutorial. Please follow my instructions closely:
Remove all unnecesairy text from the current tutorial, the player only needs the buttons that are on the bottom of the screen: FJ throw, DK catch, R restart and esc escape. The rest of text: the basics window and the pause window should be removed. Instead i'd like you to create another window that looks better and like a person talking (also create a small noise for that: in balatro they have some kind of explanation sound which i like). Remove all slowmo from the tutorial. now the text: "Hello, this is a game about juggling. If you want to learn it, you've come to the right place!" ENTER (show a small enter button icon) "Let's start with one ball in our dominant hand." Make them choose their dominant hand with an interactive window; make sure non of this: the talking window nor the choosing window ever overlap with the juggler, which should be visible at all times. "Great! Now throw it to your other hand in an arc by pressing J" i will take J as dominant hand, make sure it flips everywhere if they took left hand instead; " ENTER. Now catch it with D ENTER." here the enter means wait for the correct button to be pressed, enter shouldn't actually work here, please think for yourself what are the correct or wrong actions by the player. "Amazing! Now throw it back with F ENTER Catch it with K ENTER That's it! Feel free to master one ball, before moving on. When you are ready, press enter for the second ball. ENTER " Here ENTER is actually enter; Place on ball in each hand. " Throw the first ball: J ENTER Throw the second before it lands: F ENTER Now catch and throw on the RIGHT KJ KJ and on the LEFT DF DF. And repeat. KJ KJ DF DF Try it out! Enter when you've got it." make sure the inputs and text are aligned and correct. ; give the player 3 balls, 2 in the dominant hand. "Throw the first ball J ENTER Now you can throw all other balls one at a time right behind it and try to catch and throw them all as soon as they land or you take the easier way for now: wait for the ball to reach its peak before throwing the next one" meanwhile pause the highlight the first ball at its peak and prompt the second throw; "F ENTER Then catch it with D ENTER Now repeat on the other side: J ENTER K ENTER F ENTER D ENTER J ENTER K ENTER F ENTER D ENTER Try it out until you feel comfortable. Prove that you are ready by juggling for 10 throws and 10 catches." (show a window that just counts to 10 catches and 10 throws. ). I hope you are smart enough to fix any mistakes i made and to make it all feel smooth and logical. The player moves on when they get it. Else they juggle for free (no stamina). 

--> backyard performance. (still tutorial). "Let's test out your skills with an actual audience. The goal is to receive as many flowers as you can. This flower here "highlight the flower meter" shows your current score. When it blooms you have reached the goal and can stop juggling by catching everything or just pressing enter. "show the symbol enter" Small subflowers give partial rewards so lock them in if you're not sure. On the other hand, don't get overconfident. you lose a standing ovation bonus if you drop. The flower will grow depending on how many flowers you get from the audience, so keep them happy ("highlight the green and yellow part of the meter). Reaction afterwards depends: well done, keep going / not bad, but there's room for improvement / that was pretty bad, but at least you can eat those tomatoes. Then guide them through the rest of the menus with similar helpful text windows, like someone is explaining it all. Maybe i'll even add a little juggle prop that can talk to explain it all XD. 


---

## 15. Answering Louis's block of 2026-07-29 evening

**Done now: the basics tutorial, rewritten to his script.** It is a conversation rather than
a drill ladder. The three-passes-at-50%-25%-full structure is gone, all slow motion with it,
and so are the top banner and the full-screen intro card. What is left on screen is the
speech window, the key row he asked to keep, and a side panel for the two things that need
one. Every line is spoken a letter at a time with a soft blip, from a face in a lit disc.
The dominant hand is chosen in the lesson and every key name in every line is built from
that choice, so a left-hander is taught their own hands. `tut_do` beats wait for the ONE key
they name and Enter cannot skip them; `tut_free` beats hold until the player has really done
it, with the ten-throws-ten-catches tally in the side panel. Verified: all nineteen steps
walk end to end under `--demo --tutorial balls` with no errors and no slow motion.

**Nothing sits on the performer.** The first attempt put the hand question under him and it
crossed his legs. There is no room down there - his boots are at 0.80 of the height and the
key row owns the last 60px - so the lesson's panels live in the empty third of the stage to
his right (`TUT_SIDE_X`). The speech box is clamped above `TUT_SPEECH_BOT`.

**Still to build from his brief, in order:**
1. The **peak hold** on the three-ball beat: "pause and highlight the first ball at its peak
   and prompt the second throw". The step carries a `peak` flag already and nothing reads it.
2. The **backyard performance** guide: the flower meter explained, the sub-goals, the
   standing ovation warning, and the three closing reactions.
3. The **menu guides** after it, in the same speech window.

**On the ideas, briefly.** Bot jugglers to beat and a Mario-style node overworld are both
real features rather than tweaks, and both want their own session. The **artist** question is
the one worth answering properly: the parts that would gain most from a human hand are the
things a player looks AT rather than through - the venue exteriors, the title art, the prop
icons and the performer's face - and the parts that must stay code-drawn are anything that
moves or recolours per venue, which is most of the stage. A tablet (Procreate or Photoshop)
matching the existing palette would drop straight in as PNGs; the current code-drawn versions
make perfectly good briefs to hand over. The falling-bucket title animation depends on that
same answer, so it belongs after it.

---

## 16. The club, the cards and the shop (2026-07-30)

Louis: "improve the visuals in my game, in particular the club and the trick cards / pattern
cards, and the shop looks. Save the originals and let me compare with F9."

All three are behind F9 toggles, all three default ON, and every OFF branch is the original
code untouched (verified by rendering all four screens with the defaults flipped: they come
back pixel-identical to the committed version). The three toggles are `club_v2`, `card_v2` and
`shop_v2`, and each entry in the panel says what it switches and why.

**The club.** Its shape lived in three copies and all three carried the same leftover disc at
the head, which in the shop's version sat 2 units wider than the tapered body underneath it -
so the good profile that version's own comment describes was never the silhouette on screen.
One `CLUB_PROF` table now, one `club_shape()` that every mark is a slice of, a 3:1 body that
domes rather than points, a knob with a waist, and a pale handle against a coloured body. The
length and balance point are unchanged to the decimal, because they place the A's crossbar in
the wordmark. Cached, and the numbers are in CLAUDE.md: without the cache the new club would
have cost 3.3ms a frame at seven clubs.

**The cards.** The illustration hangs in a recessed window instead of floating on bare paper,
there is a kind index in two corners, the art is 56% of the card instead of 48% with the
description centred in what is left, and the backlight is tapered beams from behind the card
rather than twelve constant-width sticks that began in mid-air at the card's sides. The backs
got the same plate, the rosette struck three times down it, and a lattice that no longer draws
7px out through the right-hand border.

**The shop.** Two rows of four big cards instead of seven squeezed into one, which fills the
~300px the panel has had empty ever since the gear row emptied out, and gives each prop a real
lit niche at 251px of card instead of 141. Up/down walks the rows, which also fixes a key that
did nothing useful: with gear empty the old branch jumped to the last card from anywhere.

**Not done, and worth a look when Louis has seen these:** the eggs and the rings are small in
their niches next to the balls and the torch (PROP_ICON_MAG normalises by prop, and the niche
is portrait, so a short round prop does not use its height); and the shop still has no prop
CATEGORIES, which the grid postpones rather than answers - it buys room for eight or twelve,
not for thirty.

**One thing found on the machine rather than in the code:** a headless `--demo --tutorial balls`
run from an earlier session had been going for 5h49m and was burning a core, which is the hang
CLAUDE.md's verification section already warns about ("a `--demo` lesson run never quits by
itself, so give it a `--shotat`"). It was killed. It also polluted the first round of
performance numbers here, which is a good argument for checking `pgrep godot` before measuring
anything.

## 17. The wordmark and the stat milestones (2026-07-30, later)

Louis: "fix the title screen: move the letters closer together to seem more like the word
tossa, remove the middle torch at the end (in A), also replace the horizontal club with a
ball. AND: the middle ball in both s's are missing. Remove 'a juggler's climb'. fix the stat
milestones: they should be nicely spread. right now they look ugly and cramped. (you are
allowed to change the tricks actual location, the rest you should choose what to show or not,
don't move other stats around)"

**All five title-screen notes are done, and two of them were bugs.** The S's waist ball was
being dropped by both loops at once (each loop drops its first and last, and the top loop's
last IS the bottom loop's first), so every S was cut in half. The A's apex fire was a whole
third torch, which hung an upright handle down the middle of the letter. `CAP_GAP` went from
0.13 to 0.045, the crossbar is a ball, and the tagline is off the title screen.

**One thing followed from the third-torch fix and is worth knowing.** `CAP_TORCH_SC`'s comment
had been complaining for two passes that the A's strokes and its flame could not be sized
independently, because the flame rode on a handle. Now that the apex fire is drawn WITHOUT a
handle it has its own scale, so the strokes reach the cap line exactly (0.99 of a letter
height, up from 0.75) while the flame keeps the size it had. The A reads as a letter rather
than a bonfire, which is the same goal as moving the letters closer.

**The stat milestones are thinned for DISPLAY only**, in a second function. The important part
is why it is not a filter inside `stat_milestones`: that list also answers "what does my next
point buy", and thinning it would make the screen misreport the game (with clubs at Strength
20 the true next threshold is 24 for a sixth club). So the pips are a summary ladder and the
line under the track is a fact.

Strength also needed CONTENT, not just thinning: a full set of the prop in hand is Strength 60
with clubs and 15 with balls, so the top of that track was empty whatever was done to the
pips. It now carries one row per heavier prop at its full set (15 knives at 90, 15 torches at
120, 15 chainsaws at 195), which is the same rule and reads as a real ladder of props. The
three trick walls moved to fill gaps rather than sit on other marks. No prop, count or pattern
requirement was touched.

**Left alone deliberately, say the word if you want them:**
- The **store capsule keeps "a juggler's climb"** - the ask was about the title screen, and a
  storefront capsule usually wants a line under the logo.
- The **S's still read as clusters more than strokes.** Each loop is 0.45 letter-widths across
  with balls 0.238 wide, so only three or four fit round a curve and the eye gets a rough
  diamond. Fixing that properly means smaller balls or a wider loop, i.e. redesigning the
  letter, not a nudge.
- **Records and history prints 9,223,372,0...** for the Backyard and the Circus - the INT64
  sentinel is reaching that board and being clipped mid-number by the column width. It was
  fixed for goals in an earlier commit; this is a different reader of the same value.

## 18. The title screen, four ways (2026-07-30, later still)

Louis: "storefront capsule : jugglers climbs remove it. the ball between the torches should have
the same size as the other balls in the s, if it's too small to bridge the gap, just use more
balls. Make the title screen look better!, perhaps just add some of your own ideas in the
concepts folder, next to the rest"

**The tagline is off the capsule and `store/` was re-rendered.** Removing the string from the
code does not change the PNG anybody uploads, so `./render_store.sh` ran the whole six-slot set
again - which also picks up the new club and the new mark, both of which the store art still
had the old versions of.

**The A's crossbar is four balls at the S's own size.** Sizing one ball to the gap had made it
the biggest ball in the picture, and a mark built out of props has to be built out of the same
props or the odd one reads as a different object. One thing to know if it is ever retuned: the
count is intervals PLUS ONE. Sizing n to the span and spreading n balls across it leaves n-1
gaps each wider than a ball, which is how the first try came out as three balls with daylight
between them rather than a bar.

**The title screen: the menu was the last bare `draw_string` list in the game.** Settings and
Pause were both rebuilt into the card language in July for the reason recorded there, and the
screen that makes the first impression was still three lines of centred text with `> Play <`
round the lit one. It has the pause menu's language now - an icon disc, the name, a line saying
where it goes - and the cards stand on the boards rather than floating over a picture. Nothing
about the list or the input moved.

**Four backdrops, one layout, in `store/concepts/title_v1..4.png` beside the capsule concepts.**
Only the set changes between them, the same discipline the capsules follow, so picking is about
the picture. **1 THE HOUSE ships** - velvet, a box either side with heads on the rail,
footlights, boards - because a title screen's job is to say what the game is before a word is
read, and this game is a performer walking out in front of a room. 2 is FIRELIGHT (no set, the
mark's own torches), 3 is NIGHT (the Midnight Show's language, a roofline and lit windows), 4 is
THE CURTAIN, CLOSED. Say which one you want and it is a one-line change; `--menu N` shows any of
them live.

All four are built out of stage furniture the game already owns. Three of this file's own
lessons came back while doing it and are written up in CLAUDE.md: the curtain needed the same
VEIL `draw_backdrop` puts over set dressing or it out-shouted the wordmark; FIRELIGHT's embers
were centred on the mark and scattered sparks through the lettering, where they read as stray
balls; and NIGHT's roofline was invisible until it got a proper value ladder plus a halo on
every window.

**Still open from before:** the S's read as clusters more than strokes (a real letter redesign,
not a nudge), and Records and history still prints the clipped INT64 sentinel for two venues.

## 19. The A becomes clubs, and the logo loses its fire (2026-07-30, evening)

Louis: "remove the concepts except the current one (for the title screen). i'd like you to change
the two torches into clubs and change to four balls to the two middle balls for the dash of the
A. You can add one extra ball to each S, in order to make it smoother and slightly larger." Then:
"move the titlescreen menu: with 3 options a tiny bit higher: about half the height of one of
those option windows, such as Play."

All done. **The headline, said plainly: nothing in the wordmark burns any more.** The A's two
torches are clubs, so the flame at the apex went with them, and `CAP_TORCH_SHAFT` /
`CAP_TORCH_SC` / `CAP_A_FIRE_SC` are deleted. That is the biggest change the logo has had, and it
is worth knowing it can be undone in one line (a `cap_torch` call at the apex) if you miss the
fire.

**Two good things fell out of it.** The A's scale is now solved rather than tuned - a club is all
stroke, so `CLUB_LEN * cos(lean) * 0.0277` puts the noses exactly on the cap line, where the
torch version needed three attempts and a separate flame scale to approximate. And the mark got
half again as big for free: it used to reserve 2.45 letter heights of height for a flame at its
flicker peak, so a letter height of 108 already ate 280px of a 720px screen. The picture is 1.23
letter heights now, so `MENU_MARK` went to 168 and the capsule's to 185.

**One bug found on the way.** The 600x900 portrait store capsule was cutting the T and the A off
at the frame edges. Nothing about that slot had changed - the letters had simply grown (the wider
S), and every caller was sizing the mark off the frame's HEIGHT with nothing measuring its width.
There is a `mark_fit_size()` now and all five capsules, the key art and the title screen go
through it, so a portrait slot can never do that again.

The three losing title backdrops (FIRELIGHT, NIGHT, THE CURTAIN) are deleted along with the
`--menu N` selector, and `store/concepts/` keeps one current `title_screen.png`. `store/` was
re-rendered for the new mark.

**Still open:** Records and history prints the clipped INT64 sentinel for two venues.

## 20. The tutorial pause, and every lesson speaking (2026-07-30, night)

Louis: "The tutorial is still not pausing when it should ... it should pause the game when the
thrown ball comes near the perfect catch timing; that makes sure the beginning player doesn't drop
during the tutorial ... and with it i want you to fix the 'learn something new' tutorials, which
should be given in the same style and layout as the actual tutorial." Plus, on the title screen:
the wordmark centred between the top and Play, the divider tight to Play, and the two little box
windows replaced by proscenium curtains.

**The pause bug was real, and instrumenting it printed the proof.** A beat whose goal is already
MET sets `tut_advance_at` and asks for Enter - and `tut_do_step()` returns false in that state, so
nothing was frozen while the ball you had just thrown flew on. The log line was `tick=649 step=8
goal=throw_r adv=629`: a ball arriving, a satisfied throw beat, no freeze. Catch beats were no
better - they held at the arrival tick itself, so the whole flight ran at full speed and any press
on the way in was read as an ordinary catch, which can whiff or drop.

There is a catch guard now: during any HELPED stretch (everything except a `free` beat, where you
asked for dropping to be possible) the world stops as soon as a prop is within 14 ticks of landing,
wherever the script has got to, and the press that follows always lands. Helped catches are graded
PERFECT rather than on raw timing - freezing early was putting "LATE" over a beginner's hand for a
press the game had stopped itself to demand.

**The peak hold works now too.** The `peak` flag had been sitting on the three-ball step unread
since the script was written, which is why that beat froze the instant it began and asked for the
second throw while the first was still leaving the hand - the game contradicting its own line.

**All five lesson families speak.** The blocker was plumbing: there was no builder for "a line, and
the goal `trick_on`", so trick/pattern/prop/count/advanced were stuck with the intro card, the
banner and the three-pass slow-motion ladder. `tut_beat()` is that builder. Every goal, need and
reward is identical; the drills run one pass at what the old ladder's last pass asked. `tut_paced`,
`tut_pace_line`, `tut_intro`, `TRICK_TUT_SLOW` and the banner's pace pips are deleted.

**Still worth a human pass:** I verified all nine lessons run end to end headless with no errors and
that the guard engages where it should, but the FEEL of the pause - whether 14 ticks is the right
distance, whether it stops too often in the three-ball section - is a hands-on judgement I cannot
make from screenshots.

**Still open:** Records and history prints the clipped INT64 sentinel for two venues.
