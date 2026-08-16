#!/usr/bin/env python3
"""Install the three difficulty-picker mascots from artifacts/difficulty/.

Same recipe as install_cards.py (round the corner to match draw_difficulty_screen's
soft_card, verify the forced palette actually held, save through artguard) - the
picker's cards are drawn the same shape as the Skills illustration deck, at the same
104x128 authoring size, via the same art_blit_fit contract.

USAGE
  .venv/bin/python scripts/install_difficulty_cards.py           preview
  .venv/bin/python scripts/install_difficulty_cards.py --write
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

import artguard
from install_cards import CARD_H, CARD_W, off_palette, round_corners

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "artifacts" / "difficulty"
OUT = ROOT / "Assets" / "UI" / "difficulty"

CORNER_R = 5   # same digital quarter-circle as install_cards.py's own CORNER_R

NAMES = ["sloth", "bear", "octopus"]


def build(name: str, write: bool, force: bool) -> str:
	src = SRC / f"{name}.png"
	if not src.exists():
		return f"{name}: no art at artifacts/difficulty/{name}.png"
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
