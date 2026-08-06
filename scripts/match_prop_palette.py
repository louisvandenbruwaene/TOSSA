#!/usr/bin/env python3
"""Repaint the stage props in their own shop card's colours.

THE PROBLEM (2026-08-06, Louis: "make sure that the character, objects etc look the same
everywhere in the game"). Every prop in this game is TWO pieces of art, and they were made
by different methods that never agreed on what the object is made of:

  prop/*      the stage sprite, DERIVED from the game's own drawing (pixelise_prop.py)
  prop_big/*  the shop card, PAINTED by PixelLab on the locked palette

Held side by side the club is red with white bands and a pale bone handle on stage, and
crimson with gold bands and a gold pommel on the card. The torch has a brown wooden shaft
on stage and a black iron one on the card. The chainsaw is yellow on stage and orange on
the card. They are not the same object twice, they are two objects sharing a name - and
the player sees the card in the shop minutes before seeing the sprite on stage.

WHY NOT JUST SCALE THE CARD DOWN. Because the stage sprite's PROPORTIONS are not an art
decision. A club is 6x32 art pixels because prop_scale and the collision geometry say so,
and the card is 48x96 because that fills a card nicely - a 0.19 aspect against a 0.50 one.
Resampling the card into the stage's box would give a club that is right about its colour
and wrong about its shape, and the shape is the thing the player reads mid-air to time a
catch. So this transfers the PAINT and leaves the silhouette exactly as it is.

HOW THE PAINT IS TRANSFERRED. Not by luminance alone - a club's bright bone handle and the
bright highlight on its red body have the same luminance and would be painted the same
colour. These props are ELONGATED and their parts are stacked along the long axis (knob,
body, handle, pommel), and both versions stack them in the same ORDER. So a stage pixel is
matched against only the card rows near its own relative height, and within that window the
card colour whose luminance is closest wins. Position disambiguates what luminance cannot.

  1. The card is rotated first where the two disagree about which way the prop lies (the
     chainsaw is painted along the x axis and thrown along the y).
  2. The window is generous (WINDOW of the card's height) so a one-row band on the stage
     sprite can still find the card's version of that band.
  3. Alpha is copied straight through, so the silhouette - and with it every timing cue
     and the pivot the game rotates about - is bit-identical. --check proves it.

THE TINTED PROPS ARE NOT HERE. ball, egg and ring are authored greyscale and multiplied by
the game's colour, so "their palette" is not a thing that exists; they get their consistency
from scripts/make_round_props.py --stage, which draws both sizes from one analytic model.

THE OUTCOME, AND WHY THIS IS NOT WIRED IN. Generated and looked at on 2026-08-06: the
club's red went to a muddy tan, the torch's shaft came back blue, the knife lost its
contrast and the chainsaw came back grey and noisy - all four plainly worse than the
sprites they replace. The height window is the part that fails: a club's bone handle and
the highlight on its red body sit close enough in both height and luminance that the match
picks between them almost at random, and one wrong pick on a six-pixel-wide sprite is a
sixth of the object. So Resources/art_variants/props.matched.json ships the ROUND props
only, where scripts/make_round_props.py --stage solves the same problem properly by
drawing both sizes from one model. This script stays for its reasoning and for anyone who
wants to try a better matcher; the same call the previous pass made about
pixelise_prop.py --big, and for the same reason.

USAGE
  .venv/bin/python scripts/match_prop_palette.py             # report
  .venv/bin/python scripts/match_prop_palette.py --check     # prove alpha is untouched
  .venv/bin/python scripts/match_prop_palette.py --write [--force]
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

import artguard

ROOT = Path(__file__).resolve().parent.parent
PROPS = ROOT / "Assets" / "Props"
VARIANTS = ROOT / "Assets" / "Variants"

# The painted props, and how far the card has to be turned to lie the same way the stage
# sprite does. Degrees counter-clockwise, as PIL means them.
TARGETS = {"club": 0, "knife": 0, "torch": 0, "chainsaw": -90}

WINDOW = 0.16     # fraction of the card's height searched around a pixel's own height
LUM = np.array([0.2126, 0.7152, 0.0722])


def card_samples(name: str, rot: int) -> tuple[np.ndarray, np.ndarray]:
	"""Every opaque card pixel as (relative height, luminance) and its RGB."""
	im = Image.open(PROPS / f"big_{name}.png").convert("RGBA")
	if rot:
		im = im.rotate(rot, expand=True)
	a = np.asarray(im).astype(float)
	ys, xs = np.where(a[..., 3] > 127)
	if ys.size == 0:
		raise SystemExit(f"{name}: card art is empty")
	# height relative to the card's own INK, not to its canvas - a card with padding
	# would otherwise shift every band away from where the stage sprite expects it
	v = (ys - ys.min()) / max(ys.max() - ys.min(), 1)
	rgb = a[ys, xs, :3]
	lum = (rgb * LUM).sum(axis=1) / 255.0
	return np.stack([v, lum], axis=1), rgb


def repaint(name: str, rot: int) -> tuple[np.ndarray, int]:
	src = Image.open(PROPS / f"{name}.png").convert("RGBA")
	a = np.asarray(src).astype(float)
	alpha = a[..., 3]
	ys, xs = np.where(alpha > 0)
	if ys.size == 0:
		raise SystemExit(f"{name}: stage art is empty")
	vlum, crgb = card_samples(name, rot)
	cv, cl = vlum[:, 0], vlum[:, 1]

	v = (ys - ys.min()) / max(ys.max() - ys.min(), 1)
	lum = (a[ys, xs, :3] * LUM).sum(axis=1) / 255.0

	out = np.zeros_like(a)
	out[..., 3] = alpha
	for i in range(ys.size):
		near = np.abs(cv - v[i]) <= WINDOW
		if not near.any():
			# a stage row with nothing at that height on the card (the ends taper
			# differently): widen to the whole prop rather than invent a colour
			near = np.ones_like(cv, dtype=bool)
		cand = np.where(near)[0]
		j = cand[np.argmin(np.abs(cl[cand] - lum[i]))]
		out[ys[i], xs[i], :3] = crgb[j]
	colours = len({tuple(c) for c in out[ys, xs, :3].astype(int)})
	return out.astype(np.uint8), colours


def main() -> int:
	write = "--write" in sys.argv
	force = "--force" in sys.argv
	check = "--check" in sys.argv
	names = [a for a in sys.argv[1:] if not a.startswith("--")]
	names = [n for n in names if n in TARGETS] or list(TARGETS)
	for name in names:
		out, colours = repaint(name, TARGETS[name])
		src = np.asarray(Image.open(PROPS / f"{name}.png").convert("RGBA"))
		if check:
			print(f"{name:9} alpha identical: {np.array_equal(out[..., 3], src[..., 3])}")
			continue
		msg = f"{name:9} {out.shape[1]:3}x{out.shape[0]:<3} -> {colours} colours from its card"
		if not write:
			print(msg + "   (report only)")
			continue
		dst = VARIANTS / "props_matched" / f"{name}.png"
		dst.parent.mkdir(parents=True, exist_ok=True)
		status = artguard.save_guarded(dst, lambda q: Image.fromarray(out, "RGBA").save(q), force)
		print(msg + f"  [{status}]")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
