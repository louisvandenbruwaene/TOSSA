#!/usr/bin/env python3
"""Install the five day-hub vignette illustrations from artifacts/paint/.

WHAT THESE REPLACE. `draw_day_anim` draws five little pictures - a hot meal, the inn, Uncle
Dan's Pie, a raw egg, a thrown tomato - and every one of them was built from
`fill_ellipse` / `draw_colored_polygon` / `draw_capsule`, i.e. smooth vector shapes, in a
game whose whole art direction is a locked 48-colour pixel palette. Measured on captures
taken through the new `--vign` flag: the meal was a flat amber ellipse (it read as a
pancake), the inn a brown rectangle with four panes, and the pie an orange TRIANGLE on a
white ellipse, which reads as a traffic cone. They survived this long because nothing could
photograph them - a vignette plays for 0.8-1.8s in the middle of a hub action and then the
ledger moves on, so `screenshot.sh` had no target for any of the five and no one had looked
at them since the density changed.

WHY PIXELLAB IS THE RIGHT TOOL HERE, given CLAUDE.md's "derive, do not generate, anything
small". The floor is 1024 pixels of AREA and these are 96x96 to 144x96 - between 9x and 13x
over it. They are also the case the rule explicitly leaves to the generator: large UI with
no character in it. The stage props stay derived.

THE FORCED PALETTE MEANS THERE IS NO REDUCER IN HERE. `create_image_pixflux` takes
`color_image_base64`, so `Resources/palette/palette.png` goes in with the prompt and all five
came back with ZERO off-palette pixels and hard 0/255 alpha. That is checked below rather
than assumed, exactly as install_cards.py checks it - a silent drift would put colours in the
UI that exist nowhere else in the game. (`create_image_pixen` cannot do this, which is why
these are pixflux jobs even though the canvases would fit either.)

TWO THINGS THE GENERATOR ADDS THAT A DARK PANEL CANNOT TAKE:

  1. A CAST SHADOW ON AN IMPLICIT GROUND PLANE. Every one of these is lit as if it sits on a
     pale table; the vignette panel is near-black. Measured on the meal, the shadow is 744
     pixels of `#b2a699` - a MID grey, brighter than the panel it would sit on, so it reads
     as a grey smear under the bowl rather than as shade. It cannot be stripped by colour:
     the spoon is the same entry (133 px of it). It CAN be stripped by shape - a cast shadow
     is one wide flat connected component sitting on the ink's bottom edge, and the spoon is
     neither wide nor flat nor at the bottom. See `strip_ground_shadow`, which is deliberately
     conservative (it removes at most one component per image) and prints what it took, so a
     regeneration that shifts the shadow cannot silently eat an object instead.
     Only the meal has one that matters. The pie's bottom rows are its own plate, the egg's
     are its yolk, and the bed's shadow is already a near-black navy that the panel absorbs -
     so `SHADOW` is a per-asset opt-in, not a sweep. This is the same discipline
     clean_ground.py records: a repair you reach for after looking, never a sweep.

  2. AN OFF-CENTRE SUBJECT IN A PADDED CANVAS. The meal's ink runs x 11..113 of 128, so
     centring the CANVAS puts the bowl two pixels right of where the caption is centred.
     Every sprite is therefore cropped to its own ink and the game centres the crop, which
     also stops `art_blit` spending screen size on empty margin: at ART_PIXEL 2 a full 128x96
     canvas is 256x192 screen px inside a 340x210 panel, and the cropped 103x79 is 206x158,
     which leaves the caption its room.

USAGE
  .venv/bin/python scripts/install_vignettes.py           preview
  .venv/bin/python scripts/install_vignettes.py --write
"""

from __future__ import annotations

import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

import artguard
from pixelise_menu import load_palette

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "artifacts" / "paint"
OUT = ROOT / "Assets" / "UI" / "vignette"

