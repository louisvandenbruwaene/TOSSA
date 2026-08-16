#!/usr/bin/env python3
"""Draw the three round props' CARD art: ball, ring and egg.

WHY THESE THREE ARE GENERATED HERE RATHER THAN BY PIXELLAB. prop_big/* is normally
PixelLab's job and it is genuinely good at it - the club, knife, torch and chainsaw
come back on-palette, crisply banded and with a confident silhouette. It cannot draw
a BALL. Measured 2026-08-05, what came back was a raytraced sphere with a smooth
continuous ramp instead of shading bands, standing on a plinth fused to its own
outline; the egg the same; and the ring arrived as a torus in three-quarter
perspective whose tube did not close, so it read as an open coil rather than a ring.
Beside four crisp painted props they looked like a different game, which is exactly
what Louis called out.

Deriving them from the game's own drawing (pixelise_prop.py --big) fixes the geometry
and loses the volume - a flat white disc with a grey rim, because the stage sprite has
eleven pixels to say "sphere" with and does not need to.

But a ball, a ring and an egg are ANALYTIC SURFACES, so there is a third option that
neither generation nor derivation offers: compute the shading exactly. That is what
this does. Every value below is a lighting decision, not a resampling artefact.

WHAT MAKES IT READ AS PIXEL ART RATHER THAN A SMALL RENDER:

1. COVERAGE IS SUPERSAMPLED AND THEN HARD-THRESHOLDED, so the silhouette is a true
   circle at pixel resolution with no semi-transparent fringe. Blur at the edge is the
   single thing that makes generated pixel art look fake.
2. SHADING IS COMPUTED AT FINAL RESOLUTION AND QUANTISED TO BANDS, so a band boundary
   lands on an exact pixel edge. Supersampling the shading too would reintroduce the
   smooth ramp this exists to avoid.
3. The form is carried by six hard lighting bands, without a pale silhouette rim. At title
   size that rim read as a white border around every coloured ball and around the ring.

THEY ARE AUTHORED GREYSCALE AND MUST STAY THAT WAY. draw_prop_icon multiplies these by
the prop's own colour, and a multiply can only ever DARKEN, so the brightest pixel has
to be pure white or every ball in the game is permanently dulled. The floor matters
just as much: GREY_FLOOR keeps the darkest band off black, because against a dark card
a near-black pixel is indistinguishable from a transparent one and the silhouette grows
holes. That is also why there is NO dark outline here, even though the painted props
have one - an outline would multiply toward black and eat the edge.

USAGE
  .venv/bin/python scripts/make_round_props.py               # report only
  .venv/bin/python scripts/make_round_props.py --write       # apply (artguard-guarded)
  .venv/bin/python scripts/make_round_props.py --write --force
  .venv/bin/python scripts/make_round_props.py --write --stage   # the STAGE-size set
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

import artguard

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Assets" / "Props"
VARIANTS = ROOT / "Assets" / "Variants"

SS = 8                # supersampling factor, for coverage only
BANDS = 6             # discrete shading steps - matches the painted props' density
GREY_FLOOR = 0.45     # darkest value a tinted prop may use (see pixelise_prop.py)
LIGHT = np.array([-0.50, -0.62, 0.60])   # key light: upper-left, toward the viewer
LIGHT = LIGHT / np.linalg.norm(LIGHT)

# Sizes chosen so every card reads as equally filled and NOTHING overflows. The card's
# picture area is about 119x92 art px, and draw_prop_icon adds a bob and a contact
# shadow under it, so ~76 art px is the safe ceiling - the painted props run 79-90 tall
# and needed the draw-side offset fix to fit at all. Round props were far smaller than
# the painted ones (a 36px ball beside an 88px club) which left their cards looking
# empty, so they grow here as well as improve.
SIZES = {"ball": (52, 52), "ring": (62, 62), "egg": (46, 60)}

# THE SAME THREE SOLIDS AT STAGE SIZE (2026-08-06, Louis: "make sure that the character,
# objects etc look the same everywhere in the game"). The stage sprites were DERIVED from
# the game's own drawing, and at eleven pixels that derivation gives a flat white disc
# with a grey rim - so the ball in the shop is a lit sphere and the ball he is actually
# juggling is a dot. Two objects, one name.
#
# There is no reason for that: a sphere is a sphere at any resolution, and the shading
# here is computed at final resolution rather than downsampled, so eleven pixels get
# eleven pixels' worth of real bands instead of a blurred copy of fifty-two. Sizes are
# the EXISTING stage sprites' exact dimensions, because those are set by the game's
# physical prop scales and are not an art decision to revisit.
#
# THE SIZES DOUBLED ON 2026-08-15, and the sentence above about them not being an art
# decision is the one part of this note that has gone stale. The physical size on screen is
# unchanged and still not an art decision: what changed is the DENSITY the stage draws at.
# Every prop sprite is now authored at two pixels per screen pixel and blitted through a
# manifest `scale` of 0.5, because at eleven pixels these were still reading as dots while
# their own shop cards read as lit solids (Louis: the stage props "still look very bad and
# pixellated"). See derive_stage_props.py's STAGE_H note for the full reasoning.
#
# THIS IS THE ONE PLACE THAT GAINS TWICE OVER. The four painted props are reduced from a
# card, so doubling gives them more of a picture that already exists. These three are
# COMPUTED, so a 22px ball is not a smoothed 11px ball - it is a sphere solved at 22px, with
# its band boundaries landing on whole pixels at the size it actually ships.
#
# STAGE_BANDS rises 4 -> 6 with them, and for the reason the old note gives: four bands was
# chosen because six across ELEVEN pixels is a band every two pixels, which reads as stripes
# rather than shading. Across twenty-two there is room for six again, which is what the shop
# card uses, so the two sizes finally agree on the same number.
STAGE_SIZES = {"ball": (22, 22), "ring": (42, 42), "egg": (20, 26)}
STAGE_BANDS = 6


_bands = BANDS   # swapped to STAGE_BANDS for the stage set; see build()


def quantise(v: np.ndarray) -> np.ndarray:
	"""Lambert term -> one of _bands discrete values in [GREY_FLOOR, 1]."""
	b = np.clip(np.floor(v * _bands), 0, _bands - 1)
	return GREY_FLOOR + (1.0 - GREY_FLOOR) * (b / (_bands - 1))


def grids(w: int, h: int):
	"""Final-resolution pixel centres, normalised to [-1,1] on the larger axis."""
	ys, xs = np.mgrid[0:h, 0:w]
	x = (xs + 0.5) / w * 2.0 - 1.0
	y = (ys + 0.5) / h * 2.0 - 1.0
	return x, y


def ss_grids(w: int, h: int):
	ys, xs = np.mgrid[0:h * SS, 0:w * SS]
	x = (xs + 0.5) / (w * SS) * 2.0 - 1.0
	y = (ys + 0.5) / (h * SS) * 2.0 - 1.0
	return x, y


def coverage(mask_ss: np.ndarray, w: int, h: int) -> np.ndarray:
	"""Supersampled mask -> hard pixel mask (majority coverage)."""
	m = mask_ss.reshape(h, SS, w, SS).mean(axis=(1, 3))
	return m >= 0.5


def shade(nx, ny, nz, inside):
	"""Wrapped lambert + specular + rim, quantised. Returns value in [0,1]."""
	ndl = nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2]
	# WRAP LIGHTING, not clipped lambert. Straight max(0, N.L) puts the terminator
	# halfway across the form and dumps everything beyond it into the darkest band, so
	# a sphere came out as a bright crescent on a big flat grey field - and since these
	# sprites are MULTIPLIED by the prop's colour, that flat field is what the shop card
	# actually shows. Wrapping remaps [-1,1] to [0,1] so the bands spread evenly across
	# the whole surface, which is both how a round object looks under a soft stage light
	# and how pixel artists band a sphere by hand.
	lam = ndl * 0.5 + 0.5
	val = quantise(lam)
	# SPECULAR: a small hard cluster where the surface faces the light most directly.
	# Pure white, because a multiply can only darken and this is the tint's anchor.
	val = np.where(ndl > 0.955, 1.0, val)
	# A uniform dark silhouette replaces the old pale rim. It is shared by ball and ring,
	# so differently tinted copies still read as the same manufactured prop design.
	padded = np.pad(inside, 1, constant_values=False)
	core = (padded[1:-1, :-2] & padded[1:-1, 2:] & padded[:-2, 1:-1]
		& padded[2:, 1:-1])
	padded_core = np.pad(core, 1, constant_values=False)
	core = (padded_core[1:-1, :-2] & padded_core[1:-1, 2:]
		& padded_core[:-2, 1:-1] & padded_core[2:, 1:-1])
	val = np.where(inside & ~core, GREY_FLOOR, val)
	return np.where(inside, val, 0.0)


def sphere(w, h):
	xs, ys = ss_grids(w, h)
	inside = coverage(xs ** 2 + ys ** 2 <= 1.0, w, h)
	x, y = grids(w, h)
	r2 = np.clip(x ** 2 + y ** 2, 0.0, 1.0)
	z = np.sqrt(np.maximum(0.0, 1.0 - r2))
	return shade(x, y, z, inside), inside


def egg(w, h):
	# A classic egg profile: an ellipse whose width tapers toward the TOP, so the blunt
	# end is down. Shading uses the ellipsoid normal, which is close enough at this size
	# and far steadier than differentiating the taper.
	def prof(x, y):
		t = np.clip(1.0 - 0.22 * (-y), 0.02, 2.0)   # y = -1 at top, +1 at bottom
		return (x / t) ** 2 + y ** 2

	xs, ys = ss_grids(w, h)
	inside = coverage(prof(xs, ys) <= 1.0, w, h)
	x, y = grids(w, h)
	r2 = np.clip(prof(x, y), 0.0, 1.0)
	z = np.sqrt(np.maximum(0.0, 1.0 - r2))
	return shade(x, y, z, inside), inside


def ring(w, h):
	# FACE-ON, matching the ring the stage actually draws, and a closed tube - the
	# generated one's open seam is what made it read as a coil. The surface normal is
	# the torus normal: at distance d from the centre, the tube's cross-section angle
	# is phi = asin((d - R_mid) / R_tube), and the normal leans radially by sin(phi)
	# while facing the viewer by cos(phi).
	# THINNER, AND THE OUTER RADIUS IS DELIBERATELY UNCHANGED (2026-08-07, Louis: "the juggle
	# rings are too thick"). At 0.72/0.26 the tube was 53% of the outer diameter - the hole was
	# smaller than the metal round it, which is a quoit, not a juggling ring. A real one is
	# nearer 13%; 27% is as thin as this density can carry, because the stage ring is 21px
	# across and the tube has to survive a box filter and still show a lit and a shaded side.
	#
	# r_mid + r_tube stays 0.98, so the SILHOUETTE is the same size as before. That matters
	# beyond looks: a prop's outer extent is collision geometry, and only its art is being
	# changed here - collcheck must read identically after this, and it does.
	r_mid, r_tube = 0.845, 0.135
	xs, ys = ss_grids(w, h)
	d_ss = np.sqrt(xs ** 2 + ys ** 2)
	inside = coverage(np.abs(d_ss - r_mid) <= r_tube, w, h)
	x, y = grids(w, h)
	d = np.sqrt(x ** 2 + y ** 2)
	d = np.where(d < 1e-6, 1e-6, d)
	phi = np.arcsin(np.clip((d - r_mid) / r_tube, -1.0, 1.0))
	nz = np.cos(phi)
	nr = np.sin(phi)
	return shade(x / d * nr, y / d * nr, nz, inside), inside


SHAPES = {"ball": sphere, "ring": ring, "egg": egg}


def build(name: str, write: bool, force: bool, stage: bool = False) -> str:
	global _bands
	_bands = STAGE_BANDS if stage else BANDS
	w, h = (STAGE_SIZES if stage else SIZES)[name]
	val, inside = SHAPES[name](w, h)
	g = np.clip(np.round(val * 255.0), 0, 255).astype(np.uint8)
	rgba = np.dstack([g, g, g, np.where(inside, 255, 0).astype(np.uint8)])
	# tight-crop: prop_big/* has no pivot, so art_blit centres on the canvas
	ys, xs = np.where(inside)
	rgba = rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
	levels = len(np.unique(g[inside]))
	if not write:
		return f"{name:5} {rgba.shape[1]:3}x{rgba.shape[0]:<3} {levels} grey levels  (report only)"
	# BOTH SIZES ARE THE SHIPPED ART now (2026-08-06, Louis: "the shop designs for the
	# objects are decent, use those everywhere"). The stage set was briefly an F9 variant;
	# it is simply the stage sprite, because one object should not have two designs.
	p = OUT / (f"{name}.png" if stage else f"big_{name}.png")
	p.parent.mkdir(parents=True, exist_ok=True)
	status = artguard.save_guarded(p, lambda q: Image.fromarray(rgba, "RGBA").save(q), force)
	return f"{name:5} {rgba.shape[1]:3}x{rgba.shape[0]:<3} {levels} grey levels  [{status}]"


def main() -> int:
	write = "--write" in sys.argv
	force = "--force" in sys.argv
	stage = "--stage" in sys.argv
	names = [a for a in sys.argv[1:] if not a.startswith("--")] or list(SIZES)
	for n in names:
		print(build(n, write, force, stage))
	if not write:
		print("\n(pass --write to apply)")
	return 0


if __name__ == "__main__":
	sys.exit(main())
