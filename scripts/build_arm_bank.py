#!/usr/bin/env python3
"""Build the performer's ARM BANK: one still body plus two independently indexed arms.

THE PROBLEM THIS REPLACES (2026-08-07, Louis: "create more frames for the juggler to make
a smoother image; also make sure the objects align with the hand position always").

The first animation seam blitted WHOLE-BODY frames and picked one by the reach of the
FURTHEST hand. Two things follow from that and both are visible in play:

  1. A cascade's hands are in ANTIPHASE - one out catching while the other is in throwing -
     so a single whole-body frame can only ever be right about ONE of them. The other hand
     was drawn wherever the painted arm happened to be, and the prop resting in it sat in
     open air. There is no amount of extra frames that fixes this; it is the wrong shape of
     lookup, not a resolution problem.
  2. The shipped cascade table held ten frames of which SEVEN sat between reach 31.5 and
     33.5 art px, because the fitter dropped every frame outside the game's own range and
     what survived was the tight end of one sweep. So the whole 27..50 sweep snapped to
     three or four distinct poses and the arms jumped between them.

THE FIX IS TO STOP ANIMATING A MAN AND START ANIMATING TWO ARMS. Every generated frame is
taken apart (see armlib) into a body that never moves and two arm layers that do. The game
then picks the left arm from the left hand and the right arm from the right hand, with no
relationship between the two - which is exactly the relationship a real juggler's arms have.
Sixteen source frames stop being sixteen poses and become sixteen-squared.

AND IT IS POOLED ACROSS GENERATIONS. Because an arm layer is independent of the frame it
came from, several animations can contribute to one bank: what a frame is worth is its
REACH and the HEIGHT of its palm, and the run that produced it does not matter. That is what
finally makes the table dense - one generation covers its own sweep, five cover the range.

THE HEIGHT FILTER IS THE IMPORTANT ONE. Measured across the five existing generations, every
single one paints the palms between 55% and 77% of the way up the figure while the game's
hand line is at 50.5% - so the props were being drawn up to 40 screen px below the painted
hands, on every frame, in every run. Reach is horizontal and says nothing about this, which
is why it survived a fitter that checked reach carefully. A candidate whose palm is not near
the hand line is dropped here however good its reach is.

USAGE
  .venv/bin/python scripts/build_arm_bank.py artifacts/chargen/anim_*
  .venv/bin/python scripts/build_arm_bank.py artifacts/chargen/anim_* --write
  ... --sheet out.png     write a contact sheet of the bank for eyeballing
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

import armlib
import artguard

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Assets" / "Characters" / "showman"
PALETTE = ROOT / "Resources" / "palette" / "palette.png"

# THE REACH THE BANK HAS TO COVER, in art pixels from the figure's centreline.
#
# The obvious range is inner_pos..outer_pos (27..50) and it is WRONG FOR COLUMNS. A columns
# hand does not stand at a fixed slot - it stands under the lane it is about to throw, and
# columns_x spreads those lanes symmetrically about centre: measured in Game.gd's own
# comment, the outermost lane is 10px past the slot at three objects, 34 at five and 66 at
# seven. So a seven-object columns hand reaches 120 screen px = 60 art px out, ten past
# anything the cascade ever asks for, and clamping there is a stub arm on the busiest
# pattern in the game.
# ...AND THE INNER END IS NOT inner_pos EITHER. COL_HAND_MIN was removed from Game.gd in
# 2026-07-28 ("the hand goes to the column, ALL THE WAY"), so a columns hand stands under its
# own lane even when that lane is inside the torso. Measured over a 7-ball columns run: the
# right hand spends 74% of its time inside reach 30 and 36% of it inside reach 20, and touches
# 0 - dead centre - on the middle lane. A bank that starts at 30 leaves the busiest pattern in
# the game with a stub arm most of the time.
REACH_LO = 0.0
REACH_HI = 64.0
REACH_STEP = 1.0        # one bank entry per art pixel of reach: finer than the eye at 2x

# How far a candidate's palm may sit from the game's hand line, as a fraction of the figure's
# height. 0.024 is about 8 screen px at this density.
#
# THIS IS A TRADE AGAINST REACH COVERAGE and it is worth stating which way it goes. Loosening
# it to 0.035 buys entries down at reach 27 - the resting pose - and costs vertical accuracy
# everywhere. Tightening it loses the tight end and sharpens the rest. The tight end is the
# cheaper thing to lose, because of WHERE THE TWO KINDS OF ERROR SHOW:
#
#   - at rest the hand is HOLDING a prop, and a held prop is drawn at the painted palm
#     (fig_hand_pos), so the arm being a few pixels wide of the simulation's hand is
#     invisible - the ball is in the hand either way.
#   - a CATCH happens out at outer_pos, where a prop arrives on a path whose endpoint is the
#     simulation's hand and not the painting's. There the error is the gap between the ball
#     and the palm, and it is the only place a player can see it.
#
# So the bank is dense and accurate across the catching range and simply clamps at the
# resting end. Generating the tight end properly was tried five times and the model will not
# do it: asked for hands tucked at hip height it raises them to the waist every time, in
# every phrasing, because that is what a person actually does.
UP_TOL = 0.024

# THE HAND LINE IS NOT FLAT, and pretending it was is what made the inner poses bad.
#
# The first version of this file demanded one height at every reach and then loosened the
# tolerance close in, because the model would not paint a tucked hand at hip height however
# the prompt was phrased. It raises the palm as the arm folds - and it is right to, that is
# what a forearm does. Measured across all nineteen generations: 58-65% of the figure's height
# at reach 24-30, 49-51% at 45-54, and rising again past 57.
#
# The game now has the same curve (see HAND_IN_LIFT in Game.gd), so the fitter can ask for the
# pose it actually wants instead of tolerating the one it gets. The U-shape is not a curve fit
# either - it is the two hand SLOTS. The inner slot is lifted and the outer is not, so reach
# tracks height on the way out; and a COLUMNS hand stands under its own lane while still on
# the inner slot, which is why the far reaches are lifted too.
LIFT_UP = 0.067          # how much higher the inner slot sits, as a fraction of figure height
LIFT_IN = (24.0, 30.0)   # ...fully lifted out to here
LIFT_FLAT = (46.0, 56.0) # ...flat across the catching range
LIFT_OUT = 64.0          # ...and lifted again where columns' outer lanes live

PALM_BOX = (12, 12)      # the cut-out hand, in art px
PALM_SHIFT = 4           # ...offset toward the body, because the palm point is the extremity


def lift_at(reach: float) -> float:
	"""How far above the base hand line a palm belongs at this reach, 0..LIFT_UP."""
	if reach <= LIFT_IN[1]:
		return LIFT_UP
	if reach < LIFT_FLAT[0]:
		return LIFT_UP * (LIFT_FLAT[0] - reach) / (LIFT_FLAT[0] - LIFT_IN[1])
	if reach <= LIFT_FLAT[1]:
		return 0.0
	return LIFT_UP * min(1.0, (reach - LIFT_FLAT[1]) / (LIFT_OUT - LIFT_FLAT[1]))


def srgb_to_oklab(rgb: np.ndarray) -> np.ndarray:
	c = rgb / 255.0
	lin = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
	r, g, b = lin[..., 0], lin[..., 1], lin[..., 2]
	l = np.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
	m = np.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
	s = np.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
	return np.stack([
		0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
	], axis=-1)


def snap(rgba: np.ndarray, pal: np.ndarray) -> np.ndarray:
	"""Force the locked 48 colours.

	animate_image does NOT force the source palette the way create_image_pixflux does with
	color_image_base64 - measured, the shipped cascade strip carried 174 colours of which 35
	were on-palette, while the still figure it was generated from is 43 of 43. So the man
	standing still and the man juggling were literally not painted in the same colours."""
	out = rgba.copy()
	m = out[..., 3] > 0
	if m.any():
		out[..., :3][m] = _snap_rgb(out[..., :3][m], pal)
	return out


def _snap_rgb(rgb: np.ndarray, pal: np.ndarray) -> np.ndarray:
	d = np.linalg.norm(srgb_to_oklab(rgb.astype(float))[:, None, :]
					   - srgb_to_oklab(pal.astype(float))[None, :, :], axis=2)
	return pal[np.argmin(d, axis=1)]


SEARCH = 8          # px of offset to try in each direction when matching two bodies
MATCH_MIN = 0.78    # ...and how well they must then agree to be pooled at all.
#
# DELIBERATELY LOOSE, and the number is worth explaining because a strict one looks right
# and is not. Measured across every pair of generations in the set, the outside-band overlap
# runs 81-91% with no clustering by family at all - the showman wears a TAILCOAT, its hem is
# most of the silhouette below the band, and it swings a few pixels differently in every run.
# So this score cannot separate "same character, different take" from "same character, same
# take", and a 90% floor threw away the purpose-built sweeps while a composite built from an
# 83% fit was visually perfect at 4x. It is a sanity floor against pooling a different
# character, not a quality gate. THE QUALITY GATE IS --sheet AND YOUR EYES.


def align_to(ref_static: np.ndarray, static: np.ndarray) -> tuple[int, int, float]:
	"""How far this generation's body sits from the reference, and how well it fits at all.

	MATCHED ON THE WHOLE SILHOUETTE, BY SEARCH. The first version anchored on the head-top
	row, on the reasoning that the coat hem and boots are what differ between runs and the
	skull is not - and it tore the figure in half. An arm layer carries half a TORSO with it
	(see armlib.split_layer), so it has to land on a torso of exactly the same shape, and one
	landmark cannot promise that. Overlap can: slide one mask over the other and take the
	offset where they agree most.

	THE SCORE IS ALSO A VETO, which matters more than the offset. These generations are not
	all siblings - some were animated from the original standing still, some from a frame of
	an earlier animation - and a cousin's coat is a slightly different coat. Pooling one in
	puts a seam down the middle of the man that no offset can close, so a generation that
	cannot reach MATCH_MIN is dropped whatever poses it was going to contribute."""
	h = max(ref_static.shape[0], static.shape[0]) + 2 * SEARCH
	w = max(ref_static.shape[1], static.shape[1]) + 2 * SEARCH

	def outside_band(m: np.ndarray) -> np.ndarray:
		"""The head, shoulders, coat hem and legs - never an arm, in any generation.

		Matching must not look INSIDE the arm band. A generation whose arms stay tucked has
		them baked into its own static mask, so comparing full silhouettes would score two
		identical men as different and would slide the offset to average out a sleeve. Above
		and below the band there is nothing but body in every run, so that is where the two
		can be honestly compared."""
		y0, y1 = armlib.band_rows(m.shape[0])
		out = m.copy()
		out[y0:y1] = False
		return out

	def place(m: np.ndarray, ox: int, oy: int) -> np.ndarray:
		out = np.zeros((h, w), bool)
		out[oy:oy + m.shape[0], ox:ox + m.shape[1]] = m
		return out

	ref_static = outside_band(ref_static)
	static_cmp = outside_band(static)
	# both bottom-aligned and centred to start with: the feet are on the floor in every
	# frame of every generation, which is the one thing all of them agree about
	ref = place(ref_static, (w - ref_static.shape[1]) // 2, h - SEARCH - ref_static.shape[0])
	best, bx, by = -1.0, 0, 0
	base_x = (w - static_cmp.shape[1]) // 2
	base_y = h - SEARCH - static_cmp.shape[0]
	for dy in range(-SEARCH, SEARCH + 1):
		for dx in range(-SEARCH, SEARCH + 1):
			cur = place(static_cmp, base_x + dx, base_y + dy)
			inter = np.count_nonzero(ref & cur)
			union = np.count_nonzero(ref | cur)
			iou = inter / float(union) if union else 0.0
			if iou > best:
				best, bx, by = iou, dx, dy
	# back into REFERENCE-cell coordinates: where a pixel of this generation's cell lands
	return (base_x + bx) - (w - ref_static.shape[1]) // 2, \
		(base_y + by) - (h - SEARCH - ref_static.shape[0]), best


def body_width(static: np.ndarray) -> float:
	"""How wide this generation's 'body' is through the arm band - the contamination test.

	A generation whose arms never leave the silhouette has no clean body to offer: a sleeve
	that is opaque in every frame is, by the only definition available here, part of the
	body, and using that generation as the reference paints the man with a spare pair of
	arms permanently attached. The widest sweep in the set is always the cleanest body,
	and this is how to find it without looking."""
	h = static.shape[0]
	y0, y1 = armlib.band_rows(h)
	rows = [np.count_nonzero(r) for r in static[y0:y1] if r.any()]
	return float(np.median(rows)) if rows else 1e9


def gather(dirs: list[Path]) -> tuple[np.ndarray, list[dict]]:
	"""The reference body, and every arm layer any generation can offer."""
	loaded = []
	for d in dirs:
		frames = armlib.common_crop(armlib.load_frames(d))
		if not frames:
			continue
		loaded.append((d, frames) + armlib.body_of(frames)[:2])
	if not loaded:
		return None, []
	# THE REFERENCE BODY IS CHOSEN, NOT THE FIRST ONE GIVEN - see body_width.
	ref = min(loaded, key=lambda t: body_width(t[3]))
	print(f"body from {ref[0].name} (narrowest through the arm band, "
		  f"{body_width(ref[3]):.0f}px vs "
		  f"{', '.join(f'{t[0].name} {body_width(t[3]):.0f}' for t in loaded if t is not ref)})")
	ref_body, ref_static = ref[2], ref[3]
	cands: list[dict] = []
	for d, frames, body, static in loaded:
		if static is ref_static:
			dx, dy, fit = 0, 0, 1.0
		else:
			dx, dy, fit = align_to(ref_static, static)
			if fit < MATCH_MIN:
				print(f"  {d.name}: body fits the reference only {fit * 100:.0f}% - "
					  f"a different coat, dropped")
				continue
			print(f"  {d.name}: fit {fit * 100:.0f}%, offset ({dx:+d},{dy:+d})")
		h, w = static.shape
		cx = (w - 1) * 0.5
		for i, f in enumerate(frames):
			p = armlib.palms(f, static)
			if not p:
				continue
			for side in ("L", "R"):
				layer, lx, ly = armlib.split_layer(f, side)
				if layer.size == 0:
					continue
				px, py = p[side]
				cands.append({
					"src": d.name, "frame": i, "side": side,
					"reach": float(p[side + "reach"]),
					"up": float(p[side + "up"]),
					"layer": layer,
					# everything below is in the REFERENCE body's coordinates
					"ox": lx + dx, "oy": ly + dy,
					"px": px + dx, "py": py + dy,
					"cell": (w, h), "cx": cx,
				})
	return ref_body, cands


def palm_is_skin(c: dict, body_pal: np.ndarray, skin_set: set) -> bool:
	"""Is this candidate's palm actually a hand? Sampled as a small disc around the measured
	palm, snapped to the body's palette, and tested for membership in the face's colours."""
	lay = c["layer"]
	px, py = c["px"] - c["ox"], c["py"] - c["oy"]
	yy, xx = np.mgrid[0:lay.shape[0], 0:lay.shape[1]]
	m = (lay[..., 3] > 0) & ((xx - px) ** 2 + (yy - py) ** 2 <= 16)
	if not m.any():
		return False
	med = np.median(lay[m][:, :3], axis=0)
	snapped = _snap_rgb(med[None, :].astype(float), body_pal)[0]
	return tuple(int(v) for v in snapped) in skin_set


def pick(cands: list[dict], side: str, axis: float, target_py: float) -> list[dict]:
	"""One arm per reach bucket - the one whose palm is nearest the game's hand line.

	Mirrors of the other side count as candidates. The showman's coat is symmetric about the
	centreline inside the arm band (the face and the boots, which are not, are outside it),
	so a left arm flipped is a perfectly good right arm - and it doubles what every
	generation is worth. Height still decides, because height is the thing generations get
	wrong."""
	pool = []
	for c in cands:
		if c["side"] == side:
			pool.append(c)
		else:
			lay, ox = armlib.mirror_about(c["layer"], c["ox"], axis)
			pool.append(dict(c, side=side, layer=lay, ox=int(round(ox)),
							 px=2.0 * axis - c["px"], mirrored=True))
	out = []
	n = int(round((REACH_HI - REACH_LO) / REACH_STEP)) + 1
	for k in range(n):
		want = REACH_LO + k * REACH_STEP
		best, best_key = None, None
		for c in pool:
			if abs(c["reach"] - want) > REACH_STEP * 0.75:
				continue
			# SCORED ON THE PALM'S FINAL ROW, not on the height measured before alignment.
			# Two generations can agree about where a palm sits within their own crop and
			# still disagree by a pixel or two once one is slid onto the other's body, and
			# that pixel is a whole art pixel here. This is also the number the game will
			# live with, so it is the one worth minimising.
			want_py = target_py - lift_at(want) * (c["cell"][1] - 1)
			py_err = abs(c["py"] - want_py)
			if py_err > UP_TOL * (c["cell"][1] - 1):
				continue
			key = (py_err, abs(c["reach"] - want))
			if best_key is None or key < best_key:
				best, best_key = c, key
		if best is not None and not any(o["_id"] == id(best) for o in out):
			out.append(dict(best, bucket=want, _id=id(best)))
	return out


def main() -> int:
	argv = sys.argv[1:]
	write = "--write" in argv
	force = "--force" in argv
	sheet = None
	if "--sheet" in argv:
		i = argv.index("--sheet")
		sheet = Path(argv[i + 1])
		del argv[i:i + 2]
	dirs = [Path(a) for a in argv if not a.startswith("--")]
	if not dirs:
		print(__doc__)
		return 2

	body, cands = gather(dirs)
	if body is None:
		raise SystemExit("no frames found")
	ch, cw = body.shape[:2]
	print(f"body cell {cw}x{ch}, {len(cands)} raw arm candidates from {len(dirs)} generation(s)")
	ups = sorted(round(c["up"] * 100, 1) for c in cands)
	print(f"palm height across candidates: {ups[0]}% .. {ups[-1]}%  "
		  f"(game wants {armlib.GAME_HAND_UP * 100:.1f}%)")
	usable = [c for c in cands if abs(c["up"] - armlib.GAME_HAND_UP) <= UP_TOL]
	print(f"{len(usable)}/{len(cands)} candidates are within {UP_TOL * 100:.1f} points of the hand line")

	# THE MIRROR AXIS is the reference body's own ink centre, which is also what the game
	# stands on stage centre - see body_cx below and fig_body_origin in Game.gd.
	bys, bxs = np.where(body[..., 3] > 0)
	axis = (int(bxs.min()) + int(bxs.max())) * 0.5
	# HANDS THAT ARE NOT THE RIGHT COLOUR ARE NOT HANDS - see armlib.skin_colours. Done
	# before selection rather than after, so a rejected pose leaves no gap in the table.
	pal = np.asarray(Image.open(PALETTE).convert("RGB")).reshape(-1, 3).astype(int)
	body = snap(body, pal)
	body_pal = np.unique(body[body[..., 3] > 0][:, :3], axis=0)
	skin = _snap_rgb(armlib.skin_colours(body).astype(float), body_pal)
	skin_set = {tuple(int(v) for v in c) for c in skin}
	kept = [c for c in cands if palm_is_skin(c, body_pal, skin_set)]
	print(f"{len(kept)}/{len(cands)} candidates have a palm painted in his own skin "
		  f"({len(skin_set)} face colours)")
	cands = kept
	# THE ROW A PALM OUGHT TO BE ON, in the reference body's own cell: the eight-head canon's
	# hand line, which is where the game puts its hands and where every prop will be.
	target_py = (1.0 - armlib.GAME_HAND_UP) * (ch - 1)
	banks = {s: pick(cands, s, axis, target_py) for s in ("L", "R")}
	for s in ("L", "R"):
		b = banks[s]
		got = [round(c["reach"], 1) for c in b]
		print(f"  {s}: {len(b)} entries covering {min(got) if got else '-'}..{max(got) if got else '-'}")
		miss = [REACH_LO + k * REACH_STEP for k in range(int((REACH_HI - REACH_LO) / REACH_STEP) + 1)
				if not any(abs(c["bucket"] - (REACH_LO + k * REACH_STEP)) < 1e-6 for c in b)]
		if miss:
			print(f"      gaps at reach {[round(m) for m in miss]}")
	if min(len(banks['L']), len(banks['R'])) < 8:
		print("\n*** too few usable arms. Generate more animations with the hands kept LOW")
		print("*** (see the palm-height line above - that is what is failing, not reach).")

	# ONE UNIFORM ATLAS CELL, because the game addresses the atlas by UV sub-rect and a
	# uniform grid makes that arithmetic a division. The waste is a few hundred transparent
	# pixels; the alternative is a packer whose output the engine has to be told about.
	entries = banks["L"] + banks["R"]
	aw = max(c["layer"].shape[1] for c in entries)
	ah = max(c["layer"].shape[0] for c in entries)
	cols = 8
	rows = (len(entries) + cols - 1) // cols
	atlas = np.zeros((rows * ah, cols * aw, 4), np.uint8)
	# WHERE THE BODY ACTUALLY STANDS IN ITS CELL. The cell is as wide as the widest arm pose
	# in the source animation, and a sweep is rarely symmetric to the pixel - so centring the
	# CELL on stage centre stands the man slightly off it. The game centres this instead.
	meta = {"cell_w": cw, "cell_h": ch, "atlas_cols": cols, "atlas_w": aw, "atlas_h": ah,
			"body_cx": round(float(axis), 1),
			# THE HAND LINE THE PAINTED PERFORMER ACTUALLY HAS, as a row of his own cell.
			#
			# The game reads this instead of assuming its own. A painted figure is a FIXED
			# SIZE sprite (never resampled - a fractional scale is mush) while the stage
			# around it is laid out as fractions of the viewport, and the project stretches
			# with aspect "expand" - so at any window that is not 16:9 the boards move and
			# the man does not, and his palms slide off the line the props fly to. Measured
			# at 1280x803 the gap was 11px and growing with the window. Anchoring the hand
			# line to the painting closes it at every size at once.
			"hand_py": 0.0,
			"left": [], "right": []}
	for n, c in enumerate(entries):
		r, k = divmod(n, cols)
		lay = c["layer"]
		atlas[r * ah:r * ah + lay.shape[0], k * aw:k * aw + lay.shape[1]] = lay
		rec = {"slot": n, "reach": round(c["reach"], 2),
			   "ox": int(c["ox"]), "oy": int(c["oy"]),
			   "px": round(float(c["px"]), 1), "py": round(float(c["py"]), 1)}
		meta["left" if c["side"] == "L" else "right"].append(rec)
	meta["left"].sort(key=lambda r: r["reach"])
	meta["right"].sort(key=lambda r: r["reach"])
	# THE HAND LINE REPORTED TO THE GAME IS THE BASE (flat) ONE, measured only from entries in
	# the catching range. A median across the whole bank would average the lifted inner poses
	# into it and quietly raise stage_center for every screen - the curve is a property of the
	# pose, not of where the performer stands.
	flat = [r["py"] for r in meta["left"] + meta["right"]
			if LIFT_FLAT[0] <= r["reach"] <= LIFT_FLAT[1]]
	pys = [r["py"] for r in meta["left"] + meta["right"]]
	meta["hand_py"] = round(float(np.median(flat)), 1) if flat else round(target_py, 1)
	lifted = [r for r in meta["left"] if r["reach"] <= LIFT_IN[1]]
	print(f"hand line at row {meta['hand_py']} of {ch} (canon says {target_py:.1f}); "
		  f"{len(flat)} entries in the flat catching range, "
		  f"{len(lifted)} lifted inner pose(s) per side")
	if lifted:
		hi = min(r["py"] for r in lifted)
		print(f"innermost palm sits {meta['hand_py'] - hi:.0f} art px "
			  f"({(meta['hand_py'] - hi) * 2:.0f} screen px) above the catch line")

	# THE ARMS ARE SNAPPED TO THE BODY'S OWN COLOURS, not to the full 48.
	#
	# Snapping each layer independently to the whole palette looked correct and was not: the
	# generations do not agree on skin to the byte, the locked palette holds both a skin tone
	# and a gold trim tone a hair apart in Oklab, and different layers fell on different sides
	# of that line. The bank came back with GOLD HANDS at some reaches and skin at others -
	# which in play is not a subtle colour shift, it is the performer's hands changing colour
	# as he reaches out, because reach is what picks the layer.
	#
	# Restricting the arms to the colours the body is already painted in makes that
	# impossible by construction: same character, same box of crayons. The body carries a
	# face, so the skin ramp is in there; it carries the coat and the gold frogging, so the
	# sleeve and cuff are too.
	atlas = snap(atlas, body_pal)
	print(f"arms snapped to the body's own {len(body_pal)} colours")

	# THE PERFORMER'S OWN PALM, cut out on its own (2026-08-07).
	#
	# It exists for exactly one case and it is worth naming: a COLUMNS hand standing under a
	# central lane, where the bank simply has no arm (see fig_palm_far in Game.gd). The prop
	# stays on its lane because that is where it is, and something has to be holding it. The
	# traced figure's mitt was tried first and is far too big beside this character - it is
	# drawn to the old juggler's proportions and reads as a pale lump on his trousers. His own
	# hand, cut from the frame the bank already chose, cannot be the wrong size or the wrong
	# colour.
	#
	# Taken from a MID-REACH entry in the flat catching range: the arm is at full extension
	# there, so the hand is seen cleanly rather than foreshortened against the coat.
	mids = [c for c in banks["L"] if LIFT_FLAT[0] <= c["reach"] <= LIFT_FLAT[1]]
	palm_meta = {}
	if mids:
		e = min(mids, key=lambda c: abs(c["py"] - target_py))
		lay = e["layer"]
		lpx, lpy = e["px"] - e["ox"], e["py"] - e["oy"]
		# the palm point is the arm's outermost pixel, so the hand lies INWARD of it: the box
		# is shifted toward the body rather than centred, or half of it is empty air
		x0 = max(0, int(lpx - PALM_BOX[0] // 2 + PALM_SHIFT))
		y0 = max(0, int(lpy - PALM_BOX[1] // 2))
		x1 = min(lay.shape[1], x0 + PALM_BOX[0])
		y1 = min(lay.shape[0], y0 + PALM_BOX[1])
		patch = snap(lay[y0:y1, x0:x1], body_pal)
		palm_meta = {"w": int(patch.shape[1]), "h": int(patch.shape[0]),
					 "ax": round(float(lpx - x0), 1), "ay": round(float(lpy - y0), 1)}
		meta["palm"] = palm_meta
		if write:
			artguard.save_guarded(OUT / "palm_l.png",
				lambda q: Image.fromarray(patch, "RGBA").save(q), force)
			artguard.save_guarded(OUT / "palm_r.png",
				lambda q: Image.fromarray(patch[:, ::-1], "RGBA").save(q), force)
		print(f"palm patch {patch.shape[1]}x{patch.shape[0]} from the reach-{e['reach']:.0f} arm")

	if sheet:
		_write_sheet(sheet, body, entries, cw, ch)
		print(f"contact sheet -> {sheet}")
	if not write:
		print("(pass --write to apply)")
		return 0
	OUT.mkdir(parents=True, exist_ok=True)
	s1 = artguard.save_guarded(OUT / "juggle_body.png",
		lambda q: Image.fromarray(body, "RGBA").save(q), force)
	s2 = artguard.save_guarded(OUT / "juggle_arms.png",
		lambda q: Image.fromarray(atlas, "RGBA").save(q), force)
	(OUT / "juggle_arms.json").write_text(json.dumps(meta, indent=2) + "\n")
	print(f"wrote body {cw}x{ch} [{s1}] and {len(entries)} arms in a "
		  f"{cols * aw}x{rows * ah} atlas [{s2}]")
	return 0


def _write_sheet(path: Path, body: np.ndarray, entries: list[dict], cw: int, ch: int) -> None:
	"""The bank as the game will assemble it: body + left arm + right arm, swept together.

	Both hands at the SAME reach here, which is the one thing the game will never do - but it
	is what makes a mismatched pair obvious to a human eye."""
	ls = sorted([c for c in entries if c["side"] == "L"], key=lambda c: c["reach"])
	rs = sorted([c for c in entries if c["side"] == "R"], key=lambda c: c["reach"])
	n = min(len(ls), len(rs))
	# PADDED, because an arm layer may start left of the body's own cell - the widest pose in
	# some generation reaches further out than the reference sweep ever did, so its offset is
	# legitimately negative. The game draws from the body's corner and does not care; PIL
	# silently drops a negative paste, which is what made the first contact sheet look like
	# the figure had been torn in half.
	# PADDED, because an arm layer may start left of the body's own cell - the widest pose in
	# some generation reaches further out than the reference sweep ever did, so its offset is
	# legitimately negative. The game draws from the body's corner and does not care; PIL
	# silently drops a negative paste.
	pad = 60
	tw = cw + 2 * pad
	# A GRID AT NATIVE 2x, NOT ONE LONG ROW. Twice now a long row was read as evidence of a
	# torn figure when the pipeline was fine - fifteen 270px figures in a 2000px strip is a
	# 7x downscale, and a downscaled sprite always looks broken. Anything judged here must be
	# judged at the size it is drawn at.
	cols = min(6, n)
	rows = (n + cols - 1) // cols
	out = Image.new("RGBA", (tw * cols * 2, ch * rows * 2), (26, 24, 34, 255))
	for i in range(n):
		f = Image.new("RGBA", (tw, ch), (0, 0, 0, 0))
		f.alpha_composite(Image.fromarray(body, "RGBA"), (pad, 0))
		for c in (ls[i], rs[i]):
			f.alpha_composite(Image.fromarray(c["layer"], "RGBA"),
							  (pad + int(c["ox"]), int(c["oy"])))
		f = f.resize((tw * 2, ch * 2), Image.NEAREST)
		out.paste(f, ((i % cols) * tw * 2, (i // cols) * ch * 2), f)
	out.save(path)


if __name__ == "__main__":
	raise SystemExit(main())
