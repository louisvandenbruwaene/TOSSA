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
2. THE FLOOR IS HIGH (see each look's `floor`). This is cloth under a warm stage lamp, not a
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
  .venv/bin/python scripts/shade_char_regions.py --write --look volume   # a variant set
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

import artguard

ROOT = Path(__file__).resolve().parent.parent
CHARS = ROOT / "Assets" / "Characters"
VARIANTS = ROOT / "Assets" / "Variants"

# Only the costume regions. NOT torso_button (a literal colour, not costume-derived, and
# four pixels across), and NOT the head, hands, hat, glasses or boots - those were traced
# with their own shading already and are not cylinders.
REGIONS = [
	"torso_suit", "torso_vest", "torso_collar",
	"torso_back_suit", "torso_back_collar",
	"legs_trouser",
]

# THE LOOKS (2026-08-06, Louis: "implement multiple designs and let me choose them with
# F9"). Three ways of lighting ONE body, not three bodies: every profile below writes the
# same alpha, so the stance and the proportions are bit-identical across all of them and
# the never-reshape-the-juggler rule holds by construction rather than by care. --check
# proves it for whichever look is selected.
#
# They differ in the two things that actually decide whether cloth reads as cloth: how far
# the shadow side falls, and how many steps it takes to get there. Keep them in step with
# LOOKS in shade_char_hands.py - a performer lit one way at the sleeve and another at the
# wrist is worse than either look on its own.
LOOKS = {
	# The shipped default. Restrained: a high floor and four bands, which is a jacket
	# under a warm lamp rather than a figure study.
	"classic": dict(floor=0.64, bands=4, rim=0.10, light=-0.42),
	# Rounder and more lit. The floor drops far enough for a real turn away from the
	# light, five bands carry it without stepping, and the rim is strong enough to hold
	# the silhouette off a dark backdrop. This is the one that reads as volume.
	"volume":  dict(floor=0.46, bands=5, rim=0.18, light=-0.48),
	# A drawn contour instead of a lit edge: the outermost ring goes dark and the cloth
	# inside it stays bright and flat-ish. Fewer bands on purpose - an inked look wants
	# clean areas of colour, not a ramp - and it is the most legible of the three at a
	# distance, which on a stage is not nothing.
	"inked":   dict(floor=0.74, bands=3, rim=0.00, light=-0.40, ink=0.38),
}

INK_MIN_SPAN = 9   # pixels: the narrowest run an "inked" contour may be drawn on - see below


def shade_mask(alpha: np.ndarray, prof: dict | None = None) -> np.ndarray:
	"""Cylinder shading in [floor, 1.0] for every opaque pixel."""
	prof = prof or LOOKS["classic"]
	floor = prof["floor"]
	bands = prof["bands"]
	light_u = prof["light"]
	rim_lift = prof["rim"]
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
		# cylinder normal (sin theta, cos theta) against a light at `light_u`
		lt = light_u * (np.pi * 0.5)
		ndl = np.cos(theta - lt)
		# wrap it, exactly as the round props do: clipped lambert throws half the form
		# into one flat band, which on a 37px torso is most of the torso
		lam = np.clip(ndl * 0.5 + 0.5, 0.0, 1.0)
		row = floor + (1.0 - floor) * lam
		# only where this row is actually opaque (a row can have gaps - the legs are two)
		seg = alpha[y, x0:x1 + 1]
		val[y, x0:x1 + 1] = np.where(seg, row, 1.0)
		# the rim: the last opaque pixel on the SHADED side of this row
		shaded_right = light_u <= 0.0
		idx = x1 if shaded_right else x0
		if alpha[y, idx]:
			rim[y, idx] = True

	# quantise to bands, then lift the rim above its own band
	q = np.floor((val - floor) / (1.0 - floor) * bands)
	q = np.clip(q, 0, bands - 1)
	out = floor + (1.0 - floor) * (q / (bands - 1))
	if rim_lift > 0.0:
		out = np.where(rim, np.minimum(1.0, out + rim_lift), out)
	if "ink" in prof:
		# INKED: the whole outer ring goes dark, not just the shaded side's last pixel.
		# A contour is a drawn edge and belongs on every side of the shape; a rim is a
		# lit edge and belongs only where the light is not.
		edge = alpha & ~(
			np.roll(alpha, 1, 0) & np.roll(alpha, -1, 0)
			& np.roll(alpha, 1, 1) & np.roll(alpha, -1, 1))
		# ...BUT NOT WHERE THE SHAPE IS TOO NARROW TO HOLD ONE. A contour costs a pixel off
		# each side of every row it touches, and a trouser leg is six pixels wide at the
		# ankle: inked on both sides it is two thirds outline, which stops reading as a leg
		# with an edge and starts reading as a dashed line. Measured on the first pass -
		# the legs came out visibly broken while the 37px torso looked exactly right. Rows
		# under INK_MIN_SPAN keep the ordinary lit rim instead, which is the same decision
		# a person inking this by hand would make.
		narrow = np.zeros(alpha.shape, dtype=bool)
		for y in range(alpha.shape[0]):
			xs = np.where(alpha[y])[0]
			if xs.size == 0:
				continue
			# per RUN, not per row: the legs are two separate spans on one row and each
			# has to be judged on its own width, not on the gap between them
			splits = np.where(np.diff(xs) > 1)[0]
			for run in np.split(xs, splits + 1):
				if run.size < INK_MIN_SPAN:
					narrow[y, run] = True
		out = np.where(edge & ~narrow, prof["ink"], out)
	return np.where(alpha, out, 0.0)


def process(name: str, look: str, write: bool, force: bool, check: bool) -> str:
	p = CHARS / f"{name}.png"
	if not p.exists():
		return f"{name:20} MISSING"
	im = Image.open(p).convert("RGBA")
	a = np.asarray(im)
	alpha = a[..., 3] > 0
	val = shade_mask(alpha, LOOKS[look])
	g = np.clip(np.round(val * 255.0), 0, 255).astype(np.uint8)
	out = np.dstack([g, g, g, a[..., 3]])

	if check:
		same = np.array_equal(out[..., 3], a[..., 3])
		return f"{name:20} alpha identical: {same}"
	levels = len(np.unique(g[alpha]))
	if not write:
		return f"{name:20} {im.size[0]:3}x{im.size[1]:<3} 1 level -> {levels} levels (report only)"
	# "classic" IS the shipped art and is written in place; every other look goes to its
	# own directory, where a variant manifest picks it up and art_boot lays it over the top.
	dst = p if look == "classic" else (VARIANTS / f"character_{look}" / f"{name}.png")
	dst.parent.mkdir(parents=True, exist_ok=True)
	status = artguard.save_guarded(dst, lambda q: Image.fromarray(out, "RGBA").save(q), force)
	return f"{name:20} {im.size[0]:3}x{im.size[1]:<3} -> {levels} levels  [{status}]"


def main() -> int:
	write = "--write" in sys.argv
	force = "--force" in sys.argv
	check = "--check" in sys.argv
	look = sys.argv[sys.argv.index("--look") + 1] if "--look" in sys.argv else "classic"
	if look not in LOOKS:
		print(f"unknown look '{look}' - have: {', '.join(LOOKS)}")
		return 2
	names = [a for a in sys.argv[1:] if not a.startswith("--")]
	names = [n for n in names if n in REGIONS] or REGIONS
	for n in names:
		print(process(n, look, write, force, check))
	if not (write or check):
		print("\n(pass --write to apply, --check to verify the silhouette is untouched)")
	return 0


if __name__ == "__main__":
	sys.exit(main())
