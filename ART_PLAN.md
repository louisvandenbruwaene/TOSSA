# JUGGLE: making it look good

Written 2026-07-15, from a real capture of the running game rather than from
reading the draw code. This is the plan for the visual pass, and it opens with
an honest answer to the question Louis actually asked.

---

## Can I guarantee it will look good?

**No.**

I cannot draw. I can only write code that draws. And nobody, human or otherwise,
can guarantee taste in advance. If I told you "yes, trust me", that would be a
sales pitch, not an engineering answer, and you would find out I was wrong at the
worst possible moment, which is after the work was done.

Here is what I can honestly offer instead, and I think it is worth more than the
guarantee you asked for.

**What I CAN guarantee**, because these are measurable properties rather than
matters of taste:

- the props will be legible against every backdrop at every venue (a real
  contrast floor, checked numerically, not judged by eye)
- the figure will keep a readable silhouette in every pose
- the frame rate will hold at 60, and the 120Hz sim will not be touched
- one coherent palette across all six venues, derived rather than hand-picked
- nothing that hurts the player's ability to time a catch ships, ever
- every visual change lands behind its own flag, in its own small commit, so any
  single one can be reverted without unpicking the others

**What I CANNOT guarantee** is that you will like it. So the plan is built so
that you do not have to trust me on that. Which brings me to the thing I checked
before writing any of this.

**I verified I can see the game.** I ran it and captured real frames
(`godot --path . --audio-driver Dummy -- --demo --shot ./shot.png --shotat 420`,
which must be a project-relative path, an absolute path silently writes nothing).
That means every proposal below can be shown to you as an actual before-and-after
image, at the same moment in the same venue, and you can say no. We are not
relying on me describing a look and you imagining it. You will look at it.

That loop is the real guarantee: not that I get it right, but that you get to
reject it cheaply and often.

---

## What the game actually looks like right now

I captured a live performance at the Backyard. The honest diagnosis, and it is
not what I expected before I looked:

**The figure is not the problem.** The eight-head canon in `draw_juggler()` is
doing its job. It has real proportions, a tapered jacket, a waistcoat, a face,
sloped shoulders, a breathing dip. It is not a stick figure and it does not need
to be replaced.

**The light is the problem.** Specifically:

1. **The scene is dark-on-dark.** The backdrop is near-black, the Backyard's
   murky green-grey sits on top of it, and the figure's brown suit sits on top of
   that. Three dark values stacked. The "warm theatrical" promise in
   ART_AND_MUSIC.md is not landing, because there is no actual light in the
   scene, only an absence of it.

2. **The props are the smallest and dimmest things on screen**, and they are the
   most important objects in the entire game. Art pillar 1 in your own art doc is
   "read the juggling instantly". In the captured frame I had to hunt for the
   balls. This is the single biggest failure and it is a gameplay bug wearing an
   art costume.

3. **The spotlight is a flat grey triangle** with hard straight edges. It reads
   as a grey polygon someone drew, not as light falling through air. No falloff,
   no gradient, no softness at the rim.

4. **The crowd is eleven identical grey blobs**, evenly spaced, all the same size,
   in a flat band. It reads as clip art and it flattens the whole bottom of the
   frame.

5. **The composition is weak.** The juggler is small and dead centre in a large
   empty frame. The action (the arc of the props) occupies a narrow band, and
   everything above and below it is dead space.

6. **The HUD is the best-looking thing in the game**, which is a bad sign. It is
   clean, well-spaced, and confidently typeset, and it makes the world behind it
   look unfinished by comparison.

So: this game does not need a better artist. It needs a lighting pass, a contrast
pass, and a composition pass. Those are engineering problems with known, proven
answers, and that is why I am much more confident about Tracks A and B below than
I would be about "make it prettier" in the abstract.

---

## About hand-drawn figures

You said you like hand-drawn figures and guessed that is hard for me. You are
right that I cannot draw. But the premise is worth challenging, because there is
a real technique here.

**What makes an image read as hand-drawn is not draughtsmanship. It is
imperfection and frame rate.** A perfectly smooth vector shape reads as digital
no matter how beautifully it is proportioned. The same shape reads as *ink* when
you add four things, all of which are pure code:

1. **Line boil.** Real hand-drawn animation redraws every line every frame, so
   the line wobbles slightly. Perturb the outline's control points with noise
   sampled at `floor(tick / 10)` instead of `tick`, so it changes about twelve
   times a second rather than sixty. This is the single most important trick and
   it is maybe fifteen lines.
