#!/usr/bin/env python3
"""Cut the plinth off a generated round-prop sprite.

WHAT A PLINTH IS. Ask PixelLab for a ball and it returns a ball STANDING ON SOMETHING -
a little pedestal, or a cast shadow fused to the bottom of the sphere. It does this even
when the prompt forbids it, and it does it because almost every reference image of a
"product on a dark background" in the world has the object resting on a surface.

WHY IT HAS TO GO. `draw_prop_icon` already lays a contact shadow under the card itself
(`fill_ellipse`, plus a `draw_glow` pool of the prop's own colour). A plinth baked into
the sprite is therefore a SECOND shadow sitting on top of the real one, at a different
angle, in a sprite that also gets ROTATED - so on any card where the prop leans, the
baked shadow leans with it and hangs in the air. It also decentres the art: prop_big/*
carries no pivot, so `art_blit` centres on the CANVAS, and a plinth pads the bottom and
sits the object high in its niche.

WHY THE OBVIOUS RULE DOES NOT WORK. The first attempt was "drop bottom rows narrower
than 45% of the widest row", on the theory that a pedestal is a thin stub. Measured on
the real files, it fires on nothing useful: the ball's plinth rows are 22-26px wide
against a 36px sphere (61-72%), because the thing is not a stub, it is a wide flat
shadow ellipse fused to the silhouette.

THE SIGNATURE THAT DOES WORK is two signals at once, and it is specific rather than
clever - a round prop is CONVEX, so scanning down from its widest row the silhouette can
only ever get narrower:

  1. the row is WIDER than the row above it, below the widest row  (convexity broken)
  2. the row is markedly DARKER than the object's own body         (it is a shadow)

Measured on Assets/Props/big_ball.png (2026-08-05): widths run 34,33,32,30,29,28,25,23,
20 and then turn back up 22,25,26 while mean luminance collapses from 199 to 144 against
a body median of 230. big_egg turns 10 -> 15 with luminance 168. big_ring never turns
back up at all and is correctly left alone - its dark bottom rows are the underside of
the torus, which is shading, not a plinth. That is the case a luminance-only rule would
have destroyed.

USAGE
  .venv/bin/python scripts/trim_plinth.py                    # report only, touches nothing
  .venv/bin/python scripts/trim_plinth.py --write            # apply (artguard-guarded)
  .venv/bin/python scripts/trim_plinth.py --write --force    # ignore the guard
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

import artguard

ROOT = Path(__file__).resolve().parent.parent
PROPS = ROOT / "Assets" / "Props"

# The round props, whose card art is generated and therefore at risk. The painted props
# (club, knife, torch, chainsaw) are not convex and this test does not apply to them.
TARGETS = ["big_ball", "big_egg", "big_ring"]

DARK_RATIO = 0.85   # a plinth row's mean luminance, as a share of the body median
WIDEN_TOL = 0       # px a row may exceed the row above before convexity counts as broken


def luminance(a: np.ndarray) -> np.ndarray:
    return 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]


def find_plinth(path: Path):
    """Return (first_plinth_row, rows) or (None, rows) if the sprite is clean."""
    a = np.asarray(Image.open(path).convert("RGBA")).astype(float)
    op = a[..., 3] > 0
    lum = luminance(a)

    rows = [y for y in range(a.shape[0]) if op[y].any()]
    if not rows:
        return None, []
    widths = {y: int(op[y].sum()) for y in rows}
    means = {y: float(lum[y][op[y]].mean()) for y in rows}
    body_median = float(np.median(lum[op]))

    widest = max(rows, key=lambda y: widths[y])
    cut = None
    # Walk down from the widest row. The FIRST row that breaks convexity while also
    # being dark starts the plinth, and everything below it goes with it - a plinth is
    # contiguous with the bottom edge by construction.
    for y in rows:
        if y <= widest:
            continue
        above = y - 1
        if above not in widths:
            continue
        if widths[y] > widths[above] + WIDEN_TOL and means[y] < body_median * DARK_RATIO:
            cut = y
            break
    return cut, [(y, widths[y], round(means[y], 1)) for y in rows]


def trim(path: Path, write: bool, force: bool) -> str:
    cut, rows = find_plinth(path)
    if cut is None:
        return f"{path.name:14} clean - no plinth signature"

    im = Image.open(path).convert("RGBA")
    a = np.asarray(im).copy()
    removed = a.shape[0] - cut
    a = a[:cut]
    # Re-crop tight so the object re-centres: the plinth was padding the bottom, and
    # art_blit centres prop_big/* on the canvas.
    op = a[..., 3] > 0
    ys, xs = np.where(op)
    a = a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]

    if not write:
        return (f"{path.name:14} plinth from row {cut} "
                f"({removed} row(s)) -> would become {a.shape[1]}x{a.shape[0]}")

    status = artguard.save_guarded(path, lambda q: Image.fromarray(a, "RGBA").save(q), force)
    return (f"{path.name:14} trimmed {removed} row(s) -> {a.shape[1]}x{a.shape[0]}  [{status}]")


def main() -> int:
    write = "--write" in sys.argv
    force = "--force" in sys.argv
    names = [a for a in sys.argv[1:] if not a.startswith("--")] or TARGETS

    for n in names:
        p = PROPS / (n if n.endswith(".png") else f"{n}.png")
        if not p.exists():
            print(f"{p.name:14} MISSING")
            continue
        print(trim(p, write, force))
    if not write:
        print("\n(report only - pass --write to apply)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
