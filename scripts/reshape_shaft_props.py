#!/usr/bin/env python3
"""Give the club and the torch ONE handle, authored, and reshape the torch's body.

WHY THE HANDLE IS AUTHORED AND GRAFTED RATHER THAN PROMPTED (2026-08-15, Louis: "i want you
to use the handle of the knive for the torch and club ... give the exact same handle to the
club as to the torch"). "The exact same handle" is a constraint a generator cannot meet: two
paintings of the same description are two different objects, and the whole point of the ask
is that a player should recognise one grip across three props. So the grip is drawn here,
once, from a table, and stamped onto both cards. It is the same reasoning as the top hat in
draw_gear_sprites.py - when the requirement is exactness at a small size, author it.

WHAT IS COPIED FROM THE KNIFE is its STRUCTURE, measured off `big_knife.png`: a bright collar
two rows deep, a grip eight pixels wide banded with a darker wrap every six rows, and a cap
at the foot. That reads as a wrapped grip at card size and still reads as "banded" at the
14px the stage sprite gets, which is why it beat the club's old plain shaft.

WHAT IS NOT COPIED IS THE COLOUR. Louis: "keep the color palette (white handle for the club)".
The knife's grip is dark leather over wood; the club's is bone. Only the light/dark ROLES
carry over, filled from each prop's own ramp - so the three props share a design language
without the club turning brown.

THE CLUB'S KNOB IS SMALL NOW, and this is a real correction rather than taste. It was 13 px
across a 7 px shaft - nearly twice the handle - which is why the first pass at this prop read
as a lollipop and why the fix only half-took: the handle got fatter and the knob stayed huge.
A juggling club's knob is a stop for the hand, not a weight, so it is barely proud of the
grip: 10 against 8.

THE TORCH'S BODY IS NARROWER AND ITS COLLAR IS REAL. Both come from the reference Louis
supplied (torch_image.html - a saved image search for the Henrys nite flight torch, whose
photographs are the honest brief). Two things are obvious in them and were wrong here:

  * a juggling torch's coloured section is only MODESTLY wider than its shaft - it is a
    sleeve on a straight tube, not a teardrop. This card had it at 19-21 px over a 4 px
    handle, which is a club silhouette wearing a torch's colours.
  * there is a bright metal COLLAR between the coloured body and the wick, and it is a
    distinct band you can see from across a room. This card had a two-pixel dark line
    there, which reads as a seam rather than as a part. Louis: "i'm missing the small metal
    bar between the flame and the widest part of the torch".

The body is squeezed horizontally rather than redrawn, so the painting's own shading survives
the change; only its width is a decision this script makes.

USAGE
  .venv/bin/python scripts/reshape_shaft_props.py             preview to artifacts/reshape/
  .venv/bin/python scripts/reshape_shaft_props.py --write
  ...then: derive_stage_props.py --write --force, sync _TORCH, make reimport
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

import artguard

ROOT = Path(__file__).resolve().parent.parent
PROPS = ROOT / "Assets" / "Props"

# --- the shared grip, in locked-palette entries ----------------------------------------
# Bone, because the club's handle is bone and Louis asked for the club's palette to stay.
GRIP_LIT = (255, 240, 204)   # #fff0cc
GRIP_MID = (242, 204, 140)   # #f2cc8c
GRIP_DIM = (216, 160, 104)   # #d8a068
WRAP = (176, 136, 72)        # #b08848  the darker band every sixth row
WRAP_DK = (152, 96, 56)      # #986038
BRASS = (176, 136, 72)       # #b08848  collar and cap
BRASS_LIT = (255, 217, 102)  # #ffd966
BRASS_DK = (112, 72, 48)     # #704830

GRIP_W = 8       # the knife's own grip width, and the number everything else is set against
COLLAR_W = 12    # the bright ring where the grip meets the body
COLLAR_H = 2
GRIP_H = 33      # long enough that both props end near their canvas foot - see the layouts
CAP_W = 10       # the torch's foot...
CAP_H = 3
KNOB_W = 12      # ...and the club's knob. "Barely bigger than the handle" (Louis) still has
KNOB_H = 6       # to READ as a knob, and TWO things decide that, not one. At 10 over an 8
                 # grip the first cut had no knob at all; widened to 12 but left as a straight
                 # flare it read as a PLINTH, a column standing on a base. A knob is round, so
                 # the profile has to come back IN at the bottom - 10,12,12,12,11,9 - and be
                 # shaded as a ball rather than as more cylinder.
WRAP_EVERY = 6   # rows between wrap bands, measured off the knife


def col_shade(x: int, cx: float, w: int, lit, mid, dim):
    """One column of a cylinder: lit left of centre, falling away to the right."""
    t = (x - (cx - w / 2.0)) / max(1.0, w - 1)
    if t < 0.28:
        return lit
    if t < 0.62:
        return mid
    return dim


def stamp(a: np.ndarray, y0: int, rows_w, cx: float, body_fn) -> None:
    """Draw centred rows straight into the RGBA array. Everything here works on numpy and
    converts to a PIL image exactly once, at the end - mixing the two mid-draw is what made
    the first version blow up on a read-only image."""
    h, w = a.shape[:2]
    for i, rw in enumerate(rows_w):
        y = y0 + i
        if not (0 <= y < h):
            continue
        x0 = int(round(cx - rw / 2.0))
        for x in range(x0, x0 + rw):
            if 0 <= x < w:
                c = body_fn(i, x, rw)
                if c is not None:
                    a[y, x] = (c[0], c[1], c[2], 255)


def draw_handle(a: np.ndarray, cx: float, y0: int, foot: str) -> int:
    """The shared grip. Returns the first row below it."""
    y = y0
    # the collar: a bright brass ring, lit on top
    stamp(a, y, [COLLAR_W] * COLLAR_H, cx,
          lambda i, x, rw: BRASS_LIT if i == 0 else BRASS)
    y += COLLAR_H

    def grip_body(i, x, rw):
        # THE WRAP BANDS ARE THE WHOLE DESIGN. Two dark rows every sixth is what the eye
        # reads as "wrapped", and it is the one feature of this grip that survives the
        # reduction to stage size - a smooth cylinder there is just a stick.
        band = (i % WRAP_EVERY) in (0, 1) and i > 0
        if band:
            return WRAP if x < cx else WRAP_DK
        return col_shade(x, cx, rw, GRIP_LIT, GRIP_MID, GRIP_DIM)

    stamp(a, y, [GRIP_W] * GRIP_H, cx, grip_body)
    y += GRIP_H

    if foot == "knob":
        # ...BARELY PROUD OF THE GRIP. The old one was 13 across a 7 shaft.
        rows = [10, KNOB_W, KNOB_W, KNOB_W, 11, 9][:KNOB_H]

        def knob_body(i, x, rw):
            # a ball, not a drum: the top-left rows catch the light and the last row is all
            # shadow, which is what closes the shape off instead of cutting it off
            if i >= KNOB_H - 1:
                return GRIP_DIM
            if i <= 1 and x < cx:
                return GRIP_LIT
            return col_shade(x, cx, rw, GRIP_LIT, GRIP_MID, GRIP_DIM)

        stamp(a, y, rows, cx, knob_body)
        y += KNOB_H
    else:
        stamp(a, y, [CAP_W] * CAP_H, cx,
              lambda i, x, rw: BRASS_LIT if i == 0 else (BRASS if i == 1 else BRASS_DK))
        y += CAP_H
    return y


def squeeze(band: np.ndarray, factor: float) -> np.ndarray:
    """Narrow a band of the painting horizontally, keeping its own shading."""
    h, w = band.shape[:2]
    nw = max(2, int(round(w * factor)))
    im = Image.fromarray(band, "RGBA").resize((nw, h), Image.NEAREST)
    out = np.zeros((h, w, 4), np.uint8)
    x0 = (w - nw) // 2
    out[:, x0:x0 + nw] = np.asarray(im)
    return out


def build_club() -> Image.Image:
    a = np.asarray(Image.open(PROPS / "big_club.png").convert("RGBA")).copy()
    # keep the painted crimson body (rows 4..45, measured), clear everything below it
    a[46:] = 0
    draw_handle(a, 23.0, 46, foot="knob")      # 23 is the body's own centre column
    return Image.fromarray(a, "RGBA")


def build_torch() -> Image.Image:
    a = np.asarray(Image.open(PROPS / "big_torch.png").convert("RGBA")).copy()
    cx = 20.0
    # THE HEAD IS NARROWED TOO, AND BY LESS THAN THE BODY. Squeezing only the sleeve left the
    # charred wick wider than the thing carrying it, which is top-heavy and reads as a match
    # rather than a torch. In the reference photographs the wick block is a little PROUDER
    # than the coloured sleeve, so: head 0.78, sleeve 0.72, landing about 16 over 14. The
    # flame rides along with it, which also takes the last of the "orange kite" out of it.
    head = squeeze(a[4:33].copy(), 0.78)    # painted flame plus the charred wick
    body = squeeze(a[37:59].copy(), 0.72)   # the crimson sleeve, measured, then narrowed
    a[4:] = 0
    hk = head[..., 3] > 40
    a[4:4 + head.shape[0]][hk] = head[hk]
    # THE COLLAR: four rows of real metal where a two-pixel dark seam used to be - and note
    # "SMALL metal bar" (Louis). The first cut ran it to 18 across, wider than both the 16px
    # wick above it and the 14px sleeve below, and a ring wider than everything it joins is
    # not a collar, it is a TRAY with a wick standing on it. 15 sits inside the wick and just
    # proud of the sleeve, which is what the reference photographs show.
    stamp(a, 33, [13, 15, 15, 13], cx,
          lambda i, x, rw: BRASS_LIT if i == 0 else (BRASS if i <= 2 else BRASS_DK))
    keep = body[..., 3] > 40
    a[37:37 + body.shape[0]][keep] = body[keep]
    # ...and the handle must FIT. The first layout ran 38 + 28 + 2 + 27 + 3 = 98 rows into a
    # 96-row canvas and simply lost its foot off the bottom edge. The sleeve is 20 rows now,
    # which puts the cap's last row at 95.
    draw_handle(a, cx, 37 + body.shape[0], foot="cap")
    return Image.fromarray(a, "RGBA")


def main() -> None:
    write = "--write" in sys.argv
    force = "--force" in sys.argv
    out = {"big_club.png": build_club(), "big_torch.png": build_torch()}
    if not write:
        d = ROOT / "artifacts" / "reshape"
        d.mkdir(parents=True, exist_ok=True)
        for n, im in out.items():
            im.save(d / n)
            im.resize((im.width * 8, im.height * 8), Image.NEAREST).save(d / f"{Path(n).stem}_8x.png")
        print(f"previews in {d.relative_to(ROOT)} - --write to install")
        return
    res = {}
    for n, im in out.items():
        res[n] = artguard.save_guarded(PROPS / n, lambda p, i=im: i.save(p), force=force)
        print(f"{res[n]:>8}  Assets/Props/{n}")
    artguard.report(res)
    print("\nNext: derive_stage_props.py --write --force, sync _TORCH, make reimport.")


if __name__ == "__main__":
    main()
