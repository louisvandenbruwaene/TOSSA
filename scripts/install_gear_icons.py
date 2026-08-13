#!/usr/bin/env python3
"""Reduce the eight wardrobe gear icons to tintable 20x20 sprites (ui/gear_*).

WHY THE RACK NEEDED THIS. draw_gear_icon draws each piece as a vector object, and four of
the eight never read: measured on a tailor capture, the Tailcoat, the Sequin Waistcoat, the
Silk Gloves and the Stage Boots are grey blobs you cannot name, sitting in a list whose
whole job is to say what each row IS. The Top Hat, Helmet, Glasses and Glow Suit read fine,
which is the other half of the problem - half a rack of objects and half a rack of smudges
is the same uniformity break the card deck had.

GREYSCALE IS NOT A COMPROMISE HERE, IT IS THE ARCHITECTURE. draw_gear_icon's sprite path
blits through a TINT, and the tint is carrying real information at both call sites: the gear
room passes the piece's own `e["col"]`, so a white icon comes out in that item's identity
colour (the Helmet still orange, the Glow Suit still green), and the tailor passes a row
state - cream when selected, dimmer when merely owned, dimmest when not. Painting colour
INTO the sprite would fight both. So these store a luminance RATIO, the same rule the hands
and the body regions already follow: a tint can only darken, so the art must say "how much
of the tint is here", and its brightest pixel must be white or every icon comes out muddy.

40x40 GENERATED, 20x20 SHIPPED, which is an exact 2:1 box reduction and no resampling. 20x20
is under PixelLab's 1024-pixel area floor, so it cannot be asked for directly - the same
generate-big-and-derive route the props already take.

THE TAILOR'S SCALE HAD TO MOVE FROM 0.42 TO 0.5 for these to be sharp, and that is safe
precisely BECAUSE they are sprites. The 0.42 was set by the widest vector icon (the helmet
reaches +-40 units and ran into the label at 0.62); every sprite is a uniform 40x40 units, so
at 0.5 the icon reaches 10 screen px into an 18 px gutter. 0.5 is also the only scale between
"same size" and "gone" that is a whole number of screen pixels per art pixel - exactly half,
therefore lossless, the same reason fig_scale_H allows halves and nothing else.

USAGE
  .venv/bin/python scripts/install_gear_icons.py            preview
  .venv/bin/python scripts/install_gear_icons.py --write
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

import artguard

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "artifacts" / "gear"
OUT = ROOT / "Assets" / "UI" / "gear"

SRC_PX, OUT_PX = 40, 20

# the eight rack pieces, keyed by the `gear` id draw_gear_icon dispatches on
NAMES = ["hat", "helmet", "coat", "vest", "gloves", "boots", "glasses", "glow_suit"]

# Below this the pixel is not the object. A generated cut-out leaves a fringe of very low
# alpha around its edge, and at 20x20 a fringe is a fifth of the object - hard-cut it, the
# same way pixelise_prop does, rather than letting it smear the silhouette.
ALPHA_CUT = 110

# The darkest a lit pixel may go, as a fraction of the icon's own brightest. A tint can only
# darken, so anything near zero here is a hole: the rack's dimmest row state is already 0.62,
# and 0.62 * 0.15 is black. The body regions hit the same wall and settled on 0.64 for the
# same reason - below about 0.6 a coloured cloth goes to black at its edges and reads as a
# gap in the shape rather than a shadow on it.
GREY_FLOOR = 0.26


def build(name: str, write: bool, force: bool) -> str:
	src = SRC / f"{name}.png"
	if not src.exists():
		return f"{name}: no art at artifacts/gear/{name}.png"
	im = Image.open(src).convert("RGBA")
	if im.size != (SRC_PX, SRC_PX):
		raise SystemExit(f"{name}: expected {SRC_PX}x{SRC_PX}, got {im.size}")
	a = np.asarray(im).astype(float)
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
	# A RATIO, NOT AN ABSOLUTE: normalise to the icon's OWN brightest lit pixel so every
	# icon's highlight is pure white and the tint decides the actual colour. Without this an
	# icon that happened to be generated dark would simply be a dark icon for ever.
	top = float(lum[keep].max())
	ratio = np.clip(lum / max(top, 1e-6), 0.0, 1.0)
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
