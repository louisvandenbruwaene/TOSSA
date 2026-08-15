#!/usr/bin/env python3
"""Clone empty room over the centre column of a backdrop painting.

THE DEFECT (2026-08-15). The Midnight Show's backdrop had a supper table and two seated
diners in the MIDDLE of the frame. The performer stands dead centre and is about 86 art px
wide, so in play he stood on the table: his coat covered the seated man completely and the
woman was left reaching across a candle that came out from behind his legs. It is the exact
composition fault pixelise_paint.py's third framing rule exists to prevent - "the centre
column is empty ... a tent pole, a doorway or a tree trunk behind his spine reads as a
mistake" - and it shipped anyway.

WHY THE EXISTING GUARD DID NOT CATCH IT, which is the part worth keeping. `spine_busyness`
measures how much more TEXTURED the spine band is than the rest of the picture, and it read
1.15 against a "clear is around 1.0" baseline - barely above the Championship's own 1.32,
which is fine. It is a good measure of clutter and a blind one for this: a table and two
people, painted in the same tones as the drapes behind them, are no busier than the drapes.
**The thing that makes an object wrong behind the performer is that it is an OBJECT, not
that it is noisy.** A texture statistic cannot see the difference and a person can, so this
takes the column to clear as an argument rather than trying to find it.

WHY CLONE RATHER THAN RE-GENERATE. Both were tried, on the same day. Two fresh 640x360
paintings came back: the first put a table right back in the middle, and the second cleared
the middle but grew a wooden PILLAR with a wall sconce just left of centre and painted two
elliptical light pools onto the floorboards - one violation of the same framing rule and one
of the "no baked light" rule, in a picture asked for in as many words to have neither. The
model has a strong prior that a cabaret room's middle is where you put a table, and prompt
wording did not move it in three attempts.

Meanwhile the painting on disk was the best of the three everywhere ELSE: good drapes, good
tables, a real standable floor band. Cloning fixes the one thing wrong with it and cannot
introduce a second thing, which is the trade a surgical repair always offers. It is the same
call `clean_ground.py` and `trim_plinth.py` already make.

WHY IT IS SAFE HERE SPECIFICALLY. This room is HORIZONTALLY UNIFORM behind its furniture:
hung drapes above, floorboards below, both running the full width. A donor strip of empty
room is therefore a valid stand-in for any other empty column, which is not true of a
picture with real perspective convergence or a directional light gradient. Check that before
reaching for this on another venue.

THE DONOR IS MIRRORED and the joins are CROSS-FADED. Copied straight, a drape's fold pattern
repeats at a fixed offset and the eye finds it immediately - vertical folds are exactly the
kind of regular feature that makes a clone obvious. Mirroring breaks the repeat for free.
The fade is 10 px at each edge and matters more than it sounds: a hard seam between two
columns of dithered velvet is a 1px vertical line running the height of the frame, which is
more visible than the table was.

IT PATCHES THE PAINTING, NOT THE SPRITE. The edit goes into artifacts/paint/<name>.png and
pixelise_paint.py reduces it as usual, so the palette snap, the error diffusion and the
artguard ledger all still happen exactly once and in the right order.

USAGE
  .venv/bin/python scripts/clear_spine.py the_midnight_show --patch 215:350 --donor 360:496
  .venv/bin/python scripts/clear_spine.py the_midnight_show --patch 215:350 --donor 360:496 --write
  ...then: .venv/bin/python scripts/pixelise_paint.py --bg the_midnight_show --write
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "artifacts" / "paint"
FADE = 10


def column_deviation(a: np.ndarray, y0: int = 150, y1: int = 300) -> np.ndarray:
    """How far each column departs from the room's own median column.

    The median over x is "the empty room at this height" - drape above, boards below - so a
    column holding a chair, a candle or a person stands out from it while an empty one does
    not. This is what the report below prints, and it is how the donor range was chosen: it
    reads 18-29 across x 360-500 and 35-63 across the table at x 220-340.
    """
    band = a[y0:y1].astype(int)
    ref = np.median(band, axis=1)
    return np.abs(band - ref[:, None, :]).sum(axis=2).mean(axis=0)


def empty_runs(a: np.ndarray, y0: int = 150, y1: int = 300, minw: int = 12):
    """Columns holding no furniture, candle or person.

    THE DEVIATION MEASURE ABOVE IS NOT ENOUGH TO PICK A DONOR, and finding that out cost one
    bad patch. Deviation-from-median says "this column is unusual", and a chair standing
    alone against drapes is only mildly unusual - so a donor range chosen on it (x 358..500,
    deviation 18-29) turned out to contain a chair at its far end. Cloned in, that chair
    arrived in the middle of the room WITHOUT the table it belonged to: a red oval on a stick
    with nothing in front of it, which reads worse than the table did. The same mistake also
    cut the patch through the two chairs already at the spine's edges, leaving their outer
    halves behind.

    So the donor test is not statistical, it is semantic: this room is green velvet and brown
    boards, and everything else in it is either strongly RED (chair upholstery) or BRIGHT AND
    WARM (candles, faces, linen). A column with none of those is empty room. Measured, that
    finds exactly two runs - x 101..208 and x 358..406 - and the chair the deviation measure
    missed is correctly excluded from both.
    """
    band = a[y0:y1].astype(int)
    r, g, b = band[..., 0], band[..., 1], band[..., 2]
    mark = (((r > g + 40) & (r > 70)) | ((r > 150) & (g > 130))).sum(axis=0)
    runs, cur = [], None
    for x in range(len(mark)):
        if mark[x] <= 1:
            cur = x if cur is None else cur
        elif cur is not None:
            if x - cur >= minw:
                runs.append((cur, x))
            cur = None
    if cur is not None and len(mark) - cur >= minw:
        runs.append((cur, len(mark)))
    return runs


def clone(a: np.ndarray, patch: tuple[int, int], donors: list[tuple[int, int]]) -> np.ndarray:
    """Fill `patch` by tiling `donors`, alternating mirrored, with cross-faded joins.

    TILING IS NEEDED BECAUSE THE CLEAN ROOM IS NARROWER THAN THE HOLE. The spine to clear is
    149 px and the widest genuinely empty run is 108, so no single donor can cover it. Pieces
    are laid down in turn and every alternate one is mirrored, which is what keeps a drape's
    vertical folds from repeating at a fixed period - a regular repeat in a vertical texture
    is the single most obvious tell that something has been cloned.
    """
    px0, px1 = patch
    width = px1 - px0
    pieces, i, mirror = [], 0, False
    while sum(p.shape[1] for p in pieces) < width + FADE:
        d0, d1 = donors[i % len(donors)]
        piece = a[:, d0:d1].copy()
        if mirror:
            piece = piece[:, ::-1]
        pieces.append(piece)
        i += 1
        mirror = not mirror
    out = a.copy().astype(float)
    x = px0
    for piece in pieces:
        if x >= px1:
            break
        w = min(piece.shape[1], px1 - x)
        seg = piece[:, :w].astype(float)
        blend = np.ones(w)
        n = min(FADE, max(1, w // 2))
        blend[:n] = np.linspace(0.0, 1.0, n)          # fade in over whatever is already there
        if x + w >= px1:
            blend[-n:] = np.linspace(1.0, 0.0, n)     # ...and out again at the far edge only
        cur = out[:, x:x + w]
        out[:, x:x + w] = cur * (1 - blend)[None, :, None] + seg * blend[None, :, None]
        x += w - n                                    # overlap successive tiles by the fade
    return np.clip(out, 0, 255).astype(np.uint8)


def parse_range(s: str) -> tuple[int, int]:
    a, b = s.split(":")
    return int(a), int(b)


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        raise SystemExit(__doc__)
    name = args[0]
    src = SRC / f"{name}.png"
    if not src.exists():
        raise SystemExit(f"no painting at {src.relative_to(ROOT)}")
    im = Image.open(src)
    a = np.asarray(im.convert("RGB"))

    def flag(key):
        return sys.argv[sys.argv.index(key) + 1] if key in sys.argv else None

    dev = column_deviation(a)
    print(f"{name}: column deviation from the empty-room median, in 20px blocks")
    for x0 in range(0, a.shape[1], 20):
        bar = "#" * int(dev[x0:x0 + 20].mean() / 3)
        print(f"  x {x0:3d}-{x0 + 19:3d}  {dev[x0:x0 + 20].mean():5.1f}  {bar}")
    found = empty_runs(a)
    print("\nempty room (no chair, candle or face) - use these as donors:")
    for s, e in found:
        print(f"   {s}:{e}   w {e - s}")

    ps, ds = flag("--patch"), flag("--donor")
    if not (ps and ds):
        print("\nPick a --patch a:b over the furniture and --donor a:b[,a:b] over empty room.")
        return
    patch = parse_range(ps)
    donors = [parse_range(part) for part in ds.split(",")]
    out = clone(a, patch, donors)
    after = column_deviation(out)
    print(f"\npatched x{patch[0]}..{patch[1]} from " + ds + " (alternately mirrored)")
    print(f"  spine deviation {dev[patch[0]:patch[1]].mean():.1f} -> "
          f"{after[patch[0]:patch[1]].mean():.1f}")

    # keep alpha if the painting had one, so a patched file is a drop-in for the original
    if im.mode == "RGBA":
        out = np.dstack([out, np.asarray(im)[..., 3]])
    result = Image.fromarray(out, im.mode if im.mode == "RGBA" else "RGB")
    if "--write" in sys.argv:
        result.save(src)
        print(f"  wrote {src.relative_to(ROOT)}")
        print("  next: pixelise_paint.py --bg " + name + " --write, then make reimport")
    else:
        prev = ROOT / "artifacts" / "spine"
        prev.mkdir(parents=True, exist_ok=True)
        result.save(prev / f"{name}.png")
        print(f"  preview {(prev / f'{name}.png').relative_to(ROOT)} - --write to apply")


if __name__ == "__main__":
    main()
