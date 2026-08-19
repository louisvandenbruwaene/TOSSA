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
SEGMENTS = [("s1", False), ("s2", True), ("s3", True)]


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
	print(f"  wrote {len(keys)} frames to {OUT.relative_to(ROOT)}")
	print("  manifest keys: " + " ".join("stem/" + k for k in keys[:3]) + " ...")
	(SRC / "keys.json").write_text(json.dumps({"frames": len(keys), "stalk_dx": dx}, indent=1))
	return 0


def main() -> int:
	return build("--write" in sys.argv, "--force" in sys.argv)


if __name__ == "__main__":
	raise SystemExit(main())
