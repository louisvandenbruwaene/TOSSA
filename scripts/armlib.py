#!/usr/bin/env python3
"""Shared measurement for the performer's juggling arms.

WHY THIS EXISTS AS A LIBRARY. Two scripts need the same three answers about a generated
animation - where is the body, where are this frame's arms, and where are its palms - and
getting any of them slightly differently in two places is how a strip and the table that
indexes it drift apart.

THE MODEL. The showman's body does not juggle; his arms do. So a generated animation is
taken apart into

  BODY   the pixels opaque in EVERY frame, coloured by the MEDIAN across frames. The median
         matters: a torso pixel that has a sleeve over it in some frames would otherwise
         take that sleeve's colour, and the body would wear a ghost arm.
  ARMS   per frame, per side - and this is deliberately GENEROUS. See split_layer.

and put back together at draw time with the LEFT arm and the RIGHT arm chosen independently,
which is the whole point: a cascade's hands are in ANTIPHASE, so no single whole-body frame
can ever have both of them in the right place.
"""

from __future__ import annotations

import numpy as np
from PIL import Image
from scipy import ndimage

# The vertical window the arms live in, as fractions of the figure's ink height from the top.
# The top is below the chin so a jittering face never enters an arm layer; the bottom is above
# the coat hem, which swings a pixel or two between frames and would otherwise read as motion.
BAND = (0.17, 0.66)

# A frame is only usable if its palms sit near the height the GAME's hands are at. stage_center
# is s.y * 0.57 with the floor at s.y * 0.80, so the hand line is 165.6 screen px above the
# boards - almost exactly half the figure's own height.
#
# THIS IS THE CHECK THAT MATTERS AND IT IS EASY TO SKIP, because reach is horizontal and says
# nothing at all about height. The first accepted strip was a perfectly good juggling animation
# whose hands were at CHEST height; every reach number looked fine and in game the man waved
# around his lapels while the catch rings sat empty at his hips.
GAME_HAND_UP = 0.505

# The smallest share of the face a colour must cover to count as one of his skin tones.
SKIN_MIN_SHARE = 0.01


def load_frames(src) -> list[np.ndarray]:
	"""Every PNG in a directory, or every frame of a multi-frame image."""
	if src.is_dir():
		return [np.asarray(Image.open(p).convert("RGBA")).astype(int)
				for p in sorted(src.glob("*.png"))]
	im = Image.open(src)
	n = getattr(im, "n_frames", 1)
	out = []
	for i in range(n):
		im.seek(i)
		out.append(np.asarray(im.convert("RGBA")).astype(int))
	return out


def common_crop(frames: list[np.ndarray]) -> list[np.ndarray]:
	"""ONE crop box for every frame, so the figure cannot jitter between them.

	Cropping each frame to its own bounds recentres the body every time an arm moves, which
	reads as the whole man twitching rather than as his arms working."""
	union = np.zeros(frames[0].shape[:2], dtype=bool)
	for f in frames:
		union |= f[..., 3] > 127
	ys, xs = np.where(union)
	return [f[ys.min():ys.max() + 1, xs.min():xs.max() + 1] for f in frames]


