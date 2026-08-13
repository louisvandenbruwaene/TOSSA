#!/usr/bin/env python3
"""Recolour the worn top hat from dusty olive into a showman's silk.

WHY RECOLOUR AND NOT REGENERATE (2026-08-13). The hat's GEOMETRY is not the problem and is
in fact carefully settled: draw_top_hat's own comment fixes the crown at 1.5r tall and the
brim at 1.5r each side, "any shorter and it is a bowler; any taller and the figure is a
chimney", and the sprite was drawn to exactly that. Its colours are the fault - measured,
every tone in it is a desaturated olive-grey (76,66,56 / 104,96,80 / 136,120,112 /
178,166,153 / 204,189,168) which reads as a dusty prop bowler on a man in a crimson tailcoat
with gold frogging.

A generated replacement was tried first and came back in THREE-QUARTER PERSPECTIVE - a
tilted brim ellipse - which is wrong on a front-facing figure and would have thrown away the
tuned proportions to fix a palette. Recolouring cannot introduce either error: the alpha is
copied through untouched, so the silhouette is bit-identical and the never-reshape rule holds
by construction (`--check` proves it), exactly as shade_char_regions did for the body.

THE MAP IS BY LUMINANCE ONTO A WARM RAMP, with one exception: the hatband. The band is
already the palette's own gold (176,136,72) and is the one part that should NOT go dark, so
it is matched by colour and passed straight through. Everything else walks a near-black silk
ramp picked out of the locked 48, so the hat still reads as a dark topper against a lit
backdrop rather than turning into a brown blob.

USAGE
  .venv/bin/python scripts/recolour_hat.py            preview the mapping
  .venv/bin/python scripts/recolour_hat.py --check    prove alpha is untouched
  .venv/bin/python scripts/recolour_hat.py --write
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

import artguard

ROOT = Path(__file__).resolve().parent.parent
HAT = ROOT / "Assets" / "Characters" / "hat_top.png"

# The band, matched by colour and left alone. It is the palette's b08848.
BAND = {(176, 136, 72), (112, 72, 48), (71, 41, 28)}

# A silk ramp out of the locked 48, darkest first.
#
# A FIRST VERSION STARTED AT 090708 AND WAS TOO DARK - checked against the mapping report
# rather than the render, and 369 of the hat's 418 opaque pixels were landing on the bottom
# two rungs. A silk topper is nearly black in life, but this one is worn on an unlit head
# against a dark backdrop, so a literally-black hat is a hole in the silhouette. Starting the
# ramp at 170f12 keeps it clearly a DARK hat while leaving it a readable shape.
RAMP = [
	(23, 15, 18),     # 170f12
	(36, 26, 20),     # 241a14
	(71, 41, 28),     # 47291c
	(76, 66, 56),     # 4c4238
	(104, 96, 80),    # 686050
	(136, 120, 112),  # 887870  the sheen
]


def lum(c) -> float:
	return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def build(write: bool, force: bool, check: bool) -> str:
	im = Image.open(HAT).convert("RGBA")
	a = np.asarray(im).copy()
	rgb, alpha = a[..., :3], a[..., 3]
	opaque = alpha > 0
	src = np.unique(rgb[opaque], axis=0)
	# rank the source tones by luminance and spread them across the ramp, so the mapping
	# follows the drawing's own shading order rather than absolute values
	tones = sorted((tuple(int(x) for x in c) for c in src), key=lum)
	free = [t for t in tones if t not in BAND]
	# THIS SCRIPT IS NOT IDEMPOTENT AND MUST REFUSE TO RUN TWICE. It maps the source's tones
	# onto RAMP by their luminance ORDER, so feeding it its own output re-spreads an already
	# compressed set across the full ramp and walks the hat lighter every time. artguard does
	# not catch it: the file's hash matches what artguard itself last wrote, so a second
	# --write is exactly the case it is designed to allow.
	if free and all(t in {tuple(r) for r in RAMP} for t in free):
		return ("hat_top: already recoloured - every non-band tone is already on RAMP. "
				"Refusing, because a second pass would re-spread them and lighten the hat. "
				"Restore from git first if you want to re-derive.")
	out = a.copy()
	lines = []
	for i, t in enumerate(free):
		j = 0 if len(free) == 1 else round(i * (len(RAMP) - 1) / (len(free) - 1))
		dst = RAMP[j]
		m = opaque & np.all(rgb == np.array(t), axis=-1)
		out[..., :3][m] = dst
		lines.append(f"    {t} -> {dst}  ({int(m.sum())} px)")
	for t in tones:
		if t in BAND:
			lines.append(f"    {t} -> kept (band)")

	if check:
		same = bool(np.array_equal(out[..., 3], a[..., 3]))
		return f"alpha identical: {same}  (silhouette unchanged)"
	body = "\n".join(lines)
	if not write:
		return f"hat_top: {len(tones)} tones\n{body}\n  (pass --write to apply)"
	st = artguard.save_guarded(HAT, lambda q: Image.fromarray(out, "RGBA").save(q), force)
	return f"hat_top: {len(tones)} tones [{st}]\n{body}"


def main() -> int:
	print(build("--write" in sys.argv, "--force" in sys.argv, "--check" in sys.argv))
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
