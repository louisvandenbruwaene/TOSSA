#!/usr/bin/env python3
"""Give the juggler's body regions FORM, without touching his shape.

THE PROBLEM. The per-region body sprites came out of the tracing pass as flat masks -
measured 2026-08-05, torso_suit, torso_vest, torso_collar and legs_trouser each contain
exactly ONE luminance level. They are multiplied by the live costume colour, so a flat
mask means the torso and legs are drawn as flat fills with no shading whatsoever. Beside
a PixelLab backdrop with real depth in it the figure reads, in Louis's word, meh - and it
is not the drawing's fault, there is simply nothing there to catch the light.

WHAT THIS DOES AND DOES NOT TOUCH. Only the FILL. The alpha channel is copied through
untouched, so the silhouette - and therefore the stance and the proportions, which are
settled and are not to be redrawn as a side effect of anything - comes out bit-identical.
Run with --check to prove that.

THE SHADING IS A CYLINDER, per row. A torso and a trouser leg are round, and the one
thing a flat fill fails to say is that they turn away at the edges. For each opaque row
the pixel's position across that row's own span becomes an angle, and the cylinder normal
at that angle is lit from the front-upper-LEFT - which is where this game's light always
is, since the spotlight hangs centre-stage and the figure stands under it. Per-row rather
than per-sprite so it follows a taper: a trouser leg narrows and its shading narrows with
it, and a sleeve does the same.

FOUR RULES THAT KEEP IT HONEST:

1. THE LIT SIDE STAYS AT PURE WHITE. The game multiplies this by the costume colour and
   a multiply can only DARKEN, so anything below 255 at the brightest point permanently
   dulls every outfit in the game. Same rule as the tinted props.
2. THE FLOOR IS HIGH (see SHADE_FLOOR). This is cloth under a warm stage lamp, not a
   sphere in a void. Taking it much below 0.6 turned a blue suit into a black one at the
   edges, which reads as a hole rather than as a fold.
3. QUANTISED to a few bands, for the same reason the props are: a smooth ramp inside a
   37px-wide torso is a gradient, and a gradient is what the whole art pass exists to
   stop. Band boundaries land on whole pixels because the shading is computed at final
   resolution.
4. A RIM on the shaded side, one pixel in from the silhouette, very slightly brighter
   than the band it sits in. It is the same trick as the round props' rim light: it
   separates the figure from whatever is behind it, and on a dark stage that is the
   difference between a performer and a silhouette.

USAGE
  .venv/bin/python scripts/shade_char_regions.py            # report
  .venv/bin/python scripts/shade_char_regions.py --check    # prove alpha is untouched
  .venv/bin/python scripts/shade_char_regions.py --write [--force]
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

import artguard

ROOT = Path(__file__).resolve().parent.parent
CHARS = ROOT / "Assets" / "Characters"

# Only the costume regions. NOT torso_button (a literal colour, not costume-derived, and
# four pixels across), and NOT the head, hands, hat, glasses or boots - those were traced
# with their own shading already and are not cylinders.
REGIONS = [
	"torso_suit", "torso_vest", "torso_collar",
	"torso_back_suit", "torso_back_collar",
	"legs_trouser",
]

SHADE_FLOOR = 0.64      # darkest fraction of the base colour - see rule 2
BANDS = 4               # value steps across the form
LIGHT_U = -0.42         # where the key light sits across the cylinder, -1 left .. +1 right
RIM_LIFT = 0.10         # how much the rim pixel lifts above its own band


def shade_mask(alpha: np.ndarray) -> np.ndarray:
	"""Cylinder shading in [SHADE_FLOOR, 1.0] for every opaque pixel."""
	h, w = alpha.shape
	val = np.ones((h, w), dtype=float)
	rim = np.zeros((h, w), dtype=bool)

	for y in range(h):
		xs = np.where(alpha[y])[0]
		if xs.size < 2:
			continue
		x0, x1 = xs.min(), xs.max()
		span = float(x1 - x0)
		if span < 1.0:
			continue
		# position across this row, mapped to a half-turn of a cylinder
		u = (np.arange(x0, x1 + 1) - x0) / span * 2.0 - 1.0
		theta = u * (np.pi * 0.5)
		# cylinder normal (sin theta, cos theta) against a light at LIGHT_U
		lt = LIGHT_U * (np.pi * 0.5)
		ndl = np.cos(theta - lt)
		# wrap it, exactly as the round props do: clipped lambert throws half the form
		# into one flat band, which on a 37px torso is most of the torso
		lam = np.clip(ndl * 0.5 + 0.5, 0.0, 1.0)
		row = SHADE_FLOOR + (1.0 - SHADE_FLOOR) * lam
		# only where this row is actually opaque (a row can have gaps - the legs are two)
		seg = alpha[y, x0:x1 + 1]
		val[y, x0:x1 + 1] = np.where(seg, row, 1.0)
		# the rim: the last opaque pixel on the SHADED side of this row
		shaded_right = LIGHT_U <= 0.0
		idx = x1 if shaded_right else x0
		if alpha[y, idx]:
			rim[y, idx] = True

	# quantise to bands, then lift the rim above its own band
	q = np.floor((val - SHADE_FLOOR) / (1.0 - SHADE_FLOOR) * BANDS)
	q = np.clip(q, 0, BANDS - 1)
	out = SHADE_FLOOR + (1.0 - SHADE_FLOOR) * (q / (BANDS - 1))
	out = np.where(rim, np.minimum(1.0, out + RIM_LIFT), out)
	return np.where(alpha, out, 0.0)


def process(name: str, write: bool, force: bool, check: bool) -> str:
	p = CHARS / f"{name}.png"
	if not p.exists():
		return f"{name:20} MISSING"
	im = Image.open(p).convert("RGBA")
	a = np.asarray(im)
	alpha = a[..., 3] > 0
	val = shade_mask(alpha)
	g = np.clip(np.round(val * 255.0), 0, 255).astype(np.uint8)
	out = np.dstack([g, g, g, a[..., 3]])

	if check:
		same = np.array_equal(out[..., 3], a[..., 3])
		return f"{name:20} alpha identical: {same}"
	levels = len(np.unique(g[alpha]))
	if not write:
		return f"{name:20} {im.size[0]:3}x{im.size[1]:<3} 1 level -> {levels} levels (report only)"
	status = artguard.save_guarded(p, lambda q: Image.fromarray(out, "RGBA").save(q), force)
	return f"{name:20} {im.size[0]:3}x{im.size[1]:<3} -> {levels} levels  [{status}]"


def main() -> int:
	write = "--write" in sys.argv
	force = "--force" in sys.argv
	check = "--check" in sys.argv
	names = [a for a in sys.argv[1:] if not a.startswith("--")] or REGIONS
	for n in names:
		print(process(n, write, force, check))
	if not (write or check):
		print("\n(pass --write to apply, --check to verify the silhouette is untouched)")
	return 0


if __name__ == "__main__":
	sys.exit(main())
