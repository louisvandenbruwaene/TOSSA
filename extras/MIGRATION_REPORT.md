# PIXELTOSSA - pixel-art remaster preparation

**Branch** `PIXELTOSSA`, branched from `main` at `d8e8102`.
**Working copy** `~/Projects/PIXELTOSSA` (a `git worktree`, so `~/Projects/TOSSA` stays parked
on `main` and `/Applications/TOSSA.app` - whose project path is hard-coded outside the repo -
keeps launching the original).

Gameplay is untouched. No mechanic, constant, timing, hitbox, score term, input binding or
save key was changed.

---

## 1. Files changed

### Modified (2)

| File | Change |
|---|---|
| `Game.gd` | +447 / -38. **All 38 removed lines reappear verbatim among the additions** - they are re-indentations from wrapping two blocks in an `if`, not deletions. Verified mechanically: `comm -23` of removed-vs-added lines is empty. |
| `project.godot` | +30. Pixel-art rendering and texture-import defaults (section 3). |

The `Game.gd` diff is exactly three kinds of thing:

1. one new self-contained `#region PIXEL-ART RENDER SEAM` (~200 lines, no call sites in the
   simulation),
2. **20 seam call sites**, each an `if art_blit…(): return` guard whose false branch is the
   original code, unmodified,
3. four lines in `_ready`/`_notification` to boot the bank and parse three new dev flags.

### Added

- `Assets/` + six subfolders (`Characters/ Props/ Backgrounds/ UI/ Effects/ Fonts/`), 31
  placeholder PNGs, `Assets/README.md` (authoring rules and the full key table).
- `Resources/art_manifest.json` (documented, **registers nothing**),
  `Resources/art_manifest.placeholder.json` (registers all 31), `Resources/README.md`.
- `Scenes/README.md` - the folder exists; why it is empty is section 2.
- `scripts/gen_placeholders.gd`, `scripts/README.md`.

### Requested but deliberately not created

**`Scripts/`.** This machine's filesystem is case-insensitive (APFS default), so `Scripts/`
and the repo's long-standing `scripts/` are the *same directory* - `mkdir Scripts` succeeds
and silently does nothing. Renaming `scripts/` to free the name would break the `Makefile`,
`.githooks/`, `docs/`, the root README index and every path in `lib.sh`. One folder, lowercase,
documented in `scripts/README.md`. If runtime GDScript ever lives outside `Game.gd`, it should
go in a non-colliding folder (`Runtime/`).

---

## 2. Rendering: what changed and what did not

### The decision behind it

The brief asked for drawing to move into dedicated nodes/scenes. `docs/coding_guidelines.md`
lists splitting `Game.gd` into multiple files/classes/autoloads under **"off-limits without
asking first"**, citing `AUDIT_2026-07-26.md`'s P3 finding. You chose the seam layer over the
extraction, so `Game.gd` stays one file (23,866 lines, 706 functions, 1,776 `draw_*` calls) and
the remaster's actual requirement - *every visual replaceable without touching gameplay code* -
is met a different way.

### How it works

```gdscript
func draw_whatever(...):
    if art_blit("group/key", pos, sc, ang, tint): return   # sprite, if one is registered
    <the existing procedural code, untouched>              # otherwise, exactly as before
```

`Game.gd` never names a PNG. It asks for a **seam key**; `Resources/art_manifest.json` decides
whether that key resolves to a texture. Adding art is a data edit. Removing it is deleting a
line. With the shipped (empty) manifest every call is a dictionary miss, so the default run
draws precisely what `main` draws.

Three entry points: `art_blit` (sized by the art - props, flowers), `art_blit_size` (sized by
the game - heads, hands, boots, gear icons), `art_blit_rect` (sized by a layout box -
backdrops, cards, keycaps).

Two implementation choices worth knowing:

- **Textured `draw_colored_polygon`, not `draw_texture_rect`.** It composes with any
  `draw_set_transform` already in effect - `draw_prop_body`'s squash-and-stretch is exactly
  that case, and `draw_texture_rect` would have needed its own transform and silently dropped
  the squash. It also takes rotation for free, and it is **one engine call per sprite** against
  the dozens each procedural prop spends today. Per `docs/coding_guidelines.md` (~5µs per call,
  not per vertex), sprites should make this file *faster*.
