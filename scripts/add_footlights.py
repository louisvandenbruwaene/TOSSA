#!/usr/bin/env python3
"""Stamp a row of footlight lamps along a title-half's stage lip.

WHY THIS EXISTS. `menu_house_light` deleted the title screen's spotlight cone on 2026-08-15
and replaced it with a wash rising OFF THE FOOTLIGHTS - and its own note says why that is
allowed where the cone was not: "they are real lamps in the picture". So the lamps are not
decoration on this screen, they are the source the remaining light names. A title half with
no lamps in it puts the game straight back into the fault the cone was deleted for.

WHY IT IS A STAMP AND NOT ANOTHER GENERATION. Three halves were rolled for the 2026-08-20
side-curtain title (see docs/pixellab_prompts.md):
  A  the right composition - one curtain leg on the left, open stage running to the right
     edge, valance across the top - but a bare lit lip with no lamps on it;
  B  beautiful lamps, evenly spaced, flat boards... and a complete little proscenium with a
     curtain leg on BOTH of its own edges, which mirrors into the DIPTYCH the title's own
     notes warn about: two stages side by side;
  C  a curtain at the right edge, so the mirror puts one dead centre, plus two baked
     spotlight cones and two light pools on the boards.
A is right about everything the mirror cares about and B is right about the lamps, and B's
lamps are the same generator at the same size under the same forced palette - so they can
simply be moved. Re-rolling for a fourth is spending a generation on something a paste can
do exactly.

WHAT IT COPIES IS THE LAMP, NOT A RECTANGLE. A rectangular patch would bring B's own flat
board colour with it and cut a horizontal stripe across A's lit wing-spill. Only pixels that
DIFFER from the donor's local board tone are carried, so what lands is the lamp and its
housing, over whatever boards the target already has.

THE PITCH IS SET BY THE MIRROR, NOT BY THE DONOR. The finished picture is this half mirrored,
so a lamp at column c has a twin at 639-c and the gap across the axis is 2*(320-c)-1. Placing
lamps at a whole pitch from the LEFT would leave that one gap wrong by up to a full pitch -
the one irregularity in an otherwise even row, dead centre, where the eye already is. So the
row is laid out from the AXIS outward: `PITCH` 15 with the innermost lamp at 312 makes the
centre gap exactly one pitch like every other.

USAGE
  .venv/bin/python scripts/add_footlights.py artifacts/menu_half/half_a.png \
      --donor artifacts/menu_half/half_b.png --write
  ...then: pixelise_menu.py --from-half artifacts/menu_half/half_lit.png --half-shift N --write
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent

# The donor lamp: one bulb's box in half_b.png, measured rather than guessed - the lamp runs
# rows 294..306 and about nine columns wide, on a board of (71,41,28).
LAMP_BOX = (154, 293, 169, 308)     # x0, y0, x1, y1
LAMP_DIFF = 40                      # per-channel distance from the donor's board that counts
PITCH = 15                          # columns between lamps (see the mirror note above)
INNERMOST = 312                     # the lamp nearest the mirror axis at x=320
LEFT_STOP = 104                     # stop before the curtain leg swallows them


def lamp_from(donor: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """The lamp's pixels and its mask, cut out of the donor by difference from its boards."""
    x0, y0, x1, y1 = LAMP_BOX
    patch = donor[y0:y1, x0:x1].astype(int)
    # the board tone is whatever the patch's own corners agree on
    board = np.median(np.concatenate([patch[:, :1], patch[:, -1:]], axis=1).reshape(-1, 3), axis=0)
    mask = (np.abs(patch - board).max(axis=2) > LAMP_DIFF)
    return patch, mask


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        raise SystemExit(__doc__)
    target = Path(args[0])
    donor = Path(sys.argv[sys.argv.index("--donor") + 1]) if "--donor" in sys.argv else None
    if donor is None or not donor.exists() or not target.exists():
        raise SystemExit("need an existing <target-half> and --donor <half>")

    a = np.asarray(Image.open(target).convert("RGB")).astype(np.uint8).copy()
    d = np.asarray(Image.open(donor).convert("RGB")).astype(np.uint8)
    patch, mask = lamp_from(d)
    h, w = mask.shape
    x0, y0, _, _ = LAMP_BOX

    n = 0
    x = INNERMOST
    while x - w // 2 >= LEFT_STOP:
        px = x - w // 2
        win = a[y0:y0 + h, px:px + w]
        if win.shape[:2] == mask.shape:
            win[mask] = patch[mask]
            n += 1
        x -= PITCH
    print(f"{target.name}: stamped {n} lamps, pitch {PITCH}, innermost x{INNERMOST} "
          f"(centre gap {2 * (320 - INNERMOST) - 1}px)")

    out = target.with_name("half_lit.png")
    if "--write" in sys.argv:
        Image.fromarray(a, "RGB").save(out)
        print(f"  wrote {out}")
    else:
        print("  (pass --write to apply)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
