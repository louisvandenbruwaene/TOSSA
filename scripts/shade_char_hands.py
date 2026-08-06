#!/usr/bin/env python3
"""Give the juggler's HANDS form, and stop them coming out brown.

TWO FAULTS, ONE CAUSE. Measured 2026-08-06:

  hand_open    12x16   1 luminance level, all of it at 0.45
  hand_closed  12x12   1 luminance level, all of it at 0.45

They are flat masks, exactly as torso_suit and legs_trouser were before
shade_char_regions.py - and for the same reason, they were traced out of a render and the
tracing kept one tone. But a hand is worse off than a torso was, because the game draws it
through a TINT, and a tint is a multiply that can only darken. Skin is (0.87, 0.63, 0.43);
multiplied by a flat 0.45 the performer's bare hands land near (0.39, 0.28, 0.19), which
is the muddy brown Louis has been looking at on stage and in the tailor's mirror. The
gloves escaped it only because their cloth is nearly white to begin with.

So the fix is not to brighten them, it is to give them the thing a flat mask does not
have: a lit side at PURE WHITE (the tint then lands at full skin colour), shading that
falls away from it, and a rim that separates the hand from the backdrop.

A HAND IS A DOME, NOT A CYLINDER, which is why this is not shade_char_regions. A mitt is a
palm seen face-on - it turns away in every direction, not just left and right - and the
open mitt has a thumb bulge on one side that a per-row cylinder would light as though it
were part of the palm. So the height field comes from a EUCLIDEAN DISTANCE TRANSFORM of
the silhouette: far from any edge is high, near an edge is low, and that is true of the
thumb on its own terms as well as of the palm. The surface normal is the gradient of that
dome, and the light is the same front-upper-left key the rest of the figure uses.

WHAT IT DOES NOT TOUCH. The alpha channel is copied through untouched, so the silhouette,
and therefore the stance and the proportions, come out bit-identical. --check proves it.

USAGE
  .venv/bin/python scripts/shade_char_hands.py            # report
  .venv/bin/python scripts/shade_char_hands.py --check    # prove alpha is untouched
  .venv/bin/python scripts/shade_char_hands.py --write [--force]
  .venv/bin/python scripts/shade_char_hands.py --write --look volume   # a variant set
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt

import artguard

ROOT = Path(__file__).resolve().parent.parent
CHARS = ROOT / "Assets" / "Characters"
VARIANTS = ROOT / "Assets" / "Variants"

# Every part the game TINTS and draws as a hand. The head is deliberately absent: it is
# drawn UNTINTED so it keeps its own full colour, so its greyscale is not a ratio of
# anything and doming it would only flatten the face.
TARGETS = ["hand_open", "hand_closed", "glove_open", "glove_closed"]

# THE LOOKS. Each is a shading profile, not a redrawing - every one of them writes the
# same alpha, so they are three ways of lighting one hand rather than three hands. Keep
# these in step with the profiles in shade_char_regions.py: a performer whose sleeves are
# lit one way and whose hands are lit another is worse than either alone.
LOOKS = {
	# floor, bands, rim lift, light direction (x, y into the screen), specular
	"classic": dict(floor=0.62, bands=4, rim=0.10, light=(-0.45, -0.55), spec=0.0),
	"volume":  dict(floor=0.48, bands=5, rim=0.16, light=(-0.50, -0.60), spec=0.55),
	"inked":   dict(floor=0.70, bands=3, rim=0.00, light=(-0.40, -0.50), spec=0.0, ink=0.34),
}


def dome_shade(alpha: np.ndarray, prof: dict) -> np.ndarray:
	"""Lambert over a dome raised from the silhouette's distance transform."""
	solid = alpha > 127
	if not solid.any():
		return np.zeros(alpha.shape, dtype=float)

	# THE NORMAL IS A SPHERE'S, taken across the WHOLE silhouette rather than raised from
	# its edges. The first attempt built a height field out of the distance transform, and
	# on a 12-pixel hand that fails in a way worth recording: the interior of a shape that
	# small is one flat plateau three pixels in, so the gradient - and therefore all the
	# shading - lived in a one-pixel ring at the rim and the palm came out uniformly white.
	# Measured: 2 luminance levels, mean 0.99. A sphere has a normal that turns
	# continuously from one side of the shape to the other, which is what puts four real
	# bands across twelve pixels. It is also the same surface make_round_props.py fits to
	# a ball, so a hand and the ball in it are lit by one model.
	ys, xs = np.where(solid)
	cy, cx = (ys.min() + ys.max()) * 0.5, (xs.min() + xs.max()) * 0.5
	ry = max((ys.max() - ys.min()) * 0.5, 0.5)
	rx = max((xs.max() - xs.min()) * 0.5, 0.5)
	yy, xx = np.mgrid[0:alpha.shape[0], 0:alpha.shape[1]]
	u = (xx - cx) / rx
	v = (yy - cy) / ry
	# clamped rather than masked: a thumb bulge sits OUTSIDE the fitted ellipse, and
	# leaving it undefined would light it as though it were the darkest point on the hand.
	# Pinned to the limb of the sphere, it instead reads as part of the same form.
	r2 = np.clip(u * u + v * v, 0.0, 1.0)
	nz = np.sqrt(1.0 - r2)
	scale = np.where(u * u + v * v > 1.0, 1.0 / np.sqrt(np.maximum(u * u + v * v, 1e-6)), 1.0)
	n = np.dstack([u * scale, v * scale, nz])
	n /= np.maximum(np.linalg.norm(n, axis=2, keepdims=True), 1e-6)
	edt = distance_transform_edt(solid)

	lx, ly = prof["light"]
	lvec = np.array([lx, ly, 0.72])
	lvec /= np.linalg.norm(lvec)
	ndl = (n * lvec).sum(axis=2)

	# WRAPPED, not clipped - the same call the round props make. A clipped lambert dumps
	# every pixel facing away from the light into one flat band, and on a 12px hand that is
	# most of the hand.
	lam = np.clip(ndl * 0.5 + 0.5, 0.0, 1.0)

	floor, bands = prof["floor"], prof["bands"]
	q = np.clip(np.floor(lam * bands), 0, bands - 1)
	val = floor + (1.0 - floor) * (q / (bands - 1))

	if prof.get("spec", 0.0) > 0.0:
		# ONE specular pixel-cluster where the dome faces the light most directly, pinned
		# to pure white. It is what stops a shaded blob reading as a flat disc, and it is
		# the same anchor make_round_props.py puts on a ball.
		hot = ndl >= np.percentile(ndl[solid], 100.0 - prof["spec"] * 18.0)
		val = np.where(solid & hot, 1.0, val)

	# THE RIM, on the shaded side: the outermost ring of pixels, lifted slightly above the
	# band it sits in. On a dark stage this is the difference between a hand and a hole.
	edge = solid & (edt <= 1.5)
	shaded = ndl < 0.0
	if prof["rim"] > 0.0:
		val = np.where(edge & shaded, np.minimum(1.0, val + prof["rim"]), val)

	if "ink" in prof:
		# INKED: a contour instead of a rim. The outermost ring goes DARK, which is the
		# selective-outline look - it reads as a drawn edge rather than as a lit one.
		val = np.where(edge, prof["ink"], val)

	return np.where(alpha > 0, val, 0.0)