- **Sprites snap, paint does not.** `art_snap` rounds blits to the 4px art grid.
  `snap_2d_vertices_to_pixel` is left **off** at project level on purpose: it would snap every
  procedural vertex too and destroy the explicit alpha feathers this project's triangle edges
  rely on. Turn it on at the end of the remaster.

### The 20 seam points

| Group | Keys | Notes |
|---|---|---|
| `prop/*` | ball egg ring club knife torch chainsaw | seamed at `draw_prop_rich`, the single dispatcher - so one PNG replaces a prop on the **stage, the shop card, the tutorial kit panel and the skills preview at once**. `draw_prop_icon` was seamed for free. |
| `char/*` | head, head_back, hat_top, glasses, helmet, boot, hand_open/closed, glove_open/closed | all sized off the caller's radius/height, so art can never renegotiate the settled stance or proportions |
| `bg/*` | seven venues | replaces the sky gradient + set dressing **only** |
| `ui/*` | keycap, card_skill, card_trick, gear_`<id>` | keyed by id, not row index |
| `fx/*` | flower_t0/1/2, tomato | one key per flower tier |
| font | `Assets/Fonts/pixel.*` | by filename, not manifest |

### What stays procedural on purpose

- **Stage lighting** - spotlight cone, veil, footlights, `stage_darkness`, Blackout. The cone
  narrows and warms as a streak builds; that is the stage reacting to the player. A backdrop
  with lighting baked in would freeze it.
- **The catch glow** and other feedback flashes - gameplay signal, not artwork, and it has to
  read identically while the art is in flux.
- **The flower stem** - a direction (it points back at whoever threw it), not a picture.
- **The whole HUD text layer** - `fit_text`/`fit_size`/`draw_wrap_fit` are legibility
  machinery, not decoration.

### Two hazards found and handled

- `draw_hand` draws the **held props** after the mitt. An early `return` there would have made
  every held prop invisible. Only the mitt is replaced; the function runs on.
- `draw_flower` draws the stem **before** the bloom, so the seam sits after it.

---

## 3. Project configuration

```ini
[importer_defaults]
texture={ "compress/mode": 0, "mipmaps/generate": false,
          "process/fix_alpha_border": false, "detect_3d/compress_to": 0 }

[rendering]
textures/canvas_textures/default_texture_filter=0   ; Nearest
2d/snap/snap_2d_transforms_to_pixel=true
2d/snap/snap_2d_vertices_to_pixel=false             ; see above - flip at the END
```

Verified: `Assets/Props/ball.png.import` came out with `compress/mode=0`,
`mipmaps/generate=false`, `process/fix_alpha_border=false` without anyone touching the import
dock.

### Recommended internal resolution: **320x180** - and the reason is specific

Not the default answer; the arithmetic. The stage's coordinate space is **1280x720** and is not
negotiable - `inner_pos`/`outer_pos`, every hitbox, `--collcheck`'s clearances and the whole
throw model are written in it. **1280x720 is exactly 4x 320x180.** So art authored at 320x180
density blits at 4x with every source pixel landing on an exact 4x4 block, no resampling, and
on the day the viewport genuinely drops to 320x180 every asset is already the right size.
`ART_PIXEL = 4` is that ratio, and it is the only number the art has to respect.

**The viewport is NOT switched to 320x180 yet, and should not be until the remaster is done.**
Measured, not assumed: Godot's `CONTENT_SCALE_MODE_VIEWPORT` makes `content_scale_size` both
the framebuffer *and* the space the game draws in, and `content_scale_factor` does not separate
them (set to 0.25 it reads back 1.0). A live 320x180 viewport hands `get_viewport_rect().size`
= (320, 180) to a file whose every font size and panel inset is written in 1280x720 units; the
HUD collapses into overlapping boxes with text four times too big. Porting the layout is real
work, and it belongs at the **end**.

Integer scaling likewise waits for that switch: at a 1280x720 base on this display it would
force 1x with letterboxing, which is a downgrade today and correct the moment the base is 320x180.

---

## 4. Verification

| Check | Result |
|---|---|
| `godot --check-only` | clean |
| `scripts/validate.sh` (7 checks) | **all checks passed** |
| Uncalled-function scan | 15 - the same 15 as `main` (one I had added, `art_has`, was removed) |
| `--ladder` output, main vs branch | **byte-identical** (19 lines) |
| `--collcheck` output, main vs branch | **byte-identical** (10 lines) |
| Removed lines genuinely deleted | **none** - `comm -23` removed-vs-added is empty |
| Save format | untouched; no new persisted key, no settings key, no migration |

