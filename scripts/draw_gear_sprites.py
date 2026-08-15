#!/usr/bin/env python3
"""Author the two head-worn gear sprites at their FINAL size, by hand.

WHY THESE TWO LEFT THE DERIVE PIPELINE (2026-08-15)
---------------------------------------------------
`pixelise_char.py` derives every char/* sprite from the game's own render, and that is the
right rule for almost all of them: the figure is settled, so tracing it cannot drift. It
does not work for the top hat or the glasses, and the reason is a property of the objects
rather than a bug in the reducer.

Both are drawn by vector code whose whole design lives in details SMALLER THAN ONE ART
PIXEL. `draw_top_hat` builds its crown from a lit face 0.48r wide, a grosgrain band 0.34r
tall, a pin of radius 0.10r and a top ellipse 0.17r high. At the stage figure's r of about
21 SCREEN px, and ART_PIXEL 2, that pin is one art pixel across and the top ellipse is
under two rows. `draw_worn_glasses` is worse: a lens rim of `maxf(1.1, r * 0.075)` is 1.6
screen px, which is 0.8 of an art pixel - a stroke thinner than the grid it has to land on.

So the derivation was faithful and the result was still wrong, which is the interesting
part. Measured on the sprite it produced:

  * hat_top's crown was 22 art px wide and its lit face was FOUR of them, sitting
    off-centre to the left, with columns 14..25 a flat #241a14. Two thirds of the object
    was one near-black value, so the crown read as a hole in the picture with a stripe
    beside it - exactly what draw_top_hat's own comment says a flat crown does, arrived
    at by way of a sheen too narrow to prevent it.
  * the top ellipse landed as a bare #887870 bar with nothing between it and the
    near-black wall below - a 100-value jump in one row, which reads as a metal lid.
  * the band's PIN came out DARKER than the band it sits on (#4c4238 on #b08848), because
    a one-pixel disc of `accent` got its colour from whatever the reducer averaged under
    it. A jewel that is a dark spot is a smudge.
  * the brim had 2 lit rows over 3 dark ones, so its underside was thicker than its top
    face and the whole brim read as a plank rather than a rim.
  * glasses came out as two brown clumps with no bridge, no rim and no lens - unreadable
    as spectacles at any zoom, which is what a 0.8-art-pixel stroke reduces to.

**A DERIVATION CANNOT INVENT THE PIXEL BUDGET ITS SOURCE ASSUMED IT HAD.** When the source
drawing's smallest meaningful feature is under one output pixel, the honest move is to
re-author the object at the size it will actually be seen, spending the pixels on the
things that make it recognisable. That is what this script does, and it is why these two
keys are removed from pixelise_char.py's PARTS table rather than being left to fight over.

WHAT IS PRESERVED. Every ratio the vector locked in, because those are design and were
argued out already: the crown is about as tall as the head is wide, over a brim wider than
the head; the brim rides low enough to cover the hairline and high enough to leave the
brows clear; the lens sits on the brow line with a real frame around it. The blit rects in
Game.gd are unchanged for the hat, and only corrected for the glasses (see below).

THE GLASSES' BOX WAS ALSO WRONG, and this is a genuine placement bug the redraw exposed
rather than caused. `draw_worn_glasses` blits into a box 0.8r tall centred at -0.06r, so
the sprite's top edge is at -0.46r. `draw_top_hat`'s brim reaches down to -0.40r. The two
overlap by 0.06r, which is why the geared performer has NO FOREHEAD on every screen - the
brim sits straight on the lenses. The vector fallback does not have this problem: its
lenses top out at -0.34r and clear the brim by a comfortable margin. The box here matches
the vector's own extent, and Game.gd is corrected to it.

COLOURS come from the locked 48 (Resources/palette/palette.json) and are named below, so
nothing here needs a snap pass afterwards - it is authored in gamut.

USAGE
  .venv/bin/python scripts/draw_gear_sprites.py            preview to artifacts/gear_draw/
  .venv/bin/python scripts/draw_gear_sprites.py --write    install into Assets/Characters/
  .venv/bin/python scripts/draw_gear_sprites.py --write --force   overwrite hand edits
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

import artguard

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Assets" / "Characters"
PREVIEW = ROOT / "artifacts" / "gear_draw"

# --- the palette entries this art is built from ---------------------------------------
# THE RAMP IS WARM, AND THAT WAS THE SECOND THING TO GET WRONG HERE. The locked 48 has a
# near-NEUTRAL run (#090708 #170f12 #4c4238 #686050 #887870) and it is tempting, because it
# is the longest value ramp in the palette and a top hat is "black". Built on it the hat
# came back with a pale grey column down its left side and a cold grey brim - a chrome
# cylinder standing next to a crimson-and-gold coat, and the one object on the figure that
# belonged to a different picture. The 48 is a WARM theatre palette; a black silk hat in a
# warm room is lit warm, so the sheen has to climb through browns and stop early.
#
# Five steps, and the top one is used SPARINGLY - two pixels of the crown's whole width.
# The derived sprite had steps 0, 1 and 4 with nothing between, so it could only ever be
# black-with-a-stripe; this one is dark everywhere and merely less dark where the light is.
K0 = (23, 15, 18)      # #170f12  the turned-away side of the crown
K1 = (36, 26, 20)      # #241a14
K2 = (71, 41, 28)      # #47291c
K3 = (112, 72, 48)     # #704830
K4 = (152, 96, 56)     # #986038  the sheen's core, and the lit edge of the lid
GOLD_D = (112, 72, 48)   # #704830  the band, turned away
GOLD_M = (152, 96, 56)   # #986038
GOLD_L = (176, 136, 72)  # #b08848  the band, lit
PIN = (248, 184, 88)     # #f8b858  the band's pin - BRIGHTER than the band, unlike before
TORT_D = (56, 24, 16)    # #381810  tortoiseshell frame, shadow side
TORT_M = (71, 41, 28)    # #47291c  tortoiseshell frame
TORT_L = (152, 96, 56)   # #986038  tortoiseshell frame, lit
LENS = (40, 40, 72)      # a smoked lens, dark enough to read as glass over skin
GLINT = (184, 224, 255)  # #b8e0ff  the one catchlight that says "this is glazed"

CLEAR = (0, 0, 0, 0)


def put(px, w, h, x, y, rgb):
    if 0 <= x < w and 0 <= y < h:
        px[x, y] = (rgb[0], rgb[1], rgb[2], 255)


def hspan(px, w, h, x0, x1, y, rgb):
    for x in range(x0, x1 + 1):
        put(px, w, h, x, y, rgb)


# --------------------------------------------------------------------------------------
# THE TOP HAT  (31 x 24, the size Game.gd's blit box asks for at the stage figure's r)
# --------------------------------------------------------------------------------------
#
# Rows 0..1   air (the blit box is a little taller than the object, as it was before)
# Rows 2..4   the top of the crown, seen slightly from below: a shallow ellipse
# Rows 5..16  the crown wall
# Rows 17..18 the grosgrain band
# Rows 19..23 the brim - THREE lit rows over TWO dark ones, the right way round
HAT_W, HAT_H = 31, 24
CROWN_L, CROWN_R = 4, 25   # the crown wall's columns, 22 wide

# The cylinder, as one tone index per crown column. This table IS the fix: a real silk hat
# has a broad soft sheen left of centre falling away to black on the turned side, plus a
# thin reflected rim on the far edge where the room's light wraps round. The derived sprite
# had a four-pixel stripe and eleven columns of one flat value.
#
# THE BANDS ARE FLAT AND THE BOUNDARIES ARE HARD, and getting to that took two wrong turns
# worth writing down, because both are things that are true at a bigger size and false here.
#
# The first was a smooth fractional ramp, ordered-dithered between steps. Dither is the
# textbook answer to a short palette on a curved surface, and this project's own note says
# Bayer is right when the two entries are a hair apart - which these are, being adjacent
# steps of one ramp. It came back a woven basket: 22 columns of checker over 12 rows is not
# a cylinder, it is a texture, and it would be the loudest thing on the figure's head.
#
# The second was to dither ONLY the transition columns and leave flat runs between. That is
# the correct refinement and it still failed, for a reason specific to this object's shape:
# a hat is TALL AND NARROW, so a dithered column is a twelve-row dotted vertical LADDER, and
# the four of them a 22px sheen needs sit close enough together to read as one striped panel.
# Dither hides a step best along the axis the step is NOT running; here every step runs
# vertically, which is the worst case for it.
#
# What is left is what pixel art does at this scale anyway: FLAT FACETS. Five values across
# 22 columns is generous gradation, and a hard boundary between two adjacent steps of a warm
# ramp reads as the facet of a cylinder rather than as an edge. The brightest step is spent
# on ONE column of specular, which is what silk actually does, and never on a band - a broad
# bright band was the "pale plank glued to the crown" that started all this.
CROWN_TONE = {
    4: 1, 5: 2, 6: 3, 7: 3, 8: 3, 9: 3, 10: 2, 11: 2, 12: 2, 13: 2, 14: 1,
    15: 1, 16: 1, 17: 1, 18: 1, 19: 1, 20: 0, 21: 0, 22: 0, 23: 0, 24: 1, 25: 1,
}
RAMP = [K0, K1, K2, K3, K4]
# THE SPECULAR IS A PATCH, NOT A ROD. One column of K4 running the crown's full height is a
# bright vertical stroke, and this project's wardrobe rules already say a stroke reads as
# jewellery - on a hat it read as a brass rail bolted to the front. Two columns, stopped
# well above the band, is a highlight sitting ON a surface instead of a line drawn over one.
SPEC_X0, SPEC_X1 = 7, 8
SPEC_Y0, SPEC_Y1 = 5, 9


def draw_hat() -> Image.Image:
    im = Image.new("RGBA", (HAT_W, HAT_H), CLEAR)
    px = im.load()
    w, h = HAT_W, HAT_H

    # --- the top of the crown. THREE ROWS AND ALMOST FULL WIDTH, which is the difference
    # between a top hat and a loaf: the first cut of this drew the lid as a narrowing stack
    # (12 px, then 18, then 20) and the crown came out domed. A silk hat is a CYLINDER with
    # a flat top that flares very slightly outward as it rises, so the lid is as wide as the
    # wall and only its back corners are knocked off for the ellipse.
    # Row 2 is the far rim, row 3 the lid catching the same light the sheen does, row 4 the
    # near lip - one step down, which is what separates the lid from the wall without a line.
    hspan(px, w, h, 6, 23, 2, K2)
    hspan(px, w, h, CROWN_L, CROWN_R, 3, K3)
    for x in range(6, 11):
        put(px, w, h, x, 3, K4)
    hspan(px, w, h, CROWN_L, CROWN_R, 4, K1)
    for x in range(5, 11):
        put(px, w, h, x, 4, K2)

    # --- the crown wall, one column tone all the way down, then darkened toward the band.
    # Silk falls into shadow where the brim shades it, and that gradient is what stops the
    # wall reading as a flat swatch even where the column ramp is subtle.
    for y in range(5, 17):
        shade = 1 if y >= 14 else 0
        for x in range(CROWN_L, CROWN_R + 1):
            put(px, w, h, x, y, RAMP[max(0, CROWN_TONE[x] - shade)])
        if SPEC_Y0 <= y <= SPEC_Y1:
            for x in range(SPEC_X0, SPEC_X1 + 1):
                put(px, w, h, x, y, K4)
    # the crown's own left and right silhouette edges, one step down so the object has a
    # contour against a bright backdrop without a black outline round the whole thing
    for y in range(6, 17):
        put(px, w, h, CROWN_L, y, K0)
        put(px, w, h, CROWN_R, y, K0)

    # --- the grosgrain band. Two rows, lit from the same side as the crown, and its pin
    # is the BRIGHTEST pixel on the hat rather than a dark spot.
    for x in range(CROWN_L, CROWN_R + 1):
        t = CROWN_TONE[x]
        put(px, w, h, x, 17, GOLD_L if t >= 3 else (GOLD_M if t >= 1 else GOLD_D))
        put(px, w, h, x, 18, GOLD_M if t >= 3 else GOLD_D)
    # THE PIN GOES ON THE LIT SIDE. The derived sprite put it at column 21-22, which is the
    # crown's turned-away third - a jewel catching the light on the side the light does not
    # reach. It sits just off the sheen now, where a hatband pin actually is when the wearer
    # is lit from the left.
    put(px, w, h, 10, 17, PIN)
    put(px, w, h, 11, 17, PIN)
    put(px, w, h, 11, 18, GOLD_L)

    # --- the brim. An ellipse three rows of lit top face over two of dark underside; the
    # derived sprite had that ratio inverted, which is what made it read as a plank.
    hspan(px, w, h, 2, 28, 19, K1)
    hspan(px, w, h, 5, 14, 19, K2)      # where the light lands, in front of the crown
    hspan(px, w, h, 0, 30, 20, K2)
    hspan(px, w, h, 2, 13, 20, K3)
    hspan(px, w, h, 0, 30, 21, K1)
    hspan(px, w, h, 1, 29, 22, K0)
    hspan(px, w, h, 5, 25, 23, K0)
    # the brim's outer tips curl UP a touch, which is the one silhouette cue that separates
    # a top hat from a bowler at this size
    put(px, w, h, 0, 19, K1)
    put(px, w, h, 1, 19, K1)
    put(px, w, h, 29, 19, K1)
    put(px, w, h, 30, 19, K1)
    return im


# --------------------------------------------------------------------------------------
# THE GLASSES  (22 x 7)
# --------------------------------------------------------------------------------------
#
# Seven rows, not eight: the sprite is fitted to a box whose height Game.gd now takes from
# the vector's own lens extent, and an odd height puts the lens centreline on a whole row.
# What has to survive at this size is only three things, and the derived version had none
# of them - a RIM the eye can close into a circle, a BRIDGE joining the two, and one
# GLINT. Everything else (hinges, temple detail, the frame's thickness varying round the
# rim) is under a pixel and is noise.
GL_W, GL_H = 22, 7


def draw_glasses() -> Image.Image:
    im = Image.new("RGBA", (GL_W, GL_H), CLEAR)
    px = im.load()
    w, h = GL_W, GL_H

    # Two lenses, each a 7x5 rounded rectangle - a true circle at radius 2.5 comes out as
    # a plus sign, so the rim is drawn as a rectangle with its corners knocked off, which
    # is the standard way a round thing survives five pixels.
    for cx in (3, 12):
        # the glass first, so the rim can be laid over its edge
        for y in range(2, 5):
            hspan(px, w, h, cx, cx + 6, y, LENS)
        hspan(px, w, h, cx + 1, cx + 5, 1, LENS)
        hspan(px, w, h, cx + 1, cx + 5, 5, LENS)
        # the rim: top and bottom runs, two uprights, corners knocked off
        hspan(px, w, h, cx + 1, cx + 5, 1, TORT_M)
        hspan(px, w, h, cx + 1, cx + 5, 5, TORT_D)
        for y in range(2, 5):
            put(px, w, h, cx, y, TORT_M)
            put(px, w, h, cx + 6, y, TORT_D)
        put(px, w, h, cx + 1, 2, TORT_M)
        put(px, w, h, cx + 5, 2, TORT_D)
        put(px, w, h, cx + 1, 4, TORT_D)
        put(px, w, h, cx + 5, 4, TORT_D)
        # the lit top-left of the rim, so the frame is a material and not a line
        put(px, w, h, cx + 2, 1, TORT_L)
        put(px, w, h, cx + 3, 1, TORT_L)
        # THE GLINT. One pixel of sky-blue on each lens is what makes these read as glazed
        # rather than as two holes, and it is the single most valuable pixel in the sprite.
        put(px, w, h, cx + 2, 2, GLINT)

    # the bridge, sitting on the lens centreline so it cannot read as a moustache
    put(px, w, h, 10, 2, TORT_M)
    put(px, w, h, 11, 2, TORT_M)
    # the temples, running off toward the ears at the same height. One pixel each: they are
    # what stop the object floating in front of the face unattached.
    put(px, w, h, 0, 2, TORT_D)
    put(px, w, h, 1, 2, TORT_M)
    put(px, w, h, 20, 2, TORT_D)
    put(px, w, h, 21, 2, TORT_D)
    return im


def main() -> None:
    write = "--write" in sys.argv
    force = "--force" in sys.argv
    pieces = {"hat_top.png": draw_hat(), "glasses.png": draw_glasses()}

    if not write:
        PREVIEW.mkdir(parents=True, exist_ok=True)
        for name, im in pieces.items():
            im.save(PREVIEW / name)
            im.resize((im.width * 8, im.height * 8), Image.NEAREST).save(
                PREVIEW / f"{Path(name).stem}_8x.png")
            print(f"preview  {name}  {im.size}")
        print(f"\nwrote previews to {PREVIEW.relative_to(ROOT)} - --write to install")
        return

    results = {}
    for name, im in pieces.items():
        dest = OUT / name
        results[name] = artguard.save_guarded(dest, lambda p, i=im: i.save(p), force=force)
        print(f"{results[name]:>8}  {dest.relative_to(ROOT)}  {im.size}")
    artguard.report(results)
    print("\nRun `make reimport` - Godot serves a cached import, not the PNG on disk.")


if __name__ == "__main__":
    main()
