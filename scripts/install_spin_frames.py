#!/usr/bin/env python3
"""The performer's TURNAROUND: eight painted rotations, one per eighth of a Spin.

WHY THIS EXISTS. A live Spin used to be faked by scaling the body's width by cos(angle)
about its own centreline - full width facing front, a sliver at the profile, mirrored
width facing away. That is a reasonable trick for a figure drawn in code and a poor one
for a painting: the "back" of the turn is the FRONT view mirrored, so his lapels, his
bow tie and his face stay on him the whole way round, and at the profile the clamp
(`absf(sx) < 0.14`) leaves a 14%-wide vertical smear that reads as a stick rather than
as a man edge-on. Measured on a Circus capture at 6-frame intervals, one frame of every
Spin is that smear.

WHERE THE ART COMES FROM. PixelLab's `create_character` in v3 mode takes an existing
sprite as `reference_image_base64` and rotates THAT SPRITE into eight directions - it is
the one call in the API that turns a character you already have into a full turnaround,
and it is what Louis meant by "i believe they have a special button for that". The
reference handed to it was not a generation: it is the game's own performer, composited
here from `juggle_body.png` plus the two arm-atlas cells nearest reach 30, i.e. exactly
what the game draws when his hands are at rest. So the turn is of the man on stage, and
`create_character_state` on the same character is what produced the seven venue
costumes, each of which gets its own eight rotations for free.

THREE THINGS THIS SCRIPT HAS TO GET RIGHT:

1. THE PALETTE. Rotations come back outside the locked 48 (v3 has no palette forcing),
   so every frame is snapped in Oklab. No dithering: a figure is not a backdrop, and
   error diffusion across a 12px face is speckle. This is the same nearest-colour rule
   the arm layers already use.

2. THE AXIS. Each frame is 84x164, but the INK is not centred the same way in all eight
   - a coat that flares forward at the front view is edge-on at the profile, so aligning
   whole-ink bounding boxes slides the man sideways as he turns, and a pirouette that
   drifts across the stage reads as a stumble. He is aligned on his HEAD instead, which
   is the one part of a figure that genuinely stays on the axis of a turn. The head is
   found as the ink of the top 22 rows (crown to chin, measured off juggle_body.png's own
   `_FIGURE.head_bottom` of 0.2317 x 164 = 38 rows, taken shorter here so a collar cannot
   join in).

3. THE FEET. Every frame keeps its own last ink row on the canvas bottom, so the figure
   stands on the same line at every angle. Cropping to a shared box instead would let a
   frame whose coat hangs lower push him up off the boards for an eighth of a turn.

Output: Assets/Characters/showman/spin/<dir>.png plus a `_SPIN` block for the manifest.

    scripts/install_spin_frames.py <rotations_dir> [--out <name>] [--write] [--force]

<rotations_dir> holds south.png, south-west.png, ... as downloaded from the character's
rotation URLs. --out names a subdirectory under Assets/Characters/ (default
"showman/spin"), which is how a venue costume installs its own turn.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from derive_stage_props import load_palette, snap  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent

# ONE FULL TURN, in the order a body actually passes through it. PixelLab names its
# directions for a top-down camera; on this side-on stage "south" is facing the audience
# and "north" is facing away, so the list below is simply front -> right profile -> back
# -> left profile -> front. Reversing it turns him the other way and nothing else changes.
TURN = ["south", "south-east", "east", "north-east",
        "north", "north-west", "west", "south-west"]

# How many rows from the crown count as "the head" when solving the axis. 22 of 164, where
# _FIGURE puts the chin at 38: deliberately short of it, because a wing collar and the
# lapels below it are wider than a skull and swing with the coat (the same trap recorded
# for the arm rig's own neck measurement).
HEAD_ROWS = 22


def head_cx(a: np.ndarray) -> float:
    """The horizontal centre of the figure's head, in canvas pixels."""
    ink = a[..., 3] > 127
    band = ink[:HEAD_ROWS]
    xs = np.where(band.any(axis=0))[0]
    if xs.size == 0:                       # no head found: fall back to the whole ink
        xs = np.where(ink.any(axis=0))[0]
    return float(xs.min() + xs.max()) * 0.5


def load_frames(src: Path) -> dict:
    out = {}
    for d in TURN:
        p = src / f"{d}.png"
        if not p.exists():
            raise SystemExit(f"missing rotation: {p}")
        out[d] = np.array(Image.open(p).convert("RGBA"))
    return out


def build(src: Path) -> tuple[dict, dict]:
    frames = load_frames(src)
    pal = load_palette()

    # the axis every frame is aligned to: the FRONT view's own head centre, so the
    # shipped still and the first frame of the turn agree exactly
    axis = head_cx(frames["south"])
    h, w = frames["south"].shape[:2]

    out, report = {}, {}
    for d in TURN:
        a = frames[d]
        if a.shape[:2] != (h, w):
            raise SystemExit(f"{d}: {a.shape[1]}x{a.shape[0]} != {w}x{h} - rotations must share a canvas")
        ink = a[..., 3] > 127
        dx = int(round(axis - head_cx(a)))
        ys = np.where(ink.any(axis=1))[0]
        dy = (h - 1) - int(ys.max())        # feet on the canvas bottom, every frame

        moved = np.zeros_like(a)
        for y in range(h):
            sy = y - dy
            if not (0 <= sy < h):
                continue
            for x in range(w):
                sx = x - dx
                if 0 <= sx < w:
                    moved[y, x] = a[sy, sx]

        rgb = moved[..., :3].astype(float)
        snapped = moved.copy()
        snapped[..., :3] = snap(rgb.reshape(-1, 3), pal).reshape(rgb.shape)
        snapped[..., 3] = np.where(moved[..., 3] > 127, 255, 0)
        snapped[snapped[..., 3] == 0] = 0            # a locked palette wants clean holes

        out[d] = snapped
        report[d] = {"dx": dx, "dy": dy,
                     "colours": len({tuple(c) for c in snapped[snapped[..., 3] > 0][..., :3]})}
    return out, report


def main() -> int:
    argv = sys.argv[1:]
    if not argv:
        raise SystemExit(__doc__)
    src = Path(argv[0])
    name = "showman/spin"
    if "--out" in argv:
        name = argv[argv.index("--out") + 1]
    out_dir = ROOT / "Assets" / "Characters" / name

    frames, report = build(src)
    for d, a in frames.items():
        ink = (a[..., 3] > 0).sum()
        print(f"{d:>11}  shift {report[d]['dx']:+3d},{report[d]['dy']:+3d}  "
              f"{report[d]['colours']:2d} colours  {ink:5d} px")

    block = {"dirs": TURN, "cell": [int(frames["south"].shape[1]), int(frames["south"].shape[0])]}
    print("\n_SPIN block for the manifest:")
    print(json.dumps({"_SPIN": block}, indent=2))
    print("keys:")
    for d in TURN:
        print(f'  "char/spin_{d.replace("-", "_")}": '
              f'{{"path": "res://Assets/Characters/{name}/{d}.png"}},')

    if "--write" in argv:
        out_dir.mkdir(parents=True, exist_ok=True)
        for d, a in frames.items():
            Image.fromarray(a, "RGBA").save(out_dir / f"{d}.png")
        print(f"\nwrote {len(frames)} frames -> {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