def body_of(frames: list[np.ndarray]) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
	"""(body RGBA, static mask, median RGB) - the performer with his arms taken off.

	Everything opaque in every single frame is body: torso, legs, head, the hanging coat.
	This is the third hand-detection method tried and the only one that holds. Colour failed
	twice - a tolerant skin match also catches the ringmaster's GOLD FROGGING (skin
	[242,204,140], trim [176,136,72]) and reported his boots as hands on eight frames of
	seventeen; an exact palette match fails because animate_image does NOT force the source
	palette, so only 4 of 17 frames matched at all. Silhouette width failed too: run the
	search band down to the hips and the COAT HEM is wider than any reach, stop it above the
	hem and the coat's SHOULDERS are wider than the hands whenever the arms tuck in.

	What separates an arm from a coat is not where it is or what colour it is. It is that
	THE ARM MOVES.

	BUT AN INTERSECTION IS THE WRONG SILHOUETTE OUTSIDE THE ARM BAND, and that cost a
	confusing hour: a generator jitters the head by a pixel between frames, so the strictly
	intersected body came back with NO HEAD AT ALL, and the composite looked like the figure
	had been torn in half. Above the band there are no arms to exclude - the band starts
	below the chin - and below it there are none either, only a tailcoat that swings. So the
	strict rule is applied where it is needed and a majority vote everywhere else.

	Returns (body RGBA, the STRICT intersection, median RGB). The strict mask is what palms
	measures against; it is not what gets drawn."""
	masks = [f[..., 3] > 127 for f in frames]
	strict = masks[0].copy()
	for m in masks[1:]:
		strict &= m
	votes = np.sum(np.stack(masks), axis=0)
	solid = votes * 2 >= len(masks)
	h, w = strict.shape
	y0, y1 = band_rows(h)
	shape = solid.copy()
	shape[y0:y1] = strict[y0:y1]
	med = np.median(np.stack([f[..., :3] for f in frames]), axis=0).astype(int)
	body = np.zeros((h, w, 4), dtype=np.uint8)
	body[shape] = np.dstack([med, np.full((h, w), 255)])[shape].astype(np.uint8)
	# HIS FACE COMES FROM ONE FRAME, NOT FROM THE MEDIAN OF SEVENTEEN.
	#
	# The median exists to stop a sleeve that passes over the torso from staining it, and
	# above the arm band there are no sleeves - the band starts below the chin. What the
	# median does up there is average a head that the generator jitters by a pixel between
	# frames, and averaging a twenty-pixel face is not a softening, it is a demolition:
	# measured at 10x, the hair smears across the brow and both eyes disappear. That face is
	# on stage in every frame of the game and, since 2026-08-08, close up in the tutorial's
	# speech box.
	#
	# So the rows above the band are taken whole from the single frame whose head best
	# matches the voted silhouette - not frame 0, which may itself be the jittered one.
	y_top = y0
	if y_top > 0:
		head_shape = shape[:y_top]
		best_i, best_iou = 0, -1.0
		for i, m in enumerate(masks):
			hm = m[:y_top]
			union = np.count_nonzero(hm | head_shape)
			iou = np.count_nonzero(hm & head_shape) / float(union) if union else 0.0
			if iou > best_iou:
				best_iou, best_i = iou, i
		src = frames[best_i][:y_top, :, :3]
		body[:y_top][head_shape] = np.dstack(
			[src, np.full(src.shape[:2], 255)])[head_shape].astype(np.uint8)
	return body, strict, med


def band_rows(h: int) -> tuple[int, int]:
	return int(h * BAND[0]), int(h * BAND[1])


def head_rows(mask: np.ndarray) -> tuple[int, int]:
	"""The crown down to the NECK - the part of the figure that is certainly his face.

	The neck is the narrowest row between the top of the head and the shoulders, which is the
	same landmark fit_char_design.py measures for the same reason: a collar and lapels sit
	above the shoulder line and are wider than a skull, so anything that stops at the arm band
	instead calls a head twice its real size."""
	ys, _ = np.where(mask)
	top = int(ys.min())
	limit = int(mask.shape[0] * BAND[0])
	widths = [(np.count_nonzero(mask[y]), y) for y in range(top + 4, max(top + 6, limit))]
	if not widths:
		return top, limit
	return top, min(widths)[1]