Frame-hash comparison against `main` was attempted and **discarded as invalid**: `main` is not
frame-reproducible against itself (two captures of the same seed and tick differ), because the
catch chance model and crowd throws use unseeded `randf`. The two deterministic text harnesses
above are the honest equivalence test.

Real save data was backed up before any harness run, per the standing rule.

---

## 4b. First real art: four props (added after the initial pass)

`scripts/gen_prop_art.gd` draws **ball, ring, club and knife** as pixel art matching what the
game draws today, and they are **registered and live** in `art_manifest.json`. The branch's
default run is therefore no longer identical to `main` by design: those four props are sprites
now, everything else is still code.

The art is **source, not binary**. Each sprite is a block of text you can edit:

```gdscript
"club": {
    "pivot": [0.5, 0.558],
    "rows": [".r.", "rrr", "rrr", "rrR", "www", "rrR", "www", ...],
    "pal":  { "r": Color(0.90, 0.35, 0.38), "w": Color(0.96, 0.92, 0.85), ... },
},
```

Change a character, re-run, look at it. A 6x6 ball is 36 decisions and they belong in a diff.

### Two real defects this work exposed in the seam

1. **The tint was going to all seven props.** `draw_prop_rich` hands `col` only to the round
   ones (`cap_ball`/`cap_egg`/`cap_ring`); club, knife, torch and chainsaw carry their own
   painted palettes and never see it. And `col` is `ball_color(i)`, four colours cycled by
   *index*, set on every prop regardless of kind. So a club sprite would have been repainted
   gold, orange, red or blue depending on which slot it was in. Now only the round props are
   tinted, stated as "everything except the painted four" so a prop added later inherits the
   right behaviour.

2. **Props were being blitted at fractional scale.** `art_blit` multiplied by `sc`, and for
   props `sc` is `prop_scale`: 1.0 / 1.1 / 1.5 / 1.6 / 1.7 / 1.75 / 1.9, not one of them an
   integer. That draws a club's pixels at 6.4 screen px each beside a ball's at 4, which is
   the classic pixel-art mush. `art_blit_prop` now fixes every prop sprite at exactly
   `ART_PIXEL` screen px per source pixel and treats `sc` as an **integer zoom** instead, so
   the stage is 1:1 and the shop is a clean 3x magnification.

### What authoring these four taught, that the next batch should inherit

- **Sizes are derived, never chosen.** Texture size = (local extent x `prop_scale`) /
  `ART_PIXEL`. The table is in the script's header.
- **Pivots are derived too, and are not the centre.** `cap_club` and `cap_knife` both
  `draw_set_transform(p, ang)`, and the shape is not symmetric about `p`: a club spans
  -22.5..+17.8 (pivot 0.558 down the sprite), a knife -26..+13.2 (0.663). Getting this wrong
  makes a prop orbit a point instead of spinning about it, and it looks like bad art.
- **A tint can only darken.** So on a greyscale prop the highlight has to be the brightest
  value in the file, and everything else sits below it.
- **Long props are startlingly narrow.** A club is 40 units long and 8 wide, which at this
  density is **3 pixels across**. Its whole character has to live in the silhouette and the
  two bands.
- **The first ball had four tonal values and read as noise.** This file's own doctrine
  explains why (a painted highlight shimmers on a small moving object and has been reverted
  twice). Three values, seam kept, sheen dropped.

### One open question for you

The shop magnifies a prop icon 3x, so the **6x6 ball becomes a 6x6 image blown up**, not a
detailed one. It reads fine on the stage and blocky on a shop card. Two honest options: accept
it (at a true 320x180 the shop card is small, so 6px is correct), or give the shop a second,
larger icon per prop. That is a taste call, not a technical one, so I have left it as it is.

---

## 5. Placeholder artwork

31 PNGs from `scripts/gen_placeholders.gd`: white silhouettes with a grey keyline and **one
magenta pixel at the top-left**, authored at 320x180 density with sizes derived from the live
drawing constants (`BALL_RADIUS_PX = 11` → a 22-unit ball → 6 art pixels). White because props,
hands and gear are drawn through the game's own colour as a tint.

**No existing art was upscaled.** The current art is vector-smooth; scaling it produces a
blurry sprite, not pixel art. Every placeholder is drawn from scratch as a silhouette.

