#!/usr/bin/env python3
"""Reduce the two gilt menu ornaments to art-density sprites (ui/rule_flourish, ui/corner_*).

WHAT THEY REPLACE. `draw_ornament` and `draw_frame` are the two decorations every menu screen
in this game wears - the flourish under a screen title (twenty call sites) and the double gold
border around the frame (eight). Both were hand-written vector strokes, and both broke the same
rule the rest of the art has followed since the density lock: `draw_rect(..., false, 2.0)` and
`draw_line(..., 1.0)` are half-art-pixel strokes, so the inner rule and the corner ticks landed
on fractions of a block. They are the thinnest things on screen, which is exactly what makes a
half-pixel stroke show - a crisp bitmap title sitting inside a soft vector frame, on every
menu.

TWO GENERATIONS, NEITHER OF THEM REDUCED. Both were authored at 1:1 ART density and are snapped
to the palette without any box filter, and that is the whole reason they read:

  rule_flourish   256x24 pixflux (forced palette), CROPPED to the ornamented centre only.
                  Reducing the crop 2:1 was tried first and it is what a reduction always does
                  to filigree - measured, 32x12 with the scrollwork averaged into gold speckle
                  around a lozenge. Scrollwork is small-detail-on-a-thin-field, the same case
                  `clean_ground.py`'s own docstring warns is the picture rather than the noise.
  corner_scroll   40x40 pixflux (forced palette), a single acanthus volute whose two tails run
                  RIGHT and DOWN, so it is a top-left corner and the other three are flips.

THE CROP IS CENTRED ON THE RULE, NOT ON THE INK. `draw_ornament` draws plain gold rules out to
whatever half-width its caller asks for, and those rules have to meet the sprite's own tails
without a step. Measured on the generation, the plain rule occupies source rows 11-12 with a
one-pixel highlight at 9 and shadow at 14, so the crop runs rows 4..20 and lands the rule core
on the sprite's own centre line. Game.gd then draws its flanks as a 2-art-pixel rect on that
centre, which is the sprite's thickness exactly.

FOUR CORNER FILES, NOT ONE FLIPPED FOUR WAYS. `art_blit` has no flip argument and giving it one
would mean a negative half-extent in `_art_quad`, i.e. a winding change in the one function every
sprite in the game goes through. Four 40x40 PNGs cost 6KB and keep the seam's contract - the
manifest names a file, the game names a key, and nothing in between has an opinion.

USAGE
  .venv/bin/python scripts/install_ornaments.py            preview
  .venv/bin/python scripts/install_ornaments.py --write
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

import artguard
from install_prop_cards import snap_warm, warm_palette

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "artifacts" / "ornament"
OUT = ROOT / "Assets" / "UI" / "ornament"

# Below this the pixel is not the object - the same hard cut every generated cut-out in this
# project takes, for the same reason: a low-alpha fringe is what makes generated pixel art
# look fake, and on a two-pixel-thick gold rule the fringe is the whole rule.
ALPHA_CUT = 110

# GREYSCALE, BECAUSE THE CALLER OWNS THE COLOUR - and here that is not a style choice, it is
# what the twenty call sites already do. `draw_ornament` is passed a colour AND an alpha by
# every screen that uses it, and three of them are not gold: the demo wall card fades its rule
# in on `fin`, the unlock banner passes a lavender, the Purist legend a dimmer amber. Shipping
# the generation's own gold and multiplying the caller's colour into it gives a lavender
# ornament that is still brown, and a half-alpha one that is mud - measured on the first cut,
# the corner scroll came out visibly darker and muddier than the plain rule drawn beside it at
# the identical colour, because the rule is one flat gold and the scroll's own paint was
# already dark before the tint halved it. So these store a luminance RATIO normalised to their
# own brightest pixel, exactly like the gear rack and the hands: a multiply can only darken,
# so the art has to say "how much of the tint is here" and its highlight must reach white.
BANDS = 6
GREY_FLOOR = 0.30

# The ornamented span of the 256x24 rule, and the rows that centre its plain line. Measured,
# not guessed: see the docstring. Columns 88..152 hold the lozenge and both scrolls with a
# couple of plain-rule pixels either side to join onto.
RULE_BOX = (88, 4, 152, 20)

FLIPS = {
	"corner_tl": None,
	"corner_tr": Image.FLIP_LEFT_RIGHT,
	"corner_bl": Image.FLIP_TOP_BOTTOM,
	"corner_br": Image.ROTATE_180,
}


def ratio(im: Image.Image) -> Image.Image:
	"""Luminance ratio at the source's own resolution. No filtering of any kind."""
	a = np.asarray(im.convert("RGBA")).astype(float)
	rgb, alpha = a[..., :3], a[..., 3]
	keep = alpha >= ALPHA_CUT
	if not keep.any():
		raise SystemExit("nothing survived the alpha cut")
	lum = 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]
	r = np.clip(lum / max(float(lum[keep].max()), 1e-6), 0.0, 1.0)
	r = np.rint(r * (BANDS - 1)) / float(BANDS - 1)
	r = GREY_FLOOR + (1.0 - GREY_FLOOR) * r
	g = np.where(keep, np.rint(r * 255.0), 0).astype(np.uint8)
	return Image.fromarray(np.dstack([g, g, g, np.where(keep, 255, 0).astype(np.uint8)]), "RGBA")


