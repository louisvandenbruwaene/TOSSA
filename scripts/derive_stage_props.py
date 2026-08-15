#!/usr/bin/env python3
"""Make the STAGE props the same objects as the SHOP CARDS.

THE PROBLEM (2026-08-06, Louis: "the shop designs for the objects are decent, use those
everywhere! right now the titlescreen and performance uses different ones"). Every prop in
this game existed as two unrelated pieces of art:

  prop_big/*  the shop card, PAINTED by PixelLab on the locked palette - crimson club with
              gold bands, black iron torch, orange chainsaw
  prop/*      the stage sprite, DERIVED from the game's own vector drawing - red club with
              white bands and a bone handle, brown wooden torch, yellow chainsaw

Plus a third: the title wordmark baked its props straight from cap_club/cap_knife/cap_torch,
the vector drawings, bypassing the prop seam entirely. So the player met a club in the shop,
a different club on the title screen and a third one in the air.

The cards were always the better painting - they are what the other two now derive from.

WHAT THIS DOES NOT DECIDE. The LENGTH. A prop's on-screen length is set by prop_scale and
the game's collision geometry, so every sprite here keeps the exact pixel height it already
had; only the width follows the card's own aspect.

AND THE WIDTH BARELY MOVES, which is worth recording because I predicted the opposite. From
the CANVAS sizes the card club is 48x96 against a 6x32 stage club - aspect 0.50 against
0.19 - so this looked like it would make every prop nearly three times fatter, and that is
what Louis was asked to approve. Measuring the card's own INK rather than its canvas says
otherwise: the club is 20x88 of drawing inside that canvas, aspect 0.23. The real changes
are club 6->7, knife 7->7, torch 8->8 and chainsaw 21->17 art px wide. The card art was
never fat; it was padded. Always measure the ink.

THE ROUND PROPS ARE NOT HERE. ball, egg and ring get their consistency a better way, from
scripts/make_round_props.py --stage: they are analytic surfaces, so both sizes are computed
from ONE model at their own final resolution rather than one being a blurred copy of the
other. Downscaling a 52px sphere into 11px would throw away the exact thing that makes it
read - band boundaries landing on whole pixels.

THE REDUCTION, and why each step is there:
  1. PREMULTIPLY before filtering. Averaging straight RGBA pulls the transparent
     background's colour into every edge pixel, which is what makes a naive downscale
     look like it has a dark halo.
  2. AREA filter, then a HARD alpha threshold. A soft alpha fringe is the single thing
     that makes generated pixel art look fake; the silhouette must be binary.
  3. SNAP to the locked 48-colour palette in Oklab, so a reduction cannot introduce a
     colour the rest of the game does not own.

USAGE
  .venv/bin/python scripts/derive_stage_props.py            # report
  .venv/bin/python scripts/derive_stage_props.py --write [--force]
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

import artguard

ROOT = Path(__file__).resolve().parent.parent
PROPS = ROOT / "Assets" / "Props"
PALETTE = ROOT / "Resources" / "palette" / "palette.json"

# The four PAINTED props, and how far the card must be turned to lie the way the stage
# sprite does. Degrees COUNTER-CLOCKWISE, as PIL means them: the chainsaw is painted with
# its body at the left and its bar to the right, and is thrown with the body at the BOTTOM,
# so it turns +90. Getting the sign wrong is not subtle - it hangs the motor off the top
# and points the bar at the floor - but it is easy to write, so: check the picture.
TARGETS = {"club": 0, "knife": 0, "torch": 0, "chainsaw": 90}

# THE STAGE SPRITE IS AUTHORED AT DOUBLE DENSITY (2026-08-15, Louis: "i don't think that the
# good looking big versions of the props were scaled down for the juggling, they still look
# very bad and pixellated").
#
# He was right, and the reason is not the reducer - it is the pixel BUDGET the reducer was
# given. A club shipped as 7x32 authored pixels, drawn at ART_PIXEL 2, so it filled 14x64
# screen pixels. Seven pixels across has to carry a crimson body, two gold bands and a bone
# handle, and it cannot: measured, the whole sprite was 224 pixels against the card's 1760.
# No filter, no dithering and no hand-striking recovers detail that has nowhere to sit.
#
# So the sprite doubles and the manifest halves its `scale` to 0.5, which is exactly the same
# number of SCREEN pixels - one source pixel now lands on one screen pixel instead of a 2x2
# block. The prop is not bigger, it is not scaled fractionally (0.5 x ART_PIXEL 2 = 1, a whole
# number, which is the rule that matters), and it carries four times the information: 896
# pixels for the club, and the bands, the handle knob and the chainsaw's teeth all survive.
#
# WHY THESE ARE WRITTEN DOWN RATHER THAN MEASURED OFF THE FILE. The old code read the height
# of the sprite already on disk, which is fine exactly once and doubles the prop every run
# after that. A target table is idempotent and says what the intended size IS.
STAGE_H = {"club": 64, "knife": 62, "torch": 78, "chainsaw": 96}

ALPHA_CUT = 0.42     # coverage a reduced pixel needs to survive as opaque


def srgb_to_oklab(rgb: np.ndarray) -> np.ndarray:
	c = rgb / 255.0
	c = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
	m = np.array([[0.4122214708, 0.5363325363, 0.0514459929],
	              [0.2119034982, 0.6806995451, 0.1073969566],
	              [0.0883024619, 0.2817188376, 0.6299787005]])
	lms = np.cbrt(c @ m.T)
	m2 = np.array([[0.2104542553, 0.7936177850, -0.0040720468],
	               [1.9779984951, -2.4285922050, 0.4505937099],
	               [0.0259040371, 0.7827717662, -0.8086757660]])
	return lms @ m2.T


def load_palette() -> np.ndarray:
	# same shape pixelise_prop.py reads: {"count": 48, "hex": ["#rrggbb", ...]}
	#
	# ...MINUS THE COOL THIRTEEN, and it has to be here as well as in install_prop_cards.py
	# even though the card this reduces is already warm-only. The reduction AVERAGES, so it
	# invents colours the card does not contain: a warm near-black rim area-filtered against
	# a lit body lands on some intermediate value, and if the full 48 is on offer the nearest
	# entry to that value can be the indigo again. Fixing the card alone would have let the
	# purple straight back in at exactly the size it does the most damage - the stage sprite
	# is a fifth the card's width, so its rim is a third of the whole prop. See that script's
	# header for why the cool sixth of the palette is not a colour a prop can legitimately
	# need, and for the measurements.
	data = json.loads(PALETTE.read_text())
	pal = np.array([[int(h[i:i + 2], 16) for i in (1, 3, 5)] for h in data["hex"]], dtype=float)
	cool = (pal[:, 2] > pal[:, 0] + 6) | (pal[:, 1] > pal[:, 0] + 6)
	return pal[~cool]


def snap(rgb: np.ndarray, pal: np.ndarray) -> np.ndarray:
	flat = rgb.reshape(-1, 3)
	d = ((srgb_to_oklab(flat)[:, None, :] - srgb_to_oklab(pal)[None, :, :]) ** 2).sum(axis=2)
	return pal[np.argmin(d, axis=1)].reshape(rgb.shape)


def reduce_to(card: Image.Image, w: int, h: int, pal: np.ndarray) -> np.ndarray:
	a = np.asarray(card.convert("RGBA")).astype(float)
	al = a[..., 3:4] / 255.0
	pm = np.dstack([a[..., :3] * al, a[..., 3]])            # (1) premultiply
	small = np.asarray(Image.fromarray(pm.astype(np.uint8), "RGBA")
	                   .resize((w, h), Image.BOX)).astype(float)   # (2) area filter
	cov = small[..., 3] / 255.0
	keep = cov >= ALPHA_CUT
	rgb = np.zeros((h, w, 3))
	np.divide(small[..., :3], np.maximum(cov, 1e-6)[..., None], out=rgb, where=keep[..., None])
	rgb = np.clip(rgb, 0, 255)
	rgb[keep] = snap(rgb[keep], pal)                        # (3) palette snap
	return np.dstack([rgb, np.where(keep, 255, 0)]).astype(np.uint8)


# How often a tooth is struck along the chainsaw's bar, in art pixels. 2 (every other row)
# beat 3 on a light field: at 3 the teeth are chunkier but too far apart to read as a saw,
# and 25 rows of bar only fit eight of them.
# ...and it is 4 now that the sprite is authored at double density, NOT 2. The period is in
# authored pixels, so leaving it at 2 would strike twice as many teeth into a bar of the same
# physical length - a fine grey comb rather than a saw. Doubling it keeps the tooth SPACING on
# screen exactly where it was tuned, and each tooth is now two pixels of bite instead of one.
TOOTH_PERIOD = 4


def serrate_chainsaw(a: np.ndarray) -> np.ndarray:
	"""Cut teeth back into the chainsaw's bar (2026-08-07, Louis: they were not visible).

	THE BOX FILTER EATS THEM, and that is not a bug in the filter - it is what averaging
	means. The card paints the bar's teeth as one-pixel notches on a 72px picture; reduced to
	a 17px stage sprite each notch is a fraction of a pixel of coverage, so it averages into
	the bar's own grey and what survives is a smooth grey stick. Nothing about the reduction
	can preserve a feature finer than its output pixel; the feature has to be re-struck at the
	output's own scale, which is what a pixel artist would do by hand.

	The teeth are struck OUTWARD, one art pixel past the silhouette on alternate rows, in the
	bar's own darkest colour (its outline). That makes the SILHOUETTE serrated rather than
	painting a pattern inside a smooth shape - a prop is read by its outline at this size,
	especially while it is tumbling, so the outline is where the information has to be.

	THE BAR IS FOUND BY WIDTH, not by colour or by a hard-coded row. The motor body is wide
	and the bar is narrow, so the run of rows from the tip down to the first wide row is the
	bar - which stays true if the card art is ever repainted, where a row number would not."""
	out = a.copy()
	h, w = out.shape[:2]
	widths = [int(np.count_nonzero(out[y, :, 3] > 0)) for y in range(h)]
	if not any(widths):
		return out
	limit = max(widths) * 0.6
	rows: list[int] = []
	for y in range(h):
		if widths[y] == 0:
			continue
		if widths[y] > limit:
			break        # the motor body starts here; everything above it was the bar
		rows.append(y)
	if len(rows) < 4:
		return out
	sel = out[rows][..., 3] > 0
	cols = np.unique(out[rows][..., :3][sel], axis=0)
	lum = cols @ np.array([0.299, 0.587, 0.114])
	tooth = cols[int(np.argmin(lum))]
	for y in rows:
		if y % TOOTH_PERIOD:
			continue
		xs = np.where(out[y, :, 3] > 0)[0]
		if xs.size == 0:
			continue
		for x in (int(xs.min()) - 1, int(xs.max()) + 1):
			if 0 <= x < w:
				out[y, x] = [tooth[0], tooth[1], tooth[2], 255]
	return out


def strip_torch_flame(a: np.ndarray) -> tuple[np.ndarray, dict]:
	"""Take the FIRE off the torch sprite, and measure the hole it leaves.

	THE FLAME IS LIGHT, AND THIS PROJECT NEVER BAKES LIGHT (2026-08-07, Louis: "i'd like the
	fire of the torches to actually move"). It already moved - draw_torch_flame has run on a
	two-rate flicker and a lean since 2026-07-27 - and then the prop seam quietly killed it:
	registering prop/torch made the sprite the whole object, so art_blit_prop returned true and
	the drawing that owned the animation never ran at all. The torch became a photograph of a
	fire. That is the same mistake a baked spotlight cone would be, and the fix is the split
	every other bake here already makes: the OBJECT is a sprite, the LIGHT is drawn live.

	THE CANVAS SIZE IS DELIBERATELY UNCHANGED. Every prop sprite's pivot is a FRACTION of its
	own texture (measured, not chosen - see the manifest's own note), so cropping the flame
	away would silently invalidate the torch's pivot and set it orbiting a point instead of
	spinning about one. The flame pixels are cleared and the 8x39 canvas is kept.

	The measurements handed back are in ART PIXELS of that same canvas, so the game can place
	a live flame exactly where the painted one was - the card's proportions, not the vector
	drawing's, which is the whole point of deriving from the card in the first place.

	IT IS PIXEL-WISE, NOT ROW-WISE, AND THAT IS THE SECOND VERSION OF THIS (2026-08-15).
	The first walked down the image taking WHOLE ROWS while a row was majority-fire, and
	stopped at the first row that was not. That is correct for a torch whose flame sits
	entirely above its handle, which is what every torch design here had been until Louis
	asked for one where "the flame burns around" a small black wick cylinder.

	On that shape the row rule fails in the worst possible way - quietly, and by leaving
	fire behind. Measured on the card: rows 5..16 are the flame's tip and are 57-100%
	warm, so they strip; rows 17..33 are the CYLINDER with flame down either side of it,
	and a dark cylinder eight pixels wide beside six pixels of fire is only 25-43% warm,
	so the walk stops at row 17. base_row lands at the top of the cylinder, the flanking
	fire stays baked into the sprite, and the game then draws its live animated flame
	starting above all of it. A painted fire under a drawn one is exactly the thing this
	function exists to prevent.

	So fire is identified by COLOUR wherever it is, and the band is "every row from the
	top down to the last row that still contains fire". The test is tightened to match:
	`> 200` on red rather than `> 120`, because a pixel-wise rule has to separate flame
	from the BRASS BAND (155,99,23) and the crimson body (118,16,38) that a row-wise one
	never had to look at. The flame's own dimmest sampled pixel is (250,172,121); nothing
	else on any of the four torch cards comes near 200 red with 100 points of red-over-blue.

	base_row is then the row under the whole fire, so the live flame is drawn from the
	BOTTOM of the wick and burns up around the cylinder, which is the design Louis asked
	for and is also what a real torch does."""
	out = a.copy()
	h = out.shape[0]
	# ...and fire is TWO colours, not one. The orange test below misses the flame's white-hot
	# CORE, which is exactly what it sounds like - (255,240,204) and (255,255,255) - and those
	# have almost no red-over-blue at all, so 24 pixels of it survived the first pixel-wise
	# pass and were left as white specks stuck to the side of the wick. The near-white test is
	# safe here ONLY because the band is contiguous from the top: the bone-cream handle is the
	# same family of colour and is fifty rows below the fire, well outside it.
	op = out[..., 3] > 0
	orange = op & (out[..., 0] > 200) & (out[..., 0] > out[..., 2] + 100)
	core = op & (out[..., 0] > 230) & (out[..., 1] > 200) & (out[..., 2] > 150)
	hot = orange | core
	rows = [y for y in range(h) if bool(hot[y].any())]
	if not rows:
		return out, {}
	# contiguous from the top: a stray warm speck low on a handle is not part of the fire
	band_end = rows[0]
	for y in rows:
		if y <= band_end + 2:
			band_end = y
		else:
			break
	xs = np.where(hot[rows[0]:band_end + 1].any(axis=0))[0]
	height = int(band_end - rows[0] + 1)
	# THE MEASUREMENT IS A FOOTPRINT; THE DRAWING IS A PLUME, and conflating them makes a
	# kite. draw_sprite_torch_flame builds ONE tapering flame `height` tall and `half_width`
	# wide, but what gets measured here is how far the painted fire reaches SIDEWAYS - and on
	# a design whose flame burns around a wick rather than standing on top of one, that is the
	# width of the wrap, not the width of a plume. Measured on the club-shaped torch: 29 tall
	# by 10 half-wide, an aspect of 2.9 against the vector reference's TORCH_FLAME_H /
	# TORCH_FLAME_W = 5.0, and on the shop card it read as an orange diamond rather than fire.
	# Capping at height/4 keeps a plume that can wrap a wick without becoming one.
	half = min(float(xs.max() - xs.min() + 1) / 2.0, height / 4.0)
	meta = {
		# the row the fire sits ON - i.e. the first row below all of it
		"base_row": int(band_end + 1),
		"height": height,
		"half_width": round(half, 2),
	}
	out[rows[0]:band_end + 1][hot[rows[0]:band_end + 1]] = 0
	# ...AND THEN SWEEP THE ORPHANS. Clearing fire pixel-wise leaves whatever the generator
	# painted AROUND the fire - a dark edge, a soot fringe - floating in mid-air beside the
	# wick with nothing under it. Anything in the band that is not connected downward to the
	# rest of the object is not part of the object.
	keep = out[..., 3] > 0
	for y in range(band_end, rows[0] - 1, -1):
		below = keep[y + 1] if y + 1 < h else np.zeros(keep.shape[1], bool)
		near = below.copy()
		near[:-1] |= below[1:]
		near[1:] |= below[:-1]
		keep[y] &= near
	out[~keep] = 0
	return out, meta


def build(name: str, rot: int, pal: np.ndarray, write: bool, force: bool,
		suffix: str = "") -> str:
	# `suffix` DERIVES A DESIGN VARIANT THROUGH THE SAME REDUCTION (2026-08-15). A variant is
	# a second manifest overlaying the first with different PNGs for the same keys (see
	# VARIANT_DEFS in Game.gd), so `--suffix _ornate` turns big_knife_ornate.png into
	# knife_ornate.png. It has to run through THIS function rather than a copy of it: the
	# premultiply, the hard alpha cut, the warm palette snap, the chainsaw's serration and
	# above all STAGE_H are what make a prop the right object at the right length, and a
	# variant that skipped any of them would be a different prop rather than a different look.
	stage_p = PROPS / f"{name}{suffix}.png"
	stage = Image.open(stage_p).convert("RGBA") if stage_p.exists() else Image.new("RGBA", (1, 1))
	card = Image.open(PROPS / f"big_{name}{suffix}.png").convert("RGBA")
	if rot:
		card = card.rotate(rot, expand=True)
	# tight-crop the card to its own ink first, so its padding cannot shrink the object
	ca = np.asarray(card)
	ys, xs = np.where(ca[..., 3] > 127)
	card = card.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))

	h = STAGE_H[name]                                   # LENGTH IS FIXED - see the docstring
	w = max(2, int(round(card.size[0] * h / card.size[1])))
	out = reduce_to(card, w, h, pal)
	if name == "chainsaw":
		out = serrate_chainsaw(out)
	flame = {}
	if name == "torch":
		out, flame = strip_torch_flame(out)
	msg = f"{name + suffix:18} {stage.size[0]:2}x{stage.size[1]:<3} -> {w:2}x{h:<3}  (card {card.size[0]}x{card.size[1]})"
	if not write:
		return msg + "   (report only)"
	p = PROPS / f"{name}{suffix}.png"
	status = artguard.save_guarded(p, lambda q: Image.fromarray(out, "RGBA").save(q), force)
	if flame:
		# ...AND THE CARD'S FIRE IS LIVE TOO (2026-08-07, Louis: "the fire only moves when
		# juggling, not in the shop"). He is right, and the reason is the same seam in a
		# second place: the shop blits prop_big/torch and returns, so the drawing that owns
		# the animation never runs there either. A card is a still portrait of an OBJECT, but
		# fire is not an object.
		#
		# The PixelLab painting itself is never touched - it is the source both sizes derive
		# from. A flameless copy is written beside it and that is what the manifest points at.
		big = np.asarray(Image.open(PROPS / f"big_{name}.png").convert("RGBA")).astype(int)
		big_body, big_flame = strip_torch_flame(big)
		if write:
			artguard.save_guarded(PROPS / "big_torch_body.png",
				lambda q: Image.fromarray(big_body.astype(np.uint8), "RGBA").save(q), force)
		(PROPS / "torch_flame.json").write_text(
			json.dumps({"stage": flame, "card": big_flame}, indent=2) + "\n")
		msg += (f"  flame stage row {flame['base_row']}/{flame['height']}px, "
				f"card row {big_flame['base_row']}/{big_flame['height']}px (both drawn live)")
	return msg + f"  [{status}]"


def main() -> int:
	write = "--write" in sys.argv
	force = "--force" in sys.argv
	pal = load_palette()
	names = [a for a in sys.argv[1:] if not a.startswith("--")]
	names = [n for n in names if n in TARGETS] or list(TARGETS)
	suffix = ""
	if "--suffix" in sys.argv:
		suffix = sys.argv[sys.argv.index("--suffix") + 1]
		names = [n for n in names if (PROPS / f"big_{n}{suffix}.png").exists()]
	for n in names:
		print(build(n, TARGETS[n], pal, write, force, suffix))
	if not write:
		print("\n(pass --write to apply; the pivots in Resources/art_manifest.json keep their")
		print(" long-axis fraction and move to 0.5 across, since card art is drawn symmetric)")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