def skin_colours(body: np.ndarray) -> np.ndarray:
	"""Every colour on the performer's face.

	THE HANDS MUST BE PAINTED IN THE COLOURS OF HIS FACE - which sounds like a nicety and is
	actually a correctness check. The generations do not agree on skin to the byte, and the
	locked palette carries a skin tone and the coat's GOLD FROGGING close enough together that
	different layers landed on different sides: the bank came back with gold hands at some
	reaches and skin at others, and because reach is what picks a layer, that is the
	performer's hands changing colour as he reaches out.

	Distance thresholds do not separate the two cleanly - measured, the worst gold sits 0.045
	from skin in Oklab and a perfectly good shadowed palm sits 0.045 the other way. Set
	membership does, because the arm layers are already snapped to the body's own colours: a
	skin entry can only have come from the face, and a gold one can only have come from the
	coat.

	IT IS THE FACE MINUS THE COSTUME, NOT THE FACE. Taking every colour above the neck reads
	as "skin" the hair, the black outline, the collar and the lapels that rise past the
	chin - 22 entries covering most of the costume - and a mask built from that lights up
	3,210 pixels of torso as one blob, so a hand can never be found inside it. Subtracting
	everything painted BELOW the arm band leaves only what is unique to his face: the coat,
	its gold frogging, the trousers and the boots all appear down there, and the one thing
	that does not is skin. Hands are inside the band, so they are never subtracted."""
	mask = body[..., 3] > 0
	top, neck = head_rows(mask)
	head = body[top:neck + 1]
	sel = head[..., 3] > 0
	if not sel.any():
		return np.zeros((0, 3), np.uint8)
	face, cnt = np.unique(head[sel][:, :3], axis=0, return_counts=True)
	_, y1 = band_rows(body.shape[0])
	below = body[y1:]
	bsel = below[..., 3] > 0
	if not bsel.any():
		return face
	worn = {tuple(int(v) for v in c) for c in np.unique(below[bsel][:, :3], axis=0)}
	# ...AND IT HAS TO BE A REAL PART OF THE FACE. Measured on the showman: the face-only
	# set is his two skin tones at 10.2% and 2.8% of the head, then a 1px eye and a 1px lip.
	# A one-pixel entry cannot be told from a stray dither pixel, and admitting it lights up
	# scattered singles all over the coat - the mask has to describe a hand, not a freckle.
	tot = float(cnt.sum())
	skin = np.array([c for c, k in zip(face, cnt)
					 if tuple(int(v) for v in c) not in worn and k / tot >= SKIN_MIN_SHARE],
					dtype=face.dtype)
	return skin if skin.size else face


def snap_to(rgb: np.ndarray, pal: np.ndarray) -> np.ndarray:
	"""Nearest palette entry per pixel, in Oklab. Shape-preserving."""
	flat = rgb.reshape(-1, 3).astype(float)
	d = np.linalg.norm(_oklab(flat)[:, None, :] - _oklab(pal.astype(float))[None, :, :], axis=2)
	return pal[np.argmin(d, axis=1)].reshape(rgb.shape)


def skin_mask(rgb: np.ndarray, skin_set: set, body_pal: np.ndarray) -> np.ndarray:
	"""Which pixels are painted in one of the performer's own face colours.

	Set membership, not a distance threshold, for the reason skin_colours records: the
	locked palette carries a skin tone and the coat's gold frogging close enough together
	in Oklab that no threshold separates them.

	SNAPPED TO THE BODY'S OWN PALETTE FIRST, and skipping that turned 624 candidates into
	70. The frames arrive snapped to the LOCKED 48, while the skin set can only be drawn
	from the ~38 the body is actually painted in - so a skin pixel that landed on one of the
	ten colours the body does not use matched nothing at all, and the hand vanished. Both
	sides of an equality test have to be quantised the same way."""
	snapped = snap_to(rgb, body_pal)
	out = np.zeros(rgb.shape[:2], bool)
	for col in skin_set:
		out |= np.all(snapped == np.asarray(col, dtype=snapped.dtype), axis=-1)
	return out


# The smallest blob of skin that can be a hand, in pixels. Below this it is a knuckle
# showing past a cuff, a stray trim pixel that snapped onto a skin entry, or noise.
HAND_MIN = 10


