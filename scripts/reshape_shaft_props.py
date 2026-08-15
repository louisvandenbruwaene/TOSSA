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

THE TORCH'S STEEL WICK IS NOW A BOUND HEAD, LIFTED FROM A GENERATION (2026-08-15, Louis asked
PixelLab to "just create a juggling torch" and picked s11 out of eleven). Only rows 40..53 of
that painting are kept - its wrap - because s11's own shaft is FIVE pixels on the card and four
at stage size, thinner than the knife's blade and nowhere near something a hand catches. The
proportions come from the generation and the material from this pipeline, which is the only
split that survives the reduction: measured, every one of the eleven broke at stage size, three
of them by leaving painted fire baked in under the live flame.

`_TORCH` MOVES WHENEVER THE HEAD DOES and must be copied into Resources/art_manifest.json by
hand: stage base_row 29 -> 23 here, because a fourteen-row head takes room a seven-row wick did
not. Nothing syncs them and a stale block draws the flame off the end of the handle.

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

# THE TORCH'S HEAD COMES FROM THE s11 GENERATION (2026-08-15). Rows 40..53 of that painting -
# the bound wrap under its fire. Everything else about s11 is left behind; see build_torch.
# TORCH_HEAD_TOP is chosen so the shaft below it is 47 rows, which is 35 + 2 whole wrap
# periods: the handle's length is quantised to the tile, so this row is the free parameter and
# the shaft's is not.
S11_HEAD = (40, 53)
TORCH_HEAD_TOP = 32


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


def s11_head():
    """Rows 40..53 of the s11 painting - its bound head - warm-snapped, as lists of RGB.

    Snapped through `install_prop_cards.warm_palette()` rather than the plain 48, for the
    reason that module documents at length: every generated object has a near-black rim, and
    the locked palette's darkest entries are COOL, so an unrestricted snap sends a third of a
    small sprite to indigo. Measured on this head raw, its own darks are #090a10 and #390915 -
    exactly the pixels that would go.
    """
    sys.path.insert(0, str(ROOT / "scripts"))
    import install_prop_cards as ipc

    a = np.asarray(Image.open(ROOT / "artifacts" / "torchgen" / "s11.png").convert("RGBA")).astype(float)
    warm = ipc.warm_palette()
    out = []
    for y in range(S11_HEAD[0], S11_HEAD[1] + 1):
        xs = np.where(a[y, :, 3] > 40)[0]
        snapped = ipc.snap_warm(a[y, xs, :3], warm)
        out.append([tuple(int(v) for v in c) for c in snapped])
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
    a = np.zeros_like(np.asarray(Image.open(PROPS / "big_torch.png").convert("RGBA")))
    cx = 20.0
    rows = handle_rows(KNIFE_HANDLE_TOP, KNIFE_HANDLE_BOT)

    # --- THE FLAME. Drawn, not lifted, and it is a MEASUREMENT CARRIER rather than art:
    # nothing ever displays it. derive_stage_props finds it by colour, clears it, writes
    # `big_torch_body.png` (which is what the manifest points at) and publishes its extent as
    # `_TORCH`, from which the game draws a live animated flame. So what this needs to be is
    # the right SHAPE in the right PLACE. It is rasterised from the same profile Game.gd's
    # flame_shape uses, so the pipeline measures the silhouette the game will actually draw.
    prof = [(0.00, 0.00), (0.52, -0.07), (0.62, -0.26), (0.47, -0.48),
            (0.27, -0.70), (0.11, -0.87), (0.00, -1.00)]
    FLAME_H, FLAME_W = 26, 11.5
    base_y = TORCH_HEAD_TOP - 1      # the last row of fire, sitting straight on the head
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

    # --- THE HEAD: a bound wrap, lifted from the s11 painting (2026-08-15, Louis picked it out
    # of eleven generations: "fix up s11"). It replaces a thin steel wick, and it is the one
    # part of that painting worth keeping - the rest of s11 is a five-pixel pole that reduces
    # to four on stage, thinner than the knife's blade and far too thin to read as something a
    # hand catches. So the PROPORTIONS come from s11 (a long shaft under a distinct head) and
    # the material comes from the pipeline.
    #
    # Warm-snapped, its wrap lands on the club's own crimson family (#702020 / #903030 over
    # #381810 / #0f090d), which is a better outcome than the design asked for: a crimson head,
    # a brass ferrule and the knife's leather grip put the torch in the same wardrobe as the
    # other two heavy props instead of beside them.
    #
    # ITS WIDTHS ARE REMAPPED, NOT SCALED. s11's head runs 13 down to 5 over a 5px pole - a
    # ratio of 2.6 - and the same ratio over this 12px shaft would be a 31px head, which is the
    # TRAY failure this file has already paid for once. The range [5, 13] is mapped onto
    # [14, 20] instead, which keeps every bump in the bundle's outline while sitting a modest
    # two pixels proud of the shaft it sits on.
    head = s11_head()
    hw_lo, hw_hi = min(len(r) for r in head), max(len(r) for r in head)
    for i, row in enumerate(head):
        want = int(round(14 + (len(row) - hw_lo) * 6.0 / max(1, hw_hi - hw_lo)))
        x0 = int(round(cx - want / 2.0))
        for x in range(want):
            j = int(round((x / max(1, want - 1)) * (len(row) - 1)))
            c = row[min(len(row) - 1, j)]
            a[TORCH_HEAD_TOP + i, x0 + x] = (c[0], c[1], c[2], 255)

    # --- THE HANDLE: the knife's, tapering 8 at the foot to 12 at the shoulder.
    top, bot = TORCH_HEAD_TOP + len(head), 92
    seq = grip_sequence(2)
    excess = [len(rows[y]) - KNIFE_GRIP_W for y in seq]
    n = bot - top + 1
    assert len(seq) == n, f"handle sequence is {len(seq)} rows, the torch has {n}"

    # THE WIDTH RAMPS, THE EDGES ALTERNATE. Rounding a symmetric half-width about a centre
    # cannot stagger the two sides - both cross their thresholds at the same fractional width,
    # by symmetry, whatever the centre's phase - so the first version of this stepped two
    # pixels at once and came out 12px for nine rows, 11px for ONE, then 10px for twenty-five:
    # a stack of cylinders, not a cone. Round the TOTAL width instead (a linear ramp rounded
    # gives even runs, here 7/13/13/13/7 rows) and then hand each extra pixel to a different
    # side: left takes the odd ones, right the even ones. The silhouette grows one pixel at a
    # time, alternating, which is as smooth as a four-pixel taper gets at this density.
    base = KNIFE_GRIP_W                                  # the thin end, the knife's own grip
    left0 = int(cx - base / 2.0)
    widths = []
    for i in range(n):
        w = int(round(base * (TORCH_GROWTH - (TORCH_GROWTH - 1.0) * (i / (n - 1.0)))))
        grow = w - base
        # The collar and the cap ride proud of the local cone by the SAME absolute amount they
        # ride proud of the knife's grip (+4/+6/+6/+4, +2/+2/+2/0/-4), and symmetrically, since
        # they are rings rather than part of the taper. Proportional instead would put a 21px
        # collar on a 12px cone, and a ring wider than everything it joins reads as a tray.
        lo = left0 - math.ceil(grow / 2.0) - excess[i] // 2
        widths.append((max(1, w + excess[i]), lo))

    blit_rows(a, top, rows, seq, cx, widths)
    return Image.fromarray(a, "RGBA")


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