They are **not registered by default**. To see the pipeline live:

```
godot --audio-driver Dummy -- --artmanifest res://Resources/art_manifest.placeholder.json
```

Confirmed working end to end: tinted and rotated clubs, a mirrored hand from one asset, a
gridded backdrop, keycaps stretched to their label width, all at nearest-neighbour.

### New dev flags (debug builds only, after the bare `--`)

| Flag | Does |
|---|---|
| `--artreport` | prints every seam key the session reached, marked `[sprite]` / `[proc]`. **The remaster to-do list, generated from the code.** |
| `--artmanifest <path>` | load a different manifest - try placeholders without touching the real one |
| `--procart` | force every key to miss: instant A/B of a sprite against the drawing it replaced |
| `--pixel` | downsample a `--shot` capture to 320x180 with nearest, then back up - "what does this screen look like as pixel art?" |

---

## 6. Remaining procedural drawing

Effectively all of it. 1,776 `draw_*` calls; the seam intercepts 20 element classes. This is
the intended state of a *preparation* branch: the pipeline is finished, the art is not started.

Untouched and un-seamed, roughly in order of surface area:

- **Every screen's layout and chrome** - menu, day hub, shop, tailor, skills, sheet, results,
  pause, settings, credits, establishing cards. ~15 `#region` blocks of `draw_*`.
- **The juggler's body** - torso, vest, arms, legs, hair, face (`draw_face_v2`), the IK
  solver's limb capsules. Only head/hands/hat/glasses/helmet/boots are seamed. This is the
  most delicate remaining target: the stance and proportions are settled and off-limits.
- **Venue set dressing** - `draw_venue_dressing` and its ~20 helpers (`draw_bigtop`,
  `draw_arena_bowl`, `draw_theatre_boxes`, `draw_jumbotron`, …). Reachable in one step via the
  `bg/*` keys, which is why those come first.
- **Skill card faces** - art, pips, rosettes, backs.
- **Particles and stains** - trails, spin streaks, egg shards/splats, tomato stains, the baked
  flower pile (`_bake_pile` / `_soup_*` - note these are a *separate* path from `draw_flower`
  and will need their own seam).
- **Stage lighting** - deliberate, see section 2.

---

## 7. Suggested next steps

**In this order**, because each one de-risks the next.

1. **Look at `--pixel` on five screens before drawing anything.** The stage capture already
   says the figure and props read beautifully at 320x180 and **the HUD text does not** - at 4x
   down, a 13px label is 3px tall. That is the single biggest open question of the remaster and
   it is a *layout* question, not an art one. Answer it first; it may mean fewer, larger HUD
   panels, which changes what art gets drawn at all.

2. **Pick a bitmap font and drop it at `Assets/Fonts/pixel.ttf`.** One file, no manifest line,
   and it changes the feel of every screen at once - by far the largest visual return per hour
   on this list. `setup_pixel_font` already forces antialiasing, subpixel positioning and
   hinting off, which is the difference between pixel type and a small blurry font.

3. **Do the seven props next** (`prop/*`). Smallest assets, hardest-working: one PNG each and
   it lands on the stage, the shop, the tutorial and the skills preview simultaneously. Author
   them white; `--procart` A/Bs each one against the drawing it replaced.

4. **Then the seven backdrops** (`bg/*`). Biggest area, and they retire ~20 dressing helpers in
   one move. Paint the *scenery only* - no lighting, no spotlight, no footlights.

5. **Then the figure.** Extend the seam to the body parts, but treat the current drawing as the
   spec: trace the silhouette at the size it already occupies rather than redesigning it. The
   stance is settled and reshaping it as a side effect is explicitly off-limits.

6. **Convert the hands to `AnimatedSprite2D`** when the art exists. `char/hand_open` /
   `hand_closed` is a two-frame stand-in for a hand that opens and closes continuously
   (`hclose` is a float, and that motion is how the no-crossing choreography reads). This is
   the first thing that genuinely earns a scene in `Scenes/`.

7. **Only at the end:** port the HUD layout to 320x180, switch the viewport to a real 320x180
   with integer scaling, and flip `snap_2d_vertices_to_pixel` on. All three are safe once no
   procedural drawing is left to be measured in the old coordinate space.

Throughout: `--artreport` after driving a screen tells you what is still procedural on it, and
`scripts/validate.sh` stays green because nothing in this pipeline can reach the simulation.