2. **Variable-width strokes.** A pen presses harder in some places. Draw outlines
   as tapered polygons rather than constant-width `draw_polyline` calls: thick at
   the weight-bearing curves, thin at the tips.
3. **Off-register fills.** Cheap printing does not line the colour up perfectly
   with the ink. Offset every fill by one or two pixels from its outline. This is
   almost free and it instantly reads as *printed*.
4. **Paper.** A subtle grain and tooth over the whole frame, multiplied, not
   added.

Together these are the signature of ink. They do not require me to draw anything.
They require me to make the code draw *badly on purpose, in a specific way*.

**The catch, and it is a serious one.** Your game is timing. A prop whose position
jitters is a prop the player cannot time, and boil would do exactly that. So:

> **The ink treatment may touch the figure, the set, and the crowd. It must never
> touch the props.** The props stay mathematically crisp at 120Hz forever.

That split is the entire design of Track C, and it is also why Track C is the one
I am least confident about: a boiling figure next to razor-sharp props may read as
two different games glued together. It might also look wonderful. **I genuinely do
not know, and neither does anyone else until we look at it.** So it is built last,
behind a flag, and you judge it from a screenshot.

---

## Track A. Light (highest impact, lowest risk)

If we only ever do one track, do this one. Every item is additive over a
silhouette that already reads, which is why it is low risk.

### A.1 A real post-processing chain

There is currently none. `Main.tscn` has no `WorldEnvironment`, no `CanvasLayer`,
and no shader of any kind. The game is raw `_draw()` calls straight to the screen.

**One technical caveat to verify first.** `project.godot` sets
`renderer/rendering_method="gl_compatibility"`. Godot's built-in `WorldEnvironment`
glow has historically not been supported on the Compatibility renderer. I am not
certain what 4.7 does here and **this must be checked, not assumed.** If glow is
unavailable, the safe route (which works on every renderer and which I would
probably pick anyway for control) is to hand-roll the chain: render the game into
a `SubViewport`, then draw that texture through a full-screen shader.

The chain, in order:

- **Bloom.** Bright pixels bleed light. This is the single biggest visual win
  available and it is what will finally make the props, the torches, the knives,
  and the spotlight look like they are *emitting* rather than *being filled*.
  Threshold, downsample, blur, add back.
- **Spotlight falloff.** Replace the flat grey triangle with a real cone: soft
  radial falloff from the source, a gradient down its length, a soft rim. Add a
  faint volumetric haze so the beam has air in it. This alone fixes the single
  ugliest element in the current frame.
- **Vignette.** Darken the corners, pull the eye to the juggling.
- **Colour grading.** Lift the shadows slightly (pure black is what is making the
  scene read as murk rather than as darkness), add contrast, push saturation into
  the warms.
- **Film grain.** Very subtle. It hides banding in the gradients and it stops the
  large flat areas from looking like empty vector fills.

### A.2 Make the props read

This is a gameplay fix, not a cosmetic one, and it is the highest-priority single
item in this document.

- **Bigger.** They are currently too small for their importance.
- **A real glow.** Every prop gets an additive halo, scaled by weight (a torch
  should light the stage around it, a ball should not).
- **A contrast floor.** Numerically enforce that every prop's colour is at least
  N steps of luminance away from the backdrop it is currently in front of, per
  venue. Check it in code, not by eye. This is one of the things I *can* guarantee.
- **Better trails.** The trail already exists (`b.trail`, `draw_trail()`) but it
  is a thin constant-width line. Make it a tapered comet, additively blended, and
  longer for higher throws so risk stays legible at a glance, which is what the
  code comment already says it is for.
- **A light on the stage.** A lit torch should cast an actual moving pool of warm
  light on the floor and up onto the juggler. This would be spectacular and it is
  not hard.

### A.3 Light as a gameplay signal

Your art doc already asks for this and it was never built:

> "Light is a gameplay tool, not just mood. The spotlight can narrow on a Perfect
> streak to reward focus, and widen with a wobbling POISE to signal danger. A drop
> can cause a brief cool desaturation, a held streak a slow warm bloom."

Build exactly that. The spotlight tightens as the streak grows, the world warms
and blooms as applause rises, a drop desaturates the frame for half a second and
the light flickers. Every one of these has a state variable already sitting in
`Game.gd` (`streak`, `applause`, `last_drop_tick`) and none of them is currently
driving a single pixel of light.

---

## Track B. Motion (high impact, low risk)

