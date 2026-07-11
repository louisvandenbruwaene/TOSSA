# JUGGLE: Art and Music Direction

Version 0.1. A companion to GDD.md. The GDD locks one hard constraint (Section
1.1): all art and audio are produced in code, procedural or generated, no
hand-drawn frames and no imported asset packs. That constraint shapes everything
below. It is not a limitation to apologise for, it is the look. Clean vector
shapes, warm light, and generated sound give the game a single coherent hand.

Ethos: gorgeous by substance, not by flash. Readability first, then beauty, and
the beauty comes from restraint and motion rather than clutter.

---

## 1. Art pillars

1. **Read the juggling instantly.** Every visual choice serves the player's
   ability to time a catch. Props must pop against the stage, landing points must
   be legible, the hands must clearly open and close. If a flourish hurts
   readability, it loses.
2. **Warm theatrical light.** A spotlight world, deep warm shadows, gold and
   ember tones. The stage feels like a small pool of light in a dark room, which
   focuses the eye exactly where the juggling is.
3. **Everything in code.** Shapes are vector draw calls, motion is procedural,
   colour and light are computed. This already holds in the prototype (the
   juggler, hands, and every prop are drawn in Game.gd), and it scales because a
   new prop is a function, not an art commission.
4. **Escalation is the reward.** The stage gets grander as the career climbs. The
   backyard is bare, the arena is vast. The player should feel the venue ladder
   in their eyes before they read a single label.

---

## 2. Colour and light, per venue

One palette per venue tier, all sharing the warm base so the game reads as one
world. Colour is the main way the ten stages feel distinct (the GDD wants each
milestone respected). A rough progression:

- **Backyard:** dusk, muted greens and warm greys, soft flat daylight. No
  spotlight yet. Intimate and small.
- **Street:** cool evening blues with a single warm streetlamp pool. The contrast
  of cold surroundings and one warm light is the whole mood.
- **Festival:** bright, saturated, bunting colours, the most cheerful palette.
- **Theatre:** deep crimson and gold, a real spotlight cone, velvet dark
  surrounds. The prototype's current look already lives here.
- **Circus:** striped warmth, reds and creams, lantern light, a busier frame.
- **Championships:** cooler and more clinical, arena white balanced against the
  warm skin of the performer, a scoreboard glow.
- **Record and Arena:** vast darkness with a huge beam, the crowd as a field of
  faint warm points, the performer a bright island.
- **Finale:** everything at once, but controlled, the light tightening onto the
  hands as the set peaks.

Light is a gameplay tool, not just mood. The spotlight can narrow on a Perfect
streak to reward focus, and widen with a wobbling POISE to signal danger. A drop
can cause a brief cool desaturation, a held streak a slow warm bloom.

---

## 3. The juggler and the hands

The prototype already has a procedurally posed figure with a two-bone arm solve
and hands that open and close. The direction from here:

- **Hands are the star.** They should be the most expressive thing on screen: a
  wide confident open to receive, a crisp close on the catch, a clear reach inward
  to throw. Their motion is the anti-collision choreography made visible (GDD
  2.4), so selling that motion sells the whole mechanic.
- **The body follows the hands, procedurally.** Sway with tempo, a small dip on a
  heavy catch, a flourish on a streak, a wince on a drop (the face already does
  this). Never hand-animate a pose that a rule can drive.
- **Costume escalates with the venue.** The same rig, recoloured and re-trimmed:
  backyard plainclothes, street coat, theatre waistcoat (the current look), circus
  finery, arena spectacle. All palette swaps on one procedural figure.
- **Expression stays minimal.** Two eyes and a mouth curve carry a surprising
  amount. Keep it iconic, not detailed. A caricature reads better in motion than a
  portrait.

---

## 4. Prop visual language

Each prop has to be identifiable in a fraction of a second and at speed. The
prototype establishes the vocabulary: balls are solid discs, eggs are pale
ellipses, rings are open annuli, clubs and knives and torches are elongated and
they tumble in flight. Extend it with these rules:

- **Silhouette first, colour second.** A club and a knife must differ by shape
  even in shadow. Colour reinforces, it does not carry the read.
- **Weight shows.** Heavier props move with more visual heft, a slightly slower
  spin, a fatter trail, a heavier landing. The player should suspect a prop is
  heavy before they feel it in the timing.
- **Danger glows.** Torches carry a live flame (already flickering), knives catch
  a hard specular glint on the edge. The spectacle props should look like they
  cost something to drop.
