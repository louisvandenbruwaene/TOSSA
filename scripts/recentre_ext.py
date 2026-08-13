#!/usr/bin/env python3
"""Slide a venue exterior sideways so its lit focal point lands on the frame's centre line.

WHY THIS EXISTS RATHER THAN A BETTER PROMPT (2026-08-13). Louis, on the establishing cards:
"why would there be two arenas or circus tents, or two entrances to two buildings ... I'd
like the important part centered". Getting to ONE of each was a prompt fix - crop so the
subject fills the frame and there is nowhere to put a twin. Getting that one thing CENTRED
was not, and the reason is worth writing down:

    ASKING FOR "DEAD CENTRE" MAKES THE DUPLICATION COME BACK.

Measured, repeatedly. "its lit porch and glowing front door sit at the exact middle of the
picture, the same distance from the left edge as from the right edge, perfectly centred"
returned a house with TWO front doors, one either side of the middle - the model satisfies a
request for symmetry by building a symmetric composition, and two doors is symmetric. Same
prompt shape, same failure, on the Midnight Show's archway. So the two goals fight: the
wording that gives one subject is the wording that leaves it off-centre, and the wording
that centres it gives two.

The way out is to stop asking. Generate for singularity, then move the picture here, where
it is arithmetic instead of a lottery.

WHY A SHIFT IS SAFE ON THESE AND WOULD NOT HAVE BEEN BEFORE. Every exterior is now an
extreme close-up of a CONTINUOUS FACADE - brickwork, striped canvas, stonework, a stadium's
ribbed concrete. Padding the exposed edge by reflection continues a repeating texture, which
is invisible. The earlier wide compositions (a house in a garden, a street with an alley)
would have had a window or a doorway reflected into view, which is why this was not done to
them. It is also lossless: an integer shift moves whole pixels and resamples nothing.

FINDING THE FOCAL POINT: it is the LIT thing, and it took three tries to measure properly.

  1. AXIS OF SYMMETRY. Tried first, abandoned: these facades are self-similar all the way
     across, so mirror error is nearly flat and the argmin is noise - it kept returning the
     edge of its own search range.
  2. CENTROID of the warm lit pixels. Wrong whenever the light is SPREAD: the Circus's
     entrance sits at x 535 and its string of bulbs runs the full width, so the centroid
     reported 327, dead centre, and would have shifted the picture by 7px.
  3. PEAK of a smoothed per-column profile. This is the one. A 61px box filter over the
     column sums, argmax. The entrance is the densest concentration of light, which is what
     the eye picks out too, and spread-out bulbs cannot outvote it.

WITH ONE FALLBACK, because one venue is not lit warmly at all. The Championship is a cool
concrete-and-glass facade: 149 of its 54,537 bright pixels are warm (0.00), against 0.68-1.00
for every other venue, and the warm profile then locks onto stray tint and reports x=98 for
an entrance that is at 440. Below WARM_SHARE the profile is built from plain brightness
instead, which puts it at 421-440. The two regimes are three orders of magnitude apart, so
the switch is not a tuning knob.

USAGE
  .venv/bin/python scripts/recentre_ext.py                 measure only
  .venv/bin/python scripts/recentre_ext.py --write         apply, in artifacts/paint/
Run BEFORE pixelise_paint.py --ext, which is what installs the result.
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "artifacts" / "paint"

# WHICH VENUES THIS IS ALLOWED TO TOUCH, and the list is short on purpose - every name that
# is NOT here was tried, looked at, and rejected:
#
#   the_circus      -215px, and the tent's stripes have a rhythm. The join lands mid-stripe
#                   and reads as a crease down the canvas.
#   championship    -101px. The fill starts inside the glass curtain wall and the join reads
#                   as an extra structural column that does not line up with the real ones.
#   world_arena     -112px. Worst of the three: the join cuts across the curving tiers of
#                   seating, which are the one thing in that picture the eye follows.
#   backyard        architectural (a gable and a porch), and already near enough the middle.
#   small_theatre   its marquee is the subject and its neighbours are part of the street.
#
# What the two survivors have in common is a genuinely FEATURELESS field to fill from -
# plain brick, plain stonework - where a hard join has no structure to interrupt. That is
# the real precondition, not "a continuous facade", which is what I assumed first and which
# is true of the three rejected ones as well.
NAMES = ["street_corner", "the_midnight_show"]

WARM_MIN = 110.0    # a lit entrance, not a dim brick
WARM_SHARE = 0.15   # below this share of bright pixels, the venue is not warm-lit at all
SMOOTH = 61         # box filter over the column profile, in px - about an entrance's width
MAX_SHIFT = 220     # refuse anything absurd rather than wrap a picture halfway round


def focal_x(rgb: np.ndarray) -> float | None:
	"""The x of the densest concentration of light: the entrance. See the module docstring."""
	r = rgb[..., 0].astype(float)
	b = rgb[..., 2].astype(float)
	lum = rgb.mean(axis=2)
	bright = lum > WARM_MIN
	warm = bright & (r > b + 12)
	if bright.sum() < 40:
		return None
	mask = warm if warm.sum() >= WARM_SHARE * bright.sum() else bright
	col = (lum * mask).sum(axis=0)
	ker = np.ones(SMOOTH) / SMOOTH
	return float(np.convolve(col, ker, mode="same").argmax())


def quiet_strip(rgb: np.ndarray, w: int) -> np.ndarray:
	"""The `w`-wide vertical band of this picture with the least light in it.

	REFLECTION WAS THE OBVIOUS FILL AND IT IS WRONG HERE. Mirroring the adjacent strip
	continues a texture perfectly, but it also mirrors any LANDMARK inside the shift
	distance: at -125 the Street Corner grew a second lamp post, and at -215 the Circus grew
	a second lit archway - which is precisely the "two entrances" defect this whole pass
	exists to remove. Verified by looking at the shifted output, not assumed.

	So the exposed edge is filled from the picture's own QUIETEST band instead - the run of
	columns carrying the least light, which on these facades is plain brick, plain canvas or
	plain stonework. It cannot duplicate a landmark because it is chosen for containing none.
	"""
	lum = rgb.mean(axis=2)
	col = lum.sum(axis=0)
	# cumulative sums make the sliding window exact and cheap
	cum = np.concatenate([[0.0], np.cumsum(col)])
	totals = cum[w:] - cum[:-w]
	return rgb[:, int(totals.argmin()):int(totals.argmin()) + w]


def shift(rgb: np.ndarray, dx: int) -> np.ndarray:
	"""Move the picture by dx whole pixels, filling the exposed edge from a quiet band."""
	if dx == 0:
		return rgb
	pad = abs(dx)
	fill = quiet_strip(rgb, pad)
	if dx < 0:      # picture moves left, the RIGHT edge is exposed
		return np.concatenate([rgb[:, pad:], fill], axis=1)
	return np.concatenate([fill, rgb[:, :-pad]], axis=1)


def main() -> int:
	write = "--write" in sys.argv
	only = [a for a in sys.argv[1:] if not a.startswith("--")]
	for name in NAMES:
		if only and name not in only:
			continue
		p = SRC / f"ext_{name}.png"
		if not p.exists():
			print(f"  ext_{name}: no painting at {p.relative_to(ROOT)}")
			continue
		a = np.asarray(Image.open(p).convert("RGB"))
		fx = focal_x(a)
		if fx is None:
			print(f"  ext_{name}: no lit focal point found - left alone")
			continue
		dx = int(round(a.shape[1] / 2.0 - fx))
		if abs(dx) > MAX_SHIFT:
			print(f"  ext_{name}: focal at {fx:.0f}, wants {dx:+d} - REFUSED, over {MAX_SHIFT}")
			continue
		tag = f"  ext_{name}: focal at x={fx:.0f} of {a.shape[1]}, shift {dx:+d}"
		if not write:
			print(tag + "  (pass --write to apply)")
			continue
		Image.fromarray(shift(a, dx)).save(p)
		fx2 = focal_x(np.asarray(Image.open(p).convert("RGB")))
		print(tag + f" -> now x={fx2:.0f} [written]")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
