#!/usr/bin/env python3
"""Bake the title screen's proscenium into ui/menu_backdrop.

WHY THE TITLE SCREEN GETS A BAKE AT ALL. It was the last vector picture in the game
and the most-seen screen in it: measured 35% off-grid by check_pixel_grid.py, the worst
of all 32 screens, with crisp pixel props sitting on smooth antialiased velvet. Every
layer of menu_backdrop is STATIC - the only thing in that whole function that moves is
draw_dust - so there is nothing to lose by baking it, and a hundred polygons a frame to
save. The spotlight cone is baked here too, unlike a venue backdrop's: on a stage it
narrows and warms as a streak builds, but on the title screen it never changes.

THREE SOURCES, ONE OUTPUT:

  --from-half <png>  THE ONE ACTUALLY USED. A 320x360 LEFT half from PixelLab, mirrored
                 to 640x360. A proscenium is symmetric, so the mirror trick that built
                 five of the seven venue backdrops applies perfectly here - and unlike
                 those, nothing focal sits at the centre to be duplicated, because the
                 centre of this picture is deliberately an empty stage.
  --from-ref     artifacts/menu_ref/menu.png, the game's own drawing captured at
                 1280x720 by `--menuref`, reduced by exactly 2. Guaranteed to match
                 TOSSA, and the fallback if generated art is ever rejected.
  --from <png>   any 640x360 image.

WHY NOT ONE 640x360 GENERATION. It was tried (create_image_pro, 40 generations) and the
model returned a 516x360 picture padded with WHITE to fill the canvas. Stretching 516 to
640 is a non-integer resample, which is the one thing that cannot be done to pixel art.
The half-and-mirror route also costs 1 generation instead of 40 and, more importantly,
accepts `color_image_base64` - the forced palette. Measured: the half came back with 39
colours and ZERO off-palette, so it needs no colour correction at all, while the Pro
result needed darkening and re-snapping and turned the red curtains brown in the process.

WHY IT DITHERS. Reducing the game's own render and snapping to 48 colours produces
BANDS, and on a backdrop that is almost entirely one slow gradient - a dark red wall
falling to near-black - flat bands read as contour lines across the screen. Ordered
(Bayer) dithering picks between the two nearest palette entries per pixel instead, so
the gradient stays smooth at a distance and is honest pixel art up close. It is applied
ONLY where the two nearest palette colours are close together, because dithering across
a real edge just adds noise to it: `DITHER_MAX` is that distance in Oklab.

The output is fully opaque by construction - it is a backdrop, it covers the frame.
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

import artguard

ROOT = Path(__file__).resolve().parent.parent
REF = ROOT / "artifacts" / "menu_ref" / "menu.png"
OUT = ROOT / "Assets" / "UI" / "menu_backdrop.png"
PALETTE = ROOT / "Resources" / "palette" / "palette.json"

ART_W, ART_H = 640, 360
# Oklab distance below which two palette entries may be MIXED rather than one chosen.
# Measured 2026-08-05: 0.10 is far too permissive. Oklab's L axis only spans 0..1, so at
# 0.10 the spotlight cone - a wide, very low-contrast wash - started mixing genuinely
# different colours, and 4x4 Bayer over a smooth wash is not invisible texture, it is
# STRUCTURE: it produced a blobby shape in the middle of the cone that read as a figure
# standing there. Dithering is for two colours a hair apart; anything else is noise with
# a pattern.
DITHER_MAX = 0.035

# 4x4 Bayer, normalised to [-0.5, 0.5]
BAYER = (np.array([
	[0, 8, 2, 10],
	[12, 4, 14, 6],
	[3, 11, 1, 9],
	[15, 7, 13, 5],
], dtype=float) + 0.5) / 16.0 - 0.5


def srgb_to_oklab(rgb: np.ndarray) -> np.ndarray:
	c = rgb / 255.0
	lin = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
	r, g, b = lin[..., 0], lin[..., 1], lin[..., 2]
	l = np.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
	m = np.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
	s = np.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
	return np.stack([
		0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
	], axis=-1)


def load_palette() -> np.ndarray:
	import json
	data = json.loads(PALETTE.read_text())
	return np.array([[int(h[i:i + 2], 16) for i in (1, 3, 5)] for h in data["hex"]])


def snap_dithered(rgb: np.ndarray, pal: np.ndarray) -> np.ndarray:
	"""Nearest palette colour, mixing the two nearest where they are close."""
	h, w, _ = rgb.shape
	flat = rgb.reshape(-1, 3)
	d = np.linalg.norm(srgb_to_oklab(flat)[:, None, :] - srgb_to_oklab(pal)[None, :, :], axis=2)
	order = np.argsort(d, axis=1)
	i0, i1 = order[:, 0], order[:, 1]
	d0 = d[np.arange(len(flat)), i0]
	d1 = d[np.arange(len(flat)), i1]

	# How far this pixel sits between its two nearest palette entries, 0 = exactly the
	# nearest. Compared against a Bayer threshold, that is ordered dithering.
	with np.errstate(invalid="ignore", divide="ignore"):
		t = np.where(d0 + d1 > 1e-9, d0 / (d0 + d1), 0.0)
	tile = np.tile(BAYER, (h // 4 + 1, w // 4 + 1))[:h, :w].reshape(-1)
	mixable = (d1 - d0) < DITHER_MAX
	pick = np.where(mixable & (t + tile > 0.5), i1, i0)
	return pal[pick].reshape(h, w, 3)


# The generator signs its work: a faint light glyph block in the bottom-right of the
# half, sitting in the dark band UNDER the stage boards. It has to go before mirroring,
# or it lands dead centre and doubled. Patched rather than blanked, by copying a clean
# stretch from EXACTLY TWO SUPPORT-SPACINGS to the left: the under-stage band is a
# repeating run of vertical supports 16px apart, so a -32 copy lands the supports back
# on their own rhythm where a flat fill would leave an obvious gap in it.
MARK_BOX = (296, 344, 320, 360)     # x0, y0, x1, y1 in the 320x360 half
MARK_SRC_DX = -32


def unsign(a: np.ndarray) -> np.ndarray:
	x0, y0, x1, y1 = MARK_BOX
	a = a.copy()
	a[y0:y1, x0:x1] = a[y0:y1, x0 + MARK_SRC_DX:x1 + MARK_SRC_DX]
	return a


def build(src: Path, write: bool, force: bool, half: bool = False) -> str:
	im = Image.open(src).convert("RGB")
	if half:
		if im.size != (ART_W // 2, ART_H):
			raise SystemExit(f"{src.name}: --from-half wants {ART_W//2}x{ART_H}, got {im.size}")
		a = unsign(np.asarray(im).astype(np.uint8))
		full = np.concatenate([a, a[:, ::-1]], axis=1)
		im = Image.fromarray(full, "RGB")
	if im.size == (ART_W * 2, ART_H * 2):
		# the game's own render: an exact 2:1 box reduction, one art pixel per 2x2 block
		im = im.resize((ART_W, ART_H), Image.BOX)
	elif im.size != (ART_W, ART_H):
		raise SystemExit(f"{src.name}: expected {ART_W}x{ART_H} or {ART_W*2}x{ART_H*2}, got {im.size}")

	rgb = np.asarray(im).astype(int)
	out = snap_dithered(rgb, load_palette()).astype(np.uint8)
	rgba = np.dstack([out, np.full(out.shape[:2], 255, np.uint8)])

	if not write:
		return f"{src.name} -> {ART_W}x{ART_H}, {len(np.unique(out.reshape(-1, 3), axis=0))} colours (report only)"
	OUT.parent.mkdir(parents=True, exist_ok=True)
	status = artguard.save_guarded(OUT, lambda q: Image.fromarray(rgba, "RGBA").save(q), force)
	return f"{src.name} -> {OUT.relative_to(ROOT)}  [{status}]"


def main() -> int:
	write = "--write" in sys.argv
	force = "--force" in sys.argv
	src, half = REF, False
	if "--from" in sys.argv:
		src = Path(sys.argv[sys.argv.index("--from") + 1])
	if "--from-half" in sys.argv:
		src = Path(sys.argv[sys.argv.index("--from-half") + 1])
		half = True
	if not src.exists():
		raise SystemExit(f"missing {src} - capture it with:  godot --path . -- --menuref "
						 f"--shot artifacts/menu_ref/menu.png --shotat 40")
	print(build(src, write, force, half))
	if not write:
		print("(pass --write to apply)")
	return 0


if __name__ == "__main__":
	sys.exit(main())
