#!/usr/bin/env python3
"""Install the goal stem's growth animation from artifacts/plant/ and artifacts/plant_v2/.

WHAT THIS IS (2026-08-19, Louis: "the entire flower and its growing animation should be
animated by pixellab, you then just take frames from it ... try to get as many frames as you
need, like many (40 or something), because you need them for the final product to look
smooth when going from one subgoal to another").

The stem used to be assembled by the game: a stalk rect, two lens leaves, two flower-head
sprites hung off it at fixed offsets, and a bud. That composes, but it does not GROW - each
part popped into existence at its own threshold, so the plant advanced in five visible steps
across a whole act. What replaces it is one painted growth cycle: the plant is a single
sprite per frame and the meter picks the frame from its own fill.

THE CYCLE IS BUILT IN THREE STRETCHES, ONE PER GOAL (rebuilt 2026-08-19 evening, Louis: "the
flower meter should start without that leaf, and the subgoals should be linearly spread: one
at 1/3, 2/3 and 3/3 of the final goal - the last one being the big flower of course").

That sentence is a TIMING contract and the old cycle broke it badly. Its four interpolations
all overshot - told to grow a seedling into a one-flowered plant, the model grows the WHOLE
plant to full height by frame 9 and snaps back to the pinned target at 16 - so
`drop_overshoot` threw away 23 of 65 frames, and every one of them came out of the two
stretches where the side flowers grow. Measured on the shipped cycle: the first flower opened
at frame 7 of 41 (fill 0.17), the second at frame 8 (0.19), and the remaining 33 frames were
all top bud. Two subgoals inside a fifth of the meter, then four fifths of nothing.

So the frames are now CURATED per stretch rather than concatenated and filtered, and the
manifest publishes `beats` - the frame index each goal lands on - so the game can map its fill
onto them piecewise (see stem_grow_key). What each stretch is:

  1. 0 -> 1/3   a bare sprout with NO LEAF (plant_seed0, the seedling with its leaf masked
                off) grows a stalk, unfurls two leaves, and opens ONE side flower.
                a_00..a_04 + l_01..l_06 + c_01..c_16, ending exactly on plant_k1.
  2. 1/3 -> 2/3 the SECOND side flower opens, and it is stretch 1's own flower MIRRORED.
                The generated interpolation for this beat (artifacts/plant_v2/b_*) came back
                a hard pop - eight identical frames, the flower, eight more identical frames -
                which is a static middle third of the meter. Mirroring the left flower's
                measured opening gives a real, gradual bloom AND makes the two subgoals behave
                identically, which is what they mean. Ends exactly on plant_k2.
  3. 2/3 -> 1   the stalk rises, the top bud forms and blooms: the two segments from the
                original build (s3, s4), which came out clean and are unchanged.

THE SEEDLING IS DERIVED FROM THE FULL PLANT, NOT GENERATED. Both ends of an interpolation
have to be the same plant or the model spends its frames morphing one design into another
instead of growing one. Masking everything above the lowest 14 rows of the finished plant
gives a start frame that shares its stalk, its width and its exact palette. plant_k0b (the
flowerless plant, used as the middle keyframe of stretch 1) is derived the same way, by
clearing plant_k1's flower head and the shoot it stands on.

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

# WHICH RAW FRAMES EACH STRETCH IS MADE OF, as (directory, job-stem, first, last) with both
# ends INCLUSIVE. Curated rather than concatenated: see the module docstring for why the
# previous "take every frame and filter the overshoot out" build could not hold the timing.
#
# THE KEYFRAMES the interpolations run between, and where each came from:
#   K0   a bare sprout, no leaf       (artifacts/paint/plant_seed0.png - plant_seed masked)
#   K0b  stalk and leaves, no flower  (artifacts/paint/plant_k0b.png   - plant_k1 masked)
#   K1   one side flower open         (artifacts/paint/plant_k1.png)
#   K2   both side flowers open       (artifacts/paint/plant_k2.png)
#   K3   taller stalk, closed top bud (artifacts/paint/plant_mid2.png)
#   K4   full bloom                   (artifacts/paint/plant_full2.png)
# K3 IS ITSELF A COMPOSITE and K1/K2 ARE CUT FROM IT. Prompting for "the same plant but the
# top is still a bud" failed - img2img at strength 300 kept the flower open, which is the
# generator being sensibly conservative about an init image. So K3 is the closed-bud frame
# with the side flowers pasted in from the finished plant, and K1/K2 are K3 with the bud
# rows cleared and, for K1, the right-hand flower cleared too. Every pixel therefore comes
# from a frame the model drew, on one canvas, so the interpolations have nothing to
# reconcile - and the two masked keyframes above extend that same rule downward.
#
# WHY EACH SPAN STOPS WHERE IT DOES. An interpolation is pinned to its last frame and
# overshoots anyway: `a` and `l` both grow the plant to the full canvas height by frame 15
# and snap back to the target at 16. A pinned last frame is a hint, not a contract. So each
# span keeps only the frames that are still ON the way to their target - `a` up to the
# height `l` starts at, `l` up to the height K0b stands at - and the target is then taken
# from the keyframe file itself rather than from the frame that claims to be it.
STRETCH1 = [("plant_v2", "a", 0, 4), ("plant_v2", "l", 1, 6), ("plant_v2", "c", 1, 16)]
STRETCH3 = [("plant", "s3", 1, 16), ("plant", "s4", 1, 16)]
# stretch 2 is not a span: it is stretch 1's own flower, mirrored (see mirror_flower).
MIRROR_SRC = ("plant_v2", "c", 1, 15)
STALK_X = 35.0     # the column the stalk stands on, in canvas pixels - the mirror axis
MIRROR_DX = -3     # ...and the shift that lands the mirrored flower on K2's painted one.
MIRROR_DY = -2     # Measured: K1's flower occupies rows 41..48 / cols 22..27, K2's right
                   # flower rows 39..46 / cols 40..46, and a bare mirror about the stalk
                   # gives cols 43..48. The plant is not symmetric about its own stalk, so
                   # the mirror needs the offset or the last frame of the stretch jumps.


def load_frame(path: Path) -> np.ndarray:
	return np.asarray(Image.open(path).convert("RGBA")).copy()


def load_span(spans: list[tuple[str, str, int, int]]) -> list[np.ndarray]:
	"""The frames a stretch names, in order, from artifacts/<dir>/<stem>_NN.png."""
	out: list[np.ndarray] = []
	for folder, stem, lo, hi in spans:
		for i in range(lo, hi + 1):
			f = ROOT / "artifacts" / folder / f"{stem}_{i:02d}.png"
			if not f.exists():
				raise FileNotFoundError(f)
			out.append(load_frame(f))
	return out


def mirror_flower(base: np.ndarray, seed: np.ndarray, frame: np.ndarray) -> np.ndarray:
	"""`base` plus the mirror image of whatever `frame` grew on top of `seed`.

	THE SECOND SUBGOAL IS THE FIRST ONE, REFLECTED, and that is a deliberate choice rather
	than a shortcut. Two things pushed it: the generated interpolation for this beat came
	back as eight identical frames, a pop, and eight more identical frames - a third of the
	meter with nothing happening in it - and the two side flowers ARE the same event twice,
	so they should look like it. Only the DELTA is mirrored: the leaves and the stalk keep
	the asymmetry the painting gave them, and only the flower and its shoot cross the axis.
	"""
	grew = (frame[..., 3] > 0) & (np.abs(frame.astype(int) - seed.astype(int)).sum(2) > 24)
	out = base.copy()
	h, w = grew.shape
	ys, xs = np.nonzero(grew)
	for y, x in zip(ys, xs):
		mx = int(round(2.0 * STALK_X - x)) + MIRROR_DX
		my = int(y) + MIRROR_DY
		if 0 <= mx < w and 0 <= my < h:
			out[my, mx] = frame[y, x]
	return out


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
	paint = ROOT / "artifacts" / "paint"
	k1 = load_frame(paint / "plant_k1.png")
	k2 = load_frame(paint / "plant_k2.png")

	frames: list[np.ndarray] = list(load_span(STRETCH1)) + [k1]
	beats = [len(frames) - 1]
	print(f"  stretch 1 (sprout to first flower): {len(frames)} frames, goal 1 at {beats[0]}")

	folder, stem, lo, hi = MIRROR_SRC
	seed = load_frame(ROOT / "artifacts" / folder / f"{stem}_00.png")
	for i in range(lo, hi + 1):
		frames.append(mirror_flower(k1, seed, load_frame(ROOT / "artifacts" / folder / f"{stem}_{i:02d}.png")))
	frames.append(k2)
	beats.append(len(frames) - 1)
	print(f"  stretch 2 (second flower, mirrored): {beats[1] - beats[0]} frames, goal 2 at {beats[1]}")

	frames.extend(load_span(STRETCH3))
	beats.append(len(frames) - 1)
	print(f"  stretch 3 (bud and bloom): {beats[2] - beats[1]} frames, goal 3 at {beats[2]}")
	# THE SAFETY NET, NOT THE BUILD. The stretches above are curated, so nothing should be
	# dropped here - and if something is, the span it came from is wrong and wants looking
	# at rather than filtering. Beats are re-derived afterwards so a drop cannot silently
	# leave a goal pointing at the wrong picture.
	before = len(frames)
	kept = drop_overshoot(frames)
	if len(kept) != before:
		print(f"  WARNING: {before - len(kept)} curated frame(s) tripped the overshoot filter")
		beats = [kept.index(frames[b]) for b in beats]
	frames = kept
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
	# WHICH FRAME EACH GOAL LANDS ON. The stretches are different lengths on purpose (the
	# sprout has more to show than the second flower does), so the game cannot get this by
	# dividing - it reads the beats and maps its own fill onto them piecewise. Published
	# here because it is a property of the ART: a re-roll moves it.
	print(f"  goal beats at frames {beats} of {len(keys)}")
	(SRC / "keys.json").write_text(json.dumps(
		{"frames": len(keys), "stalk_dx": dx, "bloom_cx": bcx, "bloom_cy": bcy,
		 "beats": beats}, indent=1))
	return 0


def main() -> int:
	return build("--write" in sys.argv, "--force" in sys.argv)


if __name__ == "__main__":
	raise SystemExit(main())