# name -> {src: stem in artifacts/paint, shadow: strip a cast shadow?,
#          out: destination folder, half: reduce 2:1, plaque: darken the centre disc}
SPECS: dict[str, dict] = {
	"eat": {"src": "vig_eat", "shadow": True},
	"inn": {"src": "vig_inn2"},
	"pie": {"src": "vig_pie"},
	"egg": {"src": "vig_egg"},
	"tomato": {"src": "vig_tomato"},
	"tomato_bit": {"src": "vig_tomato_bit"},
	# THE RESULTS CARD'S GRADE BADGE. Not a vignette, but the same pipeline exactly -
	# generated large UI with no character in it, pixflux with the palette forced.
	# `half` because the badge slot is 84 screen px and a 96x128 source blitted at
	# ART_PIXEL 2 would be 192x256; reduced 2:1 first it lands at 96x128 on screen,
	# which is the slot plus its ribbon tails.
	# `plaque` because the model draws the rosette's centre as a PALE cream disc, and
	# the grade letter that goes on it is a bright colour (gold / green / sky blue) -
	# bright on pale is the one combination that cannot be read. The centre is a plaque
	# to write on, not a face, so it is darkened to the card's own ground.
	"rosette": {"src": "vig_rosette", "out": "", "half": True, "plaque": True},
	# THE GOAL STEM'S TWO FLOWER HEADS (2026-08-19, Louis: "smaller topflower and longer
	# green, more natural looking from pixellab"). Procedural petal ellipses read as a
	# geometric rosette however well they are rasterised; these are paintings.
	# `stalk` trims the stub of stem the model insists on drawing under a flower head - the
	# game grows its own stalk to meet them, and two stalks meeting at an angle is worse
	# than none.
	# ONLY THE HEADS ARE GENERATED. The BUD stayed procedural after three rolls came back
	# muddy: the locked 48 has five greens and all of them are light-to-mid, with no dark
	# green at all, so the model reaches for BROWN to shade with and a fresh green bud comes
	# out a dead one. That is the palette's warm bias biting exactly where CLAUDE.md says it
	# will, and at 24x28 art px the bud is also under the "derive, do not generate, anything
	# small" line. Two overlapping ellipses already read as a clean green bud; they stay.
	"bloom": {"src": "stem_bloom2", "out": "flower", "half": True, "stalk": True},
	"flower": {"src": "stem_small2", "out": "flower", "half": True, "stalk": True},
}

# A cast shadow is WIDE and FLAT. The meal's is w/h 3.38; the spoon that shares its colour
# is 1.36 and the specks are 1.0-2.0. 2.5 sits in the gap with room on both sides.
SHADOW_ASPECT = 2.5
# ...and it sits ON the ink's bottom edge. The spoon's component ends at y 34 of an ink that
# runs to 87; requiring the component to reach the last eighth of the ink excludes it on a
# second, independent property, so neither test is carrying the decision alone.
SHADOW_FOOT = 0.875
# Specks left behind once the main component goes - the fringe of the same shadow, 1-2 px
# each. Swept by SIZE inside the shadow's own rows, the rule strip_torch_flame already
# learned: a fringe is single pixels, a real object is a block.
SPECK_MAX = 20
# The rosette's darkened centre. It MUST be a locked-palette entry - a hand-picked "dark
# warm brown" is how 315 off-palette pixels get into the UI through the one step that
# exists to keep them out. `#170f12` is the nearest entry to the results card's own ground
# Color(0.12, 0.07, 0.08), a shade under it, so the plaque reads as inset rather than
# painted on.
PLAQUE = (0x17, 0x0f, 0x12)
# A flower head's own petals span most of the canvas; the stem stub under it is a few
# pixels wide. A quarter of the widest row separates them with room to spare, and the scan
# runs bottom-up so it stops at the first real row rather than eating into the petals.
STALK_FRAC = 0.25


