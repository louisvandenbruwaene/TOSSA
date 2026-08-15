#!/usr/bin/env python3
"""Put the KNIFE'S OWN HANDLE on the club, and rebuild the torch around a tapered one.

WHY A TEMPLATE LIFTED FROM THE KNIFE AND NOT A HANDLE DRAWN TO MATCH IT (2026-08-15, Louis:
"just give the torch and club the exact handle from the knive"). The previous pass drew a
grip *like* the knife's - same 8px width, same collar, same wrap-every-six rhythm - and the
verdict was "the handles are way too thick". They were not. Measured, all three grips are 8
across on the card and 7 at stage size; they were already identical to the pixel.

**WHAT DIFFERED WAS VALUE, AND VALUE IS WHAT READS AS THICKNESS.** The knife's grip runs a
mid-brown around (82,49,33) banded with ribs at (19,9,8) - a 3:1 step, nearly black. The
drawn one ran near-white (255,240,204) banded with (176,136,72), a 1.4:1 step. A pale object
with weak banding advances and fattens; a dark object with hard banding recedes and reads
slim. Two grips of exactly the same width looked like different objects, and the way to stop
guessing about that is to stop redrawing the thing and copy it.

So `knife_handle()` lifts rows 50..84 of `big_knife.png` as a LUMINANCE-RATIO template - the
collar, twenty-six rows of grip with its ribs, the brass cap - and every prop stamps that
same template through its own ramp. The club and torch get a bone ramp (Louis, earlier:
"white handle for the club"), but they get the knife's CONTRAST, which is the part that was
actually wrong.

THE TORCH'S BODY IS NOW ITS HANDLE. Louis: "the red part becomes the handle completely: i
want a conelike handle, where the thinnest part is the width of the knive handle, and the
widest part is the current widest part of the torch, linearly growing wider and keeping the
design of the knive handle all the way". So there is no separate sleeve any more - one cone
running 8px at the foot to 15px at the shoulder, carrying the same rib rhythm the whole way,
with the knife's collar as its golden border at the top.

AND THE FLAME SITS ABOVE THE WICK RATHER THAN OVER IT ("with a metal cilinder on top with
the flame above that (not layered over it)"). This is the one part that was never an art
problem: the wick was a black cylinder INSIDE the flame band, so the game's own live fire was
drawn straight over it and it never showed in play. The wick is a thin metal cylinder now -
deliberately thinner than the handle's thinnest point - and the painted flame starts ABOVE
it, so `_TORCH.base_row` lands on its top and the drawn fire begins where the wick ends.

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

# The knife's handle, by row, measured off big_knife.png. Everything below is derived from
# these two numbers, so a re-rolled knife needs them re-measured and nothing else.
KNIFE_HANDLE_TOP = 50
KNIFE_HANDLE_BOT = 84

# The bone ramp, darkest first. Five steps of the locked palette, spanning a range close to
# the knife's own 3:1 rather than the 1.4:1 that made the last grip look fat.
# ...and it is normalised over the GRIP's own range, not the whole handle's. The handle
# includes a brass collar at 193 luminance; measured against that, the grip's body sits at
# t=0.3 and comes out TAN however light the ramp is - which is how the first attempt at a
# "white handle" produced a brown one. Normalising over the grip alone lets its body reach
# the top of the ramp and its ribs the bottom, which is what carries the knife's contrast
# into a bone-coloured object.
BONE = [(112, 72, 48), (176, 136, 72), (216, 160, 104), (242, 204, 140), (255, 240, 204)]
BRASS = [(112, 72, 48), (152, 96, 56), (176, 136, 72), (255, 217, 102), (255, 240, 204)]
STEEL = [(76, 66, 56), (104, 96, 80), (158, 145, 133), (204, 189, 168), (255, 255, 255)]


def lum(rgb) -> float:
    return 0.2126 * float(rgb[0]) + 0.7152 * float(rgb[1]) + 0.0722 * float(rgb[2])


def knife_handle():
    """(rows, lo, hi) - the knife's handle as per-row (x-offset, luminance) plus its range.

    Kept as ratios rather than colours so one shape can be stamped in bone, brass or steel.
    Each row's x positions are relative to its own centre, which is what lets the torch
    stretch a row to a different width while keeping the rib pattern intact.
    """
    a = np.asarray(Image.open(PROPS / "big_knife.png").convert("RGBA")).astype(float)
    op = a[..., 3] > 40
    rows = []
    for y in range(KNIFE_HANDLE_TOP, KNIFE_HANDLE_BOT + 1):
        xs = np.where(op[y])[0]
        if len(xs) == 0:
            continue
        cx = (xs.min() + xs.max()) / 2.0
        rows.append([(x - cx, lum(a[y, x, :3])) for x in xs])
    # the GRIP's range (rows 4..29 of the handle), for the reason in BONE's note above
    grip = [v for r in rows[4:30] for _, v in r]
    return rows, min(grip), max(grip)


def ramp_at(ramp, t: float):
    return ramp[int(np.clip(t, 0.0, 0.999) * len(ramp))]


def stamp_rows(a: np.ndarray, y0: int, rows, lo: float, hi: float, cx: float, ramp,
               widths=None) -> int:
    """Stamp the template into `a`. `widths[i]` stretches row i to that many pixels."""
    h, w = a.shape[:2]
    for i, row in enumerate(rows):
        y = y0 + i
        if not (0 <= y < h):
            continue
        native = len(row)
        want = native if widths is None else max(2, widths[i])
        for x in range(want):
            # LINEAR sampling across the row, then quantised by the ramp. Nearest-source was
            # tried and is visibly worse on the torch: stretching an 8px row to 15 repeats
            # different source pixels on adjacent rows, so the wrap bands came out as ragged
            # blobs instead of bands. Interpolating first and quantising second keeps each
            # band a straight edge whatever width the cone is at that height.
            u = (x / max(1, want - 1)) * (native - 1)
            i0 = int(u)
            i1 = min(native - 1, i0 + 1)
            f = u - i0
            v = row[i0][1] * (1 - f) + row[i1][1] * f
            t = (v - lo) / max(1e-6, hi - lo)
            c = ramp_at(ramp, t)
            px = int(round(cx - want / 2.0)) + x
            if 0 <= px < w:
                a[y, px] = (c[0], c[1], c[2], 255)
    return y0 + len(rows)


def build_club() -> Image.Image:
    a = np.asarray(Image.open(PROPS / "big_club.png").convert("RGBA")).copy()
    rows, lo, hi = knife_handle()
    # the painted crimson body is rows 4..45; everything under it is replaced by the knife's
    # handle at its NATIVE width - no stretch, no redraw, the same 35 rows it has on the knife
    a[46:] = 0
    stamp_rows(a, 46, rows, lo, hi, 23.0, BONE)
    return Image.fromarray(a, "RGBA")


def build_torch() -> Image.Image:
    a = np.zeros_like(np.asarray(Image.open(PROPS / "big_torch.png").convert("RGBA")))
    cx = 20.0
    rows, lo, hi = knife_handle()

    # --- THE FLAME, lifted from the old card and moved UP so nothing overlaps it. It has to
    # be present and it has to be the topmost thing: derive_stage_props finds it by colour,
    # clears it, and publishes base_row as the first row below it - which is how "the flame
    # above that, not layered over it" becomes a number the game can use.
    # --- THE FLAME IS DRAWN, NOT LIFTED, and it is a MEASUREMENT CARRIER rather than art.
    # Nothing ever displays it: derive_stage_props finds it by colour, clears it, writes
    # `big_torch_body.png` (which is what the manifest points at) and publishes its extent as
    # `_TORCH`, from which the game draws a live animated flame. So what this needs to be is
    # the right SHAPE in the right PLACE, and drawing it beats reusing the old card's fire -
    # that fire was painted wrapped around a black wick, so lifting only its flame-coloured
    # pixels left a hollow ring, and lifting the lot brought the old wick with it and gave the
    # torch two.
    #
    # It is rasterised from the same profile Game.gd's flame_shape uses, so the measurement
    # the pipeline takes describes the silhouette the game will actually draw.
    prof = [(0.00, 0.00), (0.52, -0.07), (0.62, -0.26), (0.47, -0.48),
            (0.27, -0.70), (0.11, -0.87), (0.00, -1.00)]
    FLAME_H, FLAME_W = 26, 11.5
    base_y = 32                      # the last row of fire, one clear of the wick below
    for i in range(FLAME_H):
        v = -i / (FLAME_H - 1.0)
        hw = 0.0
        for k in range(len(prof) - 1):
            if prof[k + 1][1] <= v <= prof[k][1]:
                span = prof[k][1] - prof[k + 1][1]
                f = 0.0 if span == 0 else (prof[k][1] - v) / span
                hw = (prof[k][0] * (1 - f) + prof[k + 1][0] * f) * FLAME_W
                break
        y = base_y - i
        for x in range(int(round(cx - hw)), int(round(cx + hw)) + 1):
            if 0 <= x < a.shape[1] and 0 <= y < a.shape[0]:
                # THE TIP IS ORANGE, and that is not only truer to a flame - it is what keeps
                # the strip able to find it. The band is defined by ORANGE pixels; a tip drawn
                # in the pale core colour has no orange beside it, so the band starts one row
                # below and that lone white pixel survives into the stripped sprite as a speck
                # floating above the fire. Measured: the body came back starting at row 7.
                d = abs(x - cx) / max(0.6, hw)
                c = ((255, 240, 204) if d < 0.35 else ((248, 184, 88) if d < 0.7 else (240, 104, 64))) if hw >= 2.0 else (240, 104, 64)
                a[y, x] = (c[0], c[1], c[2], 255)

    # --- THE WICK: a very thin metal cylinder, deliberately narrower than the handle's
    # thinnest point (8) so it reads as a separate fitting rather than as more handle.
    wick_w, wick_h, wick_y = 6, 7, 33
    x0 = int(round(cx - wick_w / 2.0))
    for i in range(wick_h):
        for j in range(wick_w):
            t = j / max(1.0, wick_w - 1)
            c = STEEL[4] if t < 0.3 else (STEEL[2] if t < 0.7 else STEEL[0])
            if i == wick_h - 1:
                c = STEEL[0]
            a[wick_y + i, x0 + j] = (c[0], c[1], c[2], 255)

    # --- THE CONE. One handle from the shoulder to the foot: the knife's own rows, tiled to
    # fill the length, each stretched to a width running linearly from 15 at the top to 8 -
    # the knife's own grip - at the bottom. The collar leads it (the "golden border at the
    # top") and the cap closes it.
    top, bot = wick_y + wick_h, 93
    n = bot - top
    collar, grip, cap = rows[:4], rows[4:30], rows[30:]
    seq = list(collar)
    while len(seq) < n - len(cap):
        seq.append(grip[len(seq) % len(grip)])
    seq = seq[:n - len(cap)] + list(cap)
    widths = [int(round(16 - (16 - 8) * (i / max(1, len(seq) - 1)))) for i in range(len(seq))]
    for i in range(len(collar)):          # collar and cap stay proud of the local cone width
        widths[i] += 2
    for i in range(len(cap)):
        widths[-1 - i] += 2
    stamp_rows(a, top, seq, lo, hi, cx, BONE, widths)
    stamp_rows(a, top, collar, lo, hi, cx, BRASS, widths[:len(collar)])
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
