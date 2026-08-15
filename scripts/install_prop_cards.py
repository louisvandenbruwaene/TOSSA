#!/usr/bin/env python3
"""Install and repair the painted prop cards (prop_big/*), the SOURCE every prop derives from.

Two unrelated jobs land in one script because they are the same pipeline stage: whatever this
writes into Assets/Props/big_*.png is what derive_stage_props.py then reduces into the stage
sprite, and what mark_prop bakes the title wordmark from. Fix a card and all three follow.

=====================================================================================
1. THE COOL-DARK TRAP, and why it is a rule and not a one-off repair (2026-08-15)
=====================================================================================
THE LOCKED 48 IS A WARM PALETTE WITH A COOL BASEMENT. Ranked by luminance, its darkest
entries are #241a14, #1f1a2e, #141a17, #170f12 - and #1f1a2e is INDIGO (31,26,46), sitting
one step from #241a14 in Oklab. There is no warm mid-dark NEUTRAL grey at all. That is a
deliberate property of a warm theatre palette and it is right for the backdrops: the night
skies over the Backyard, the Street Corner and the World Arena are 15-19% indigo and could
not be painted without it.

It is wrong for a PROP, and the failure is invisible until you measure it. Anything with a
dark rim - which is every generated object, because a generator outlines by default - has
that rim snapped to the nearest palette entry, and for a near-black neutral the nearest
entry is the indigo. Measured across Assets/:

    big_chainsaw   33% indigo + 4% lavender     chainsaw   32% + 4%
    big_torch      27% indigo                   torch      45% indigo
    big_torch_body 52% indigo                   knife       3% + 9% navy

A third of the chainsaw is indigo, and it is the whole outline. At the card's own size that
is a violet fringe round an orange saw; at stage size, where the sprite is 35 art pixels of
which 32% are rim, the prop reads as PURPLE in flight. Half the torch body is indigo, which
is most of why it read as a cold grey stick with no material.

**A BACKDROP MAY USE THE WHOLE PALETTE; A PROP MAY NOT.** A prop is a small warm object
seen against warm light, and it has no sky in it, so the cool sixth of the palette is not a
colour it can legitimately need. `snap_warm` below drops those entries from the candidate
set before the nearest-colour search, which sends a near-black rim to #170f12 (a warm
near-black at almost exactly the indigo's luminance) instead. The luminances differ by 11.6
of 255, so the repair is invisible AS A VALUE CHANGE and total as a HUE change - which is
the signature of a snap bug rather than an art choice, and the reason this is safe to apply
to art already on disk.

=====================================================================================
2. THE CLUB AND THE TORCH ARE REPAINTED
=====================================================================================
THE CLUB'S HANDLE WAS THREE PIXELS WIDE. Measured on the stage sprite: a body 13 art px
across dropping to a handle of 3 over five rows, then a 6px knob. That is not a taper, it is
a stick glued to a bulb, and it reads as a lollipop - which is the last thing the game's
signature prop should read as, given it is also the A in the title wordmark. The repaint
keeps the design (crimson body, two gold bands, bone handle, round knob) and gives the
handle real width so it flows out of the body.

THE TORCH WAS HALF INDIGO AND NINE PIXELS WIDE, a dark stick with no readable parts next to
a club and a knife that both have material. The repaint gives it what a juggling torch
actually has: a bound cream wick head, a narrow brass collar, a dark iron shaft and a
leather grip with brass rings.

**THE MODEL WILL NOT PAINT AN UNLIT TORCH.** Three prompts, each one saying unlit / no flame
/ no fire in as many words, and all three came back burning. It is the same class of thing
as the fake handwriting the ground cleaner exists for: the model knows what a torch is for.
So the flame is CROPPED here rather than prompted away, which is cheap and exact - the
flame is a contiguous orange block above the wick and the cut row is measured, not guessed.
It has to go, because the game draws the flame itself (`_TORCH` in the manifest, animated,
reacting to play) and a painted one would be a second static flame under the real one.

**AND THE FLAME IS NOT CROPPED HERE AFTER ALL** - see the REPAINTS table. derive_stage_props
already owns that job, does it by colour rather than by a hand-picked row, and needs the fire
present in order to publish where it was. This script's only duty is to hand it a good card.

THE OUTLINE COMES OFF. Locked decision 3 is selective or no outlines, never a thick black
16-bit rim, and `create_image_pixen` draws one whatever the `outline` argument says - the
club came back with 184 of its 186 edge pixels at (3,3,4) under both `selective outline` and
`lineless`. `deoutline` replaces each rim pixel with a darkened sample of the neighbour just
inside it, so the object keeps a contour in ITS OWN material instead of a black ring.

USAGE
  .venv/bin/python scripts/install_prop_cards.py              report only
  .venv/bin/python scripts/install_prop_cards.py --write [--force]
  ...then: .venv/bin/python scripts/derive_stage_props.py --write
           make reimport
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

import artguard

ROOT = Path(__file__).resolve().parent.parent
PROPS = ROOT / "Assets" / "Props"
PAINT = ROOT / "artifacts" / "paint"
PALETTE = ROOT / "Resources" / "palette" / "palette.json"

ALPHA_CUT = 40      # below this a source pixel is background, not a soft edge
OUTLINE_LUM = 26.0  # a rim pixel this dark is an outline, not the object's own shadow


def srgb_to_oklab(rgb: np.ndarray) -> np.ndarray:
    c = rgb / 255.0
    c = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    m = np.array([[0.4122214708, 0.5363325363, 0.0514459929],
                  [0.2119034982, 0.6806995451, 0.1073969566],
                  [0.0883024619, 0.2817188376, 0.6299787005]])
    lms = np.cbrt(c @ m.T)
    m2 = np.array([[0.2104542553, 0.7936177850, -0.0040720468],
                   [1.9779984951, -2.4285922050, 0.4505937099],
                   [0.0259040371, 0.7827717662, -0.8086757660]])
    return lms @ m2.T


def warm_palette() -> np.ndarray:
    """The locked 48 minus its cool sixth - the candidate set a PROP may snap into.

    The test is "red is not the dominant channel", and it has to be BOTH halves of that.
    The first cut of this excluded only blue (`b > r + 6`) and the greens walked straight
    through the gap: the palette's #283028 (40,48,40) and #141a17 (20,26,23) are green-cast
    near-blacks, and with the indigo gone they became the new nearest entry for exactly the
    same rim pixels. The knife's blade groove went from navy to TEAL and the torch's iron
    shaft came out olive - a lateral move, not a fix, and one this game notices twice over
    because "no green on stage" is a standing rule of its own.
    So: drop anything where blue OR green leads red by more than 6. That is the seven blues,
    the indigo, the navy, the lavender, the five greens and the two green-blacks. It keeps
    every true neutral (#887870, #b2a699, #4c4238, #e0e0d0 and the rest sit within a point
    or two of neutral), so a steel chainsaw bar and a silver blade still have somewhere to
    land, and it keeps pure white and pure black.
    """
    data = json.loads(PALETTE.read_text())
    pal = np.array([[int(h[i:i + 2], 16) for i in (1, 3, 5)] for h in data["hex"]], dtype=float)
    cool = (pal[:, 2] > pal[:, 0] + 6) | (pal[:, 1] > pal[:, 0] + 6)
    return pal[~cool]


def snap_warm(rgb: np.ndarray, pal: np.ndarray) -> np.ndarray:
    flat = rgb.reshape(-1, 3)
    d = ((srgb_to_oklab(flat)[:, None, :] - srgb_to_oklab(pal)[None, :, :]) ** 2).sum(axis=2)
    return pal[np.argmin(d, axis=1)].reshape(rgb.shape)


def deoutline(a: np.ndarray) -> np.ndarray:
    """Turn a hard dark rim into the object's own dark edge.

    A rim pixel is one on the silhouette's boundary whose luminance is under OUTLINE_LUM.
    It takes the colour of the nearest INTERIOR neighbour, at 55% - dark enough to still
    read as a contour, in the material's own hue rather than in black. Deleting the rim
    instead was tried and is worse: it shrinks the object by a pixel all round, which on a
    48px card costs the club its gold bands' top row.
    """
    out = a.copy()
    op = a[..., 3] > ALPHA_CUT
    lum = 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]
    boundary = np.zeros_like(op)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        sh = np.roll(op, (dy, dx), (0, 1))
        if dy == 1:
            sh[0, :] = False
        if dy == -1:
            sh[-1, :] = False
        if dx == 1:
            sh[:, 0] = False
        if dx == -1:
            sh[:, -1] = False
        boundary |= op & ~sh
    rim = boundary & (lum < OUTLINE_LUM)
    interior = op & ~rim
    ys, xs = np.where(rim)
    for y, x in zip(ys, xs):
        best = None
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                ny, nx = y + dy, x + dx
                if 0 <= ny < a.shape[0] and 0 <= nx < a.shape[1] and interior[ny, nx]:
                    cand = a[ny, nx, :3]
                    if best is None or cand.sum() > best.sum():
                        best = cand
        if best is not None:
            out[y, x, :3] = np.clip(best * 0.55, 0, 255)
    return out


def ink_box(a: np.ndarray):
    op = a[..., 3] > ALPHA_CUT
    ys, xs = np.where(op.any(1))[0], np.where(op.any(0))[0]
    return ys.min(), ys.max(), xs.min(), xs.max()


def place(ink: np.ndarray, w: int, h: int, top: int) -> np.ndarray:
    """Centre `ink` horizontally in a w x h canvas with its first row at `top`."""
    out = np.zeros((h, w, 4), dtype=np.uint8)
    ih, iw = ink.shape[:2]
    ih = min(ih, h - top)
    x0 = (w - iw) // 2
    out[top:top + ih, x0:x0 + iw] = ink[:ih]
    return out


# --------------------------------------------------------------------------------------
# THE TWO REPAINTS
# --------------------------------------------------------------------------------------
# Each entry: source painting, target card, canvas, and where the ink's top row goes.
#
# THE TORCH'S `top` IS `_TORCH.card.base_row` AND MUST STAY 34. The flame is drawn from
# that row upward, so if the wick's top row moves the fire detaches from the torch - it is
# the same number seen from two sides, which is exactly the kind of coupling that breaks
# silently when only one of the two is edited.
REPAINTS = {
    "club": dict(src="club_v2.png", dst="big_club.png", canvas=(48, 96), top=4),
    # THE TORCH TARGETS `big_torch.png`, WITH ITS FLAME ON, and that is not a compromise -
    # it is the architecture. `big_torch.png` is the canonical card; derive_stage_props.py's
    # strip_torch_flame() finds the fire by colour, clears it, writes `big_torch_body.png`,
    # and MEASURES the hole to publish `_TORCH` (base_row / height / half_width) so the game
    # can draw a live animated flame exactly where the painted one was. Writing the body file
    # directly, as the first version of this script did, is therefore worse than useless: the
    # next derive run silently regenerates it from the old card and the repaint vanishes with
    # no error anywhere. Measured - it did, and the report said "card 19x90" for a card whose
    # ink is 11x57.
    #
    # So the painted flame is USEFUL here, not an obstacle: the model's refusal to draw an
    # unlit torch turns out to hand the pipeline exactly the measurement it wants. It also
    # takes the cloth wick with it, because the strip's own test (bright and red-of-blue)
    # catches cream cloth as readily as fire - which is the crop this script used to do by
    # hand, done by the code that already existed for it.
    "torch": dict(src="torch_v3.png", dst="big_torch.png", canvas=(40, 96), top=4, cut=0,
                  drop=(29, 35)),
}

# Cards already on disk that only need the warm re-snap. Nothing is repainted here - the
# drawings are good, their rims are simply the wrong hue.
#
# THE ROUND PROPS ARE NOT HERE, AND PUTTING THEM HERE IS A TRAP I FELL INTO ONCE. ball, egg
# and ring are authored GREYSCALE because the game multiplies them by ball_color(i); a warm
# candidate set has no true neutrals above #887870 (136,120,112), so a warm re-snap moved 66%
# of every round prop's pixels into browns - measured, 1410 of 2128 on the ball alone. Tinted
# afterwards, a warm base times a cool tint is mud, and the whole point of the greyscale rule
# is that the file stores a luminance RATIO and nothing else. They also do not come from this
# pipeline at all: make_round_props.py computes both sizes analytically. Leave them alone.
RESNAP = ["big_chainsaw.png", "big_knife.png"]


def build_repaint(name: str, spec: dict, pal: np.ndarray):
    src = PAINT / spec["src"]
    if not src.exists():
        return None, f"missing {src.relative_to(ROOT)}"
    a = np.asarray(Image.open(src).convert("RGBA")).astype(float)
    if spec.get("cut"):
        a = a[spec["cut"]:]
    if spec.get("drop"):
        # SPLICE A ROW BAND OUT AND CLOSE THE GAP. This exists for one measured defect and
        # is written generally because the cause will recur: a generator draws a part the
        # game does not want, in the MIDDLE of a part it does.
        #
        # The torch's painted head is a plug of bound cream cloth between the flame and the
        # brass collar. derive_stage_props' strip_torch_flame cannot take it - its test is
        # "bright and red-of-blue", and the cloth's own grey-cream pixels (161,147,132) miss
        # the red-of-blue margin by one point, so the strip stops at the top of the plug and
        # leaves it. At eleven pixels across, that plug is two dark eye-shaped notches over a
        # pale muzzle inside a brass ring: it reads unmistakably as a small OWL sitting on
        # the torch, and it was on the shop card at full size.
        #
        # Trimming from the top instead cannot work, because the flame is ABOVE the thing
        # being removed and the flame is the measurement the whole torch pipeline is built
        # to take. So the band comes out of the middle and the picture closes over it: the
        # fire ends up seated directly in the brass cup, which is what a lit juggling torch
        # looks like anyway.
        lo, hi = spec["drop"]
        a = np.concatenate([a[:lo], a[hi + 1:]], axis=0)
    a = deoutline(a)
    y0, y1, x0, x1 = ink_box(a)
    ink = a[y0:y1 + 1, x0:x1 + 1]
    op = ink[..., 3] > ALPHA_CUT
    rgb = ink[..., :3].copy()
    rgb[op] = snap_warm(rgb[op], pal)
    ink = np.dstack([rgb, np.where(op, 255, 0)]).astype(np.uint8)
    w, h = spec["canvas"]
    return place(ink, w, h, spec["top"]), f"ink {ink.shape[1]}x{ink.shape[0]} at row {spec['top']}"


def build_resnap(name: str, pal: np.ndarray):
    p = PROPS / name
    if not p.exists():
        return None, "missing"
    a = np.asarray(Image.open(p).convert("RGBA")).astype(float)
    op = a[..., 3] > ALPHA_CUT
    before = a[..., :3].copy()
    rgb = a[..., :3].copy()
    rgb[op] = snap_warm(rgb[op], pal)
    moved = int((np.abs(rgb - before).sum(axis=2) > 0).sum())
    return (np.dstack([rgb, a[..., 3]]).astype(np.uint8),
            f"{moved} px re-snapped of {int(op.sum())}")


def main() -> None:
    write = "--write" in sys.argv
    force = "--force" in sys.argv
    pal = warm_palette()
    print(f"warm candidate set: {len(pal)} of 48 palette entries\n")

    built = {}
    for name, spec in REPAINTS.items():
        arr, note = build_repaint(name, spec, pal)
        print(f"  repaint {name:10s} -> {spec['dst']:20s} {note}")
        if arr is not None:
            built[spec["dst"]] = arr
    for name in RESNAP:
        arr, note = build_resnap(name, pal)
        print(f"  re-snap {name:20s} {note}")
        if arr is not None:
            built[name] = arr

    if not write:
        out = ROOT / "artifacts" / "propcards"
        out.mkdir(parents=True, exist_ok=True)
        for name, arr in built.items():
            Image.fromarray(arr, "RGBA").save(out / name)
        print(f"\npreviews in {out.relative_to(ROOT)} - --write to install")
        return

    results = {}
    for name, arr in built.items():
        dest = PROPS / name
        im = Image.fromarray(arr, "RGBA")
        results[name] = artguard.save_guarded(dest, lambda p, i=im: i.save(p), force=force)
        print(f"{results[name]:>8}  {dest.relative_to(ROOT)}")
    artguard.report(results)
    print("\nNext: derive_stage_props.py --write, then make reimport.")


if __name__ == "__main__":
    main()
