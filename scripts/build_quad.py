"""The four positions as WHOLE CHARACTERS, built from the best material we already have.

SYMMETRIC ON PURPOSE. Each pose puts the SAME arm on both sides (one mirrored), for two
reasons: it is one image per position instead of sixteen, and the splitter that already
exists cuts a symmetric frame into a good left arm AND a good right arm. The game still
picks the two sides independently afterwards - the symmetry is in the SOURCE, not on stage.

These are the images PixelLab is asked to polish, so they must be on-model rather than
pretty: the real body, the real palette, the real proportions.
"""
import sys
sys.path.insert(0, "scripts")
import numpy as np
from PIL import Image
from pathlib import Path
from build_arm_bank import gather
import armlib

OUT = Path("artifacts/chargen/quad")
OUT.mkdir(parents=True, exist_ok=True)
body, cands = gather(sorted(Path("artifacts/chargen").glob("anim_*")))
ch, cw = body.shape[:2]
bys, bxs = np.where(body[..., 3] > 0)
axis = (int(bxs.min()) + int(bxs.max())) * 0.5
line = armlib.GAME_HAND_UP

# reach and height each position is defined by - the game's own two slots, and the rise
# the art actually offers at the top of its sweep
TARGETS = {
    "in_low":   (27.0, line),
    "in_high":  (27.0, line + 0.13),
    "out_low":  (50.0, line),
    "out_high": (50.0, line + 0.13),
}

def score(c, want_r, want_up):
    return (abs(c["reach"] - want_r) / 8.0 + abs(c["up"] - want_up) / 0.04
            - round(c["flat"] * 4) * 0.25
            - round(c["layer"].shape[1] / max(1.0, c["layer"].shape[0]) * 4) * 0.15)

for name, (wr, wu) in TARGETS.items():
    best = min(cands, key=lambda c: score(c, wr, wu))
    lay, ox, oy = best["layer"], best["ox"], best["oy"]
    # put it on the side it came from, and mirror a copy onto the other
    if best["side"] == "R":
        r_lay, r_ox = lay, ox
        l_lay, l_ox = armlib.mirror_about(lay, ox, axis)
    else:
        l_lay, l_ox = lay, ox
        r_lay, r_ox = armlib.mirror_about(lay, ox, axis)
    canvas = body.copy().astype(int)
    for L, X in ((l_lay, int(round(l_ox))), (r_lay, int(round(r_ox)))):
        h, w = L.shape[:2]
        y0, x0 = oy, X
        y1, x1 = y0 + h, x0 + w
        sy0, sx0 = max(0, -y0), max(0, -x0)
        y0, x0 = max(0, y0), max(0, x0)
        y1, x1 = min(ch, y1), min(cw, x1)
        if y1 <= y0 or x1 <= x0:
            continue
        sub = canvas[y0:y1, x0:x1]
        src = L[sy0:sy0 + (y1 - y0), sx0:sx0 + (x1 - x0)]
        a = src[..., 3:4] / 255.0
        sub[:] = (src * a + sub * (1 - a)).astype(int)
    im = Image.fromarray(canvas.astype(np.uint8), "RGBA")
    im.save(OUT / f"{name}.png")
    print(f"{name:9} <- {best['src']} f{best['frame']} {best['side']}  "
          f"reach {best['reach']:5.1f} up {best['up']:.3f} palm-flat {best['flat']:.2f}")
print(f"\nwrote 4 poses to {OUT}")
