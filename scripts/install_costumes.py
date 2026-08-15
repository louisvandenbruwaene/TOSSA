#!/usr/bin/env python3
"""THE SEVEN VENUE COSTUMES: one painted performer per house, plus his turnaround.

Louis, 2026-08-15: "create costumes for all stages with pixeltossa, give it the decor or
palette and tell it to give something that would fit a juggler in that venue: do make sure
to keep the current design for one of the venues."

WHERE THE ART COMES FROM. `create_character_state` takes an existing PixelLab character and
applies a wardrobe edit across all eight of its rotations while preserving the same
individual's face, body and proportions. That is the whole reason the costumes are usable:
they are not seven generated jugglers, they are one juggler photographed seven times in
different clothes, so every landmark in `_FIGURE` still describes all of them. The source
character is the game's own performer (see install_spin_frames.py).

THE CIRCUS IS THE ONE THAT DOES NOT MOVE. Its costume is the shipped crimson ringmaster's
tailcoat, untouched, still with its hand-built arm bank - Louis's "keep the current design
for one of the venues", and a ringmaster belongs in a circus tent. This script therefore
installs SIX costumes and leaves venue 3 alone.

THE COLOURS ARE NOT INVENTED HERE. `venue_data` has carried a five-colour costume palette
per venue since long before any of this was painted - brown and tan at the Backyard, slate
blue on the street, crimson and gold at the theatre, navy at the Championship, purple and
gold at the Arena, near-black with a phosphor-green waistcoat at the Midnight Show. The
prompts were written to those colours, so every swatch already in the tailor's rack, every
`costume_palette()` reader and the Glow Kit's whole reason for existing still line up with
what is now painted. A costume that ignored them would have made the rack lie.

WHAT IT WRITES, per costume:
  Assets/Characters/<venue>/figure.png       the still, 84x164, palette-snapped
  Assets/Characters/<venue>/spin/<dir>.png   eight frames of his turn

and prints the manifest block for each. The stills go in as `char/figure`, which is the
seam's own key for a whole painted performer.

    scripts/install_costumes.py <costumes_dir> [--write] [--force]

<costumes_dir> holds one subdirectory per venue key, each with the eight rotation PNGs.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from derive_stage_props import load_palette, snap  # noqa: E402
from install_spin_frames import TURN, build as build_spin  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent

# venue index -> (directory key, the name venue_data gives it). Index 3, The Circus, is
# absent on purpose: it keeps the shipped showman.
COSTUMES = {
    0: ("backyard", "Backyard"),
    1: ("street_corner", "Street Corner"),
    2: ("small_theatre", "Small Theatre"),
    4: ("championship", "Championship"),
    5: ("world_arena", "World Arena"),
    6: ("midnight_show", "The Midnight Show"),
}


def snap_frame(a: np.ndarray, pal: np.ndarray) -> np.ndarray:
    """Into the locked 48, nearest colour, NO dithering.

    Error diffusion is right for a backdrop and wrong for a person: it is designed to
    scatter residual across neighbours, and scattered residual over a 12px face is
    speckle - the same reason the arm layers snap by set membership rather than by
    diffusing. See CLAUDE.md's ordered-dither-vs-error-diffusion note.
    """
    out = a.copy()
    rgb = a[..., :3].astype(float)
    out[..., :3] = snap(rgb.reshape(-1, 3), pal).reshape(rgb.shape)
    out[..., 3] = np.where(a[..., 3] > 127, 255, 0)
    out[out[..., 3] == 0] = 0            # clean holes: a locked palette has no half-alpha
    return out


def figure_of(src: Path, pal: np.ndarray) -> tuple[np.ndarray, dict]:
    """The still, cropped to its own ink and snapped.

    Cropped rather than left on the rotation's canvas because `char/figure` is blitted
    centred with its feet on the standing line, so any transparent margin it carries is a
    silent offset - and the margin differs per costume, because a tailcoat is wider than a
    shirt.
    """
    a = np.array(Image.open(src / "south.png").convert("RGBA"))
    ink = a[..., 3] > 127
    ys, xs = np.where(ink)
    a = a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    return snap_frame(a, pal), {"w": int(a.shape[1]), "h": int(a.shape[0])}


def main() -> int:
    argv = sys.argv[1:]
    if not argv:
        raise SystemExit(__doc__)
    src_root = Path(argv[0])
    write = "--write" in argv
    pal = load_palette()

    manifest = {}
    for vi, (key, name) in sorted(COSTUMES.items()):
        src = src_root / key
        if not src.is_dir():
            print(f"[skip] {key}: no rotations at {src}")
            continue
        fig, meta = figure_of(src, pal)
        spin, _ = build_spin(src)
        cols = len({tuple(c) for c in fig[fig[..., 3] > 0][..., :3]})
        print(f"venue {vi}  {name:<18} figure {meta['w']}x{meta['h']}  "
              f"{cols:2d} colours  + {len(spin)} turn frames")

        out_dir = ROOT / "Assets" / "Characters" / key
        manifest[key] = {
            "char/figure": {"path": f"res://Assets/Characters/{key}/figure.png"},
            **{f"char/spin_{d.replace('-', '_')}":
               {"path": f"res://Assets/Characters/{key}/spin/{d}.png"} for d in TURN},
        }
        if write:
            (out_dir / "spin").mkdir(parents=True, exist_ok=True)
            Image.fromarray(fig, "RGBA").save(out_dir / "figure.png")
            for d, a in spin.items():
                Image.fromarray(a, "RGBA").save(out_dir / "spin" / f"{d}.png")

    if write:
        print(f"\nwrote {len(manifest)} costumes")
    print("\nmanifest fragments:")
    print(json.dumps(manifest, indent=2)[:400] + " ...")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
