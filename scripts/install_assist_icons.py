#!/usr/bin/env python3
"""Reduce the two assist icons to tintable 10x10 sprites (ui/assist_boot, ui/assist_watch).

WHAT THEY ARE. The play HUD carries two switches - a BOOT for the Speed stat's slow motion
and a STOPWATCH for every temporary source of it (the difficulty base, Uncle Dan's Pie, the
two earned bursts). Louis asked for the marks themselves to come from PixelLab rather than
be drawn from primitives, which they were first: at eight art pixels a boot built from two
rectangles is the letter L, and the notch that makes it a boot is the whole silhouette.

40x40 GENERATED, 10x10 SHIPPED. That is an exact 4:1 box reduction and no resampling, the
same generate-big-and-derive route the props and the gear rack already take, and it exists
because 10x10 is a hundred pixels against PixelLab's 1024-pixel AREA floor - the size cannot
be asked for directly at all. 10 art px is 20 screen px, which is the scale a stage ball is
drawn at (11x11), so these sit in the HUD as objects rather than as glyphs.

GREYSCALE IS THE ARCHITECTURE, NOT A COMPROMISE - the same rule the gear rack follows and
for a sharper reason here: the tint IS the switch's state. A running assist is drawn in warm
cyan at full strength; one the player has given up is dim grey. Paint colour into the sprite
and neither state can be expressed, because a tint can only darken. So the file stores a
luminance RATIO normalised to the icon's own brightest pixel, and every icon's highlight is
therefore white.

WHERE THE SOURCES COME FROM. `artifacts/` is gitignored - only derived assets ship, the same
as the gear rack - so the two 40x40 inputs are NOT in the repo and the prompts are written
down here instead, or they are unregenerable. Both were `create_image_pixflux`, 40x40,
no_background, selective outline, basic shading, low detail, seed 7:

  boot   "a single tall leather boot in side profile, one boot only, plain sturdy riding
          boot with a cuff at the top and a flat sole, no legs, no person, no ground, no
          shadow"  (view: side)
  watch  "a round pocket stopwatch seen face on, big circular dial with a small crown button
          and ring on top, two hands on the dial, no chain, no ground, no shadow"

Save each to artifacts/assist/<name>.png before running this.

USAGE
  .venv/bin/python scripts/install_assist_icons.py            preview
  .venv/bin/python scripts/install_assist_icons.py --write
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

import artguard

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "artifacts" / "assist"
OUT = ROOT / "Assets" / "UI" / "assist"

SRC_PX, OUT_PX = 40, 20

# THE OUTPUT SIZE IS 20, AND 10 WAS TRIED AND MEASURED. At 10x10 the boot came back as 22 lit
# pixels - the cuff, the heel and the ankle all gone - which is the letter L again, i.e. exactly
# the shape the hand-drawn version was replaced for. At 20x20 it is 97 pixels and has a heel, a
# sole and a cuff, and the stopwatch has a dial, two hands, a crown and a ring.
#
# IT STILL DRAWS 20 SCREEN PX WIDE, because the manifest blits these at `scale` 0.5 - the same
# double-density route every stage prop takes. One source pixel lands on exactly one screen
# pixel, which keeps the whole-number rule the density lock exists to protect, and buys four
# times the authored detail at an unchanged size on screen. See CLAUDE.md's prop-density note.

NAMES = ["boot", "watch"]

# Below this the pixel is not the object. A generated cut-out leaves a fringe of very low
# alpha around its edge, and at 10x10 a fringe is a THIRD of the object - hard-cut it, the
# same way pixelise_prop and the gear rack do, rather than letting it smear the silhouette.
# Higher than the rack's 110 for exactly that reason: the reduction here is 4:1, not 2:1, so
# a single edge pixel of the source contributes a sixteenth of an output pixel's alpha and
# the fringe arrives correspondingly fainter and wider.
ALPHA_CUT = 128

# The darkest a lit pixel may go, as a fraction of the icon's own brightest. A tint can only
# darken, and the OFF state already multiplies by a dim grey - so anything near zero here is
# a hole in the shape rather than a shadow on it. The rack settled on 0.26 and the body
# regions on 0.64 for the same reason; these are read at a glance, so they take the rack's.
GREY_FLOOR = 0.26

# How many discrete lighting steps a finished icon may use. Six is what the round props
# already band to, and it is the density the painted props read at - enough for a lit face,
# a mid tone, a shadow side and a rim, and few enough that every boundary is a hard edge.
BANDS = 6


def trim_plinth(a: np.ndarray) -> np.ndarray:
	"""Cut the pedestal PixelLab fuses to the bottom of a round object.

	The generator returns objects STANDING ON SOMETHING even when told not to - the stopwatch
	came back on a flat dark bar - and a baked shadow under an icon that the HUD already draws
	its own ground for is a second shadow at a different angle. trim_plinth.py explains the
	failure and the fix at length for the round props; this is the same two-signal rule it
	arrived at, because the obvious "drop narrow bottom rows" test fires on nothing: a plinth
	is not a thin stub, it is a wide flat shadow fused to the silhouette.

	  1. below the widest row, the row is WIDER than the row above it  (convexity broken)
	  2. and it is markedly DARKER than the object's own body          (it is a shadow)

	Measured on the stopwatch: widths run ... 19, 17, 15, then 19, 25, 19, 11 while luminance
	falls from ~160 in the dial to 33-124. Everything from the first break down goes.
	"""
	alpha = a[..., 3]
	lum = 0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]
	lit = alpha >= ALPHA_CUT
	widths = lit.sum(axis=1)
	rows = np.flatnonzero(widths)
	if rows.size == 0:
		return a
	body = float(np.median(lum[lit])) if lit.any() else 0.0
	widest = int(np.argmax(widths))
	for y in range(widest + 1, int(rows[-1]) + 1):
		if widths[y] <= widths[y - 1] or widths[y] == 0:
			continue
		row_lum = float(lum[y][lit[y]].mean())
		if row_lum < body * 0.92:
			a = a.copy()
			# `a[y:, :, 3]`, NOT `a[y:, 3]` - the second slices COLUMN 3 of those rows across
			# all four channels, which on this sprite was already transparent, so the trim
			# silently did nothing and reported success.
			a[y:, :, 3] = 0.0     # the plinth and everything under it
			break
	return a


def build(name: str, write: bool, force: bool) -> str:
	src = SRC / f"{name}.png"
	if not src.exists():
		return f"{name}: no art at artifacts/assist/{name}.png"
	im = Image.open(src).convert("RGBA")
	if im.size != (SRC_PX, SRC_PX):
		raise SystemExit(f"{name}: expected {SRC_PX}x{SRC_PX}, got {im.size}")
	a = np.asarray(im).astype(float)
	rgb, alpha = a[..., :3], a[..., 3]
	a = trim_plinth(a)
	rgb, alpha = a[..., :3], a[..., 3]

	# PREMULTIPLY BEFORE FILTERING. Box-averaging straight RGBA pulls the colour of fully
	# transparent pixels (usually black) into every edge pixel, which at this size darkens
	# the whole rim. Average premultiplied colour and alpha, then unpremultiply.
	pm = rgb * (alpha[..., None] / 255.0)
	k = SRC_PX // OUT_PX
	pm = pm.reshape(OUT_PX, k, OUT_PX, k, 3).mean(axis=(1, 3))
	al = alpha.reshape(OUT_PX, k, OUT_PX, k).mean(axis=(1, 3))
	safe = np.maximum(al[..., None] / 255.0, 1e-6)
	small = pm / safe

	keep = al >= ALPHA_CUT
	lum = (0.299 * small[..., 0] + 0.587 * small[..., 1] + 0.114 * small[..., 2])
	if not keep.any():
		return f"{name}: nothing survived the alpha cut"
	top = float(lum[keep].max())
	ratio = np.clip(lum / max(top, 1e-6), 0.0, 1.0)
	# BANDED, NOT RAMPED, AND THIS IS WHAT MAKES IT PIXEL ART (2026-08-24, Louis: everything
	# has to look "sharp and pixellated"). A 4:1 or 2:1 box reduction of a generation is an
	# AVERAGE, so what came out here was a continuous ratio - measured, 84 distinct grey
	# levels inside a 20x20 boot and 56 inside a glove. At that size a smooth ramp has
	# nowhere to be smooth: every one of those levels is one or two pixels, so the icon
	# reads as a blurred photograph of an object rather than a drawing of one, which is
	# exactly the fault `make_round_props.py` exists to avoid on the round props.
	# Quantising to BANDS steps is the same decision that file already made ("shading is
	# computed at final resolution and quantised to bands, so a band boundary lands on an
	# exact pixel edge"), applied one stage later - here the ramp is measured rather than
	# computed, but the cure is identical.
	ratio = np.rint(ratio * (BANDS - 1)) / float(BANDS - 1)
	ratio = GREY_FLOOR + (1.0 - GREY_FLOOR) * ratio
	g = np.where(keep, np.rint(ratio * 255.0), 0).astype(np.uint8)
	out = np.dstack([g, g, g, np.where(keep, 255, 0).astype(np.uint8)])

	levels = len(np.unique(g[keep]))
	cover = int(keep.sum())
	tag = f"{name}: {cover}/{OUT_PX * OUT_PX} px, {levels} grey levels"
	if not write:
		return tag + "  (pass --write to apply)"
	OUT.mkdir(parents=True, exist_ok=True)
	st = artguard.save_guarded(OUT / f"{name}.png",
							   lambda q: Image.fromarray(out, "RGBA").save(q), force)
	return tag + f" [{st}]"


def main() -> int:
	write = "--write" in sys.argv
	force = "--force" in sys.argv
	only = [x for x in sys.argv[1:] if not x.startswith("--")]
	for name in NAMES:
		if only and name not in only:
			continue
		print("  " + build(name, write, force))
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
