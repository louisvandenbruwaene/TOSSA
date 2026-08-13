#!/usr/bin/env python3
"""Reduce a FULL-FRAME PixelLab painting to a shipped 640x360 backdrop.

WHY THIS EXISTS ALONGSIDE pixelise_bg.py. That script reduces the game's own --bgref
capture (a drawing) and snaps it with a plain nearest-colour pass. This one takes a
PAINTING straight from PixelLab, already authored at the art density, and snaps it with
serpentine error diffusion. A drawing is flat fills that land on the palette almost
exactly; a painting is continuous tone, and a nearest-colour snap turns its skies and
its lamplight into hard bands. Same reasoning, and the same ERR_CLAMP, as pixelise_ext.

THE MIRROR IS GONE, AND THAT IS THE POINT OF THIS FILE. Five of the seven backdrops were
built as one 320x360 half mirrored down the middle, because create_image_pixflux caps a
side at 400px. `create_image_pixen` takes up to 768 per side with a 512x512 area budget,
and 640x360 = 230400 is inside it - so a backdrop is now ONE image. That removes three
standing compromises at once:

  1. the visible bilateral mirror line down the centre of every indoor venue;
  2. "anything focal at the centre gets duplicated by the mirror", which is why the old
     prompts had to say "the far LEFT SIDE only" and why one tent came back with two poles;
  3. the rule that asymmetric outdoor venues (the Backyard, the Street Corner) could not be
     generated at all and had to be derived from the game's own dressing instead. They were
     the two weakest pictures in the game precisely because of it.

WHAT PIXEN DOES NOT DO is force a palette - it has no color_image_base64. That is fine
here and was always the weaker half of the deal: the forcing happens in this script, in
Oklab, against the same locked 48. Measured on the seven: the raw paintings come back with
thousands of colours and reduce to 28-40, which is the same range the palette-forced
pixflux halves landed in.

WHAT THE PAINTING MUST NOT CONTAIN is light that reacts to the player. draw_backdrop
replaces exactly two layers with this sprite - the sky gradient and the set dressing - and
then draws the veil, the spotlight cone, the footlights and the floor OVER it, because the
cone narrows and warms as a streak builds. A backdrop with its own spotlight baked in
freezes the half of the picture that is answering the player.

TWO FRAMING RULES THE PROMPTS HAVE TO CARRY, both measured off draw_backdrop:
  - the bottom 20% (art y >= 288) is covered by the stage floor, so nothing essential
    may live there;
  - the performer stands dead centre and is ~172 art px tall, so the centre column wants
    to be empty - a tent pole or a doorway behind his spine reads as a mistake.

USAGE
  scripts/fetch_paint.sh <job-id> artifacts/paint/<name>.png     # download
  .venv/bin/python scripts/pixelise_paint.py <name> [...]        # preview
  .venv/bin/python scripts/pixelise_paint.py <name> --write
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

import artguard
from pixelise_ext import snap_diffused
from pixelise_menu import ART_H, ART_W, load_palette, srgb_to_oklab

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "artifacts" / "paint"
OUT = ROOT / "Assets" / "Backgrounds"

# venue order matches Game.gd's venue_data(); the key is bg/<name>
NAMES = ["backyard", "street_corner", "small_theatre", "the_circus",
		 "championship", "world_arena", "the_midnight_show"]


# HOW MUCH OF A PAINTING MAY SIT OUTSIDE THE LOCKED 48 BEFORE IT IS NOT WORTH SHIPPING.
#
# THE PALETTE IS A WARM THEATRE PALETTE and that is the whole reason this gate exists.
# Measured on the first two full-frame paintings: the circus (warm reds, cream, amber)
# came through the snap essentially intact; the backyard, painted with a desaturated TEAL
# dusk sky, had its whole sky land on muddy grey-brown speckled with the palette's only
# greens, which are bright and saturated. Nothing in the reducer can fix that - error
# diffusion moves a residual around, it cannot invent a colour the palette does not have,
# and at that distance every neighbour is wrong in the same direction.
#
# THE MEAN DISTANCE IS THE WRONG STATISTIC AND NEARLY FOOLED ME. The two score 0.028 and
# 0.034 - a 1.2x spread for a difference that is glaring on screen - because the damage is
# LOCALISED to the sky and a whole-frame mean averages it against a lot of fabric that
# snapped perfectly. What separates them is the TAIL: the fraction of pixels further than
# 0.05 Oklab from any entry is 2.9% on the circus and 26.9% on the backyard (51.5% over its
# sky band alone), a 9x separation. Measure the tail, not the average.
#
# The fix is always at the PROMPT, never here: steer a sky to deep indigo (the palette
# holds 1f1a2e / 282848 / 585078) rather than teal, and keep foliage dark rather than
# mid-green. 0.10 sits an order of magnitude clear of the good case.
GAMUT_FAR = 0.05
GAMUT_MAX = 0.10


def gamut_fit(rgb: np.ndarray) -> float:
	"""Fraction of pixels further than GAMUT_FAR from the nearest palette entry.

	Answers the one question a thumbnail cannot: will this painting SURVIVE the snap? A
	picture inside the palette's gamut reduces to itself; one outside it reduces to
	whatever is least wrong, and no amount of dithering rescues that.
	"""
	lab_p = srgb_to_oklab(load_palette().astype(float))
	flat = srgb_to_oklab(rgb.reshape(-1, 3).astype(float))
	# chunked: 230k pixels against 48 entries at once is 33M floats
	far = 0
	for i in range(0, len(flat), 32768):
		part = flat[i:i + 32768]
		d = np.linalg.norm(part[:, None, :] - lab_p[None, :, :], axis=2).min(axis=1)
		far += int((d > GAMUT_FAR).sum())
	return far / len(flat)


def build(name: str, write: bool, force: bool) -> str:
	src = SRC / f"{name}.png"
	if not src.exists():
		return f"{name}: no painting at artifacts/paint/{name}.png"
	im = Image.open(src).convert("RGB")
	if im.size != (ART_W, ART_H):
		raise SystemExit(f"{name}: expected {ART_W}x{ART_H}, got {im.size}. A backdrop is "
						 "authored at the art density and must never be resampled.")
	src_rgb = np.asarray(im).astype(int)
	out = snap_diffused(src_rgb, load_palette())
	# opaque by construction: a backdrop covers the frame, and the seam blits it full-rect
	rgba = np.dstack([out, np.full(out.shape[:2], 255, np.uint8)])
	cols = len(np.unique(out.reshape(-1, 3), axis=0))
	spine = spine_busyness(out)
	fit = gamut_fit(src_rgb)
	tag = f"{name}: {cols} colours, spine {spine:.2f}, gamut {fit:.3f}{'  <-- REPROMPT' if fit > GAMUT_MAX else ''}"
	if not write:
		return tag + "  (pass --write to apply)"
	return tag + " [" + artguard.save_guarded(
		OUT / f"{name}.png", lambda q: Image.fromarray(rgba, "RGBA").save(q), force) + "]"


def spine_busyness(img: np.ndarray) -> float:
	"""Mean horizontal detail in the performer's column, relative to the whole row.

	Not a gate - a backdrop is judged by eye - but a vertical feature standing behind the
	figure's spine is the one composition fault a 640x360 thumbnail hides completely and
	the game then shows every single frame. He stands at x = 320 and is about 172 art px
	tall, so this compares mean absolute horizontal gradient down the middle 60 px, over
	the rows he actually occupies, against the same measure across the whole row. Around
	1.0 is "as busy as anywhere else"; well above it means something is standing there.
	"""
	g = img.astype(float).mean(axis=2)
	rows = slice(116, 288)                     # crown to floor at the figure's real height
	d = np.abs(np.diff(g[rows], axis=1))
	mid = d[:, 290:350].mean()
	allr = d.mean()
	return float(mid / allr) if allr > 0 else 0.0


def main() -> int:
	write = "--write" in sys.argv
	force = "--force" in sys.argv
	only = [a for a in sys.argv[1:] if not a.startswith("--")]
	OUT.mkdir(parents=True, exist_ok=True)
	for name in NAMES:
		if only and name not in only:
			continue
		print("  " + build(name, write, force))
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
