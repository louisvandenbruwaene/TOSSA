#!/usr/bin/env python3
"""Give the club and the torch THE KNIFE'S OWN HANDLE - its pixels, not a likeness of them.

2026-08-15, Louis: "the torch and club handles should be the same as the knive handle (which
looks great), but they aren't: they are fatter, and a different color ... Just use the exact
same thing for the club: same width and colors and decorations etc, for the torch i just
wanted you to let the diameter grow 50% over the entire length of the torch handle (make sure
this looks like a smooth line) and also give it the same decorations and colors etc."

WHAT THE MEASUREMENT SAID, because two previous passes argued about this from theory. Per-row
widths off the cards, before this change:

    knife  collar 12/14/14/12,  grip 8 for 25 rows,  pommel 10/10/10/8/4
    club   collar 12/14/14/12,  grip 8 for 25 rows,  pommel 10/10/10/8/4   <- already identical
    torch  collar 18/18/18/18,  cone 15 -> 9,        pommel 11/10/10/10/10 <- genuinely fatter

So the club was never wider by a pixel, and the last pass was right about that and wrong about
what to do with it: it kept a BONE ramp, so the grip stayed cream (#fff0cc / #d8a068) against
the knife's leather (#986038 / #704830 / #170f12) and read as a different object anyway. Value
does drive apparent thickness - a pale grip advances - but the answer to "use the exact same
handle" is not a better-calibrated ramp. It is the same pixels.

`knife_handle()` therefore returns RGB, not luminance ratios, and the club is a straight
transplant of rows 50..84. The torch is the same rows STRETCHED, so its colours are still the
knife's own and can only ever be palette entries the knife already uses.

**THIS OVERRIDES "white handle for the club"** (Louis, earlier). One handle for three props
cannot also be per-prop colours; asked to choose, he chose the knife's.

THE TORCH'S TAPER IS 8 -> 12, AND HOW THE EDGES STEP IS THE WHOLE JOB. Four pixels of growth
over fifty-three rows is two pixels per side, and rounding a symmetric width to an integer
moves BOTH edges at once - so the silhouette would jump two pixels wide, twice, and read as
three stacked cylinders rather than a cone. Each edge is rounded from the fractional half-width
INDEPENDENTLY, so the left and right steps fall on different rows and the handle widens one
pixel at a time, alternating sides. That is "a smooth line" at this density; there is no
smoother one available.

AND THE RIB RHYTHM SURVIVES THE TILE. The torch's handle is 53 rows and the knife's is 35, so
the grip has to repeat - and repeating rows 55..79 whole leaves a twelve-row plain stretch
across the seam, in a grip whose ribs come every six. The tile is the SIX-ROW UNIT the knife
is actually built from (four plain rows, then a two-row dark wrap): lead in with 54..61, repeat
68..73 five times, tail with 74..79. 8 + 30 + 6 + 4 collar + 5 cap = 53 exactly, with no seam.

Nearest-neighbour sampling is safe here, and was not last time. Stretching a row to a width
that changes every row repeats different source columns on adjacent rows and shreds the wrap
bands into blobs - which is why the previous pass interpolated. But the width is now piecewise
CONSTANT for ten-odd rows at a stretch (only four steps in the whole cone), so every row in a
run maps identically and each band stays a straight edge. Interpolating would instead invent
colours between palette entries, which is the one thing a locked palette cannot take.

The collar and the cap keep their EXCESS over the grip in absolute pixels (+4/+6/+6/+4 and
+2/+2/+2/0/-4), not as a ratio. Scaled proportionally the collar would be 21px over a 12px
cone, and a ring wider than everything it joins reads as a tray with a wick standing on it -
already learned once, see CLAUDE.md. Absolute excess also means the torch's foot is the knife's
pommel to the pixel, since the cone is 8 there.

THE TORCH IS NOT BUILT HERE ANY MORE - IT IS THE pro0 PAINTING (2026-08-15, Louis: "i want
EXACTLY pro0: the same flame, the same handle, everything exactly like pro0 ... take the same
handle as in the png, not the one overlaid on top of it which is the same as the knives").

Two passes before this grafted a generation's head onto the knife's grip, on the rule that a
generated SHAFT never survives the reduction. That rule was learned on s11, whose pole is five
pixels wide and reduces to four; **pro0's shaft is already eight, which is the knife grip's own
width**, so the rule simply does not bite on this painting. The general lesson survives - check
the shaft's width before trusting a generated prop - but "always replace it" was over-fitted to
one example.

What is left is a warm snap, a rim fold (see `build_torch`), and `place`. Everything a player
sees is pro0's own pixels.

`_TORCH` MOVES WHENEVER THE ART DOES and must be copied into Resources/art_manifest.json by
hand. Nothing syncs them and a stale block draws the flame off the end of the handle.

THE FLAME IS NOT ART AND NEVER WAS, which is the answer to "do animate that flame". The painted
fire is a measurement carrier that nothing displays: derive_stage_props finds it, clears it, and
publishes the hole as `_TORCH`, from which `draw_torch_flame` draws a live animated fire every
frame - at exactly the place and size the painting put it, which is what makes "animate that
flame on that exact location as in the png" a measurement problem rather than an art one.

USAGE
  .venv/bin/python scripts/reshape_shaft_props.py             preview to artifacts/reshape/
  .venv/bin/python scripts/reshape_shaft_props.py --write
  ...then: derive_stage_props.py --write --force, sync _TORCH, make reimport
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

import artguard

ROOT = Path(__file__).resolve().parent.parent
PROPS = ROOT / "Assets" / "Props"

# The knife's handle, by row, measured off big_knife.png. Everything below is derived from
# these, so a re-rolled knife needs them re-measured and nothing else.
KNIFE_HANDLE_TOP = 50    # first row of the brass collar
KNIFE_HANDLE_BOT = 84    # last row of the pommel
KNIFE_GRIP_TOP = 54      # first row below the collar
KNIFE_GRIP_BOT = 79      # last row above the pommel
KNIFE_GRIP_W = 8         # the grip's width, and so the torch's thinnest point

# The grip, in the three parts a tile has to respect. Its dark wraps fall at rows 61, 66-67
# and 72-73, so the pattern is a run-in ending on the first rib, then a six-row unit (four
# plain rows, a two-row wrap), then a plain run-out. The knife's own grip is LEAD + 2 tiles +
# TAIL; the torch takes 5 tiles, and the seams are invisible because every one falls where a
# unit already begins.
KNIFE_LEAD = (54, 61)
KNIFE_TILE = (62, 67)
KNIFE_TAIL = (74, 79)

TORCH_GROWTH = 1.5       # Louis: "let the diameter grow 50% over the entire length"

# THE CLUB IS LENGTHENED, AND ONLY LENGTHENED (2026-08-15, Louis: "make the juggling club just
# a tiny bit longer on both the handle and the upper part ... save the original tho"). The
# previous card is kept as `big_club_short.png` / `club_short.png`.
#
# **LONGER IS NOT BIGGER, and the derivation is what keeps them apart.** derive_stage_props
# sets the stage width from the card's aspect at a fixed `STAGE_H`, so growing the card's
# HEIGHT and `STAGE_H["club"]` by the same fraction leaves the stage width where it was: 23 x
# 64/77 = 19 before, 23 x 73/88 = 19 after. Grow one without the other and the club either gets
# fatter or gets squashed.
#
# The two parts grow differently because they are made of different things. The handle grows by
# exactly ONE six-row tile - the smallest step that leaves the knife's wrap rhythm intact, and
# the only step that does. The body is a painting, so it is resampled by duplicating rows, and
# only BELOW its two gold bands: the bands are one pixel tall each, and a nearest resample that
# happens to land on one turns it into a two-pixel band, which at stage size is the difference
# between a pinstripe and a stripe. Rows 4..14 are copied untouched for that reason and the
# stretch is confined to the plain taper under them, where a duplicated row is invisible.
CLUB_BODY_TOP = 4        # first row of the painted crimson body
CLUB_BODY_KEEP = 14      # ...and the last row copied verbatim: the dome and both gold bands
CLUB_BODY_BOT = 45       # the last row of the body, where the handle's collar begins
CLUB_BODY_GROW = 5       # extra rows of taper
CLUB_HANDLE_EXTRA = 1    # extra six-row wrap periods; the knife's own handle is 0

# THE TORCH IS THE pro0 PAINTING AND NOTHING ELSE (2026-08-15, Louis: "i want EXACTLY pro0:
# the same flame, the same handle, everything exactly like pro0 ... take the same handle as in
# the png, not the one overlaid on top of it which is the same as the knives").
#
# Two earlier passes grafted a generation's HEAD onto the knife's grip, on the reasoning that a
# generated shaft never survives the reduction. That was true of s11, whose pole is five pixels
# wide, and it is NOT true of pro0, whose shaft is already eight - the knife grip's own width.
# The general rule stands and this is simply a painting the rule does not bite on.
#
# `TORCH_HEAD_SRC` names the painting. Previous designs are kept on disk: `big_torch_s11.png` /
# `torch_s11.png`, and the knife-grip torch before them is at commit 3930e10.
TORCH_HEAD_SRC = "pro0"

# The fire's lowest reach in the painting. Above this row every pixel is either fire or fire's
# outline, EXCEPT the bundle running up the middle - see build_torch's rim fold.
TORCH_FIRE_BOT = 37
BUNDLE_MIN = 4           # a central run narrower than this is a speck in the fire, not the wick

# The painted flame's own four entries, for telling fire from wick where they interleave, and
# the deepest of them, which the fire's folded-in outline is repainted as.
FLAME_COLS = {(240, 104, 64), (255, 148, 61), (248, 184, 88), (255, 224, 140)}
FLAME_DEEP = (240, 104, 64)


def handle_rows(y0: int, y1: int):
    """Rows y0..y1 of the knife's handle as lists of RGB, centre-aligned.

    RGB and not a luminance ratio: the point of this pass is that the club and the torch get
    the knife's actual colours. Keeping them as pixels also guarantees they stay inside the
    locked 48, since they already are.
    """
    a = np.asarray(Image.open(PROPS / "big_knife.png").convert("RGBA"))
    op = a[..., 3] > 40
    out = {}
    for y in range(y0, y1 + 1):
        xs = np.where(op[y])[0]
        out[y] = [tuple(int(v) for v in a[y, x, :3]) for x in xs]
    return out


def grip_sequence(extra_tiles: int = 0):
    """The knife's handle, optionally lengthened by whole six-row wrap periods.

    `extra_tiles = 0` is the knife's own 35 rows VERBATIM and contiguous - which is what makes
    the club a byte-for-byte transplant rather than a near-copy. Extra tiles are spliced in at
    a period boundary, just before the plain run-out, so the rhythm never breaks: 41 rows for
    the club (one extra), 53 for the torch (three).
    """
    base = list(range(KNIFE_HANDLE_TOP, KNIFE_HANDLE_BOT + 1))
    tile = list(range(KNIFE_TILE[0], KNIFE_TILE[1] + 1))
    at = base.index(KNIFE_TAIL[0])
    return base[:at] + tile * extra_tiles + base[at:]


def blit_rows(a: np.ndarray, y0: int, rows, seq, cx: float, widths=None) -> None:
    """Copy the knife's rows into `a`. `widths[i]` stretches row i; None keeps it native."""
    h, w = a.shape[:2]
    for i, src in enumerate(seq):
        y = y0 + i
        row = rows[src]
        native = len(row)
        want, x0 = (native, int(round(cx - native / 2.0))) if widths is None else widths[i]
        for x in range(want):
            # NEAREST source column. Safe because `want` is constant over long runs of rows
            # (see the module docstring); interpolating would mix two palette entries into a
            # colour that is in neither the knife nor the locked 48.
            j = int(round((x / max(1, want - 1)) * (native - 1))) if want > 1 else 0
            px = x0 + x
            if 0 <= y < h and 0 <= px < w:
                c = row[min(native - 1, j)]
                a[y, px] = (c[0], c[1], c[2], 255)