def components(mask: np.ndarray) -> list[np.ndarray]:
	"""4-connected components of a boolean mask, as index arrays."""
	lab = np.zeros(mask.shape, np.int32)
	out: list[np.ndarray] = []
	for sy in range(mask.shape[0]):
		for sx in range(mask.shape[1]):
			if not mask[sy, sx] or lab[sy, sx]:
				continue
			n = len(out) + 1
			lab[sy, sx] = n
			q = deque([(sy, sx)])
			while q:
				cy, cx = q.popleft()
				for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
					ny, nx = cy + dy, cx + dx
					if 0 <= ny < mask.shape[0] and 0 <= nx < mask.shape[1] \
							and mask[ny, nx] and not lab[ny, nx]:
						lab[ny, nx] = n
						q.append((ny, nx))
			out.append(lab == n)
	return out


def strip_ground_shadow(rgba: np.ndarray) -> tuple[np.ndarray, str]:
	"""Clear the one wide, flat, bottom-sitting neutral-grey component, plus its specks."""
	a = rgba.copy()
	op = a[..., 3] > 0
	if not op.any():
		return a, "no ink"
	ys = np.where(op.any(1))[0]
	foot = ys.min() + (ys.max() - ys.min()) * SHADOW_FOOT
	# the palette's neutral greys - the only entries a cast shadow can land on
	pal = load_palette()
	neutral = [c for c in pal if abs(int(c[0]) - int(c[2])) <= 40 and 60 <= int(c.mean()) <= 200]
	best: np.ndarray | None = None
	best_n = 0
	for col in neutral:
		m = op & np.all(a[..., :3] == col, axis=-1)
		if not m.any():
			continue
		for comp in components(m):
			cys, cxs = np.where(comp)
			w = cxs.max() - cxs.min() + 1
			h = cys.max() - cys.min() + 1
			if w / h < SHADOW_ASPECT or cys.max() < foot or comp.sum() <= best_n:
				continue
			best, best_n = comp, int(comp.sum())
	if best is None:
		return a, "no cast shadow found"
	a[best, 3] = 0
	# and the fringe of the same shadow, in the rows the shadow itself occupied
	bys = np.where(best.any(1))[0]
	took = best_n
	op = a[..., 3] > 0
	for col in neutral:
		m = op & np.all(a[..., :3] == col, axis=-1)
		m[: bys.min(), :] = False
		if not m.any():
			continue
		for comp in components(m):
			if comp.sum() <= SPECK_MAX:
				a[comp, 3] = 0
				took += int(comp.sum())
	return a, f"stripped {took}px of cast shadow"


def crop_to_ink(rgba: np.ndarray) -> np.ndarray:
	op = rgba[..., 3] > 0
	ys, xs = np.where(op)
	return rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def off_palette(rgba: np.ndarray) -> int:
	pal = {tuple(c) for c in load_palette()}
	op = rgba[..., 3] > 0
	return sum(1 for c in map(tuple, rgba[..., :3][op]) if c not in pal)


def snap_palette(rgba: np.ndarray) -> np.ndarray:
	"""Nearest locked-palette colour per opaque pixel, in Oklab, no dither.

	A REDUCTION UNDOES THE FORCED PALETTE, and that is the whole reason this exists. The
	generator returns art already exactly on the 48 (checked by off_palette), so the
	vignettes need no reducer at all - but a 2:1 box reduction AVERAGES four pixels, and the
	mean of two palette entries is not a palette entry. Measured on the rosette: 615
	off-palette pixels out of ~1900 straight after the resize.
	No dithering, unlike pixelise_menu: Bayer over a 34x56 sprite is not invisible texture at
	this size, it is speckle on an object the player looks straight at. Dither is for a
	backdrop's slow wash.
	"""
	pal = load_palette()
	op = rgba[..., 3] > 0
	if not op.any():
		return rgba
	from pixelise_menu import srgb_to_oklab
	px = rgba[..., :3][op].astype(float)
	d = np.linalg.norm(srgb_to_oklab(px)[:, None, :] - srgb_to_oklab(pal)[None, :, :], axis=2)
	out = rgba.copy()
	out[..., :3][op] = pal[np.argmin(d, axis=1)]
	return out


