#!/usr/bin/env python3
"""Bake the prop wordmark to a sprite, at the title screen's size.

WHY THE LOGO HAD TO BE BAKED. capsule_mark spells MARK_WORD out of juggling objects by
calling cap_ball / cap_ring / cap_knife / cap_club DIRECTLY - it never goes through
draw_prop_rich, so it never touches the prop seam. Every other object in the game became
pixels while the title screen, the key art and the credits stayed vector, and the title
screen is the first thing a player sees.

WHY BAKED AND NOT ASSEMBLED FROM prop_big. The mark is a composition, not a pile of
props: each S is a line of balls at tuned offsets, the A is two leaning clubs, and the T
is a knife lying across another. Rebuilding that from the display sprites would mean
reproducing capsule_mark's layout a second time and letting the two drift - which is
exactly the failure the "a game has one logo" note in Game.gd was written about.

THE PIXEL PREFIX IS NOT IN THE BAKE. It is type, it is already crisp in the pixel font at
a quantised size, and reducing it by two would destroy it. --markref suppresses it, and
the word draws live over the sprite.

ONE SIZE ONLY. The sprite is authored against MENU_MARK and the seam uses it only at that
exact letter height; anything else would need a fractional scale. The credits (52) and a
narrow window's clamped title fall through to the drawing, which is correct.

USAGE
  godot --audio-driver Dummy --path . -- --markref --shot artifacts/mark_ref/mark.png --shotat 200
  .venv/bin/python scripts/pixelise_mark.py [--force]
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artguard  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
REF = ROOT / "artifacts" / "mark_ref" / "mark.png"
OUT = ROOT / "Assets" / "UI" / "wordmark.png"
PALETTE = ROOT / "Resources" / "palette" / "palette.json"

CLEAR = np.array([15, 8, 13])
BG_TOL = 10
ALPHA_CUT = 0.42
ART_PIXEL = 2
MENU_MARK = 168.0
MARK_PREFIX, MARK_RISE, MARK_DROP = 0.46, 1.06, 0.17
VIEW = (1280.0, 720.0)


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
    if not REF.exists():
        raise SystemExit(f"no {REF} - run the game with --markref first (see the docstring)")
    a = np.asarray(Image.open(REF).convert("RGB")).astype(np.float64)
    m = np.abs(a - CLEAR).sum(axis=2) > BG_TOL
    ys, xs = np.where(m)
    x0, y0, x1, y1 = int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1

    # Snap the crop to EVEN screen pixels. The reduction is exactly 2:1, and an odd origin
    # would put every source pixel across a 2x2 boundary - the whole sprite would soften
    # by half a pixel and no amount of palette snapping afterwards would bring it back.
    x0 -= x0 % 2
    y0 -= y0 % 2
    x1 += (x1 - x0) % 2
    y1 += (y1 - y0) % 2

    crop = a[y0:y1, x0:x1]
    al = m[y0:y1, x0:x1].astype(np.float64)
    pm = np.concatenate([crop * al[..., None], al[..., None] * 255.0], axis=2).astype(np.uint8)
    tw, th = (x1 - x0) // ART_PIXEL, (y1 - y0) // ART_PIXEL
    small = np.asarray(Image.fromarray(pm, "RGBA").resize((tw, th), Image.BOX)).astype(np.float64)

    aa = small[..., 3] / 255.0
    with np.errstate(invalid="ignore", divide="ignore"):
        rgb = np.where(aa[..., None] > 0, small[..., :3] / np.maximum(aa, 1e-6)[..., None], 0)
    keep = aa >= ALPHA_CUT

    pal = np.array([[int(h[i:i + 2], 16) for i in (1, 3, 5)]
                    for h in json.loads(PALETTE.read_text())["hex"]], dtype=np.float64)
    flat = np.clip(np.round(rgb), 0, 255).reshape(-1, 3)
    d = np.linalg.norm(srgb_to_oklab(flat)[:, None, :] - srgb_to_oklab(pal)[None, :, :], axis=2)
    rgb = pal[np.argmin(d, axis=1)].reshape(rgb.shape)

    out = np.concatenate([rgb, np.where(keep, 255, 0)[..., None]], axis=2).astype(np.uint8)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    st = artguard.save_guarded(OUT, lambda q: Image.fromarray(out, "RGBA").save(q),
                               "--force" in sys.argv)
    artguard.report({"Assets/UI/wordmark.png": st})

    # The placement the seam needs, measured rather than assumed: where the drawn mark sits
    # relative to (screen centre, the props' baseline), in units of the letter height.
    cy = VIEW[1] * 0.5 + MENU_MARK * ((MARK_PREFIX + MARK_RISE - MARK_DROP) * 0.5 - 0.5)
    base = cy + MENU_MARK * 0.5
    print(f"{st}: {tw}x{th}")
    print("  capsule_mark's box, in units of `size`:")
    print(f"    x  {(x0 - VIEW[0] * 0.5) / MENU_MARK:.5f}   y  {(y0 - base) / MENU_MARK:.5f}")
    print(f"    w  {(x1 - x0) / MENU_MARK:.5f}   h  {(y1 - y0) / MENU_MARK:.5f}")


if __name__ == "__main__":
    main()
