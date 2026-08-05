#!/usr/bin/env python3
"""Derive the juggler's char/* sprites from the game's own figure.

WHY DERIVED AND NOT GENERATED. This was tested, 2026-08-05: asked for the same
costume in the same palette, PixelLab returns a lovely figure that is not this
character - realistic proportions instead of the big round head, a semi-realistic
face, the arms down. The stance and proportions of this juggler are settled and
changing them as a side effect of an art pass is explicitly off-limits, so the only
honest source for the figure is the figure. Tracing the game's own render cannot
drift, because it IS the game's own render.

The head is also simply too small to generate: 27x27 is 729 pixels of area against
PixelLab's 1024 floor.

HOW THE CROPS ARE FOUND. Not by eye. `--artboxes` makes the seam record the exact
centre and size the game asks for each sized element, while that element is still
procedural, and `--charref` draws the figure alone on a flat field at native stage
size. So each part is cropped by rectangle and reduced by exactly ART_PIXEL, with
every source pixel landing in a clean 2x2 box - no resample, no measuring.

TINT DISCIPLINE, WHICH DIFFERS PER PART AND IS NOT GUESSABLE:
  char/head        blitted with Color.WHITE, so it keeps its own full colour -
                   skin, hair, eyes, mouth all live in the file.
  char/hand_*      blitted with the skin colour as a TINT, so they must be greyscale
                   with the highlight at pure white (a multiply can only darken), and
                   floored so the darkest silhouette pixel does not read as a hole.
Read the call site before adding a part here; getting this backwards produces a grey
face or a hand that ignores the costume.

USAGE
  1. godot --audio-driver Dummy --path . -- --charref --artboxes \
       --shot <dir>/juggler.png --shotat 200 > <dir>/boxes.txt
  2. .venv/bin/python scripts/pixelise_char.py <dir>
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Assets" / "Characters"
PALETTE = ROOT / "Resources" / "palette" / "palette.json"

CLEAR = np.array([15, 8, 13])
BG_TOL = 10
ALPHA_CUT = 0.42
GREY_FLOOR = 0.45
ART_PIXEL = 2

# key -> (filename, tinted?)
PARTS = {
    "char/head":        ("head.png", False),
    "char/head_back":   ("head_back.png", False),
    "char/hand_open":   ("hand_open.png", True),
    "char/hand_closed": ("hand_closed.png", True),
    "char/glove_open":  ("glove_open.png", True),
    "char/glove_closed": ("glove_closed.png", True),
    "char/hat_top":     ("hat_top.png", False),
    "char/glasses":     ("glasses.png", False),
    "char/helmet":      ("helmet.png", False),
    "char/boot":        ("boot.png", False),
}

BOX_RE = re.compile(r"^BOX (\S+) ([-\d.]+) ([-\d.]+) ([-\d.]+) ([-\d.]+)")

# --- PER-REGION BODY PARTS ------------------------------------------------------------
#
# costume_palette() repaints the outfit per venue across five colours, so the body cannot
# be one sprite and cannot be one tint. Each region becomes its own GREYSCALE mask, blitted
# over the same box with that region's live colour.
#
# WHICH PIXELS BELONG TO WHICH REGION IS ANSWERED BY THE GAME, NOT BY ME. `--charid` makes
# costume_palette return saturated primaries no costume contains, so a second render is a
# region ID map and classification is a nearest-colour test between maximally separated
# points rather than an attempt to split two similar browns.
#
# key -> (filename, ID colour in the --charid render)
REGIONS = {
    "char/torso_suit":   ("torso_suit.png",   (255, 0, 0)),
    "char/torso_collar": ("torso_collar.png", (255, 255, 0)),
    "char/torso_vest":   ("torso_vest.png",   (0, 0, 255)),
    # The buttons are NOT costume-derived - Color(0.34, 0.20, 0.11) is a literal - so they
    # keep their own colour and are matched by it. Baking them into the vest mask instead
    # would have let the waistcoat's tint repaint the buttons at every venue.
    "char/torso_button": ("torso_button.png", (87, 51, 28)),
    # Trousers are `suit_dk`, so they carry that region's ID rather than a trouser one.
    "char/legs_trouser": ("legs_trouser.png", (0, 255, 0)),
}
ID_MAX_DIST = 90.0   # a pixel further than this from every ID colour is an overlay, not a region


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


def snap(rgb: np.ndarray, pal: np.ndarray) -> np.ndarray:
    flat = rgb.reshape(-1, 3)
    d = np.linalg.norm(srgb_to_oklab(flat)[:, None, :] - srgb_to_oklab(pal)[None, :, :], axis=2)
    return pal[np.argmin(d, axis=1)].reshape(rgb.shape)


def main() -> None:
    d = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    boxes = {}
    for line in (d / "boxes.txt").read_text(errors="replace").splitlines():
        m = BOX_RE.match(line.strip())
        if m:
            boxes[m.group(1)] = tuple(float(x) for x in m.groups()[1:])
    if not boxes:
        raise SystemExit("no BOX lines - did the run include --artboxes?")

    src = np.asarray(Image.open(d / "juggler.png").convert("RGB")).astype(np.int64)

    # THE ISOLATION DIFFERENCE. juggler_off.png is the same figure rendered with
    # --charsuppress, i.e. with every char/* element claimed by the seam and drawn as
    # nothing. Pixels that differ between the two images are exactly the pixels those
    # elements produced, so a part's own art can be lifted out without cropping in
    # whatever happened to sit behind it. This matters: the head is drawn OVER the shirt
    # collar, so its bounding box contains collar in every corner the head does not cover,
    # and a plain crop bakes a white notch under the chin into the sprite.
    off_path = d / "juggler_off.png"
    own = None
    if off_path.exists():
        off = np.asarray(Image.open(off_path).convert("RGB")).astype(np.int64)
        if off.shape == src.shape:
            own = np.abs(src - off).sum(axis=2) > BG_TOL

    pal = np.array([[int(h[i:i + 2], 16) for i in (1, 3, 5)]
                    for h in json.loads(PALETTE.read_text())["hex"]])
    OUT.mkdir(parents=True, exist_ok=True)

    rows = []
    for key, (fname, tinted) in PARTS.items():
        if key not in boxes:
            rows.append((key, "not reached this run", "", ""))
            continue
        x, y, w, h = boxes[key]
        x0, y0 = int(round(x)), int(round(y))
        x1, y1 = int(round(x + w)), int(round(y + h))
        crop = src[y0:y1, x0:x1].astype(np.float64)
        if own is not None:
            mask = own[y0:y1, x0:x1].astype(np.float64)
        else:
            mask = (np.abs(crop - CLEAR).sum(axis=2) > BG_TOL).astype(np.float64)
        if mask.sum() == 0:
            rows.append((key, "empty crop", "", ""))
            continue

        tw, th = max(1, round(w / ART_PIXEL)), max(1, round(h / ART_PIXEL))
        pm = np.concatenate([crop * mask[..., None], mask[..., None] * 255.0], axis=2)
        small = np.asarray(Image.fromarray(pm.astype(np.uint8), "RGBA")
                           .resize((tw, th), Image.BOX)).astype(np.float64)
        aa = small[..., 3] / 255.0
        with np.errstate(invalid="ignore", divide="ignore"):
            rgb = np.where(aa[..., None] > 0,
                           small[..., :3] / np.maximum(aa, 1e-6)[..., None], 0)
        keep = aa >= ALPHA_CUT
        rgb = snap(np.clip(np.round(rgb), 0, 255).astype(int), pal)

        if tinted:
            lum = 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]
            lit = lum[keep]
            if lit.size:
                t = (lum - lit.min()) / max(1e-6, lit.max() - lit.min())
                lum = (GREY_FLOOR + (1.0 - GREY_FLOOR) * t) * 255.0
            rgb = np.repeat(np.clip(lum, 0, 255)[..., None], 3, axis=2)

        # STRIP A BLED-IN EDGE ROW. The isolation difference removes everything the part
        # did not touch, but not everything it touched and does not OWN: the head's
        # antialiased lower edge blends over the white cravat, so those blended pixels
        # differ between the two renders and survive as an all-white row across the bottom
        # of the sprite - visible in game as a pale band under the chin.
        # This is a heuristic and is deliberately a narrow one: only the outermost rows,
        # only while they are near-white, and only until a row is not. A face has no
        # all-white row, and the two things that can bleed into a head box from below are
        # the cravat and the shirt collar.
        #
        # The row is CLEARED, never removed. art_blit_size stretches the texture to the
        # box the game asked for, so a 27x26 sprite in a 54x54 box would scale 2.0 across
        # and 2.077 down - fractional, and fractional scaling is precisely what makes
        # pixel art mush. The canvas size is part of the contract; only its contents move.
        if not tinted:
            near_white = (rgb.min(axis=2) > 225) & keep
            idx = list(range(th))
            for seq in (idx, idx[::-1]):
                for row in seq:
                    lit = int(keep[row].sum())
                    if lit == 0:
                        continue
                    if int(near_white[row].sum()) < 0.8 * lit:
                        break
                    keep[row] = False

        out = np.concatenate([rgb, np.where(keep, 255, 0)[..., None]], axis=2).astype(np.uint8)
        Image.fromarray(out, "RGBA").save(OUT / fname)
        rows.append((key, f"{int(w)}x{int(h)}", f"{tw}x{th}", "grey" if tinted else "colour"))

    # --- per-region body parts -------------------------------------------------------
    idp = d / "juggler_id.png"
    if idp.exists():
        idm = np.asarray(Image.open(idp).convert("RGB")).astype(np.float64)
        ids = np.array([v[1] for v in REGIONS.values()], dtype=np.float64)
        dist = np.linalg.norm(idm[:, :, None, :] - ids[None, None, :, :], axis=3)
        which = np.argmin(dist, axis=2)
        near = dist.min(axis=2) <= ID_MAX_DIST

        # THE BUTTONS NEED A GUARD THE SATURATED IDS DO NOT. Every other region is painted
        # a primary no costume contains, so nearest-colour classification is unambiguous.
        # The buttons keep their real colour, Color(0.34, 0.20, 0.11), and the jacket's
        # antialiased outer edge fades from red toward the dark field straight THROUGH
        # that brown - so the raw match picks up a thin outline down the coat. Buttons are
        # drawn on the waistcoat, so intersecting with a dilated vest mask removes the
        # edge without touching a single real button pixel.
        vest_i = list(REGIONS).index("char/torso_vest")
        vest_m = (which == vest_i) & near
        grown = vest_m.copy()
        for _ in range(3):
            g = grown
            grown = (g | np.roll(g, 1, 0) | np.roll(g, -1, 0)
                     | np.roll(g, 1, 1) | np.roll(g, -1, 1))

        for ri, (key, (fname, _idc)) in enumerate(REGIONS.items()):
            if key not in boxes:
                rows.append((key, "not reached", "", ""))
                continue
            x, y, w, h = boxes[key]
            x0, y0 = int(round(x)), int(round(y))
            x1, y1 = int(round(x + w)), int(round(y + h))
            m = (which == ri) & near
            if key == "char/torso_button":
                m = m & grown
            mask = m[y0:y1, x0:x1]
            if mask.sum() == 0:
                rows.append((key, "no pixels", "", ""))
                continue
            crop = src[y0:y1, x0:x1].astype(np.float64)

            # THE VALUE IS A RATIO, NOT A NORMALISATION. The sprite is multiplied by the
            # live costume colour at draw time, so what it has to store is "how much of
            # the base colour is here" - 1.0 on flat cloth, less where the drawing already
            # shaded it. Dividing by the region's MODAL colour (the flat base, by far the
            # most common pixel) reproduces the original exactly wherever it is flat, and
            # darkens correctly where the procedural version had a shadow or a fold.
            # Normalising min-to-max instead would invent contrast that was never there
            # and would make a flat region come out as noise.
            lum = 0.2126 * crop[..., 0] + 0.7152 * crop[..., 1] + 0.0722 * crop[..., 2]
            vals = np.round(lum[mask]).astype(int)
            base = float(np.bincount(np.clip(vals, 0, 255)).argmax())
            v = np.clip(lum / max(base, 1e-6), 0.0, 1.0) * 255.0

            tw, th = max(1, round(w / ART_PIXEL)), max(1, round(h / ART_PIXEL))
            a = mask.astype(np.float64)
            pm = np.stack([v * a, v * a, v * a, a * 255.0], axis=2).astype(np.uint8)
            small = np.asarray(Image.fromarray(pm, "RGBA")
                               .resize((tw, th), Image.BOX)).astype(np.float64)
            aa = small[..., 3] / 255.0
            keep = aa >= ALPHA_CUT
            with np.errstate(invalid="ignore", divide="ignore"):
                g = np.where(aa > 0, small[..., 0] / np.maximum(aa, 1e-6), 0)
            g = np.clip(g, 0, 255)
            out = np.stack([g, g, g, np.where(keep, 255, 0)], axis=2).astype(np.uint8)
            Image.fromarray(out, "RGBA").save(OUT / fname)
            rows.append((key, f"{int(w)}x{int(h)}", f"{tw}x{th}", "region"))
    else:
        print("(no juggler_id.png - skipping per-region body parts; run with --charid)")

    print(f"{'key':<20} {'render':>10} {'sprite':>8}  mode")
    for k, a, b, c in rows:
        print(f"{k:<20} {a:>10} {b:>8}  {c}")
    print("\nmanifest lines:")
    for k, a, b, c in rows:
        if b:
            fn = PARTS[k][0] if k in PARTS else REGIONS[k][0]
            print(f'  "{k}": {{ "path": "res://Assets/Characters/{fn}" }},')


if __name__ == "__main__":
    main()
