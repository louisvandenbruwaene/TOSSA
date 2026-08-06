#!/usr/bin/env python3
"""Fit a GENERATED juggler to the game's skeleton, and take his arms off.

WHY THE ARMS COME OFF, which is the whole design (2026-08-06, Louis: "these character
designs should be generated with pixellab and then modified such that the hands fit, but
for example the very long arms aren't needed, make the look more natural").

The hand positions are the MECHANIC. outer_pos and inner_pos are where a catch and a throw
happen, the catch windows are measured against them, and the whole choreography of every
pattern is written in those two points - so they do not move for a costume. The arms,
though, are not art at all: draw_arm solves a two-bone IK from the shoulder to wherever the
hand is THIS FRAME, and a hand moves continuously. A generated figure with its arms painted
on would freeze them, and the juggler would catch with his elbows.

So this cuts the arms off the generated figure and hands the game a shoulder point instead.
The game draws the arms, in the design's own sleeve colour, from that point to the hands it
already had. Nothing about catching changes.

AND THAT IS ALSO HOW THE ARMS GET SHORTER. They are long today because the shoulders are
narrow (0.9 head units out) and the hands are 2.5 head units out, so each arm spans most of
a head unit and a half of empty air. A design with BROAD shoulders makes the same hand
position a shorter reach, with no change to the mechanic at all. Arm length is a
consequence of the body, which is why it was worth generating whole new bodies rather than
adding a length slider.

HOW THE ARMS ARE FOUND. A T-pose figure is a narrow column with a wide band across it: the
median row width is the body, and rows more than ARM_FACTOR times that are the arm band.
The band is then EXTENDED down past the taper (see below), and inside it only the pixels in
the BODY CORRIDOR are kept. Measured on the three 2026-08-06 designs: body widths 44, 56 and
28 against arm-band widths 150, 152 and 131, so the separation is not marginal.

WHAT COMES OUT
  <name>.png     the figure with its arms removed, at its own native size - NEVER resampled
  <name>.json    landmarks as fractions of the figure's own ink height, plus the colours
                 the procedural arms must be drawn in to match the painting

NOTHING IS RESAMPLED, and that is deliberate. The obvious move is to scale the generated
figure to the traced one's exact head unit, but that lands on a ~1.02 factor, and a 2%
resample of pixel art smears every edge it has. The game reads the height back off the
sprite instead and lays the figure out from that, so a design is drawn at exactly
ART_PIXEL screen pixels per art pixel and is 1-2% shorter or taller than the traced
juggler. Nobody can see 2%; everybody can see a smeared outline.

USAGE
  .venv/bin/python scripts/fit_char_design.py natural showman acrobat
  .venv/bin/python scripts/fit_char_design.py --write [--force]
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

import artguard

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "artifacts" / "chargen"
VARIANTS = ROOT / "Assets" / "Variants"

ARM_FACTOR = 1.8     # a row this much wider than the median body row is arm
CORRIDOR_PAD = 3     # art px of slack each side, so a shoulder slopes instead of shearing


def centre_run(mask: np.ndarray, y: int, mid: int) -> tuple[int, int]:
	"""The run of opaque pixels on row y that contains column `mid` - i.e. the torso,
	with the arms either side of it excluded because they are separate runs."""
	row = mask[y]
	if not row.any():
		return (mid, mid)
	m = int(np.clip(mid, 0, row.size - 1))
	if not row[m]:                                  # centre falls in a gap (an open coat)
		near = np.where(row)[0]
		m = int(near[np.argmin(np.abs(near - m))])
	lo = m
	while lo > 0 and row[lo - 1]:
		lo -= 1
	hi = m
	while hi < row.size - 1 and row[hi + 1]:
		hi += 1
	return (lo, hi)


def rows_extent(mask: np.ndarray) -> np.ndarray:
	out = np.zeros((mask.shape[0], 3), dtype=int)
	for y in range(mask.shape[0]):
		xs = np.where(mask[y])[0]
		out[y] = (xs.min(), xs.max(), xs.size) if xs.size else (0, 0, 0)
	return out


def fit(name: str) -> tuple[np.ndarray, dict]:
	im = Image.open(SRC / f"{name}.png").convert("RGBA")
	a = np.asarray(im).astype(int)
	mask = a[..., 3] > 127
	ys, xs = np.where(mask)
	y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
	a = a[y0:y1 + 1, x0:x1 + 1]
	mask = mask[y0:y1 + 1, x0:x1 + 1]
	h, w = mask.shape

	ext = rows_extent(mask)
	widths = ext[:, 2]
	med = float(np.median(widths[widths > 0]))
	arm_rows = np.where(widths > med * ARM_FACTOR)[0]
	if arm_rows.size == 0:
		raise SystemExit(f"{name}: found no arm band - is this a T-pose?")
	a_top, a_bot = int(arm_rows.min()), int(arm_rows.max())

	# THE BAND HAS TO BE EXTENDED DOWNWARD, because a T-pose arm TAPERS. The width
	# threshold finds the shoulders and the upper arm fine, but by the wrist the row is no
	# longer 1.8x the body and the band stops - leaving the forearms and hands attached.
	# Measured on the 2026-08-06 designs: the band ended at row 44 of 'natural' while the
	# arms ran to 52. Keep walking down while a row still has significant ink OUTSIDE its
	# own central run, which is true exactly while there is still an arm on it.
	centre_col = int(np.median(np.where(mask[a_bot])[0]))
	while a_bot + 1 < h:
		r0, r1 = centre_run(mask, a_bot + 1, centre_col)
		if int(widths[a_bot + 1]) <= (r1 - r0 + 1) + 4:
			break
		a_bot += 1

	# THE BODY CORRIDOR, from the torso's OWN RUN just below the arms - not from the row's
	# full extent. That distinction is the bug that made the first two attempts wrong: a
	# row's min and max x include any stray arm pixel still on it, so the corridor came out
	# 86 art px wide on a figure whose chest is 34, and the "arm removal" then kept the
	# arms. A centre run cannot do that, because an arm is a separate run.
	runs = [centre_run(mask, y, centre_col) for y in range(a_bot + 1, min(a_bot + 9, h))
			if mask[y].any()]
	if not runs:
		raise SystemExit(f"{name}: no torso under the arm band")
	c0 = min(r[0] for r in runs) - CORRIDOR_PAD
	c1 = max(r[1] for r in runs) + CORRIDOR_PAD

	# THE SHOULDER JOINT IS NOT THE CORRIDOR EDGE, and reading it as one is a mistake worth
	# recording because the number looks plausible until you draw an arm from it. The
	# corridor is measured under the armpit, where a tailcoat is at its WIDEST - so on the
	# 'natural' design it came out 0.267 of figure height, putting the shoulder 85px from
	# the centreline with the hand at 100. The arms became 15px stubs.
	#
	# The joint is where the arm leaves the TORSO, at the TOP of the arm band. Inside that
	# band the torso is the run of pixels containing the centre column and the arms are the
	# runs either side of it, so taking the central run at a_top measures the shoulders
	# themselves with the arms excluded - which is the width a sleeve should start at.
	mid_col = (c0 + c1) // 2
	# ...and the shoulder joint is that corridor's own edge. Taking the CENTRE RUN at the
	# shoulder row instead does not work and is worth saying why: in a T-pose the arms are
	# CONNECTED to the shoulders, so at that row the torso and both arms are one run and
	# the "torso width" comes back as the whole span - 0.463 of figure height on the
	# showman, which would put his shoulders further out than his hands.
	sh_dx = (c1 - c0 + 1) * 0.5

	# SAMPLE THE SLEEVE before cutting, from the arm pixels just outside the corridor at
	# the shoulder. The game draws the arms itself, so it needs the colour the painting
	# would have used - a procedural sleeve in the wrong colour is worse than no design.
	sleeve = sample_arm_colour(a, mask, a_top, a_bot, c0, c1)

	out = a.copy()
	cut = np.zeros_like(mask)
	cut[a_top:a_bot + 1, :] = True
	cut[:, max(c0, 0):min(c1 + 1, w)] = False
	out[cut] = 0

	# KEEP ONLY WHAT IS STILL ATTACHED TO THE BODY. The band cut alone leaves debris: a
	# hand or a fingertip that happens to sit a row or two outside a_top..a_bot survives as
	# a little island of skin floating beside the figure, and on all three of the
	# 2026-08-06 designs it did. Row arithmetic cannot see that, because the thing that
	# makes it wrong is not WHERE it is but that it is no longer joined to anything.
	# The largest 8-connected component is the body by a wide margin.
	from scipy.ndimage import label
	keep = out[..., 3] > 0
	lab, n = label(keep, structure=np.ones((3, 3), dtype=int))
	if n > 1:
		sizes = np.bincount(lab.ravel())
		sizes[0] = 0
		out[lab != int(np.argmax(sizes))] = 0

	# ...then tighten the canvas to what is left, so the sprite carries no dead margin and
	# the metadata below is measured against the real figure.
	ys2, xs2 = np.where(out[..., 3] > 0)
	ty0, ty1, tx0, tx1 = ys2.min(), ys2.max(), xs2.min(), xs2.max()
	out = out[ty0:ty1 + 1, tx0:tx1 + 1]
	a_top -= int(ty0)
	a_bot -= int(ty0)
	c0 -= int(tx0)
	c1 -= int(tx0)
	h, w = out.shape[0], out.shape[1]
	head_bottom = a_top

	# THE HEAD, so the wardrobe still has somewhere to put a hat. A design cannot wear the
	# costume (it is painted) but it CAN wear a crown, and the tailor is the screen a player
	# opens to try things on - a mirror that says "trying it on" while nothing appears on
	# his head is just broken. The head is everything above the arm band; its radius is
	# taken from the WIDER of its two axes so a hat brim clears the hair either way.
	# THE HEAD ENDS AT THE NECK, not at the arm band. Taking everything above the band gave
	# the showman a radius of 0.207 of his own height - a head twice the size of the one he
	# has - because his collar and lapels sit above the shoulder line and are wider than his
	# skull. The neck is the NARROWEST row between the crown and the shoulders, which is
	# true of every human silhouette and is what separates the two.
	hw_rows = [(y, centre_run(mask, y, mid_col)) for y in range(0, a_top) if mask[y].any()]
	if hw_rows:
		hy0 = hw_rows[0][0]
		lower = [(y, r[1] - r[0] + 1) for y, r in hw_rows if y > hy0 + (a_top - hy0) * 0.4]
		neck = min(lower, key=lambda t: t[1])[0] if lower else a_top
		crown = [r[1] - r[0] + 1 for y, r in hw_rows if y <= neck]
		hw = max(crown) if crown else (a_top - hy0)
		head_h = neck - hy0
		head_cy = (hy0 + neck) * 0.5
		head_r = max(hw, head_h) * 0.5
	else:
		head_cy, head_r = a_top * 0.5, a_top * 0.5
	head_bottom = a_top
	meta = {
		"height_art": int(h),
		"width_art": int(w),
		"head_bottom": round(head_bottom / h, 4),
		"head_cy": round(head_cy / h, 4),
		"head_r": round(head_r / h, 4),
		"shoulder_y": round((a_top + 1) / h, 4),
		"shoulder_dx": round(sh_dx / h, 4),
		"corridor": [int(max(c0, 0)), int(min(c1, w - 1))],
		"sleeve": sleeve,
	}
	return out.astype(np.uint8), meta


def sample_arm_colour(a: np.ndarray, mask: np.ndarray, a_top: int, a_bot: int,
                      c0: int, c1: int) -> dict:
	"""The painting's own sleeve and cuff, so the procedural arms match the design."""
	band = slice(a_top, min(a_bot + 1, mask.shape[0]))
	sel = np.zeros_like(mask)
	sel[band, :] = mask[band, :]
	sel[:, max(c0, 0):c1 + 1] = False
	if not sel.any():
		return {"sleeve": [128, 128, 128], "cuff": [200, 200, 200]}
	cols = a[sel][:, :3]
	xs = np.where(sel)[1]
	mid = (c0 + c1) * 0.5
	dist = np.abs(xs - mid)
	# the SLEEVE is the inner two-thirds of the arm (upper arm and forearm); the CUFF is
	# the outermost few pixels, which on a tailcoat is the shirt showing at the wrist
	inner = dist <= np.percentile(dist, 66)
	outer = dist >= np.percentile(dist, 90)
	sleeve = np.median(cols[inner], axis=0) if inner.any() else np.median(cols, axis=0)
	cuff = np.median(cols[outer], axis=0) if outer.any() else sleeve
	return {"sleeve": [int(v) for v in sleeve], "cuff": [int(v) for v in cuff]}


def main() -> int:
	write = "--write" in sys.argv
	force = "--force" in sys.argv
	names = [a for a in sys.argv[1:] if not a.startswith("--")]
	if not names:
		names = sorted(p.stem for p in SRC.glob("*.png"))
	for name in names:
		out, meta = fit(name)
		msg = (f"{name:9} {meta['width_art']:3}x{meta['height_art']:<3}  "
		       f"shoulder y={meta['shoulder_y']:.3f} dx={meta['shoulder_dx']:.3f}  "
		       f"sleeve {meta['sleeve']['sleeve']}")
		if not write:
			print(msg + "   (report only)")
			continue
		d = VARIANTS / f"character_{name}"
		d.mkdir(parents=True, exist_ok=True)
		status = artguard.save_guarded(d / "figure.png",
			lambda q: Image.fromarray(out, "RGBA").save(q), force)
		(d / "figure.json").write_text(json.dumps(meta, indent=2) + "\n")
		print(msg + f"  [{status}]")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
