#!/usr/bin/env python3
"""Measure how much of a frame is actually on the art grid.

WHY THIS EXISTS: at ART_PIXEL = 2 a correct PIXELTOSSA frame has a hard
invariant - every 2x2 block aligned to even coordinates is four IDENTICAL
pixels, because one art pixel is drawn as a 2x2 screen block with no
resampling. Anything smooth breaks that: an antialiased curve, a gradient, a
rounded panel corner, a diagonal drawn as a polygon.

So "is this screen really pixel art?" stops being an opinion and becomes a
number, and a map of the broken blocks is a map of exactly what is left to
convert. That matters here because the seam (`art_manifest.json`) can only
report which KEYS are sprites; it cannot see chrome that was never a key -
panels, bars, gauges and cones drawn straight into `_draw`.

Usage:
    check_pixel_grid.py <png> [<png> ...]        report per-file
    check_pixel_grid.py --map <png> <out.png>    write a heatmap of offenders
    check_pixel_grid.py --fail-over N <png> ...  exit 1 if any file is worse

The number to read is "off-grid %": the share of 2x2 blocks that are not flat.
Zero is not the target for every screen - see THRESHOLDS below.

THRESHOLDS (measured 2026-08-05, see the commit that added this file):
a fully converted screen lands under ~2%. The stage sits higher than the menus
because the spotlight cone and the crowd gauge are deliberately smooth.
"""

import sys

import numpy as np
from PIL import Image


def blocks(path):
	"""Return (H/2, W/2) bool array: True where the 2x2 block is NOT flat."""
	im = Image.open(path).convert("RGBA")
	a = np.asarray(im).astype(np.int16)
	h, w = a.shape[0] // 2 * 2, a.shape[1] // 2 * 2
	a = a[:h, :w]
	# The four corners of every aligned 2x2 block, as parallel arrays.
	tl, tr, bl, br = a[0::2, 0::2], a[0::2, 1::2], a[1::2, 0::2], a[1::2, 1::2]
	same = (tl == tr).all(-1) & (tl == bl).all(-1) & (tl == br).all(-1)
	return ~same


def pct(path):
	b = blocks(path)
	return 100.0 * b.mean(), b


def heatmap(path, out):
	"""Write the frame dimmed, with off-grid blocks flagged in magenta."""
	b = blocks(path)
	im = Image.open(path).convert("RGB")
	a = np.asarray(im).astype(np.uint8).copy()
	a = (a * 0.35).astype(np.uint8)
	# Upsample the block mask back to screen resolution to paint it.
	mask = np.kron(b, np.ones((2, 2), dtype=bool))
	a[: mask.shape[0], : mask.shape[1]][mask] = (255, 0, 200)
	Image.fromarray(a).save(out)


def main(argv):
	if len(argv) >= 3 and argv[0] == "--map":
		heatmap(argv[1], argv[2])
		p, _ = pct(argv[1])
		print(f"{p:6.2f}%  {argv[1]} -> {argv[2]}")
		return 0

	limit = None
	if len(argv) >= 2 and argv[0] == "--fail-over":
		limit = float(argv[1])
		argv = argv[2:]

	if not argv:
		print(__doc__)
		return 2

	worst = 0.0
	rows = []
	for path in argv:
		p, _ = pct(path)
		worst = max(worst, p)
		rows.append((p, path))
	for p, path in sorted(rows, reverse=True):
		flag = "  <-- over" if limit is not None and p > limit else ""
		print(f"{p:6.2f}%  off-grid   {path}{flag}")

	if limit is not None and worst > limit:
		print(f"\nFAIL: worst screen is {worst:.2f}% off-grid (limit {limit:.2f}%)")
		return 1
	return 0


if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