**Animation quality beats drawing quality.** This is the most reliable way to make
simple shapes look expensive, and it is where the "hand-drawn" *feeling* actually
comes from in most games people describe that way.

What already exists: a breathing dip, a catch absorb, two-bone IK arms, a full
pirouette on Spin. That is a good foundation.

What to add, in descending order of value per line of code:

1. **The head tracks the highest ball.** About five lines. It transforms the
   figure from a mannequin with moving arms into a *performer who is watching his
   own juggling*. If you build one thing from this track, build this.
2. **Anticipation and follow-through.** A small wind-up before a throw, and the
   arm continuing past the release before settling. Animation's oldest trick and
   the reason hand-keyed motion looks alive and procedural motion usually does
   not.
3. **Secondary motion.** A coat tail and a lock of hair on a two-link spring
   chain, driven by the body's own velocity. Cheap, and it is 80 percent of what
   makes a figure feel like it has weight.
4. **Weight shift.** The hips counter-rotate against the shoulders. Right now the
   figure is bilaterally symmetric and rooted, which is why it reads as a stand
   for two arms.
5. **Squash and stretch on the props at the moment of catch.** One frame of it.
   Sells the impact.
6. **Blink**, and a face that reacts (the wince on a drop already exists in
   `draw_face`, so extend rather than invent).
7. **Fix the crowd.** Give each figure its own size, its own colour jitter, its
   own bob phase, and its own reaction delay, so a cheer ripples across the crowd
   instead of the whole row moving as one object. Currently they are eleven
   identical blobs on a metronome.

---

## Track C. The ink pass (highest risk, highest identity payoff)

This is the one that answers what you actually want, and it is the one I cannot
promise. Build it last, behind `--ink`, and judge it from a screenshot.

Order of work:

1. `draw_ink_polygon(pts, fill, ink)`: fill first, offset by one or two pixels,
   then a tapered variable-width outline over the top.
2. Add boil: perturb the outline points with noise sampled on a 10-tick clock, so
   the line wobbles at roughly 12Hz.
3. Apply it to the figure, the set dressing, and the crowd. **Never the props.**
4. A paper grain layer, multiplied over everything.
5. Consider stepping the figure's *animation* (not the sim) to 24Hz or even 12Hz,
   which is the other half of what makes hand-drawn read as hand-drawn. The props
   keep updating at 120Hz. This is the riskiest single idea here and the most
   likely to either look superb or look broken.

**Honest risk assessment:** steps 1, 2 and 4 are safe and reversible. Step 5 is a
coin flip. And the whole track fights art pillar 1 (readability), so if it ever
makes a catch harder to time, it loses and it goes in the bin, however good it
looks.

---

## The escape hatch: if you want REAL hand-drawn

If, after seeing Track C, you still want genuine hand-drawn art (and you might,
and that would be a legitimate call), then the honest answer is that it needs a
human hand: yours, or a commissioned artist's. The code-only rule in GDD 1.1
would end, and that is fine. A rule that was serving the game stops serving it the
moment it caps the ceiling.

**The useful thing I can do about that is architectural, and I would suggest doing
it regardless of which way you go.** Right now, `draw_juggler()` mixes two
different jobs: computing the figure's *pose* (where the shoulders, hips, head and
hands are this tick, which is gameplay truth) and *rendering* that pose (capsules,
polygons, colours). Split them. Have the sim produce a pose (a small struct of
joint positions), and have a renderer consume it.

Then the procedural renderer, the ink renderer, and a future hand-drawn sprite or
cut-out renderer are three implementations of one interface, swappable with a
flag, none of which can break the gameplay because none of them can touch it. That
refactor costs one session, it makes Track C safe to attempt, and it keeps the
door to a real artist open at zero future cost. It is the highest-leverage
structural thing in this whole document.

---

## Order of work

1. **The pose/render split** (the refactor above). It de-risks everything after it.
2. **Track A.2, make the props read.** This is a gameplay bug and it comes first.
3. **Track A.1, the post chain.** Verify the glow situation on `gl_compatibility`
   before committing to an approach.
4. **Track B, motion.** Head-tracking first, it is five lines and it is the
   biggest single win in the document.
5. **Track A.3, light as signal.** The art doc already designed it.
6. **Track C, the ink pass.** Behind a flag. You judge it.

After each step I will capture the same frame, at the same venue, at the same
tick, before and after, and put the two images in front of you. If you do not like
it, we revert that commit and nothing else is affected.

That is not a guarantee that it will look good. It is a guarantee that it will
never look bad *for long*, and that you will always be the one deciding.