def process(name: str, look: str, write: bool, force: bool, check: bool) -> str:
	src = CHARS / f"{name}.png"
	if not src.exists():
		return f"{name:16} MISSING"
	im = Image.open(src).convert("RGBA")
	a = np.asarray(im)
	val = dome_shade(a[..., 3], LOOKS[look])
	g = np.clip(np.round(val * 255.0), 0, 255).astype(np.uint8)
	out = np.dstack([g, g, g, a[..., 3]])

	if check:
		return f"{name:16} alpha identical: {np.array_equal(out[..., 3], a[..., 3])}"

	solid = a[..., 3] > 127
	before = (np.asarray(im).astype(float)[..., :3].mean(axis=2) / 255.0)[solid].mean()
	after = (val[solid].mean()) if solid.any() else 0.0
	levels = len(np.unique(g[a[..., 3] > 0]))
	msg = (f"{name:16} {im.size[0]:3}x{im.size[1]:<3} mean {before:.2f} -> {after:.2f}"
	       f"  {levels} levels")
	if not write:
		return msg + "   (report only)"
	# option 0 ("classic") IS the shipped art and is written in place; every other look
	# goes to its own directory, where a variant manifest picks it up.
	dst = src if look == "classic" else (VARIANTS / f"character_{look}" / f"{name}.png")
	dst.parent.mkdir(parents=True, exist_ok=True)
	status = artguard.save_guarded(dst, lambda q: Image.fromarray(out, "RGBA").save(q), force)
	return msg + f"  -> {dst.relative_to(ROOT)}  [{status}]"


def main() -> int:
	write = "--write" in sys.argv
	force = "--force" in sys.argv
	check = "--check" in sys.argv
	look = "classic"
	if "--look" in sys.argv:
		look = sys.argv[sys.argv.index("--look") + 1]
	if look not in LOOKS:
		print(f"unknown look '{look}' - have: {', '.join(LOOKS)}")
		return 2
	names = [a for a in sys.argv[1:] if not a.startswith("--")]
	names = [n for n in names if n in TARGETS] or TARGETS
	for name in names:
		print(process(name, look, write, force, check))
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
