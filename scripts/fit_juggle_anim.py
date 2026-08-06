#!/usr/bin/env python3
"""Turn a generated juggling animation into a strip the game indexes by HAND POSITION.

THE PROBLEM (2026-08-06, Louis: "please do generate a custom juggling animation with
pixellab ... these old overlapping arms look awful").

The arms were solved live: draw_arm ran a two-bone IK from the shoulder to wherever the hand
was that frame. That is why they never desynced from the physics - and also why they looked
like two sausages crossing each other, because a two-bone solve with a fixed elbow bow has
no idea what a juggler's arm does. A painted animation knows.

But an animation is a fixed set of poses, and the hands are the MECHANIC: outer_pos and
inner_pos are where a catch and a throw happen and the PLAYER decides when. So the two
cannot both be authoritative, and a loop played on a clock drifts against the throws within
seconds of real play.

THE STRIP IS INDEXED BY THE HANDS, NOT BY A CLOCK. Every frame is measured for where its
hands are; the game picks the frame whose hands best match the hands the simulation already
has (fig_anim_pick in Game.gd). There is no phase to keep in sync because there is no
phase - there is a lookup, and the player's own throws drive the picture.

FINDING THE HANDS WITHOUT COLOUR, which took three attempts. The hands are skin, so the
obvious move is to look for skin - and it fails twice over. A tolerant match also catches
the ringmaster's GOLD FROGGING, whose colour sits right beside skin (skin [242,204,140] and
[152,96,56]; trim [176,136,72]), and it reported the boots as hands on eight frames out of
seventeen. An exact palette match fails differently and worse: animate_image does NOT force
the source palette, so the generated frames use their own slightly-shifted skin tones and
only 4 of 17 frames matched at all.

What works is geometry. In the arm band - below the head, above the coat hem - the WIDEST
ROW of the silhouette is the row the hands are on, and its two ends are the two hands. No
colour, no palette assumption, no clustering. It gives a clean monotone sweep on the real
animation (spread 0.97 down to 0.00 and back to 1.00) and the hand x positions come out of
the same measurement for free.

ONLY THE FRAMES THAT FIT THE GAME ARE KEPT. The generated arms reach further than the
juggler's hands ever go: measured, the art spans 56..152 screen px from the centreline while
outer_pos is 100 and inner_pos is 54. Mapping the whole sweep onto the game's range would
put the drawn hand 50px outside the ball it is supposed to be catching. So the strip is
trimmed to the frames whose hands fall inside the game's own reach, and the widest, most
theatrical poses are simply dropped. A catch that lands in the palm beats a bigger gesture.

USAGE
  .venv/bin/python scripts/fit_juggle_anim.py cascade artifacts/chargen/anim_cascade
  .venv/bin/python scripts/fit_juggle_anim.py cascade artifacts/chargen/anim_cascade --write
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

import artguard

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Assets" / "Characters" / "showman"

# The arm band, as fractions of the figure's ink height measured from the TOP: below the
# chin, above the boots. It can be generous now that the hands are found from MOTION rather
# than from silhouette width - see moving_mask - because a coat that does not move is not a
# candidate however wide it is.
BAND = (0.18, 0.72)

# The game's own hand reach, in ART pixels from the figure's centreline. outer_pos is 100
# screen px and inner_pos 54, and ART_PIXEL is 2. A frame whose hands fall outside this is
# a pose the juggler never actually strikes, so it is dropped rather than squeezed in.
GAME_INNER = 27.0
GAME_OUTER = 50.0
REACH_SLACK = 6.0     # art px of tolerance at each end, so a near-miss frame still counts

# THE HAND LINE, as a fraction of the figure's height measured UP FROM THE FEET. stage_center
# puts it at s.y * 0.57 with the floor at s.y * 0.80, so it sits 165.6 screen px above the
# boards - almost exactly HALF the figure's own height, which is the hip on the eight-head
# canon and is why the game's comment calls it the waist.
#
# THIS IS CHECKED, because getting it wrong is invisible in the art and obvious in play. The
# first pass generated a perfectly good juggling animation whose hands were at CHEST height
# (58-72% up), and the reach numbers all looked fine because reach is horizontal - so the
# strip was accepted, and in game the man waved his hands around his lapels while the catch
# rings sat empty at his hips. A vertical mismatch cannot be fixed by scaling either: the
# figure would have to shrink by a sixth, and a fractional scale is mush.
GAME_HAND_UP = 0.505
HAND_UP_SLACK = 0.09


def load_frames(src: Path) -> list[np.ndarray]:
	if src.is_dir():
		return [np.asarray(Image.open(p).convert("RGBA")).astype(int)
				for p in sorted(src.glob("*.png"))]
	im = Image.open(src)
	n = getattr(im, "n_frames", 1)
	if n > 1:
		out = []
		for i in range(n):
			im.seek(i)
			out.append(np.asarray(im.convert("RGBA")).astype(int))
		return out
	return [np.asarray(im.convert("RGBA")).astype(int)]


def moving_mask(masks: list[np.ndarray]) -> np.ndarray:
	"""Pixels that are NOT opaque in every frame - i.e. the arms and hands.

	THE THIRD DETECTION METHOD, and the one that holds. Colour failed (the gold frogging
	sits beside skin, and the generated frames are not palette-locked). "Widest row in the
	arm band" failed too, in two different ways: run the band down to the hips and the
	COAT HEM is wider than any reach, so his hands measure at his knees; stop the band above
	the hem and the coat's SHOULDERS are wider than the hands whenever the arms tuck in, so
	every frame reports the same row and the reach stops varying at all.

	What separates arms from coat is not where they are or what colour they are - it is that
	THE ARMS MOVE. Everything opaque in every single frame is the body: torso, legs, head,
	the hanging coat. Whatever is left in a given frame is that frame's arms."""
	static = masks[0].copy()
	for m in masks[1:]:
		static &= m
	return static