def build_club() -> Image.Image:
    """The knife's handle transplanted onto a body stretched a little longer.

    THE BODY IS READ FROM `big_club_short.png`, NOT FROM THE LIVE CARD, and that is the whole
    reason the short original is kept in the repo rather than only in git. Reading the card
    this script writes would be idempotent exactly once and then lengthen the club again on
    every run - the same trap `STAGE_H` is a written-down table to avoid.
    """
    src = np.asarray(Image.open(PROPS / "big_club_short.png").convert("RGBA"))
    a = np.zeros_like(src)
    top, keep, bot = CLUB_BODY_TOP, CLUB_BODY_KEEP, CLUB_BODY_BOT

    a[top:keep + 1] = src[top:keep + 1]          # the dome and both one-pixel gold bands
    n_src = bot - keep                           # the plain taper, 31 rows
    n_dst = n_src + CLUB_BODY_GROW
    for j in range(n_dst):
        # NEAREST, i.e. whole rows duplicated. Interpolating would mix two palette entries,
        # and on a taper it would also blur the silhouette's own edge into a half-pixel.
        a[keep + 1 + j] = src[keep + 1 + int(round(j * (n_src - 1) / (n_dst - 1)))]

    rows = handle_rows(KNIFE_HANDLE_TOP, KNIFE_HANDLE_BOT)
    blit_rows(a, keep + 1 + n_dst, rows, grip_sequence(CLUB_HANDLE_EXTRA), 23.0)
    return Image.fromarray(a, "RGBA")