def hands(frame: np.ndarray, skin_set: set, body_pal: np.ndarray) -> dict:
	"""This frame's two HANDS - the actual blobs of skin, not the arm's outermost pixel.

	THIS REPLACES MEASURING A PALM AS AN EXTREMITY, and the difference is not a refinement,
	it is the bug Louis reported as "the objects don't match the hand placement". The old
	rule took the moving pixel furthest from the centreline, which is only the hand when the
	arm is straight and pointing out. Fold the elbow - which is most of a juggling sweep -
	and the outermost moving pixel is a SLEEVE edge, with the hand hanging somewhere else
	entirely. Measured across all 624 candidates in the pool: the extremity sat a median of
	25 art px from the real hand, which at this density is FIFTY screen pixels. Every held
	prop, every catch glow and every tutorial key hangs off this point.

	A hand is found instead as the outermost sufficiently large blob of the performer's own
	skin inside the arm band. The band already excludes his face (see BAND), so the only
	skin below it is a hand; taking the outermost blob rather than the nearest-to-anything
	means this needs no prior guess to refine.

	Returns {"L": {...}, "R": {...}} with, per side, the palm centre in cell coordinates,
	the blob's extent, and how flat it is - or {} if either hand could not be found.
	`frame` must already be snapped to the body's palette."""
	h, w = frame.shape[:2]
	cx = (w - 1) * 0.5
	y0, y1 = band_rows(h)
	sk = skin_mask(frame[..., :3], skin_set, body_pal) & (frame[..., 3] > 127)
	sk[:y0] = False
	sk[y1:] = False
	lab, n = ndimage.label(sk, np.ones((3, 3)))
	out = {}
	for side in ("L", "R"):
		best, bx = None, -1.0
		for l in range(1, n + 1):
			ys, xs = np.where(lab == l)
			if len(ys) < HAND_MIN:
				continue
			mx = float(xs.mean())
			if (mx > cx) if side == "L" else (mx < cx):
				continue
			far = (cx - mx) if side == "L" else (mx - cx)
			if far > bx:
				bx, best = far, (xs, ys)
		if best is None:
			return {}
		xs, ys = best
		px, py = float(xs.mean()), float(ys.mean())
		bw = float(xs.max() - xs.min() + 1)
		bh = float(ys.max() - ys.min() + 1)
		out[side] = (px, py)
		# the blob itself, so split_layer can protect the fingers from its own thinning
		hm = np.zeros((h, w), bool)
		hm[ys, xs] = True
		out[side + "mask"] = hm
		out[side + "reach"] = abs(px - cx)
		out[side + "up"] = (h - 1 - py) / float(h - 1)
		# HOW FLAT THE HAND IS, which is how a palm-up hand is told from a hanging one
		# without asking a model what it painted. A hand held out to catch is a broad mass
		# with the fingers spread across it; a hand hanging palm-down from a wrist is a
		# narrow vertical one. Measured over the pool: median 0.52, and only 32 of 624
		# candidates come out wider than tall - which is the same finding as "no generation
		# ever painted an upturned palm", arrived at by measurement rather than by eye.
		out[side + "flat"] = bw / max(bh, 1.0)
		out[side + "px"] = len(xs)
	return out


def palms(frame: np.ndarray, static: np.ndarray) -> dict:
	"""This frame's two arm EXTREMITIES, found from what moved.

	Kept for the reach-only callers and for diagnostics. This is NOT where a hand is - see
	hands() for that, and for the fifty screen pixels of difference between the two."""
	mask = frame[..., 3] > 127
	h, w = mask.shape
	cx = (w - 1) * 0.5
	y0, y1 = band_rows(h)
	mv = mask & ~static
	mv[:y0] = False
	mv[y1:] = False
	# thin slivers along a jittering silhouette edge are not an arm: an arm is a limb, so it
	# survives being eroded and a one-pixel outline does not
	core = ndimage.binary_erosion(mv, np.ones((2, 2)))
	lab, n = ndimage.label(mv, np.ones((3, 3)))
	keep = [l for l in np.unique(lab[core]) if l and (lab == l).sum() >= 40]
	mv = np.isin(lab, keep)
	out = {}
	for side, sel in (("L", lambda xx: xx <= cx), ("R", lambda xx: xx >= cx)):
		ys, xs = np.where(mv)
		s = sel(xs)
		if not s.any():
			return {}
		ys, xs = ys[s], xs[s]
		ex = xs.min() if side == "L" else xs.max()
		near = np.abs(xs - ex) <= 2
		px, py = float(ex), float(np.median(ys[near]))
		out[side] = (px, py)
		out[side + "reach"] = abs(px - cx)
		out[side + "up"] = (h - 1 - py) / float(h - 1)
	return out


def _oklab(rgb: np.ndarray) -> np.ndarray:
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


# How far from the body's own colour a pixel must be before it counts as something drawn IN
# FRONT of the body rather than the body repainted. In Oklab, where 0.10 is a clearly
# different colour and 0.02 is two neighbouring palette entries.
DIFF_MIN = 0.10


