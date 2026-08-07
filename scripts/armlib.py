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
	coat."""
	top, neck = head_rows(body[..., 3] > 0)
	head = body[top:neck + 1]
	sel = head[..., 3] > 0
	return np.unique(head[sel][:, :3], axis=0) if sel.any() else np.zeros((0, 3), np.uint8)


def palms(frame: np.ndarray, static: np.ndarray) -> dict:
	"""This frame's two palms, found from what MOVED.

	Returns {"L": (x, y), "R": (x, y), "lr": reach_left, "rr": reach_right, "up": ...} in the
	cell's own pixel coordinates, or {} if either side had nothing to measure.

	A palm is the moving pixel furthest from the centreline on its own side. The frame's arm
	may well continue inward under the coat - that part is invisible to this measurement and
	does not matter, because what has to line up with a thrown prop is the HAND."""
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


def split_layer(frame: np.ndarray, side: str) -> tuple[np.ndarray, int, int]:
	"""One side's ARM LAYER: the frame's whole half of the arm band.

	DELIBERATELY GENEROUS, and that is the design rather than laziness. The obvious layer is
	"the pixels that moved", and it severs the arms: at the innermost reach the sleeve lies
	flat against the coat, so most of the limb is opaque in every frame and a subtractive mask
	keeps only the hand, leaving it floating in the air with no arm attached to it.

	Taking the entire half-band instead cannot sever anything. It costs nothing either: the
	half a torso that comes along is drawn over a body whose torso is the MEDIAN of the same
	pixels, so it lands on top of itself. The seam runs down the centreline, where the vest
	and bow tie are identical in every frame, and the band stops above the coat hem and below
	the chin, so the two halves never disagree about anything a viewer can see.

	Returns (RGBA layer cropped to its own ink, x offset, y offset in the cell)."""
	h, w = frame.shape[:2]
	cx = (w - 1) * 0.5
	y0, y1 = band_rows(h)
	keep = np.zeros((h, w), dtype=bool)
	xs = np.arange(w)
	col = (xs <= cx) if side == "L" else (xs > cx)
	keep[y0:y1, :] = col[None, :]
	keep &= frame[..., 3] > 127
	ys, xx = np.where(keep)
	if xx.size == 0:
		return np.zeros((0, 0, 4), np.uint8), 0, 0
	ax0, ax1, ay0, ay1 = int(xx.min()), int(xx.max()), int(ys.min()), int(ys.max())
	sub = np.zeros((ay1 - ay0 + 1, ax1 - ax0 + 1, 4), np.uint8)
	k = keep[ay0:ay1 + 1, ax0:ax1 + 1]
	f = frame[ay0:ay1 + 1, ax0:ax1 + 1]
	sub[k] = np.dstack([f[..., :3], np.full(f.shape[:2], 255)])[k].astype(np.uint8)
	return sub, ax0, ay0


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