- **A flight trail keyed to height.** A faint arc trail that lengthens and cools
  with throw height, so a risky high throw is legible as risky from its trail
  alone. This doubles as juice and as a readability aid for the inaccuracy.
- **Cosmetic sets are palette and particle swaps.** The GDD's glow-in-the-dark set
  is just the stage light dropped and the props self-lit, no new art.

---

## 5. Crowd, stage, and motion

- **The crowd is suggestion, not detail.** A field of simple warm shapes that
  swell, lean, and brighten with Applause, and go dim and still on a bad run. It
  should be felt at the edge of vision, never competing with the props.
- **Juice with discipline.** Short popups (already present), a small screen shake
  on a drop, a bloom on a Perfect, a ripple of crowd light on a streak. Every
  effect is brief and serves feedback. Screen shake is a toggle (GDD Settings).
- **The reward state is visual.** When slow-motion arrives (later, and out of
  scope for now), it should look like the whole room holds its breath: colour
  deepens, the crowd sound drops away, the props leave longer trails. It is the
  visual climax the whole art system builds toward.

---

## 6. Typography and UI

- One warm, humane typeface used at a few clear sizes. The prototype uses the
  engine fallback, which is fine for now. A single clean sans with good numerals
  is the target, since the HUD is mostly numbers.
- HUD sits in the dark margins, never over the lit stage. Score and streak top
  left, resources top right, prop and controls along the bottom, the middle kept
  clear for juggling. This is already the layout.
- Menus (sheet, shop) are warm dark panels with a thin ember border, matching the
  stage. The shop already draws each prop's real icon in its row, which is the
  right instinct: show the object, not a word.

---

## 7. Music

Update 2026-07-10: the background music is now Louis's own recorded track,
Juggling Game.mp3 in the project root, the second deliberate exception to the
code-only rule alongside the font. The game rides its volume per state (fullest
while a performance cooks, easy in menus and on the stage card, a dip on a
drop) instead of generating material. All in-game SFX remain procedural, and the
adaptive ideas below now apply to volume automation over the one track rather
than to layered synthesis.

The original direction, kept for reference. Generated or procedural, per the
code-only rule. This is the harder half of the constraint, so the direction
leans on structure and adaptivity rather than on lush production.

- **Adaptive layers tied to the run.** A small set of musical layers that fade in
  and out with the performance state. A calm base bed while warming up, rhythm and
  melody layers that swell with the Applause meter and the streak, a thinning and
  souring when POISE wobbles. The music is a second Applause meter you hear.
- **Tempo is the juggler's tempo.** Because the player sets the pace from the
  first throw (GDD 2.5), the music can lock a pulse to the throw rhythm, so a
  steady juggler literally plays in time with the score. A rushed or ragged run
  falls out of pocket, which feels wrong in a useful, diegetic way.
- **A theme per venue tier.** Each stage of the ladder gets its own mode and
  instrumentation colour, sharing motifs so the climb feels like one piece of
  music growing up. Street music is sparse and small, the arena is full and tall.
- **Stingers for the moments.** A bright chime on a Perfect, a rising figure on a
  streak milestone, a dead thud and a beat of near-silence on a drop. The
  Amazing frame-perfect catch gets a signature sound that the player will chase.
- **Silence as a tool.** The record attempt and the finale can strip the music
  almost bare, so the tension sits in the crowd noise and the props alone. Bringing
  the full theme back as the finale lands is the biggest musical payoff in the game.

Feasibility note: Godot can synthesise audio at runtime (an audio stream
generator plus simple oscillators and envelopes), which is enough for the stingers
and a layered adaptive bed built from short generated loops. This keeps the whole
soundtrack inside the code-only rule. It will not sound like a scored orchestra,
and it does not need to. It needs to breathe with the juggling.

---

## 8. Sound effects

- **Catch and throw** are the load-bearing sounds and must feel tactile: a soft
  clean pock on a Perfect catch, a duller one on a Late, a whiff of air on a miss.
- **Per-prop audio.** Balls are soft, rings hum, clubs knock woody, knives ring
  metallic, torches add a low whoosh on every throw. The ear should know the prop
  with its eyes closed.
- **The crowd** is a living bed: a murmur that lifts to cheers with Applause,
  scattered gasps on a risky high throw, a collective groan on a drop.
- **Restraint.** In a game about timing, audio clutter is a real cost. Fewer,
  cleaner sounds that always mean the same thing will serve the player's rhythm
  better than a busy mix.
