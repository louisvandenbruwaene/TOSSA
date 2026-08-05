#!/usr/bin/env python3
"""Derive PIXELTOSSA's locked palette from TOSSA's own colours.

WHY THIS EXISTS. Every asset in this fork is generated, and the single thing most
likely to make generated art look like a different game is colour. PixelLab accepts
a "colour image" whose pixels become a forced palette, so if we can state TOSSA's
palette as a PNG, every prop, limb and backdrop comes back already in the game's own
register instead of in whatever amber the model felt like.

TWO SOURCES, DELIBERATELY, because they disagree and both are right:

  1. The Color(...) literals in Game.gd - roughly 1300 of them. This is the
     designer's INTENT, stated explicitly, and its frequency is meaningful: a colour
     written 40 times is load-bearing and a colour written once is a detail.

  2. Real rendered frames. This is what a player SEES, which is not the same thing:
     the literals never mention the warm haze the spotlight lays over the whole
     stage, the gradient falloffs, or any alpha blend. Cluster only the literals and
     the palette comes out too clean and too saturated to match a screenshot.

CLUSTERING HAPPENS IN OKLAB, NOT RGB. Euclidean distance in sRGB is not perceptual.
A k-means run in RGB spends clusters splitting dark browns that a human reads as one
colour, and collapses the amber-vs-crimson distinction that actually carries this
game's identity. Oklab is cheap (the transform below is ~15 lines) and fixes both.

OUTPUTS, all into Resources/palette/:
  palette.png   the forced-palette image handed to PixelLab
  palette.gpl   a GIMP palette - Aseprite loads these directly, so Louis's hand
                edits stay inside the same colours the generator used
  palette.json  machine-readable, for any script that needs the list
  swatch.png    a big labelled grid, purely to look at

USAGE
  .venv/bin/python scripts/extract_palette.py [--colors 48]
"""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from pathlib import Path

import numpy as np
from PIL import Image
from sklearn.cluster import KMeans

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Resources" / "palette"

# A screenshot's own frequencies are enormous next to a source literal's, so the two
# sources are normalised to sum to these weights instead of being merged raw. The
# literals lead because they are intent; the frames matter because they are truth.
W_LITERALS = 0.6
W_FRAMES = 0.4

COLOR_RE = re.compile(
    r"Color\(\s*([0-9.]+)\s*,\s*([0-9.]+)\s*,\s*([0-9.]+)\s*(?:,\s*[0-9.]+\s*)?\)"
)


def srgb_to_linear(c: np.ndarray) -> np.ndarray:
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(c: np.ndarray) -> np.ndarray:
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.clip(c, 0, None) ** (1 / 2.4) - 0.055)


def rgb_to_oklab(rgb: np.ndarray) -> np.ndarray:
    """sRGB 0..1 -> Oklab. Bjorn Ottosson's matrices, unchanged."""
    r, g, b = srgb_to_linear(rgb).T
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l_, m_, s_ = np.cbrt(l), np.cbrt(m), np.cbrt(s)
    return np.stack([
        0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
        1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
        0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_,
    ], axis=-1)


def oklab_to_rgb(lab: np.ndarray) -> np.ndarray:
    L, a, b = lab.T
    l_ = L + 0.3963377774 * a + 0.2158037573 * b
    m_ = L - 0.1055613458 * a - 0.0638541728 * b
    s_ = L - 0.0894841775 * a - 1.2914855480 * b
    l, m, s = l_ ** 3, m_ ** 3, s_ ** 3
    lin = np.stack([
        +4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
        -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
        -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
    ], axis=-1)
    return np.clip(linear_to_srgb(lin), 0.0, 1.0)


def from_literals(game_gd: Path) -> Counter:
    """Color(r,g,b[,a]) -> counts, keyed by RGB only.

    Alpha is dropped on purpose. The same rgb written at four alphas is one PIGMENT
    used at four strengths, and a palette wants the pigment. Keeping alpha would have
    filled the palette with near-duplicates of whatever colour gets faded most.
    """
    counts: Counter = Counter()
    text = game_gd.read_text(encoding="utf-8", errors="replace")
    for m in COLOR_RE.finditer(text):
        rgb = tuple(min(1.0, float(x)) for x in m.groups())
        counts[rgb] += 1
    return counts


def from_frames(paths: list[Path]) -> Counter:
    """Pixel colours from real captures, quantised to 5 bits per channel.

    The quantisation is what makes this tractable and is not a loss: a 1280x720 frame
    holds ~900k pixels and tens of thousands of distinct gradient steps, and clusters
    are about to be fitted anyway. 32 levels per channel is finer than the clustering
    that follows, so nothing a human could see is thrown away here.
    """
    counts: Counter = Counter()
    for p in paths:
        img = Image.open(p).convert("RGB")
        arr = np.asarray(img, dtype=np.uint8).reshape(-1, 3)
        q = (arr >> 3) << 3
        uniq, n = np.unique(q, axis=0, return_counts=True)
        for c, k in zip(uniq, n):
            counts[tuple(float(v) / 255.0 for v in c)] += int(k)
    return counts


