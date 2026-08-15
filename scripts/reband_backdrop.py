#!/usr/bin/env python3
"""Redistribute a backdrop painting's horizontal bands vertically.

WHY THIS EXISTS: `stand` IS NOT A FREE PARAMETER (2026-08-15). A backdrop is three or four
horizontal bands - sky or drapes, then the floor the performer stands on, then whatever is
in front of it - and `venue_data`'s `stand` puts his feet partway down the floor band. The
architecture says a painting can put its floor wherever it likes and `stand` follows. That
is true about the PICTURE and false about the GAME, and the difference is throw height.

Measured on the Midnight Show repaint that prompted this. The new painting put its stage
band at art y 120..250, so `stand` had to move 0.83 -> 0.645 and the whole figure rose 133
screen px. Every throw rose with it, because the hand line hangs off the standing line:

    arc peak = BASE_AIR * height * ARC_PER_AIR = 84 * 1.4 * 2.15 = 253 px

    stand 0.83   full-hold 1.4 apex at screen y  85   (on screen, just)
    stand 0.645  full-hold 1.4 apex at screen y -48   (gone)
    stand 0.645  High Toss 1.8 apex at screen y -121  (long gone)

A full-hold throw is not an edge case, it is what holding the key does, and the player has
to TRACK a prop to catch it. The game does have a top-edge marker for a prop that leaves the
frame, but that exists for the High Toss at a normal house - making it the ordinary case at
the game's final bonus venue is a playability regression dressed as an art change.

**SO THE FLOOR BAND HAS A MINIMUM DEPTH, SET BY THE ARC AND NOT BY THE PICTURE.** Rather
than re-roll the painting and hope the model puts the horizon where the physics needs it -
its vertical composition control is the weakest thing about it, measured over five rolls -
this rescales the bands the painting already has.

WHY RESCALING IS SAFE HERE AND IS NOT A GENERAL LICENCE. Vertical stretch destroys anything
whose vertical detail carries meaning. It is fine for the two bands that needed it because
of what they are made of: hung drapes are VERTICAL folds, so stretching them along the fold
changes nothing you can see; floorboards are horizontal planks, so a mild compression just
makes the boards shallower, which is what perspective does anyway. The band that must NOT be
touched is the foreground furniture - a chair squashed to 0.55 is a chair that is wrong - so
that one is moved at 1:1 and CROPPED instead, which costs only the table legs and the dark
floor under them. Cropping a foreground object at the bottom edge of the frame is what
foreground objects do.

Check the same three questions before using it anywhere else: is this band's detail vertical
(stretch is free), horizontal (compression is mild), or an object (move it, never scale it)?

USAGE
  .venv/bin/python scripts/reband_backdrop.py the_midnight_show \\
      --band 0:119:0:186 --band 120:251:186:301 --band 251:263:301:308 --band 263:317:308:360
  ...add --write to overwrite artifacts/paint/<name>.png, then pixelise_paint.py --bg <name>
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "artifacts" / "paint"


def reband(im: Image.Image, bands) -> Image.Image:
    """bands: list of (src_y0, src_y1, dst_y0, dst_y1), in order, covering the frame."""
    w, h = im.size
    out = Image.new(im.mode, (w, h))
    for sy0, sy1, dy0, dy1 in bands:
        piece = im.crop((0, sy0, w, sy1))
        # NEAREST, never BILINEAR. This is pixel art on a locked palette: a smooth resample
        # invents intermediate colours that the reducer then has to snap back, which is how a
        # clean two-tone plank edge turns into a three-pixel gradient. Nearest duplicates or
        # drops whole rows, which at these ratios is invisible and is reversible in kind.
        piece = piece.resize((w, max(1, dy1 - dy0)), Image.NEAREST)
        out.paste(piece, (0, dy0))
    return out


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        raise SystemExit(__doc__)
    name = args[0]
    src = SRC / f"{name}.png"
    if not src.exists():
        raise SystemExit(f"no painting at {src.relative_to(ROOT)}")
    bands = []
    for i, a in enumerate(sys.argv):
        if a == "--band":
            bands.append(tuple(int(x) for x in sys.argv[i + 1].split(":")))
    if not bands:
        raise SystemExit("need at least one --band src0:src1:dst0:dst1")

    im = Image.open(src)
    out = reband(im, bands)
    for sy0, sy1, dy0, dy1 in bands:
        sh, dh = sy1 - sy0, dy1 - dy0
        print(f"  src {sy0:3d}..{sy1:3d} ({sh:3d} rows) -> dst {dy0:3d}..{dy1:3d} "
              f"({dh:3d} rows)  x{dh / sh:.2f}")
    if "--write" in sys.argv:
        out.save(src)
        print(f"  wrote {src.relative_to(ROOT)}")
        print(f"  next: pixelise_paint.py --bg {name} --write, then make reimport")
    else:
        prev = ROOT / "artifacts" / "reband"
        prev.mkdir(parents=True, exist_ok=True)
        out.save(prev / f"{name}.png")
        print(f"  preview {(prev / f'{name}.png').relative_to(ROOT)} - --write to apply")


if __name__ == "__main__":
    main()
