#!/usr/bin/env python3
"""Install the eight skill/pattern card illustrations from artifacts/carddeck/.

WHY THE DECK WAS REGENERATED AS A SET (2026-08-13). The eight cards were generated one at
a time on 2026-08-07 and each one is fine on its own; laid out side by side they were the
worst uniformity break left in the game. A cold blue waterfall, a bright yellow duck on a
GREEN pond, a cream Greek temple, a photoreal mallard, a ballerina, and a "high toss" card
that measured 98% TRANSPARENT - eight pictures with no shared framing, no shared light and
no shared background, sitting in one row on the Skills screen.

The metaphors are Louis's own (ballerina / waterfall / temple / duck / duckling / racket /
behind-the-back / high toss) and are kept exactly. What changed is that every prompt now
carries the SAME art-direction clause: the subject centred under a wide vertical cone of
warm amber spotlight, standing in an elliptical pool of light, against a deep warm brown
background. The deck is a set of eight things on the same dark stage, which is both what
the game is about and the cheapest possible way to make eight unrelated subjects agree.

THE BEHIND-THE-BACK CARD WAS ALSO SIMPLY WRONG. It showed a man in a grey-green jacket and
a red apron - not the showman, who is the only performer in this game, and who was standing
in the preview panel immediately to its right on the same screen.

THESE ARE OPAQUE, AND THE PREVIOUS ONES WERE NOT. That is a deliberate change and it is the
one thing that needed care. draw_skill_card_art measures a painting against `r`, the full
card window, on the documented grounds that "a painted illustration carries its own
transparent margin". These paintings do not - they are full-bleed - so they would square off
the frame's rounded corners, which is the exact defect the 5.5% inset was added for and then
retired. Rather than reintroduce the inset (which drops the art below the whole-2x scale
art_blit_fit insists on, silently falling back to the drawing), the corner is punched out of
the illustration's OWN alpha here, at the sprite's own radius, so it scales with the card.

USAGE
  .venv/bin/python scripts/install_cards.py           preview
  .venv/bin/python scripts/install_cards.py --write
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

import artguard
from pixelise_menu import load_palette, srgb_to_oklab

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "artifacts" / "carddeck"
OUT = ROOT / "Assets" / "UI" / "cards"

CARD_W, CARD_H = 104, 128

# draw_card_art_window's own corner, DERIVED not chosen: it calls soft_card with radius
# 10.0, and draw_card_pix converts that to art pixels as round(radius / ART_PIXEL) = 5.
# (The window is drawn whenever the `card_v2` experiment is on, and it defaults to true.)
#
# Punching the radius into the SPRITE rather than rounding in screen space is what makes it
# correct at both sizes the card is drawn at: the illustration is authored at exactly the
# Skills window's 104x128 and art_blit_fit blits it at whole zooms, so a corner cut here
# scales with the picture. A fixed screen-space rounding would be right at one size only.
CORNER_R = 5

NAMES = ["btb", "cascade", "columns", "halfshower", "high", "shower", "spin", "tennis"]


def round_corners(rgba: np.ndarray, radius: int) -> np.ndarray:
	"""Clear the four corners to transparent, on the art grid.

	Uses the same digital quarter-circle rule as Game.gd's pix_corner: each row's inset is
	measured at the row's CENTRE, not its top edge, so the staircase matches the frame the
	card is drawn in instead of sitting a pixel inside or outside it.
	"""
	out = rgba.copy()
	h, w = out.shape[:2]
	for i in range(radius):
		dy = radius - (i + 0.5)
		dx = np.sqrt(max(0.0, radius * radius - dy * dy))
		inset = int(np.clip(radius - round(dx), 0, radius))
		if inset <= 0:
			continue
		for row in (i, h - 1 - i):
			out[row, :inset, 3] = 0
			out[row, w - inset:, 3] = 0
	return out


def off_palette(rgb: np.ndarray) -> int:
	"""How many pixels are not exactly on the locked 48.

	pixflux's color_image_base64 forces the palette, so this should be zero and is checked
	rather than assumed - a silent drift here would put colours in the UI that exist nowhere
	else in the game.
	"""
	pal = {tuple(c) for c in load_palette()}
	return sum(1 for c in map(tuple, rgb.reshape(-1, 3)) if c not in pal)


def build(name: str, write: bool, force: bool) -> str:
	src = SRC / f"{name}.png"
	if not src.exists():
		return f"{name}: no art at artifacts/carddeck/{name}.png"
	im = Image.open(src).convert("RGBA")
	if im.size != (CARD_W, CARD_H):
		raise SystemExit(f"{name}: expected {CARD_W}x{CARD_H}, got {im.size}")
	a = np.asarray(im).copy()
	bad = off_palette(a[..., :3])
	a = round_corners(a, CORNER_R)
	tag = f"{name}: {len(np.unique(a[..., :3].reshape(-1, 3), axis=0))} colours, {bad} off-palette"
	if not write:
		return tag + "  (pass --write to apply)"
	return tag + " [" + artguard.save_guarded(
		OUT / f"{name}.png", lambda q: Image.fromarray(a, "RGBA").save(q), force) + "]"


def main() -> int:
	write = "--write" in sys.argv
	force = "--force" in sys.argv
	only = [x for x in sys.argv[1:] if not x.startswith("--")]
	OUT.mkdir(parents=True, exist_ok=True)
	for name in NAMES:
		if only and name not in only:
			continue
		print("  " + build(name, write, force))
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
