#!/usr/bin/env python3
"""Turn a --propref render into a 640x360-density pixel sprite.

WHY DERIVE RATHER THAN GENERATE. PixelLab's smallest canvas is 1024 pixels of area,
and at this density every prop is below it: a ball is 12x12 (144), a club 7x33 (231),
and even the chainsaw at 21x48 is 1008. Props are simply too small to generate. They
are also the assets where fidelity matters most, because a prop is on screen at all
times and the player tracks its silhouette to catch it.

So the source is TOSSA's own drawing. `--propref` renders each prop isolated at x6
through the real draw_prop_rich, and this reduces that render to the exact target
size, snaps it to the locked palette, and hardens the alpha. What comes out is the
game's actual silhouette on the pixel grid - not a model's idea of a juggling club -
which is the whole brief. Hand tuning in Aseprite happens on top of this, not instead
of it.

THREE THINGS THIS DOES THAT A PLAIN RESIZE DOES NOT:

1. Premultiplies alpha before filtering. Downsampling straight RGBA drags the
   background colour into every edge pixel in proportion to its transparency, which
   on a dark field means a dark halo around the whole prop. At 12 pixels across, a
   one-pixel halo is 17% of the sprite.

2. Hardens alpha to a threshold. Pixel art has no soft edges; a gradient of
   semi-transparent pixels around a 12px ball reads as blur, and blur is the single
   thing that makes generated pixel art look fake.

3. Snaps colour in Oklab to the locked palette, so a prop cannot introduce a shade
   the rest of the game never uses.

TINTED PROPS ARE WRITTEN IN GREYSCALE. draw_prop_rich hands the tint to the round
props only (ball, egg, ring); the game multiplies them by ball_color(i), one of four
colours cycled by index. A tint can only ever DARKEN, so the highlight has to be the
brightest value in the file and everything else sits below it - which is what
--grey does. Club, knife, torch and chainsaw carry their own painted palettes and
never see the tint, so they keep their colour.

USAGE
  .venv/bin/python scripts/pixelise_prop.py            # all seven, from the table
  .venv/bin/python scripts/pixelise_prop.py club ball  # just these
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

import artguard

ROOT = Path(__file__).resolve().parent.parent
REFS = ROOT / "artifacts" / "prop_refs"
OUT = ROOT / "Assets" / "Props"
PALETTE = ROOT / "Resources" / "palette" / "palette.json"

CLEAR = np.array([15, 8, 13])   # project.godot default_clear_color 0.06,0.03,0.05
BG_TOL = 10                     # sum-of-channels distance that still counts as background
ALPHA_CUT = 0.42                # below this a filtered pixel is dropped entirely
GREY_FLOOR = 0.45               # darkest value a tinted prop may use - see the note below
MAG = 6                         # --propref's PROPREF_MAG
ART_PIXEL = 2                   # Game.gd's ART_PIXEL
PROPREF_AT = np.array([640.0, 420.0])

# Which props the game tints (author greyscale) and which carry their own paint.
TINTED = {"ball", "egg", "ring"}

FORCE = False
RESULTS: dict = {}


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
    data = json.loads(PALETTE.read_text())
    return np.array([[int(h[i:i + 2], 16) for i in (1, 3, 5)] for h in data["hex"]])


def snap(rgb: np.ndarray, pal: np.ndarray) -> np.ndarray:
    """Nearest palette colour per pixel, measured perceptually."""
    flat = rgb.reshape(-1, 3)
    d = np.linalg.norm(srgb_to_oklab(flat)[:, None, :] - srgb_to_oklab(pal)[None, :, :], axis=2)
    return pal[np.argmin(d, axis=1)].reshape(rgb.shape)


def pixelise(name: str, pal: np.ndarray) -> dict:
    src = np.asarray(Image.open(REFS / f"{name}.png").convert("RGB")).astype(np.int64)

    mask = np.abs(src - CLEAR).sum(axis=2) > BG_TOL
    ys, xs = np.where(mask)
    if len(xs) == 0:
        raise SystemExit(f"{name}: reference is empty - re-run --propref")
    x0, x1, y0, y1 = int(xs.min()), int(xs.max()) + 1, int(ys.min()), int(ys.max()) + 1
    bw, bh = x1 - x0, y1 - y0

    # Target size: the on-stage extent divided by ART_PIXEL. The render is MAG times
    # the stage, so that is simply the bounding box over (MAG * ART_PIXEL).
    tw = max(1, round(bw / (MAG * ART_PIXEL)))
    th = max(1, round(bh / (MAG * ART_PIXEL)))

    crop = src[y0:y1, x0:x1].astype(np.float64)
    a = mask[y0:y1, x0:x1].astype(np.float64)

    # (1) premultiply before filtering, or the dark field bleeds into every edge pixel
    pm = np.concatenate([crop * a[..., None], a[..., None] * 255.0], axis=2).astype(np.uint8)
    small = np.asarray(Image.fromarray(pm, "RGBA").resize((tw, th), Image.BOX)).astype(np.float64)

    aa = small[..., 3] / 255.0
    with np.errstate(invalid="ignore", divide="ignore"):
        rgb = np.where(aa[..., None] > 0, small[..., :3] / np.maximum(aa, 1e-6)[..., None], 0)
    rgb = np.clip(rgb, 0, 255)

    keep = aa >= ALPHA_CUT              # (2) hard edges: pixel art has no soft alpha
    rgb = snap(np.round(rgb).astype(int), pal)   # (3) locked palette, perceptual nearest

    if name in TINTED:
        # Greyscale, stretched into [GREY_FLOOR, 1.0].
        #
        # The TOP of the range is pinned to pure white because the game multiplies this by
        # ball_color(i) and a multiply can only ever DARKEN - anything short of 255 in the
        # brightest pixel permanently dulls every ball in the game.
        #
        # The FLOOR is the half that had to be learned. Stretching to a true 0 looked
        # correct in the greyscale contact sheet and was wrong on a shop card: the darkest
        # rim and seam pixels multiplied down to near-black, and against a dark card a
        # near-black pixel is indistinguishable from a transparent one, so an 11px ball
        # appeared to have bites taken out of its edge. A pixel that is part of the
        # silhouette has to still read as the object at its darkest tint.
        lum = (0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2])
        lit = lum[keep]
        if lit.size:
            t = (lum - lit.min()) / max(1e-6, lit.max() - lit.min())
            lum = (GREY_FLOOR + (1.0 - GREY_FLOOR) * t) * 255.0
        rgb = np.repeat(np.clip(lum, 0, 255)[..., None], 3, axis=2)

    out = np.concatenate([rgb, np.where(keep, 255, 0)[..., None]], axis=2).astype(np.uint8)
    OUT.mkdir(parents=True, exist_ok=True)
    status = artguard.save_guarded(OUT / f"{name}.png",
                                   lambda q: Image.fromarray(out, "RGBA").save(q), FORCE)

    # The pivot is where the game rotates the shape about, expressed in the sprite's own
    # normalised space. PROPREF_AT is the known draw position, so this falls straight out.
    piv = ((PROPREF_AT[0] - x0) / bw, (PROPREF_AT[1] - y0) / bh)
    RESULTS[f"Assets/Props/{name}.png"] = status
    return {"name": name, "w": tw, "h": th, "pivot": (round(piv[0], 3), round(piv[1], 3)),
            "bbox": (bw, bh), "tinted": name in TINTED}


def main() -> None:
    global FORCE
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    FORCE = "--force" in sys.argv
    names = args or ["ball", "egg", "ring", "club", "knife", "torch", "chainsaw"]
    pal = load_palette()
    rows = [pixelise(n, pal) for n in names]

    print(f"{'prop':<10} {'render':>10} {'sprite':>9}  {'pivot':>14}  tint")
    for r in rows:
        print(f"{r['name']:<10} {r['bbox'][0]:>4}x{r['bbox'][1]:<5} "
              f"{r['w']:>3}x{r['h']:<5} {str(r['pivot']):>14}  {'grey' if r['tinted'] else 'painted'}")

    artguard.report(RESULTS)
    print("\nmanifest lines (paste into Resources/art_manifest.json):")
    for r in rows:
        print(f'  "prop/{r["name"]}": {{ "path": "res://Assets/Props/{r["name"]}.png", '
              f'"pivot": [{r["pivot"][0]}, {r["pivot"][1]}], "scale": 1.0 }},')


if __name__ == "__main__":
    main()
