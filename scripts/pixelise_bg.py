#!/usr/bin/env python3
"""Reduce a --bgref capture to a 640x360 backdrop on the art grid.

WHY TWO VENUES USE THIS AND FIVE DO NOT. Five backdrops are PixelLab paintings, built
from one 320x360 half mirrored, because PixelLab caps an image at 400px a side and a
symmetric venue survives the mirror. The Backyard and the Street Corner are outdoor
and genuinely asymmetric: mirroring duplicates their scenery (two sheds, two trees),
and generating a left and a right half separately produces halves that will not meet -
different horizon heights, different sky tone - which no seam blend can rescue.

So these two are DERIVED from the game's own dressing instead, exactly as the props
and the body were. The result is flatter than a painting and it is unarguably TOSSA:
the same tree, the same washing line, the same lit shed window, in the same places.
For the venue a new player sees first, matching beats embellishing.

The reduction is exactly 2:1 - the capture is 1280x720 and the art density is 640x360 -
so every source pixel lands in a clean 2x2 box with no resampling. Colours are snapped
to the locked palette so a backdrop cannot introduce a shade the rest of the game never
uses. There is no alpha: a backdrop is opaque by definition, and the seam blits it into
a full-screen rect.

USAGE
  godot --audio-driver Dummy --path . -- --bgref --demo --booking --venue 0 \
      --shot <dir>/v0.png --shotat 400
  .venv/bin/python scripts/pixelise_bg.py <dir>/v0.png backyard
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Assets" / "Backgrounds"
PALETTE = ROOT / "Resources" / "palette" / "palette.json"
ART_W, ART_H = 640, 360


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


def main() -> None:
    src_path, name = Path(sys.argv[1]), sys.argv[2]
    im = Image.open(src_path).convert("RGB").resize((ART_W, ART_H), Image.BOX)
    arr = np.asarray(im).astype(np.float64)

    pal = np.array([[int(h[i:i + 2], 16) for i in (1, 3, 5)]
                    for h in json.loads(PALETTE.read_text())["hex"]], dtype=np.float64)
    flat = arr.reshape(-1, 3)
    d = np.linalg.norm(srgb_to_oklab(flat)[:, None, :] - srgb_to_oklab(pal)[None, :, :], axis=2)
    snapped = pal[np.argmin(d, axis=1)].reshape(arr.shape).astype(np.uint8)

    OUT.mkdir(parents=True, exist_ok=True)
    Image.fromarray(snapped, "RGB").save(OUT / f"{name}.png")
    print(f"{name}: {src_path.name} -> {ART_W}x{ART_H}, {len(np.unique(snapped.reshape(-1,3),axis=0))} colours")
    print(f'  "bg/{name}": {{ "path": "res://Assets/Backgrounds/{name}.png" }},')


if __name__ == "__main__":
    main()
