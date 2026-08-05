# Assets — editing the art

**Nothing in here is referenced by name from `Game.gd`.** The only thing connecting a
file to the screen is a line in `../Resources/art_manifest.json` keyed by a seam key.
That indirection is the point: replacing a visual is a data edit, never a code edit.

Every sprite is a plain PNG on a **640x360 pixel grid** (one art pixel = a 2x2 screen
block, `ART_PIXEL = 2`). Open any of them in Aseprite and change whatever you like. This
file covers the two things that are not obvious: which colours to use, and how to stop a
generator eating your edit.

---

## 1. Load the palette first

`../Resources/palette/palette.gpl` — in Aseprite: **Palette menu → Load Palette**.

48 colours pulled out of TOSSA itself: the ~1300 `Color()` literals in `Game.gd` weighted
against 13 real screen captures, clustered perceptually. Staying inside it is what keeps a
hand-edited sprite looking like it belongs to the same game. Nothing enforces it, but
everything generated obeys it.

## 2. Your edits are protected, and here is exactly how

Almost every file here is **generated** — derived from the game's own render, or made with
PixelLab and post-processed — and regenerating is cheap, so it happens often. That is a
trap unless something guards it, because a clobbered edit does not error. It just quietly
vanishes, at the moment someone re-runs a script for an unrelated reason.

`../scripts/artguard.py` records the SHA-256 of every file a generator writes, in
`.generated.json`. Before writing again it re-hashes what is on disk:

| what it finds | what it does |
|---|---|
| hash matches what it last wrote | nobody touched it — overwrites freely |
| hash differs | **you edited it — skips, and says so** |
| no record at all | unknown provenance — treats it as hand-made and skips |

So the normal workflow is simply: **edit in Aseprite, save, done.** From then on that file
is yours and no generator will touch it.

Two escape hatches for when you want the generator back:

```bash
.venv/bin/python scripts/pixelise_prop.py club --force   # discard my edit, regenerate
.venv/bin/python scripts/artguard.py --relock            # accept everything on disk as canonical
```

## 3. Sizes and pivots are derived — do not "fix" them

A sprite's dimensions are not a taste decision. Texture size = (the extent the game draws
it at) ÷ `ART_PIXEL`. **Resizing a canvas breaks the blit**, because `art_blit_size`
stretches the texture to the box the game asks for: a 27x26 head in a 54x54 box scales 2.0
across and 2.077 down, and fractional scaling is exactly what makes pixel art mush. Change
the pixels, keep the canvas.

Pivots are worse than arbitrary — they are the point the game *rotates* the shape about,
and three of the seven props are not centred (club 0.558 down its sprite, knife 0.624,
torch and chainsaw off-centre horizontally too). Get one wrong and the prop orbits a point
instead of spinning about it. Re-measure with `--propref`, never by eye.

## 4. Which files take a tint, and why it matters

Some sprites are drawn through a colour the game picks, so they are authored **greyscale
with the highlight at pure white** — a multiply can only darken, so any highlight short of
255 permanently dulls the object. Painting one of these in colour comes out muddy.

| greyscale (tinted at draw time) | full colour (own paint) |
|---|---|
| `Props/{ball,egg,ring}` and their `big_` versions | `Props/{club,knife,torch,chainsaw}` and `big_` |
| `Characters/hand_*`, `glove_*` | `Characters/head` |
| `Characters/torso_*`, `legs_*` | `Backgrounds/*` |

**Two sizes per prop.** `prop/*` is the stage sprite, tiny because the stage genuinely
draws a club 13x64 screen px. `prop_big/*` is the shop card sprite, authored at card size,
because magnifying the stage sprite produced a blown-up 6x32 image rather than a detailed
one.

**The body is one file per costume region**, because `costume_palette()` repaints the
outfit per venue across five colours. `torso_suit` is the jacket, `torso_vest` the
waistcoat, `legs_trouser` the legs; each is tinted separately at draw time, which is what
keeps the wardrobe working. Their greyscale value is a *ratio*: white means "full costume
colour here", darker means "the drawing shaded it here". `torso_button` is the exception —
buttons are a fixed colour, not a costume one.

## 5. Folders and seam keys

| Folder | Seam keys |
|---|---|
| `Props/` | `prop/{ball,egg,ring,club,knife,torch,chainsaw}` and `prop_big/*` |
| `Characters/` | `char/head`, `char/hand_open`, `char/hand_closed`, `char/torso_{suit,collar,vest,button}`, `char/legs_trouser`, plus `head_back`, `hat_top`, `glasses`, `helmet`, `boot`, `glove_*` (not yet authored) |
| `Backgrounds/` | `bg/{backyard,street_corner,small_theatre,the_circus,championship,world_arena,the_midnight_show}` — full 640x360. **Do not paint the lighting in**: the spotlight, veil and footlights stay procedural because they react to the player |
| `UI/` | `ui/keycap`, `ui/card_skill`, `ui/card_trick`, `ui/gear_<id>` — stretched to a box the layout computed, so proportion matters and absolute size does not |
| `Effects/` | `fx/flower_t0..2`, `fx/tomato` |
| `Fonts/` | `pixel.ttf` (Pixel Operator, CC0). Only crisp at **multiples of 4** — see `ps()` in `Game.gd` |

## 6. Turning a sprite off

Delete its line from `../Resources/art_manifest.json` and that element goes straight back
to being drawn by code. `--procart` forces *everything* procedural for an A/B.
`--artreport` prints every seam key a session actually reached, marked `[sprite]` or
`[proc]` — generated from the code, so it can never go stale.

## 7. Regenerating from scratch

```bash
# props: render each isolated through the real drawing code, then reduce
godot --audio-driver Dummy --path . -- --propref club --shot artifacts/prop_refs/club.png --shotat 30
.venv/bin/python scripts/pixelise_prop.py club

# the figure: three passes (see scripts/pixelise_char.py for why three), then derive
godot --audio-driver Dummy --path . -- --charref --artboxes --shot D/juggler.png --shotat 200 > D/boxes.txt
godot --audio-driver Dummy --path . -- --charref --charsuppress --shot D/juggler_off.png --shotat 200
godot --audio-driver Dummy --path . -- --charref --charid --shot D/juggler_id.png --shotat 200
.venv/bin/python scripts/pixelise_char.py D

# a backdrop from the game's own dressing
godot --audio-driver Dummy --path . -- --bgref --demo --booking --venue 0 --shot D/v0.png --shotat 400
.venv/bin/python scripts/pixelise_bg.py D/v0.png backyard
```

**`--shot` lies when the window is not focused** — it hands back the last *presented*
frame, which can be seconds stale. Give the window focus a couple of seconds in, or the
capture will be of an older screen.
