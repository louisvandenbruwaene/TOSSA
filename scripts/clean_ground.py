#!/usr/bin/env python3
"""Scrub the model's fake handwriting off a painted backdrop's floor.

WHY THIS EXISTS (2026-08-14). Ask PixelLab for "texture" on a large plain surface - a lawn, a
sand ring, a bare floor - and it reliably paints illegible CURSIVE SCRIBBLES across it. It is
not a one-off: measured on two independent Backyard rolls, both came back with pale
handwriting scattered right over the grass the performer stands on, and adding "no writing, no
letters, no markings" to the prompt did not stop it (that roll came back with a tree dead
centre instead, which is the other failure). It is invisible in a 640x360 thumbnail and
unmistakable at 2x on screen, which is why it shipped once.

RE-ROLLING IS THE WRONG TOOL FOR IT. A backdrop has to satisfy several things at once - a real
floor band, an empty centre column, an in-gamut sky - and the roll that gets all three is rare
enough that throwing one away over a defect this local is a bad trade. The scribbles are the
one fault that is genuinely mechanical to remove.

WHAT MAKES IT SAFE: the marks are SMALL DETAIL ON A FLAT FIELD. They are a pixel or two wide,
they sit on smooth ground, and a median filter over a smooth field is a no-op. So a pixel is
scrubbed when both of these hold:

  - it differs from its own neighbourhood's MEDIAN by more than THRESH (either direction - the
    scribbles are drawn in both a lighter and a darker ink than the grass, which the first
    version of this got wrong and half-erased them);
  - and the ground there is FLAT.

MEASURE THE FLATNESS ON THE MEDIAN, NOT ON THE ORIGINAL, and this is the whole trick. The
obvious version - local deviation of the source - is inflated BY the scribbles themselves, so
the writing hides from the test that is looking for it, while genuine EDGES (the stone path,
the plant silhouettes, the fence base) score high on both halves and get eaten. Measured, that
version scrubbed the path's outline and left the words legible. The median image has already
had the writing removed from it, so its local range is the real structure: the path is still
an edge in it and the scribbles are not there at all.

That is what protects everything you do not want touched. A stone path, a porch step, a plant,
the fence, a lit window - all of them are structure in the median too, so none of them is ever
a candidate. Measured on the Backyard: 3,650 pixels replaced, all inside the lawn; the path,
the pots, the shrubs and the porch steps come through untouched.

IT CONVERGES, so it needs no ledger (unlike recentre_ext.py, whose operations were relative
moves and could silently move a picture twice). Each internal pass finds about a tenth of what
the last one did and the fourth finds single digits; re-running the script on an already-clean
painting is close to a no-op rather than a second bite out of it.

RUN IT ON THE PAINTING, NOT ON THE SPRITE - artifacts/paint/<name>.png, before
pixelise_paint.py reduces it. The raw painting is continuous tone, which is what a median
filter wants; after the snap to 48 colours the marks have landed on palette entries and the
local statistics are much coarser.

THIS IS NOT A PIPELINE STEP AND MUST NEVER BE SWEPT ACROSS THE SEVEN. It is a repair you reach
for after LOOKING at a floor and finding writing on it. Its whole premise is that the ground is
a flat field, and only some grounds are: measured on the current set it would scrub 0.2% of the
Backyard's lawn and 12-19% of the Street Corner's cobbles, the Small Theatre's plank grain, the
Championship's markings and the World Arena's mown pitch - because on those the small detail on
a smooth field IS the picture. Name one venue, look at the result, and stop.

USAGE
  .venv/bin/python scripts/clean_ground.py backyard            measure only
  .venv/bin/python scripts/clean_ground.py backyard --write    apply, in artifacts/paint/
  .venv/bin/python scripts/clean_ground.py backyard --map out.png   paint the hits magenta
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import maximum_filter, median_filter, minimum_filter

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "artifacts" / "paint"

WIN = 7        # neighbourhood side, in art px. A scribble stroke is 1-2px wide and a word of
               # them spans ~20, so the window has to be wide enough that the median is still
               # GROUND inside a word - 7 is, 5 is not (measured: 5 left the thick strokes).
THRESH = 6.0   # how far from the local median counts as a mark, in 0-255 luminance. The
               # scribbles run 9-40 off it; real grass texture in these paintings runs 2-5.
CALM = 14.0    # local RANGE of the median image, below which the ground counts as flat. The
               # lawn measures 3-9; the stone path's edge 22, the shrubs 30+, the fence 40+.
BAND = 0.68    # only the bottom third and a bit: the floor. Above this is set dressing, where
               # small detail on a calm field is a lit window or a star, not a defect.


def median_rgb(rgb: np.ndarray) -> np.ndarray:
	return np.dstack([median_filter(rgb[:, :, c], size=WIN, mode="nearest") for c in range(3)])


def marks(rgb: np.ndarray, med: np.ndarray) -> np.ndarray:
	"""Boolean mask of the pixels to replace."""
	lum = rgb.astype(float).mean(axis=2)
	lmed = med.astype(float).mean(axis=2)
	flat = (maximum_filter(lmed, size=5, mode="nearest")
			- minimum_filter(lmed, size=5, mode="nearest"))
	m = (np.abs(lum - lmed) > THRESH) & (flat < CALM)
	m[: int(m.shape[0] * BAND)] = False
	return m


def clean(rgb: np.ndarray, passes: int = 4) -> tuple[np.ndarray, int]:
	"""Scrub to convergence, and return the picture and how many pixels went.

	IT TAKES MORE THAN ONE PASS, because replacing a pixel changes the median its neighbours
	are measured against: a thick stroke's core is only exposed once its edge has gone.
	Measured on the Backyard, the passes run 3650, 373, 44, 6 - each about a tenth of the last,
	so it converges rather than eating away at the picture. Stopping after one pass leaves the
	fattest strokes as faint ghosts, which is worse than not bothering.
	"""
	out = rgb
	total = 0
	for _ in range(passes):
		med = median_rgb(out)
		m = marks(out, med)
		n = int(m.sum())
		if n == 0:
			break
		out = np.where(m[:, :, None], med, out)
		total += n
	return out, total


def main() -> int:
	write = "--write" in sys.argv
	mapto = ""
	rest = sys.argv[1:]
	if "--map" in rest:
		i = rest.index("--map")
		mapto = rest[i + 1] if i + 1 < len(rest) else ""
		rest = rest[:i] + rest[i + 2:]      # ...and its VALUE is not a venue name
	args = [a for a in rest if not a.startswith("--")]
	if not args:
		raise SystemExit(__doc__)
	for name in args:
		p = SRC / f"{name}.png"
		if not p.exists():
			print(f"  {name}: no painting at {p.relative_to(ROOT)}")
			continue
		a = np.asarray(Image.open(p).convert("RGB"))
		out, n = clean(a)
		pct = 100.0 * n / a[int(a.shape[0] * BAND):].size * 3
		print(f"  {name}: {n} pixels scrubbed ({pct:.2f}% of the floor band)"
			  + ("" if write else "  (pass --write to apply)"))
		if mapto:
			shown = a.copy()
			shown[marks(a, median_rgb(a))] = (255, 0, 255)
			Image.fromarray(shown).save(mapto)
			print(f"    map -> {mapto}")
		if write:
			Image.fromarray(out.astype(np.uint8)).save(p)
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
