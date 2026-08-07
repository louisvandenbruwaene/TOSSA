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
	data = json.loads(PALETTE.read_text())
	return np.array([[int(h[i:i + 2], 16) for i in (1, 3, 5)] for h in data["hex"]], dtype=float)


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
TOOTH_PERIOD = 2


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
	drawing's, which is the whole point of deriving from the card in the first place."""
	out = a.copy()
	h = out.shape[0]
	# warm = distinctly red-of-blue and bright. The handle below is grey, brown and near-black,
	# none of which can pass this; the flame's own dark red root can.
	warm = (out[..., 3] > 0) & (out[..., 0] > 120) & (out[..., 0] > out[..., 2] + 30)
	rows: list[int] = []
	for y in range(h):
		op = int(np.count_nonzero(out[y, :, 3] > 0))
		if op and int(np.count_nonzero(warm[y])) * 2 >= op:
			rows.append(y)
		elif rows:
			break        # the first row that is mostly NOT fire is the top of the handle
	if not rows:
		return out, {}
	xs = np.where(warm[rows[0]:rows[-1] + 1].any(axis=0))[0]
	meta = {
		# the row the fire sits ON - i.e. the first row of handle, which is where its base goes
		"base_row": int(rows[-1] + 1),
		"height": int(len(rows)),
		"half_width": round(float(xs.max() - xs.min() + 1) / 2.0, 2),
	}
	out[rows[0]:rows[-1] + 1] = 0
	return out, meta


def build(name: str, rot: int, pal: np.ndarray, write: bool, force: bool) -> str:
	stage = Image.open(PROPS / f"{name}.png").convert("RGBA")
	card = Image.open(PROPS / f"big_{name}.png").convert("RGBA")
	if rot:
		card = card.rotate(rot, expand=True)
	# tight-crop the card to its own ink first, so its padding cannot shrink the object
	ca = np.asarray(card)
	ys, xs = np.where(ca[..., 3] > 127)
	card = card.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))

	h = stage.size[1]                                   # LENGTH IS FIXED - see the docstring
	w = max(2, int(round(card.size[0] * h / card.size[1])))
	out = reduce_to(card, w, h, pal)
	if name == "chainsaw":
		out = serrate_chainsaw(out)
	flame = {}
	if name == "torch":
		out, flame = strip_torch_flame(out)
	msg = f"{name:9} {stage.size[0]:2}x{stage.size[1]:<3} -> {w:2}x{h:<3}  (card {card.size[0]}x{card.size[1]})"
	if not write:
		return msg + "   (report only)"
	p = PROPS / f"{name}.png"
	status = artguard.save_guarded(p, lambda q: Image.fromarray(out, "RGBA").save(q), force)
	if flame:
		(PROPS / "torch_flame.json").write_text(json.dumps(flame, indent=2) + "\n")
		msg += f"  flame base row {flame['base_row']}, {flame['height']}px tall (drawn live)"
	return msg + f"  [{status}]"


def main() -> int:
	write = "--write" in sys.argv
	force = "--force" in sys.argv
	pal = load_palette()
	names = [a for a in sys.argv[1:] if not a.startswith("--")]
	names = [n for n in names if n in TARGETS] or list(TARGETS)
	for n in names:
		print(build(n, TARGETS[n], pal, write, force))
	if not write:
		print("\n(pass --write to apply; the pivots in Resources/art_manifest.json keep their")
		print(" long-axis fraction and move to 0.5 across, since card art is drawn symmetric)")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