def trim_stalk(rgba: np.ndarray) -> tuple[np.ndarray, str]:
	"""Drop the stub of stem under a flower head, by row width from the bottom up."""
	a = rgba.copy()
	op = a[..., 3] > 0
	if not op.any():
		return a, "no ink"
	widths = op.sum(1)
	peak = int(widths.max())
	ys = np.where(widths > 0)[0]
	cut = ys.max() + 1
	for y in range(ys.max(), ys.min(), -1):
		if widths[y] > peak * STALK_FRAC:
			break
		cut = y
	if cut > ys.max():
		return a, "no stalk stub"
	a[cut:, :, 3] = 0
	return a, f"trimmed {ys.max() + 1 - cut} stalk rows"


def darken_plaque(rgba: np.ndarray) -> tuple[np.ndarray, str]:
	"""Sink the pale centre disc to the card's ground so a bright letter can sit on it."""
	a = rgba.copy()
	h, w = a.shape[:2]
	lum = a[..., :3].astype(int).mean(-1)
	pale = (a[..., 3] > 0) & (lum > 150)
	# the centre disc is the pale component containing the sprite's own middle
	best = None
	for comp in components(pale):
		if comp[h // 3:h // 2, w // 2 - 2:w // 2 + 2].any():
			if best is None or comp.sum() > best.sum():
				best = comp
	if best is None:
		return a, "no plaque found"
	a[best, 0], a[best, 1], a[best, 2] = PLAQUE
	return a, f"darkened {int(best.sum())}px of plaque"


def build(name: str, write: bool, force: bool) -> str:
	spec = SPECS[name]
	stem = spec["src"]
	src = SRC / f"{stem}.png"
	if not src.exists():
		return f"{name}: no art at artifacts/paint/{stem}.png"
	im = Image.open(src).convert("RGBA")
	a = np.asarray(im).copy()
	bad = off_palette(a)          # measured on the SOURCE, which is what the generator sent
	note = ""
	if spec.get("half"):
		im = im.resize((im.width // 2, im.height // 2), Image.BOX)
		a = np.asarray(im).copy()
		# hard alpha FIRST - the box filter averaged it, and every soft rim pixel would
		# otherwise be snapped as if it were a real colour
		a[..., 3] = np.where(a[..., 3] >= 128, 255, 0).astype(np.uint8)
		a = snap_palette(a)
		note += "  re-snapped after 2:1"
	if spec.get("shadow"):
		a, n = strip_ground_shadow(a)
		note += "  " + n
	if spec.get("plaque"):
		a, n = darken_plaque(a)
		note += "  " + n
	if spec.get("stalk"):
		a, n = trim_stalk(a)
		note += "  " + n
	soft = int(((a[..., 3] > 0) & (a[..., 3] < 255)).sum())
	left = off_palette(a)
	a = crop_to_ink(a)
	note += f", {left} off-palette out"
	dest = OUT if spec.get("out") is None else (OUT.parent / spec["out"] if spec.get("out") else OUT.parent)
	tag = f"{name}: {a.shape[1]}x{a.shape[0]}  {bad} off-palette, {soft} soft-alpha{note}"
	if not write:
		return tag + "  (pass --write to apply)"
	dest.mkdir(parents=True, exist_ok=True)
	return tag + "  [" + artguard.save_guarded(
		dest / f"{name}.png", lambda q: Image.fromarray(a, "RGBA").save(q), force) + "]"


def main() -> int:
	write = "--write" in sys.argv
	force = "--force" in sys.argv
	only = [x for x in sys.argv[1:] if not x.startswith("--")]
	OUT.mkdir(parents=True, exist_ok=True)
	for name in SPECS:
		if only and name not in only:
			continue
		print("  " + build(name, write, force))
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
