#!/usr/bin/env python3
"""Snap the showman's two hands to his own skin ramp, in `source.png`.

WHY (2026-08-13, Louis: "improve ... the character itself"). At play size the performer
reads well - good coat, good face, good hat - and then his hands are two pale lumps with a
dark notch in them. Measured rather than eyeballed: the left hand's 24x31 box holds ~300
opaque pixels carrying THIRTY-TWO distinct colours, over a hand whose actual skin ramp is
five warm tans. The other twenty-seven include

    (242,140,115) x9   a salmon PINK, scattered across the palm
    (136,120,112) x8   a cold grey
    (204,189,168) x8   a pale grey
    (216,208,184) x3   near-white
    (255,240,204) x3   near-white
    (255,255,255) x1   pure white

plus stray cuff-gold specks sitting inside the fingers. Those twenty-three noise pixels are
a third of the hand's visible area at the size it is actually drawn (about 12 art px), which
is why it reads as damaged rather than as a hand.

They are not a mistake in the generation so much as a scale mismatch: at 176px they are
plausible sub-pixel shading on knuckles and nails, and there is no such thing as sub-pixel
shading on a 12px hand. Everything that is not the skin ramp is noise there.

THIS IS THE SAME RULE THE ARM LAYERS ALREADY FOLLOW, and it is worth naming because the
project paid for it once. From CLAUDE.md: "THE HANDS MUST BE PAINTED IN THE COLOURS OF HIS
FACE. Layers snapped independently to the 48 gave GOLD hands at some reaches and skin at
others... Distance thresholds do NOT separate skin from the coat's frogging; SET MEMBERSHIP
against the face's own colours does." Same answer, applied one step earlier - to the source
the whole rig is cut from, so every one of the 48 poses inherits the fix for free.

WHAT IT MUST NOT DO:
  - touch ALPHA. The silhouette is the figure's stance, the rig measures its hand blob to
    drive the IK, and the standing rule is that a mechanics fix never reshapes the juggler.
    Alpha is copied through untouched and `--check` asserts it bit for bit.
  - touch the OUTLINE. The dark pixels inside the hand are the drawn finger separations and
    the contour; snapping those to skin would fill the hand into a mitten. Anything below
    OUTLINE_LUM is left exactly as it is.
  - reach the sleeve, the cuff or the face. The regions below are bounded by MEASURED
    geometry: the sleeve's red starts at x>=34 on the left and ends at x<=135 on the right,
    so the hands are everything outboard of that.

NOT IDEMPOTENT IN SPIRIT, THOUGH IT IS IN FACT. A second run finds every pixel already on
the ramp and changes nothing, so unlike recolour_hat.py it does not need to refuse itself.
`--check` prints the count it would change, which is the honest way to see that.

AFTER RUNNING IT, REBUILD THE BANK - the atlas is cut from this file, not read from it live:
    .venv/bin/python scripts/build_arm_rig.py --write
    make reimport

USAGE
  .venv/bin/python scripts/clean_hands.py            preview: what would change
  .venv/bin/python scripts/clean_hands.py --check    verify alpha is untouched
  .venv/bin/python scripts/clean_hands.py --write
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

import artguard
from pixelise_menu import srgb_to_oklab

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "Assets" / "Characters" / "showman" / "source.png"

# The two hands, in source pixels. MEASURED, not chosen: the sleeve's red runs x 34..135
# (see the module docstring), the skin blobs sit at x 15..38 and x 137..160 with y 38..54,
# and these boxes are those blobs with a pixel of margin, stopping short of the sleeve.
HANDS = ((14, 34, 34, 58), (141, 34, 162, 58))   # x0, y0, x1, y1

# HIS OWN SKIN, taken from the hand itself - the five tans that carry 142 of its ~300
# pixels. Ordered light to dark; nothing else is skin.
SKIN_RAMP = np.array([
	(242, 204, 140),
	(216, 160, 104),
	(176, 136, 72),
	(152, 96, 56),
	(112, 72, 48),
], dtype=float)

# Below this, a pixel is contour or a drawn finger separation and is left alone. The darkest
# skin on the ramp is (112,72,48) at luminance ~80 and the outline colours all sit under 60,
# so 65 separates them with room on both sides rather than by a hair.
OUTLINE_LUM = 65.0


def lum(rgb: np.ndarray) -> np.ndarray:
	return 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]


def clean(a: np.ndarray) -> tuple[np.ndarray, int]:
	"""Return the cleaned RGBA and how many pixels moved."""
	out = a.copy()
	ramp_lab = srgb_to_oklab(SKIN_RAMP)
	changed = 0
	for x0, y0, x1, y1 in HANDS:
		box = out[y0:y1, x0:x1]
		rgb = box[..., :3].astype(float)
		sel = (box[..., 3] > 128) & (lum(rgb) >= OUTLINE_LUM)
		if not sel.any():
			continue
		lab = srgb_to_oklab(rgb[sel])
		near = np.linalg.norm(lab[:, None, :] - ramp_lab[None, :, :], axis=2).argmin(axis=1)
		new = SKIN_RAMP[near].astype(np.uint8)
		changed += int((new != box[..., :3][sel]).any(axis=1).sum())
		box[..., :3][sel] = new
	return out, changed


def main() -> int:
	write = "--write" in sys.argv
	check = "--check" in sys.argv
	force = "--force" in sys.argv
	im = Image.open(SRC).convert("RGBA")
	a = np.asarray(im)
	out, changed = clean(a)

	before = {tuple(c) for c in a[..., :3].reshape(-1, 3)}
	after = {tuple(c) for c in out[..., :3].reshape(-1, 3)}
	print(f"  hands: {changed} pixels snapped to the skin ramp")
	print(f"  whole figure: {len(before)} -> {len(after)} distinct colours")

	if check:
		same = np.array_equal(a[..., 3], out[..., 3])
		print(f"  ALPHA UNCHANGED: {same}  (the stance and the hand blob the rig measures)")
		if not same:
			return 1
	if not write:
		print("  (pass --write to apply)")
		return 0
	print("  [" + artguard.save_guarded(
		SRC, lambda q: Image.fromarray(out, "RGBA").save(q), force) + "]")
	print("  now: .venv/bin/python scripts/build_arm_rig.py --write && make reimport")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