def build_torch() -> Image.Image:
    """pro0, verbatim (2026-08-15, Louis: "i want EXACTLY pro0: the same flame, the same
    handle, everything exactly like pro0 ... take the same handle as in the png, not the one
    overlaid on top of it which is the same as the knives").

    So this no longer BUILDS a torch out of parts - it warm-snaps the painting, folds the
    flame's own dark outline into the flame so the fire is one clean region, and places it.
    The shaft is pro0's mottled brown, the ferrule is pro0's, the wick is pro0's cream, and
    the fire is drawn live in exactly the place pro0 painted it.

    THE ONE THING DONE TO THE PAINTING IS THE RIM FOLD, and it exists so the strip can be
    exact. pro0 outlines its fire in near-black, and those pixels are the same palette entries
    as the shaft's own edge - so no colour test can tell "the dark line around the flame" from
    "the dark line down the handle". Position can: above the wick every pixel is fire or fire's
    outline, and across the wick the fire is everything OUTSIDE the bundle's central run. Those
    pixels are repainted in the flame's own deepest orange, which makes the fire a single
    region of four known colours that `strip_torch_flame` lifts without touching the wick.
    Nothing a player sees changes - the whole region is deleted before anything is drawn.
    """
    sys.path.insert(0, str(ROOT / "scripts"))
    import install_prop_cards as ipc

    raw = np.asarray(Image.open(ROOT / "artifacts" / "torchgen" / f"{TORCH_HEAD_SRC}.png")
                     .convert("RGBA")).astype(float)
    warm = ipc.warm_palette()
    a = np.zeros(raw.shape, np.uint8)
    op = raw[..., 3] > 40
    for y in range(raw.shape[0]):
        xs = np.where(op[y])[0]
        if len(xs) == 0:
            continue
        cols = [tuple(int(v) for v in c) for c in ipc.snap_warm(raw[y, xs, :3], warm)]
        if y <= TORCH_FIRE_BOT:
            # everything outside the bundle's own central run, on a row the fire reaches, is
            # fire or fire's outline - see the note above
            keep = [i for i, c in enumerate(cols) if c not in FLAME_COLS]
            runs = []
            for i in keep:
                if runs and i == runs[-1][-1] + 1:
                    runs[-1].append(i)
                else:
                    runs.append([i])
            mid = len(cols) // 2
            hit = [r for r in runs if r[0] <= mid <= r[-1] and len(r) >= BUNDLE_MIN]
            body = set(hit[0]) if hit else set()
            cols = [c if i in body else FLAME_DEEP for i, c in enumerate(cols)]
        for i, x in enumerate(xs):
            a[y, x] = (cols[i][0], cols[i][1], cols[i][2], 255)

    y0, y1, x0, x1 = ipc.ink_box(a.astype(float))
    return Image.fromarray(ipc.place(a[y0:y1 + 1, x0:x1 + 1], 40, 96, 4), "RGBA")

def report(name: str, im: Image.Image) -> None:
    a = np.asarray(im)
    op = a[..., 3] > 40
    runs = []
    for y in range(a.shape[0]):
        xs = np.where(op[y])[0]
        if len(xs) == 0:
            continue
        w = int(xs.max() - xs.min() + 1)
        if runs and runs[-1][0] == w:
            runs[-1][2] = y
        else:
            runs.append([w, y, y])
    print(f"  {name}: " + " ".join(f"{w}px@{y0}-{y1}" for w, y0, y1 in runs))


def main() -> None:
    write = "--write" in sys.argv
    force = "--force" in sys.argv
    out = {"big_club.png": build_club(), "big_torch.png": build_torch()}
    for n, im in out.items():
        report(n, im)
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
