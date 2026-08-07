#!/usr/bin/env python3
"""Bake the seven VENUE EXTERIOR cards into ui/ext_*.

WHY THESE, AND WHY LAST. The exterior is a full-bleed illustration shown before every act
and twice more in the day hub, and it was one of the last vector pictures left in the game.
It is not sloppy code: it is a moon, a fan of big-top stripes, a row of city rooftops and a
theatre pediment, and every one of those is a circle or a diagonal. Antialiasing is what a
renderer does with those, however carefully the vertices are snapped - so the card was crisp
pixel-art text and a crisp pixel wordmark standing in front of a smooth painting.

THE SPLIT IS THE SAME ONE EVERY BAKE IN THIS PROJECT MAKES: the bake holds the SCENERY and
whatever MOVES is drawn live over it. Here that is the dust, and only the dust. Compare
--bgref (sky and dressing baked, veil and spotlight live, because the cone narrows as a
streak builds) and --menuref (the proscenium baked, the light live).

THE STARS ARE BAKED IN, and that is a gain rather than a compromise. A star was a 2.6px
rect at a fractional position - at this density a grey smudge straddling four art pixels,
which is exactly what a bake is supposed to remove. Baked it becomes a hard white speck.
What it costs is the twinkle, and the card answers that with drifting dust.

THE SOURCE IS THE GAME'S OWN DRAWING, captured by `--extref <vi>` at 1280x720 and reduced by
exactly two. There is no generation step and there should not be: unlike a stage backdrop,
an exterior is a picture the game already composes correctly, with the venue's hero mid-frame
and the marquee text laid out against it. A model asked for "a circus tent at night" would
give back a different composition, and the card's own layout would no longer fit it.

USAGE
  scripts/gen_ext_refs.sh                       capture all seven
  .venv/bin/python scripts/pixelise_ext.py      reduce every capture found
  .venv/bin/python scripts/pixelise_ext.py --write
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

import artguard
from pixelise_menu import ART_H, ART_W, load_palette, srgb_to_oklab

ROOT = Path(__file__).resolve().parent.parent
REF = ROOT / "artifacts" / "ext_ref"
OUT = ROOT / "Assets" / "UI"

# index order matches Game.gd's EXT_KEYS and draw_venue_exterior's own match
NAMES = ["backyard", "street_corner", "small_theatre", "the_circus",
		 "championship", "world_arena", "the_midnight_show"]


# HOW MUCH QUANTISATION ERROR MAY BE PUSHED INTO THE NEXT PIXEL, per channel.
#
# Unclamped Floyd-Steinberg fixes the banding and then speckles a dusk sky with RED, because
# the locked 48 colours have no purples in the middle of that ramp: the residual after
# picking a blue is a large red error, it all lands on one neighbour, and that neighbour
# flips to a warm entry. Capping the error keeps the diffusion doing what it is for - moving
# a small residual around so a gradient averages out - without letting one pixel's shortfall
# spend itself on a single loud pixel next door. Measured against 24 and 40: at 14 the sky
# is smooth and quiet, at 40 it is a red rash.
ERR_CLAMP = 14.0


def snap_diffused(rgb: np.ndarray, pal: np.ndarray) -> np.ndarray:
	"""Palette-snap with SERPENTINE ERROR DIFFUSION, not the ordered dither the menu uses.

	The two are not interchangeable and it took a couple of wrong turns to see why. Ordered
	(Bayer) dithering mixes the two NEAREST palette entries in the ratio of their distances,
	which is exactly right when a colour sits between two entries a hair apart - the title
	proscenium's case, where the whole picture is one slow near-black wash. An exterior is
	the other case: a dusk sky crosses the palette's sparsest region, so the true colour is
	far from BOTH neighbours, the distance ratio stops predicting the perceptual mix, and the
	result is a plateau. Whole rows of the card picked the same pair and the backyard came
	back looking like a deckchair.

	Error diffusion does not guess the mix - it measures what it got wrong and carries the
	remainder forward, so a ramp the palette cannot hold comes out as the right average.
	Serpentine (alternate rows scanned backwards) because a one-way scan drags its residual
	into a diagonal grain that is very visible across an empty sky.

	THE SOURCE HAS TO BE SMOOTH FIRST. This was the other wrong turn: draw_gradient_v paints
	about twenty strips, invisible on screen and hard stripes once snapped, and no reducer
	setting can undo a band that is already in its input. See the reference-render branch in
	draw_gradient_v."""
	a = rgb.astype(float).copy()
	h, w = a.shape[:2]
	lab = srgb_to_oklab(pal.astype(float))
	out = np.zeros((h, w, 3), np.uint8)
	for y in range(h):
		fwd = y % 2 == 0
		xs = range(w) if fwd else range(w - 1, -1, -1)
		d = 1 if fwd else -1
		for x in xs:
			old = a[y, x]
			i = int(np.argmin(np.linalg.norm(
				srgb_to_oklab(np.clip(old, 0.0, 255.0)[None, :]) - lab, axis=1)))
			out[y, x] = pal[i]
			err = np.clip(old - pal[i], -ERR_CLAMP, ERR_CLAMP)
			if 0 <= x + d < w:
				a[y, x + d] += err * (7.0 / 16.0)
			if y + 1 < h:
				if 0 <= x - d < w:
					a[y + 1, x - d] += err * (3.0 / 16.0)
				a[y + 1, x] += err * (5.0 / 16.0)
				if 0 <= x + d < w:
					a[y + 1, x + d] += err * (1.0 / 16.0)
	return out


def build(src: Path, dst: Path, write: bool, force: bool) -> str:
	im = Image.open(src).convert("RGB")
	if im.size == (ART_W * 2, ART_H * 2):
		# the game's own render: an exact 2:1 box reduction, one art pixel per 2x2 block
		im = im.resize((ART_W, ART_H), Image.BOX)
	elif im.size != (ART_W, ART_H):
		raise SystemExit(f"{src.name}: expected {ART_W*2}x{ART_H*2} or {ART_W}x{ART_H}, "
						 f"got {im.size} - was the capture window really 1280x720?")
	out = snap_diffused(np.asarray(im).astype(int), load_palette())
	# opaque by construction: it is a backdrop, it covers the frame
	rgba = np.dstack([out, np.full(out.shape[:2], 255, np.uint8)])
	cols = len(np.unique(out.reshape(-1, 3), axis=0))
	if not write:
		return f"{dst.name}: {cols} colours (pass --write to apply)"
	return f"{dst.name}: {cols} colours [" + artguard.save_guarded(
		dst, lambda q: Image.fromarray(rgba, "RGBA").save(q), force) + "]"


def main() -> int:
	write = "--write" in sys.argv
	force = "--force" in sys.argv
	only = [a for a in sys.argv[1:] if not a.startswith("--")]
	OUT.mkdir(parents=True, exist_ok=True)
	done = 0
	for i, name in enumerate(NAMES):
		if only and name not in only:
			continue
		src = REF / f"ext_{i}.png"
		if not src.exists():
			print(f"  {name}: no capture at {src} - run scripts/gen_ext_refs.sh")
			continue
		print("  " + build(src, OUT / f"ext_{name}.png", write, force))
		done += 1
	if not done:
		print(__doc__)
		return 2
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