def split_layer(frame: np.ndarray, side: str, body: np.ndarray, ref_pal,
		hand: tuple = None, hand_mask: np.ndarray = None) -> tuple:
	"""One side's ARM: only the pixels that differ from the body underneath.

	THE FIRST VERSION TOOK THE WHOLE HALF-BAND, torso and all, and that shipped a performer
	CUT IN HALF (Louis, 2026-08-07). The reasoning was that a subtractive mask severs an arm -
	at close reach the sleeve lies flat on the coat, so most of the limb is opaque in every
	frame and "the pixels that moved" keeps only the hand. True, and it does not matter: the
	severed pixels are severed precisely because they are IDENTICAL to the coat beneath them,
	and the body draws that coat. Dropping them changes nothing on screen.
	
	What taking the whole half-band DID do is put half a torso in every layer - and the two
	arms are chosen independently, from different generations, so the man got generation A's
	lapel on one side and generation B's on the other, meeting down the centreline. There is
	no offset that fixes that; the layers simply must not carry a torso.

	So an arm is: opaque here, and either the body is transparent here (it is outside the
	silhouette - a real reach) or the colour differs from the body's (a sleeve shading the
	coat, a hand over the vest). Snapped to the body's own palette FIRST, so generation-to-
	generation colour drift snaps onto the same entry and reads as "no difference" instead of
	as a torso-shaped arm.

	AN ARM IS THE LIMB THE HAND IS ON, AND NOTHING ELSE. Selecting "every blob that leaves
	the silhouette" was tried and looks reasonable right up until you draw one: the tailcoat
	swings a few pixels between frames, so its front piping and the shirt behind it leave the
	median body's silhouette in almost every frame, and each layer came out as a good arm
	with a loose gold stripe and a scrap of bow tie floating beside it. On stage that is a
	dark streak in mid-air next to the performer. The hand is the one part of an arm that is
	certainly an arm, so the limb is grown FROM it: close the mask by a pixel to bridge a
	cuff, then keep the connected component the hand sits in.

	AND "DIFFERS" IS A PERCEPTUAL TEST, NOT A BYTEWISE ONE - which is the whole of the
	2026-08-08 fix. `frame != body` fires on a single palette step, and the body is a MEDIAN
	across frames, so a coat pixel that landed one entry away in this particular frame read
	as "arm". Measured over the pool that admitted 61% of every layer as torso: the two arms
	are picked independently, so the man wore one frame's lapel on his left and another
	frame's on his right, and the shirt, bowtie and frogging changed as his hands moved.
	That is exactly what Louis saw as "the left and right side don't match when he's
	juggling", and it survived the previous fix because that fix changed WHICH pixels were
	compared without changing HOW.

	A COMPONENT ALSO HAS TO BE PART OF THE ARM. Even at a perceptual threshold, a repainted
	waistcoat button is a legitimate difference - it is just not a limb. So the surviving
	blobs are filtered to those that either reach OUTSIDE the body's silhouette (a real
	extension into open air) or contain the HAND, which is the one part of an arm that is
	certainly an arm even when it is entirely in front of the coat. A chest that has been
	repainted a shade darker touches neither and is dropped, and the body draws it anyway.

	`frame` and `body` must already be in the SAME coordinates - see gather()."""
	h, w = body.shape[:2]
	cx = (w - 1) * 0.5
	y0, y1 = band_rows(h)
	fa = frame[..., 3] > 127
	ba = body[..., 3] > 0
	differs = np.linalg.norm(_oklab(frame[..., :3].astype(float))
							 - _oklab(body[..., :3].astype(float)), axis=-1) > DIFF_MIN
	arm = fa & (~ba | differs)
	arm[:y0] = False
	arm[y1:] = False
	xs = np.arange(w)
	arm &= ((xs <= cx) if side == "L" else (xs > cx))[None, :]
	if hand is None:
		return np.zeros((0, 0, 4), np.uint8), 0, 0
	hx, hy = int(round(hand[0])), int(round(hand[1]))
	if not (0 <= hy < h and 0 <= hx < w):
		return np.zeros((0, 0, 4), np.uint8), 0, 0
	# NOT CLOSED FIRST, and that was worth one wrong turn: a 3x3 closing bridges the sleeve
	# to the coat front it is lying against, so the "limb" came back as the arm plus the
	# whole waistcoat, frogging and shirt in one component - more torso than the rule it
	# replaced. Eight-connectivity on the raw mask already keeps a sleeve whole.
	#
	# OPENED, THOUGH, BECAUSE A LIMB IS THICK AND THE COAT'S PIPING IS NOT. The sleeve meets
	# the lapel at the shoulder, so they are legitimately one component - and the gold
	# stripe down the coat front came along with every arm, trailing off the hand as a thin
	# dark streak in mid-air. A 2x2 erosion deletes anything one pixel wide and leaves a
	# forearm untouched, so the limb is grown from the eroded CORE and the thin stuff never
	# joins. The hand is unioned back in unconditionally: fingers are one pixel wide too,
	# and they are the one thin thing that has to survive.
	lab, _ = ndimage.label(arm, np.ones((3, 3)))
	limb = lab[hy, hx]
	if not limb:
		ys, xs = np.where(lab > 0)
		if xs.size == 0:
			return np.zeros((0, 0, 4), np.uint8), 0, 0
		i = int(np.argmin((xs - hx) ** 2 + (ys - hy) ** 2))
		limb = lab[ys[i], xs[i]]
	whole = lab == limb
	# THE THINNING IS APPLIED INSIDE THE LIMB, AND KEEPS EVERY THICK PART OF IT - not only
	# the part the hand happens to sit in. Taking the single eroded core under the hand
	# looked equivalent and was not: an erosion also severs the narrow bridge at the
	# SHOULDER, so the upper arm became its own core, was discarded, and the performer
	# juggled with two forearms floating in the air beside a coat. Everything an erosion
	# leaves is a limb; everything it deletes is piping.
	core = ndimage.binary_erosion(whole, np.ones((2, 2)))
	arm = ndimage.binary_dilation(core, np.ones((3, 3))) & whole
	if hand_mask is not None:
		arm |= hand_mask & whole
	# a limb survives being eroded; a one-pixel rim of dither noise along an edge does not
	if int(arm.sum()) < 25:
		return np.zeros((0, 0, 4), np.uint8), 0, 0
	ys, xx = np.where(arm)
	if xx.size == 0:
		return np.zeros((0, 0, 4), np.uint8), 0, 0
	ax0, ax1, ay0, ay1 = int(xx.min()), int(xx.max()), int(ys.min()), int(ys.max())
	sub = np.zeros((ay1 - ay0 + 1, ax1 - ax0 + 1, 4), np.uint8)
	k = arm[ay0:ay1 + 1, ax0:ax1 + 1]
	f = frame[ay0:ay1 + 1, ax0:ax1 + 1]
	sub[k] = np.dstack([f[..., :3], np.full(f.shape[:2], 255)])[k].astype(np.uint8)
	return sub, ax0, ay0


