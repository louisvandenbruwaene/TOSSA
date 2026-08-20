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
  --half-shift N modifier on --from-half: slide the half N px sideways first, so a
                 CHOSEN column lands on the mirror axis rather than whichever one the
                 generator happened to leave at the edge. See shift_half.
  --mirror       modifier on any of the above: keep the source's LEFT half and mirror
                 it. THIS IS WHAT THE SHIPPED BAKE USES (2026-08-19, Louis: the title
                 "is not centered: the edges of the curtain are missing and the bows
                 aren't symmetric"). The 2026-08-13 rewrite made this a single
                 full-frame pixen painting, and a model asked for a proscenium does not
                 draw one: measured on that painting, 46.9% of pixels differed from
                 their own mirror by more than 20 levels, the swag gathers sat at x
                 26/122/253/355/565 - spans of 96, 131, 102 and then a 210-wide swag
                 drooping 20px lower than its neighbours - and both frame edges cut a
                 different fraction of a different swag.
                 **A PROSCENIUM IS ARCHITECTURE, SO ITS ASYMMETRY IS NOT CHARACTER, IT
                 IS AN ERROR**, and this is the one picture in the game where the
                 retired mirror is still right: the note that retired it (CLAUDE.md,
                 "A FULL-FRAME PICTURE IS ONE GENERATION NOW") retired it for the seven
                 VENUES, whose whole problem was a focal seam down the middle. This
                 picture's middle is deliberately an empty stage, which is exactly the
                 exemption the --from-half block below was written for.
                 **THE AXIS IS NOT A FREE CHOICE - IT MUST LAND ON A SWAG'S LOW POINT.**
                 The mirror meets itself with the source's own slope at that column, so
                 an axis on a rising arc makes a sharp inverted-V spike where the two
                 halves join. Measured on this painting: mirroring the left half puts
                 the axis at the bottom of the 253..387 swag and the join is invisible,
                 while shifting the window 26px right (to land a gather on each frame
                 edge, which is the more literal reading of "the edges of the curtain")
                 put the axis on a rising arc and drew a spike dead centre. Symmetric
                 and smooth beat symmetric and edge-aligned.

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


def shift_half(a: np.ndarray, dx: int) -> np.ndarray:
	"""Slide a half's content sideways so a CHOSEN column lands on the mirror axis.

	THE AXIS IS NOT A FREE CHOICE - it must land on a swag's low point (the note at the top
	of this file, and CLAUDE.md, both say so, and both were written after a spike appeared
	dead centre). `--from-half` mirrors at the half's own right edge, so until now the axis
	was wherever the generator happened to put it. Measured on the 2026-08-20 side-curtain
	half: the pelmet's gathers sit at x 112, 160, 240 and 306, and the frame edge at 319 is
	13px past the last of them on a falling arc - which mirrors into a shallow inverted V at
	the centre of the finished picture.

	Shifting RIGHT crops the right edge, which on a side-curtain half is plain empty stage
	and can be spared, and pads the left with a repeat of column 0, which is the dark outer
	edge of the curtain running off frame - what a valance behind a proscenium does anyway.
	Shifting LEFT is the mirror image of that and pads from the last column.

	The alternative - re-rolling until a gather lands on the edge - is what the venue notes
	call spending a generation on something arithmetic can fix.
	"""
	if dx == 0:
		return a
	out = np.empty_like(a)
	if dx > 0:
		out[:, dx:] = a[:, :-dx]
		out[:, :dx] = a[:, :1]
	else:
		out[:, :dx] = a[:, -dx:]
		out[:, dx:] = a[:, -1:]
	return out


# How much a row or column has to vary along its own length before it counts as PICTURE
# rather than as framing - see fit(), which is what does something about it (2026-08-20,
# Louis: "fit the edges of the curtains to the edges of the screen: no need for blackspace
# above and to the sides").
FIT_STD = 2.0
FIT_REL = 3.0       # ...or this many times the edge row's own variation, whichever is larger


def _margin(lum: np.ndarray) -> int:
	"""How many leading rows of `lum` are flat framing rather than picture."""
	edge = float(lum[0].std())
	gate = max(FIT_STD, edge * FIT_REL)
	n = 0
	while n < len(lum) - 1 and float(lum[n].std()) <= gate:
		n += 1
	return n


def fit(a: np.ndarray) -> np.ndarray:
	"""Scale the picture's real content up until it fills the frame.

	A BACKDROP COVERS THE FRAME. That is the whole contract of `art_blit_rect` - the sprite is
	stretched to the box it is given, and the box here is the viewport - so a painting that
	frames ITSELF with empty space does not read as a picture with a border, it reads as a
	game that has not filled its own window. half_lit came back with ten perfectly uniform
	rows above the pelmet and nine flat columns outside the drape, and the half-shift that
	puts the mirror axis on a swag's low point adds thirteen more to each side.

	**RESCALED, NOT FILLED** (2026-08-20, Louis: "can't you just rescale it all? don't
	regenerate, don't try to fix it by filling the rest, i just want you to rescale it so it
	all keeps looking good"). Running the outermost row and column out to the edges was tried
	first and is not a fix: the band it fills with is the drape's dark outer fold, so the
	border stayed dark and the curtains still started an inch inside the frame. What he is
	asking for is the picture to be BIGGER, and it costs 596 -> 640 across and 350 -> 360 down.

	NEAREST, and this is the one decision here that is not arithmetic. The scale is 1.074 x
	1.029, so a resample either duplicates about one column in fourteen and one row in
	thirty-five (nearest) or invents new colours between them (anything smoothing). Tried
	both: Lanczos then re-snapped through the dither came back speckled right across the
	curtain, because the dither is picking between palette entries on gradients the
	interpolation has just softened, and the seats at the bottom turned to mush. Nearest
	copies pixels, so it cannot leave the palette, cannot soften an edge, and the duplication
	is invisible on cloth - the fringe's tassel rhythm survives it, which was the thing worth
	checking.

	THE LEFT HALF IS SCALED AND MIRRORED, never the whole frame: a resample of an even width
	has no reason to duplicate the same columns on both sides of the axis, and this picture's
	symmetry is not decoration - see the note at the top of this file for what an asymmetric
	proscenium looks like.

	A no-op on a painting that already fills its frame, which is why it needs no flag.
	"""
	lum = a.mean(axis=2)
	left = _margin(lum.T)
	right = _margin(lum.T[::-1])
	top = _margin(lum)
	if not (left or right or top):
		return a
	h, w, _ = a.shape
	content = a[top:, left:w - right]
	half = content[:, :(content.shape[1] + 1) // 2]
	grown = Image.fromarray(half.astype(np.uint8), "RGB").resize((w // 2, h), Image.NEAREST)
	g = np.asarray(grown).astype(int)
	return np.concatenate([g, g[:, ::-1]], axis=1)


def build(src: Path, write: bool, force: bool, half: bool = False, mirror: bool = False,
		  half_shift: int = 0) -> str:
	im = Image.open(src).convert("RGB")
	if mirror:
		# --mirror: take a FULL-FRAME painting's left half and mirror it, which is
		# --from-half's symmetry without --from-half's unsign() patch (that patch is
		# aimed at a pixflux half's own bottom-right signature; a full-frame pixen
		# painting signs the bottom-right of the FULL frame, in the half this throws
		# away, so applying it here would scrub real picture instead).
		a = np.asarray(im).astype(np.uint8)
		if a.shape[1] != ART_W:
			raise SystemExit(f"{src.name}: --mirror wants a {ART_W}-wide source, got {im.size}")
		h = a[:, :ART_W // 2]
		im = Image.fromarray(np.concatenate([h, h[:, ::-1]], axis=1), "RGB")
	if half:
		if im.size != (ART_W // 2, ART_H):
			raise SystemExit(f"{src.name}: --from-half wants {ART_W//2}x{ART_H}, got {im.size}")
		a = unsign(np.asarray(im).astype(np.uint8))
		a = shift_half(a, half_shift)
		full = np.concatenate([a, a[:, ::-1]], axis=1)
		im = Image.fromarray(full, "RGB")
	if im.size == (ART_W * 2, ART_H * 2):
		# the game's own render: an exact 2:1 box reduction, one art pixel per 2x2 block
		im = im.resize((ART_W, ART_H), Image.BOX)
	elif im.size != (ART_W, ART_H):
		raise SystemExit(f"{src.name}: expected {ART_W}x{ART_H} or {ART_W*2}x{ART_H*2}, got {im.size}")

	rgb = fit(np.asarray(im).astype(int))
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
	mirror = "--mirror" in sys.argv
	if "--from" in sys.argv:
		src = Path(sys.argv[sys.argv.index("--from") + 1])
	if "--from-half" in sys.argv:
		src = Path(sys.argv[sys.argv.index("--from-half") + 1])
		half = True
	half_shift = 0
	if "--half-shift" in sys.argv:
		half_shift = int(sys.argv[sys.argv.index("--half-shift") + 1])
	if not src.exists():
		raise SystemExit(f"missing {src} - capture it with:  godot --path . -- --menuref "
						 f"--shot artifacts/menu_ref/menu.png --shotat 40")
	print(build(src, write, force, half, mirror, half_shift))
	if not write:
		print("(pass --write to apply)")
	return 0


if __name__ == "__main__":
	sys.exit(main())