def painted(im: Image.Image) -> Image.Image:
	"""Palette snap in place, keeping the generation's own colour. No filtering of any kind."""
	a = np.asarray(im.convert("RGBA")).astype(float)
	rgb, alpha = a[..., :3], a[..., 3]
	keep = alpha >= ALPHA_CUT
	# WARM, like every other small object in this project: the locked 48's darkest entries are
	# a cool indigo and a gold object's own dark edge is exactly the pixel that lands on it.
	out = snap_warm(np.clip(rgb, 0.0, 255.0), warm_palette())
	rgba = np.dstack([out, np.where(keep, 255, 0)]).astype(np.uint8)
	rgba[..., :3][~keep] = 0
	return Image.fromarray(rgba, "RGBA")


def build(write: bool, force: bool) -> list[str]:
	lines: list[str] = []
	rule_src = SRC / "rule.png"
	corner_src = SRC / "corner_scroll.png"
	if not rule_src.exists() or not corner_src.exists():
		return [f"missing sources under {SRC.relative_to(ROOT)}/ (rule.png, corner_scroll.png)"]

	OUT.mkdir(parents=True, exist_ok=True)

	flourish = ratio(Image.open(rule_src).crop(RULE_BOX))
	lines.append(f"rule_flourish: {flourish.size[0]}x{flourish.size[1]} art px, "
				 f"{len(flourish.getcolors(9999) or [])} grey levels"
				 + (f" [{artguard.save_guarded(OUT / 'rule_flourish.png', lambda q: flourish.save(q), force)}]"
					if write else "  (pass --write to apply)"))

	corner = ratio(Image.open(corner_src))
	for name, flip in FLIPS.items():
		im = corner if flip is None else corner.transpose(flip)
		tag = f"{name}: {im.size[0]}x{im.size[1]} art px"
		if write:
			tag += f" [{artguard.save_guarded(OUT / f'{name}.png', lambda q, i=im: i.save(q), force)}]"
		lines.append(tag)

	# THE CROWN KEEPS ITS OWN PAINT, and the reason is the same test the ornaments failed the
	# other way: what does the caller need the tint for? A save-slot crown is drawn at ONE
	# colour in ONE state - it says "this career is finished" and nothing else - so there is no
	# state for a tint to carry, and its red jewels are the whole difference between a crown
	# and a gold sawtooth. Ratio it and they go grey.
	crown_src = SRC / "crown.png"
	if crown_src.exists():
		crown = painted(Image.open(crown_src))
		tag = f"crown: {crown.size[0]}x{crown.size[1]} art px, {len(crown.getcolors(9999) or [])} colours"
		if write:
			tag += f" [{artguard.save_guarded(OUT / 'crown.png', lambda q: crown.save(q), force)}]"
		lines.append(tag)
	return lines


def main() -> int:
	write = "--write" in sys.argv
	force = "--force" in sys.argv
	for line in build(write, force):
		print("  " + line)
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