def place_into(frame: np.ndarray, dx: int, dy: int, shape: tuple) -> np.ndarray:
	"""This generation's frame, shifted into the REFERENCE body's coordinates."""
	out = np.zeros((shape[0], shape[1], 4), dtype=frame.dtype)
	sy0, sx0 = max(0, -dy), max(0, -dx)
	dy0, dx0 = max(0, dy), max(0, dx)
	hh = min(frame.shape[0] - sy0, shape[0] - dy0)
	ww = min(frame.shape[1] - sx0, shape[1] - dx0)
	if hh > 0 and ww > 0:
		out[dy0:dy0 + hh, dx0:dx0 + ww] = frame[sy0:sy0 + hh, sx0:sx0 + ww]
	return out


def mirror_about(layer: np.ndarray, x0: int, axis: float) -> tuple[np.ndarray, float]:
	"""The same arm on the other side, reflected in the BODY'S OWN centreline.

	The axis is not negotiable and getting it wrong is how the first version put a floating
	second half-a-man beside the figure: a layer's x0 has already been translated into the
	reference body's coordinates, so reflecting it about its own SOURCE cell's width mixes
	two coordinate systems and lands the result tens of pixels away. Mirroring is worth
	having - the showman's coat is symmetric inside the arm band, so a left arm flipped is a
	perfectly good right arm, and it doubles what every generation is worth - but only about
	the one axis both sides actually share.

	Returns (flipped layer, its new left edge). A point at x maps to 2*axis - x, so the span
	[x0, x0+w) maps to [2*axis - x0 - w, 2*axis - x0)."""
	return layer[:, ::-1], 2.0 * axis - x0 - layer.shape[1]