def hands_from_moving(mask: np.ndarray, static: np.ndarray, y0: int, y1: int
					  ) -> tuple[int, int, int, int]:
	"""The two extremes of this frame's moving pixels: the left hand and the right hand."""
	mv = mask & ~static
	mv[:y0] = False
	mv[y1:] = False
	ys, xs = np.where(mv)
	if xs.size == 0:
		return 0, 0, 0, y0
	lx, rx = int(xs.min()), int(xs.max())
	# the hand ROW is where the moving pixels are furthest out, not their average height -
	# an arm is moving along its whole length and only its end is the hand
	edge = ys[(xs <= lx + 2) | (xs >= rx - 2)]
	hy = int(np.median(edge)) if edge.size else y0
	return lx, rx, rx - lx + 1, hy


def main() -> int:
	args = [a for a in sys.argv[1:] if not a.startswith("--")]
	if len(args) < 2:
		print(__doc__)
		return 2
	name, src = args[0], Path(args[1])
	write = "--write" in sys.argv
	force = "--force" in sys.argv
	keep_all = "--all" in sys.argv

	frames = load_frames(src)
	if not frames:
		raise SystemExit(f"{src}: no frames")

	# ONE COMMON CROP for every frame, so the figure cannot jitter between them. Cropping
	# each frame to its own bounds would recentre the body every time an arm moved, which
	# reads as the whole man twitching rather than as his arms working.
	union = np.zeros(frames[0].shape[:2], dtype=bool)
	for f in frames:
		union |= f[..., 3] > 127
	ys, xs = np.where(union)
	y0, y1, x0, x1 = int(ys.min()), int(ys.max()), int(xs.min()), int(xs.max())
	cells = [f[y0:y1 + 1, x0:x1 + 1] for f in frames]
	h, w = cells[0].shape[:2]
	cx = (w - 1) * 0.5
	by0, by1 = int(h * BAND[0]), int(h * BAND[1])

	masks = [c[..., 3] > 127 for c in cells]
	static = moving_mask(masks)
	rows = []
	for i, c in enumerate(cells):
		lx, rx, ww, hy = hands_from_moving(masks[i], static, by0, by1)
		reach = ((cx - lx) + (rx - cx)) * 0.5
		up = (h - 1 - hy) / float(h - 1)      # height of the hands above the feet
		rows.append({"i": i, "lx": lx, "rx": rx, "w": ww, "reach": reach, "up": up})

	lo, hi = GAME_INNER - REACH_SLACK, GAME_OUTER + REACH_SLACK
	kept = [r for r in rows if lo <= r["reach"] <= hi] if not keep_all else rows
	for r in rows:
		mark = "keep" if r in kept else " -- outside the game's reach, dropped"
		print(f"  f{r['i']:02d} hands x {r['lx']:3d}..{r['rx']:3d}  reach {r['reach']:5.1f}"
			  f"  hands {r['up'] * 100:4.1f}% up  {mark}")

	# THE VERTICAL CHECK. Reach is horizontal and says nothing about height, so a strip can
	# pass every other test here and still be unusable - see GAME_HAND_UP.
	if kept:
		mean_up = sum(r["up"] for r in kept) / len(kept)
		off = mean_up - GAME_HAND_UP
		print(f"\n  hand line: art {mean_up * 100:.1f}% up, game wants {GAME_HAND_UP * 100:.1f}%"
			  f"  (off by {off * 100:+.1f} points)")
		if abs(off) > HAND_UP_SLACK:
			where = "TOO HIGH - the hands are up at the chest" if off > 0 else "TOO LOW"
			print(f"  *** {where}. In game the catch rings will sit empty while he waves")
			print(f"  *** somewhere else. Re-generate with the hand height stated in the")
			print(f"  *** action description; this cannot be fixed by scaling the figure.")
	if len(kept) < 4:
		raise SystemExit(f"only {len(kept)} frame(s) inside the game's reach - "
						 f"re-generate with a tighter action, or pass --all to inspect")

	# ORDER BY REACH, not by time. The game does a lookup on hand position, so what it needs
	# is a table sorted by the thing it looks up. It also makes the strip readable: frame 0
	# is hands in, the last frame is hands out.
	kept.sort(key=lambda r: r["reach"])
	strip = np.concatenate([cells[r["i"]] for r in kept], axis=1)
	meta = {
		"frames": len(kept),
		"cell_w": int(w), "cell_h": int(h),
		"source_index": [int(r["i"]) for r in kept],
		# hand positions as ART PIXELS FROM THE CENTRELINE, positive outward, so the game
		# can compare them directly against its own |hand.x - cx| without knowing anything
		# about how the sprite was cropped.
		"reach": [round(float(r["reach"]), 2) for r in kept],
	}
	print(f"\n{name}: kept {len(kept)}/{len(rows)} frames, cell {w}x{h}, "
		  f"reach {meta['reach'][0]:.1f}..{meta['reach'][-1]:.1f} art px")
	if not write:
		print("(pass --write to apply)")
		return 0
	OUT.mkdir(parents=True, exist_ok=True)
	status = artguard.save_guarded(OUT / f"juggle_{name}.png",
		lambda q: Image.fromarray(strip.astype(np.uint8), "RGBA").save(q), force)
	(OUT / f"juggle_{name}.json").write_text(json.dumps(meta, indent=2) + "\n")
	print(f"wrote {w}x{h} x{len(kept)}  [{status}]")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
