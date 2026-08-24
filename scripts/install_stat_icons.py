#!/usr/bin/env python3
"""Reduce the five stat/record icons to tintable 20x20 sprites (ui/stat_*).

WHAT THEY ARE (2026-08-24, Louis: "regenerate the stats menus with pixellab so that it
looks better"). The two stats screens were the last menus in the game made of nothing but
type: the talent sheet drew four columns whose only mark was a coloured border, and Records
and History drew two panels of plain rows. Every other card menu in TOSSA - the day hub, the
shop, the wardrobe - carries an icon in a lit disc, so these two read as older than the
screens either side of them. Four stat marks and two panel emblems is the whole change.

  acc  ACCURACY   a target        str  STRENGTH   a dumbbell    end  ENDURANCE  a heart
  rec  VENUE RECORDS  a cup       car  THE CAREER SO FAR  an open ledger

SPEED IS THE BOOT, AND IT IS THE ONE THAT IS NOT GENERATED HERE. `ui/stat_spd` points at
`Assets/UI/assist/boot.png` - the same sprite the play HUD's speed assist wore until that row
was removed on the same day. Louis picked that mark himself and his reason is the reason it
is right for the STAT: "a boot is a thing you WEAR, which is what a permanent invested stat
is". Re-rolling a second boot to sit in a different folder would be spending a generation on
a copy.

THE PIPELINE IS install_assist_icons', NOT A SECOND COPY OF IT. Same 40x40 source, same 2:1
box reduction to 20x20, same plinth trim, same normalise-to-own-brightest, same six bands,
same `scale` 0.5 in the manifest. That file's docstring is the long version of why each of
those steps exists; this one only supplies paths and names, so the two families cannot drift.

WHERE THE SOURCES COME FROM. `artifacts/` is gitignored, so the prompts are the source and
they live in `docs/pixellab_prompts.md`. All five: `create_image_pixflux`, 40x40,
no_background, selective outline, basic shading, low detail, seed 7.

USAGE
  .venv/bin/python scripts/install_stat_icons.py            preview
  .venv/bin/python scripts/install_stat_icons.py --write
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import install_assist_icons as assist  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent

assist.SRC = ROOT / "artifacts" / "stat"
assist.OUT = ROOT / "Assets" / "UI" / "stat"
assist.NAMES = ["acc", "str", "end", "rec", "car"]

if __name__ == "__main__":
    raise SystemExit(assist.main())
