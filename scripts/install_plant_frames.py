#!/usr/bin/env python3
"""Install the goal stem's growth animation from artifacts/plant/.

WHAT THIS IS (2026-08-19, Louis: "the entire flower and its growing animation should be
animated by pixellab, you then just take frames from it ... try to get as many frames as you
need, like many (40 or something), because you need them for the final product to look
smooth when going from one subgoal to another").

The stem used to be assembled by the game: a stalk rect, two lens leaves, two flower-head
sprites hung off it at fixed offsets, and a bud. That composes, but it does not GROW - each
part popped into existence at its own threshold, so the plant advanced in five visible steps
across a whole act. What replaces it is one painted growth cycle: the plant is a single
sprite per frame and the meter picks the frame from its own fill.

HOW THE FRAMES WERE MADE, because the count matters and one call cannot give it.
`animate_image` caps at 16 frames, so a single pass over the whole growth is a 6% step per
frame - visibly steppy on a bar the player watches for a full act. The cycle is therefore
built in two passes:

  1. one interpolation, seedling -> full plant, 16 frames. That establishes the WHOLE arc:
     what grows when, where the leaves land, when the bud rises and opens.
  2. three more interpolations between frames taken OUT of that first pass (0->6, 6->11,
     11->16), each 16 frames. Because every endpoint is a frame the model itself drew, the
     three segments cannot drift apart the way three independent generations would.

THE SEEDLING IS DERIVED FROM THE FULL PLANT, NOT GENERATED. Both ends of an interpolation
have to be the same plant or the model spends its frames morphing one design into another
instead of growing one. Masking everything above the lowest 14 rows of the finished plant
gives a start frame that shares its stalk, its width and its exact palette.

AND THE PALETTE IS WHY THE STALK IS A RE-ROLL. The locked 48 has five greens, all
light-to-mid, and no dark green at all - so asked to shade a stalk the model reaches for
BROWN, and the first full plant came back with a brown stem and brown leaves. Saying "bright
grass green, absolutely no brown anywhere" fixed it. Expect to say that again after any
re-roll; it is the palette's warm bias, not the prompt being unclear.

USAGE
  .venv/bin/python scripts/install_plant_frames.py           preview
  .venv/bin/python scripts/install_plant_frames.py --write
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

import artguard
from install_vignettes import off_palette, snap_palette

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "artifacts" / "plant"
OUT = ROOT / "Assets" / "UI" / "flower"

# The three densifying segments, in growth order, as (job-stem, drop-first-frame).
# Each segment's first frame IS the previous segment's last, so all but the first drop it.
# GROWTH ORDER, AND IT IS THE WHOLE POINT (2026-08-19, Louis: "small flower grows a
# subflower, grows another subflower, continues growing stalk, grows top bud, blooms top
# bud; i wouldn't want a top bud, when the subflowers still have to grow").
# That is the order the meter MEANS - a subgoal falls before the goal does - and it cannot
# be got by reordering frames, because a frame carries the whole plant. It needs KEYFRAMES
# to interpolate through, one per beat, and two of them do not exist as generations:
#   K1  one side flower open, no top bud
#   K2  both side flowers open, no top bud
#   K3  taller stalk, closed top bud            (artifacts/paint/plant_mid2.png)
#   K4  full bloom                              (artifacts/paint/plant_full2.png)
# K3 IS ITSELF A COMPOSITE and K1/K2 ARE CUT FROM IT. Prompting for "the same plant but the
# top is still a bud" failed - img2img at strength 300 kept the flower open, which is the
# generator being sensibly conservative about an init image. So K3 is the closed-bud frame
# with the side flowers pasted in from the finished plant, and K1/K2 are K3 with the bud
# rows cleared (the bud spans rows 9..33; the stalk resumes 3px wide at row 34) and, for
# K1, the right-hand flower cleared too. Every pixel therefore comes from a frame the model
# drew, on one canvas, so the interpolations have nothing to reconcile.
#
# THE INTERPOLATIONS OVERSHOOT BADLY HERE and drop_overshoot is what makes them usable:
# told to grow from a seedling to K1, the model grows the WHOLE plant to full height by
# frame 9 and then snaps back to the pinned target at frame 16. Measured heights across the
# raw 65: 14, 19, 24, 34, 41, 44, 49, 55, 64, 71, 71, 72, 72, 72, 72, 72, then 46. Twenty-
# three frames are dropped, against three on the previous cycle - a pinned last frame is a
# hint, not a contract, and the further the target is from "keep going", the less it holds.
SEGMENTS = [("s1", False), ("s2", True), ("s3", True), ("s4", True)]


def load_segment(stem: str) -> list[np.ndarray]:
	fs = sorted(SRC.glob(f"{stem}_*.png"))
	return [np.asarray(Image.open(f).convert("RGBA")).copy() for f in fs]


# How much taller than the frame AFTER it a frame may be before it is treated as an
# overshoot rather than as growth. A plant's HEIGHT never goes down, but the tail of the
# cycle legitimately wobbles by a pixel or two as the bloom opens and the silhouette
# settles, so the test has to be a ratio with slack rather than "never decreases".
OVERSHOOT = 1.10


def drop_overshoot(frames: list[np.ndarray]) -> list[np.ndarray]:
	"""Remove frames that grow past where the next frame is, at a segment join.

	INTERPOLATION DOES NOT RELIABLY LAND ON ITS PINNED LAST FRAME, and that is what this
	exists for. Each densifying segment is pinned to a frame taken out of the first pass, so
	its end and the next segment's start are the same picture - but measured on the built
	cycle, segment one climbed to an ink height of 70 and 73 in its last two frames and the
	next segment opened at 48. Played in order that is a plant shooting up and then snapping
	back, twice, in the middle of a run.

	Dropping by HEIGHT alone is wrong and was tried: a backwards monotone filter threw away
	nineteen frames, almost all of them the tail where the plant has stopped getting taller
	and the BLOOM is opening - exactly the frames the animation exists for. Only a frame
	that is taller than what follows it is a defect; a frame that is the same height as what
	follows is the flower doing its work.
	"""
	def ink(a: np.ndarray) -> int:
		return int((a[..., 3] > 0).any(1).sum())

	keep = list(range(len(frames)))
	changed = True
	while changed:
		changed = False
		for a in range(len(keep) - 1):
			if ink(frames[keep[a]]) > ink(frames[keep[a + 1]]) * OVERSHOOT:
				keep.pop(a)
				changed = True
				break
	if len(keep) < len(frames):
		print(f"  dropped {len(frames) - len(keep)} overshoot frame(s) at the segment joins")
	return [frames[i] for i in keep]


def build(write: bool, force: bool) -> int:
	frames: list[np.ndarray] = []
	for stem, drop in SEGMENTS:
		seg = load_segment(stem)
		if not seg:
			print(f"  missing artifacts/plant/{stem}_*.png")
			return 1
		frames.extend(seg[1:] if drop else seg)
		print(f"  {stem}: {len(seg)} frames" + ("  (first dropped, shared with previous)" if drop else ""))

	frames = drop_overshoot(frames)
	# every frame is a 2:1-free generation, so the only correction needed is the hard alpha
	# and palette contract every other sprite in this game holds to
	bad_in = sum(off_palette(f) for f in frames)
	out: list[np.ndarray] = []
	for f in frames:
		f = f.copy()
		f[..., 3] = np.where(f[..., 3] >= 128, 255, 0).astype(np.uint8)
		out.append(snap_palette(f))
	bad_out = sum(off_palette(f) for f in out)
	h, w = out[0].shape[:2]
	print(f"  {len(out)} frames total, {w}x{h}, {bad_in} off-palette in, {bad_out} out")
	if not write:
		print("  (pass --write to apply)")
		return 0

	OUT.mkdir(parents=True, exist_ok=True)
	keys: list[str] = []
	for i, f in enumerate(out):
		name = f"grow_{i:02d}"
		keys.append(name)
		artguard.save_guarded(OUT / f"{name}.png", lambda q, a=f: Image.fromarray(a, "RGBA").save(q), force)
	# WHERE THE STALK IS IN ITS OWN CANVAS, so the game can hang the plant on the track's
	# centre line instead of on the canvas's. Measured, not assumed: the painted stalk sits
	# 3.5 art px LEFT of centre in every frame, which put the empty groove visibly beside
	# the plant rather than behind it. The offset is a property of the ART, so it is
	# published here and re-measured on every install.
	band = out[0][..., 3] > 0
	ys = np.where(band.any(1))[0]
	xs = np.where(band[ys.max() - 7:ys.max() + 1].any(0))[0]
	dx = round(((xs.min() + xs.max()) / 2.0) - out[0].shape[1] / 2.0, 1)
	print(f"  stalk sits {dx} art px from the canvas centre")
	# WHERE THE OPEN BLOOM ACTUALLY IS, so the celebration glow can sit on it. The aura was
	# hung at the sprite's own top edge, which is the top of the CANVAS - measured, 27 art
	# px above the bloom's centre, i.e. a halo floating clear of the flower it belongs to.
	# Measured on the LAST frame because that is the only one the aura is ever drawn over
	# (it appears at frac >= 0.999), and the bloom's centre moves as it opens.
	last = out[-1]
	lop = last[..., 3] > 0
	warm = lop & (last[..., 0].astype(int) > 180) & (last[..., 0].astype(int) > last[..., 2].astype(int) + 60)
	wy, wx = np.where(warm)
	bcx = round(float(wx.mean()), 1) if len(wx) else out[0].shape[1] / 2.0
	bcy = round(float(wy.mean()), 1) if len(wy) else 0.0
	print(f"  bloom centre at ({bcx}, {bcy}) art px of the canvas")
	print(f"  wrote {len(keys)} frames to {OUT.relative_to(ROOT)}")
	print("  manifest keys: " + " ".join("stem/" + k for k in keys[:3]) + " ...")
	(SRC / "keys.json").write_text(json.dumps(
		{"frames": len(keys), "stalk_dx": dx, "bloom_cx": bcx, "bloom_cy": bcy}, indent=1))
	return 0


def main() -> int:
	return build("--write" in sys.argv, "--force" in sys.argv)


if __name__ == "__main__":
	raise SystemExit(main())
