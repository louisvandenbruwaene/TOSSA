# PixelLab Prompt Walkthrough — TOSSA Pixel Art Pass

Work through this top to bottom. Every prompt is typed individually — PixelLab
doesn't understand shorthand lists like "[ball / club / torch]", one prompt =
one asset.

**Detail target (say this in every prompt):**
`high-detail 16-bit pixel art, Stardew Valley pixel density, subtle dithering
and shading, NOT flat/chunky low-res like Celeste`

---

## Step 0 — Style Lock (no screenshot, do this first)

Generate once. Save the output image — you'll upload IT as a style reference
for every single prompt after this.

```
16-bit pixel art, warm circus-spotlight color palette (amber/crimson/cream),
Stardew Valley pixel density, subtle dithering and shading, thick 1px black
outline, NOT flat/chunky low-res like Celeste — character style reference sheet
```

---

## Step 1 — Character rig

**Screenshot to upload:** one clean gameplay screenshot with the juggler
clearly visible, cropped tight to just the figure. Upload this **+** the
Style Lock image as two references for every prompt in this section.

Canvas size: ~96–128px tall per part (not 32px — too small for this detail
level).

Run each of these separately:

```
[upload: style lock + juggler screenshot] — repaint this juggler's HEAD in
16-bit pixel art, Stardew Valley density, dithered shading, transparent
background, isolated part
```
```
[upload: style lock + juggler screenshot] — repaint the TORSO, isolated
segment, transparent background, same style
```
```
[upload: style lock + juggler screenshot] — repaint the UPPER ARM, isolated
segment, pivot point at the top edge, transparent background
```
```
[upload: style lock + juggler screenshot] — repaint the FOREARM, isolated
segment, pivot point at the top edge, transparent background
```
```
[upload: style lock + juggler screenshot] — repaint the THIGH, isolated
segment, pivot point at the top edge, transparent background
```
```
[upload: style lock + juggler screenshot] — repaint the SHIN, isolated
segment, pivot point at the top edge, transparent background
```
```
[upload: style lock + juggler screenshot] — repaint the HAND in OPEN pose,
isolated, transparent background
```
```
[upload: style lock + juggler screenshot] — repaint the HAND in CLOSED
(gripping) pose, isolated, transparent background
```

Accessories — same pattern, one at a time, no need to re-crop the screenshot,
just reuse it:

```
[upload: style lock + juggler screenshot] — repaint the TOP HAT, isolated
accessory, transparent background
```
```
[upload: style lock + juggler screenshot] — repaint the HELMET, isolated
accessory, transparent background
```
```
[upload: style lock + juggler screenshot] — repaint the GLASSES, isolated
accessory, transparent background
```
```
[upload: style lock + juggler screenshot] — repaint the GLOVE in OPEN pose,
isolated accessory, transparent background
```
```
[upload: style lock + juggler screenshot] — repaint the GLOVE in CLOSED pose,
isolated accessory, transparent background
```
```
[upload: style lock + juggler screenshot] — repaint the BOOT, isolated
accessory, transparent background
```

---

## Step 2 — Props

**Screenshot:** optional. These are simple icons — a screenshot of the prop
in-game helps PixelLab match silhouette, but isn't required. Upload the
Style Lock image every time regardless.

Canvas size: 48–64px (large enough to hold Stardew-level detail on a small
icon; 32px is too tight at this density).

```
[upload: style lock] — pixel art JUGGLING BALL, game prop icon, transparent
background, 48x48px
```
```
[upload: style lock] — pixel art JUGGLING CLUB, game prop icon, transparent
background, 48x48px
```
```
[upload: style lock] — pixel art TORCH (lit), game prop icon, transparent
background, 48x48px
```
```
[upload: style lock] — pixel art CHAINSAW, game prop icon, transparent
background, 48x48px
```
```
[upload: style lock] — pixel art JUGGLING RING, game prop icon, transparent
background, 48x48px
```
```
[upload: style lock] — pixel art KNIFE, game prop icon, transparent
background, 48x48px
```
```
[upload: style lock] — pixel art EGG, game prop icon, transparent
background, 48x48px
```

**Extra follow-up prompts** — only for the two props that visibly animate
in the air. Do these AFTER the base icon above exists, referencing that
result:

```
[upload: club icon result] — generate a 4-frame spin animation of this club
rotating end over end, transparent background, consistent size and pivot
```
```
[upload: torch icon result] — generate a 4-frame flame flicker animation for
this torch, flame only changes, handle stays fixed, transparent background
```

---

## Step 3 — Backgrounds (7 total)

**Screenshot:** yes, upload the actual current background screenshot each
time — this is a repaint, not a fresh design, so composition should match.

Canvas size: 320x180 (exact 4x downscale of your 1280x720 screen — keeps
scaling crisp with nearest-neighbor filtering).

Run once per venue, swapping only the bracketed name/description:

```
[upload: style lock + backyard.png screenshot] — repaint this scene in
16-bit pixel art, Stardew Valley density, keep the same composition and
framing: a scruffy backyard practice space, dusk lighting. Split output
into three layers: sky, midground, foreground. 320x180px
```
```
[upload: style lock + street_corner.png screenshot] — repaint this scene,
keep composition: a city street corner busking spot, evening. Sky/midground/
foreground layers. 320x180px
```
```
[upload: style lock + small_theatre.png screenshot] — repaint this scene,
keep composition: a small local theatre stage, warm stage lights. Sky/
midground/foreground layers. 320x180px
```
```
[upload: style lock + the_circus.png screenshot] — repaint this scene, keep
composition: a circus big-top interior. Sky/midground/foreground layers.
320x180px
```
```
[upload: style lock + midnight_show.png screenshot] — repaint this scene,
keep composition: a late-night show under moonlight/stage spots. Sky/
midground/foreground layers. 320x180px
```
```
[upload: style lock + championship.png screenshot] — repaint this scene,
keep composition: a championship arena, bright competitive lighting. Sky/
midground/foreground layers. 320x180px
```
```
[upload: style lock + world_arena.png screenshot] — repaint this scene, keep
composition: the World Arena, grand finale stage, dramatic lighting. Sky/
midground/foreground layers. 320x180px
```

---

## Step 4 — Effects

**Screenshot:** upload the existing `flower_t0/t1/t2.png` and `tomato.png`
as references each time.

```
[upload: style lock + flower_t0.png] — repaint this as a small pixel art
flower bud icon, transparent background, 32x32px
```
```
[upload: style lock + flower_t1.png] — repaint this as a small pixel art
half-bloomed flower icon, transparent background, 32x32px
```
```
[upload: style lock + flower_t2.png] — repaint this as a small pixel art
full-bloom flower icon, transparent background, 32x32px
```
```
[upload: style lock + tomato.png] — repaint this as a small pixel art
thrown tomato icon, transparent background, 32x32px
```

---

## Step 5 — UI / HUD / Menus

**Screenshot:** yes — upload a screenshot of each actual menu/card/panel.
Cards and keycaps are icon-style; panels/menus are repaints like the
backgrounds.

Cards and keycap (icon style, transparent bg, ~64x64px):
```
[upload: style lock + card_trick.png screenshot] — repaint as a pixel art
trick card icon, transparent background, 64x64px
```
```
[upload: style lock + card_skill.png screenshot] — repaint as a pixel art
skill card icon, transparent background, 64x64px
```
```
[upload: style lock + keycap.png screenshot] — repaint as a pixel art
keycap icon, transparent background, 64x64px
```

Panel/border chrome (generate once, reused everywhere as a 9-slice):
```
[upload: style lock] — pixel art UI panel frame, 9-slice border style,
wood-and-brass circus-poster look, transparent center, for dialog boxes and
score HUD
```

Full menu screens — repaint, keep layout, one at a time:
```
[upload: style lock + [screen].png screenshot] — repaint this menu in
16-bit pixel art, Stardew Valley density, keep the exact layout and button
positions: [title screen / day-night hub / shop / venue picker /
records & results screen / settings / pause menu / skills hub]
```
(Run that once per screen name in the bracket — 8 separate prompts.)

---

## Step 6 — Font (skip AI entirely)

Don't generate this. Download a free bitmap font — **Pixel Operator** or
**m5x7** — and drop the `.ttf` into `fonts/` next to `Nunito.ttf`. AI image
tools can't produce a clean, legible bitmap font at readable sizes; a
ready-made one will look better and take five minutes.

---

## Order to do this in
0 (style lock) → 1 (character) → 2 (props) → 3 (backgrounds) → 4 (effects)
→ 5 (UI/menus) → 6 (font swap). Send me the results whenever a batch is
done and I'll wire it into Godot.