def merge(lit: Counter, frm: Counter) -> tuple[np.ndarray, np.ndarray]:
    total_l = sum(lit.values()) or 1
    total_f = sum(frm.values()) or 1
    pool: dict[tuple, float] = {}
    for c, n in lit.items():
        pool[c] = pool.get(c, 0.0) + W_LITERALS * n / total_l
    for c, n in frm.items():
        pool[c] = pool.get(c, 0.0) + W_FRAMES * n / total_f
    cols = np.array(list(pool.keys()), dtype=np.float64)
    wts = np.array(list(pool.values()), dtype=np.float64)
    return cols, wts


def order_for_humans(rgb: np.ndarray) -> np.ndarray:
    """Sort into ramps: greys by lightness first, then chromatic colours by hue.

    A palette file is read by a person in Aseprite, and a k-means output order is
    arbitrary. Grouping by hue and running each group light-to-dark is what makes a
    ramp visible, which is the whole reason to look at a palette at all.
    """
    lab = rgb_to_oklab(rgb)
    L, a, b = lab[:, 0], lab[:, 1], lab[:, 2]
    chroma = np.hypot(a, b)
    hue = np.arctan2(b, a)
    grey = chroma < 0.02
    hue_bin = np.floor((hue + np.pi) / (2 * np.pi) * 12).astype(int)
    key = np.where(grey, -1, hue_bin)
    return np.lexsort((-L, key))


def write_gpl(path: Path, rgb255: np.ndarray, name: str) -> None:
    lines = [f"GIMP Palette", f"Name: {name}", "Columns: 8",
             "# Generated by scripts/extract_palette.py from TOSSA's own colours.",
             "# Load in Aseprite: Palette menu > Load Palette.", "#"]
    for r, g, b in rgb255:
        lines.append(f"{r:3d} {g:3d} {b:3d}\t#{r:02x}{g:02x}{b:02x}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--colors", type=int, default=48)
    ap.add_argument("--frames", nargs="*", default=None,
                    help="PNG captures to sample; defaults to artifacts/palette_frames/*.png")
    args = ap.parse_args()

    lit = from_literals(ROOT / "Game.gd")
    frame_dir = ROOT / "artifacts" / "palette_frames"
    paths = [Path(p) for p in args.frames] if args.frames else sorted(frame_dir.glob("*.png"))
    frm = from_frames(paths) if paths else Counter()

    print(f"literals: {len(lit)} distinct rgb from {sum(lit.values())} Color(...) calls")
    print(f"frames:   {len(frm)} distinct rgb from {len(paths)} capture(s)")
    if not paths:
        print("  (no frames found - palette is intent-only; see the module docstring)")

    cols, wts = merge(lit, frm)
    lab = rgb_to_oklab(cols)

    km = KMeans(n_clusters=min(args.colors, len(cols)), n_init=10, random_state=0)
    km.fit(lab, sample_weight=wts)

    # Snap each centroid to the REAL colour nearest it rather than shipping the mean.
    # A mean is a colour nobody chose; the nearest real one is a colour the game
    # actually uses, and on a small palette that difference is visible.
    centers = km.cluster_centers_
    chosen = []
    for c in centers:
        d = np.linalg.norm(lab - c, axis=1)
        chosen.append(int(np.argmin(d)))
    rgb = cols[sorted(set(chosen))]

    rgb = rgb[order_for_humans(rgb)]
    rgb255 = np.round(rgb * 255).astype(int)

    OUT.mkdir(parents=True, exist_ok=True)
    n = len(rgb255)
    Image.fromarray(rgb255.astype(np.uint8).reshape(1, n, 3), "RGB").save(OUT / "palette.png")
    write_gpl(OUT / "palette.gpl", rgb255, "PIXELTOSSA")
    (OUT / "palette.json").write_text(json.dumps(
        {"count": n, "hex": ["#%02x%02x%02x" % tuple(c) for c in rgb255],
         "rgb01": [[round(float(v), 4) for v in c] for c in rgb]}, indent=2), encoding="utf-8")

    cell, cols_n = 48, 8
    rows = (n + cols_n - 1) // cols_n
    sw = Image.new("RGB", (cols_n * cell, rows * cell), (18, 12, 16))
    for i, c in enumerate(rgb255):
        x, y = (i % cols_n) * cell, (i // cols_n) * cell
        sw.paste(tuple(int(v) for v in c), (x, y, x + cell - 2, y + cell - 2))
    sw.save(OUT / "swatch.png")

    print(f"\nwrote {n} colours to {OUT.relative_to(ROOT)}/")
    for i in range(0, n, 8):
        print("  " + "  ".join("#%02x%02x%02x" % tuple(c) for c in rgb255[i:i + 8]))


if __name__ == "__main__":
    main()
