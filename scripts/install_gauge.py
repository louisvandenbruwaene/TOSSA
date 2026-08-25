#!/usr/bin/env python3
"""Install the crowd gauge's painted HOUSING (ui/gauge_face) and publish its geometry.

WHAT THIS IS FOR (2026-08-25, Louis: "also regenerate a prettier happiness meter with
pixellab"). THE CROWD dial is the one instrument a player reads mid-set, and it was drawn
entirely from primitives - a flat dark half-disc, four coloured arcs, five tick spokes and two
thin rings for a bezel. That is a good VECTOR gauge and it is why it still read as one: a
bezel two art pixels thick has no material, and a face with no material is a shape rather than
an object.

WHAT IS PAINTED AND WHAT IS STILL DRAWN, and the split is the whole design. Painted: the brass
bezel with its rivets, the recessed dark face, the graduation ticks. Drawn: the four coloured
zones, the needle, the peak pin, the hub. **Everything that MOVES or CHANGES STATE stays in
code**, because the zones light as the needle passes them and the hub takes the live zone's
colour - bake those and the instrument stops answering.

SO THE PAINTING HAS TO GIVE ITS GEOMETRY BACK. The generator will not land a groove on a
radius chosen in Game.gd, so the fit runs the other way: the band is MEASURED here and
published as `_GAUGE`, and draw_gauge lays its own zones into the groove the painting actually
has. Same contract as `_TORCH`, and the same warning applies - **copy the block this prints
into `Resources/art_manifest.json` by hand after any re-roll**, or the zones sit off the
groove with nothing complaining.

EVERYTHING INSIDE THE BEZEL IS THROWN AWAY, which is the whole finding of the first cut: the
band, the ticks, the needle it drew after being told not to (same family as the unlit torch),
the pivot boss and the face itself. Cutting on RADIUS rather than on colour is what makes that
one line instead of three fragile masks - the needle and the bezel are the same brass, so no
colour test can separate them, and the position test does not care.

USAGE
  .venv/bin/python scripts/install_gauge.py            preview
  .venv/bin/python scripts/install_gauge.py --write
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artguard  # noqa: E402
from derive_stage_props import load_palette, snap  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "artifacts" / "gauge" / "face.png"
OUT = ROOT / "Assets" / "UI" / "gauge_face.png"

ALPHA_CUT = 128
HUB_R = 10.0        # everything inside this is the painted pivot boss, which the game redraws


def band_mask(a: np.ndarray, op: np.ndarray) -> np.ndarray:
	"""The coloured scale, and nothing else on the instrument.

	The four scale colours come back all but pure - measured on the shipped roll, (245,5,0),
	(251,169,3), (251,253,2), (4,252,0), every one of them with a channel under 10 and a
	channel over 240. The brass runs (182,138,71) down to (98,55,21): saturated too, which is
	why a plain saturation threshold takes the bezel with the band, and never within 40 of
	black in any channel. **Separate them on the DARKEST channel, not on saturation.**
	"""
	rgb = a[..., :3]
	return op & (rgb.min(axis=2) < 40) & (rgb.max(axis=2) > 200)


def centre(ring: np.ndarray) -> tuple[float, float]:
	"""The dial's centre, SOLVED from the brass ring rather than guessed from the silhouette.

	The rim is an annulus about the pivot, so the centre is the point that makes it one: the
	(cx, cy) minimising the spread of its radii. A search is honest here where a measurement
	is not - the obvious "middle of the widest row" reads the bezel's flat bottom, which the
	model draws a few pixels below the true centre and thicker on one side than the other,
	and three pixels of error puts the drawn scale visibly off the painted rim.

	FIT ON THE RIM, NOT ON THE BAND, and that is what makes this work for any roll: a gauge
	asked for with no coloured scale at all (the shipped one) has no band to fit, and every
	roll has a rim by definition - it is the only thing this script keeps.
	"""
	ys, xs = np.nonzero(ring)
	best, at = 1.0e9, (float(xs.mean()), float(ys.max()))
	for cy in np.arange(ys.max() - 8.0, ys.max() + 8.01, 0.5):
		for cx in np.arange(xs.mean() - 4.0, xs.mean() + 4.01, 0.5):
			rr = np.hypot(xs - cx, ys - cy)
			spread = float(rr.max() - rr.min())
			if spread < best:
				best, at = spread, (float(cx), float(cy))
	return at


def build(write: bool, force: bool) -> str:
	if not SRC.exists():
		return "no art at artifacts/gauge/face.png"
	im = Image.open(SRC).convert("RGBA")
	a = np.asarray(im).astype(int).copy()
	h, w = a.shape[:2]
	op = a[..., 3] >= ALPHA_CUT
	rgb = a[..., :3]
	brass = op & (rgb[..., 0] > 80) & (rgb[..., 0] > rgb[..., 1] + 20) & (rgb[..., 1] > rgb[..., 2] + 10)
	if brass.sum() < 200:
		return "found no brass rim - check the roll"
	cx, cy = centre(brass)
	yy, xx = np.mgrid[0:h, 0:w]
	rr = np.hypot(xx - cx, yy - cy)
	# a roll asked for WITH a coloured scale still has one; it is measured only so the report
	# can say what was thrown away, and never shipped - see the note above.
	band = band_mask(a, op)
	r_in = float(rr[band].min()) if band.sum() > 100 else 0.0
	r_out = float(rr[band].max()) if band.sum() > 100 else 0.0

	# THE SPRITE IS THE BEZEL RING AND NOTHING ELSE, and the first cut proved why. Keeping the
	# whole housing and repainting only the band gave a face carrying the generation's own
	# baked shading - a soft brown blob across the middle, a streak of needle the brass test
	# could not separate from the ticks, and, after the palette snap, a brass gone muddy over
	# most of its area. Measured against the drawn instrument it replaced, it was worse.
	# **The generator is good at a chunky ring of lit metal and bad at a large flat dark
	# surface**, which is the same division the props already record (a painted club, a drawn
	# stage). So the ring is what ships: the code keeps its clean recessed face, its graduation
	# ticks and its four lit zones, and the painting gives them an edge to sit inside.
	ring = brass & (rr > r_out)
	if ring.sum() < 200:
		return "found no brass bezel outside the band - check the roll"
	bezel_in = float(rr[ring].min())
	# ...taken with the dark shadow line just inside it, which is what makes a bezel read as
	# SET INTO something rather than laid on top of it
	keep_ring = rr >= bezel_in - 2.0
	a[..., 3] = np.where(op & keep_ring, 255, 0)

	# crop so the dial's centre row IS the bottom edge, which is what lets the manifest use
	# the documented [0.5, 1.0] pivot instead of a fraction nobody can check by eye
	a = a[: int(round(cy)) + 1]
	pal = load_palette()
	rgbs = snap(a[..., :3].astype(float), pal)
	keep = a[..., 3] >= ALPHA_CUT
	out = np.dstack([rgbs.astype(np.uint8),
					 np.where(keep, 255, 0).astype(np.uint8)])
	# TWO NUMBERS, AND ONLY TWO. Where the metal starts is the whole constraint the painting
	# puts on the game; how thick the scale inside it should be is Game.gd's business, and an
	# early version that published the roll's own groove had draw_gauge lay its zones into it
	# and come out smaller and further from the rim than the drawn instrument it replaced.
	block = {
		"pivot": [0.5, 1.0],
		"bezel_in": round(bezel_in - 2.0, 1),
		"outer": round(float(rr[op].max()), 1),
	}
	tag = ("gauge: %dx%d ring, bezel from %.1f, outer %.1f, %d colours%s"
		   % (out.shape[1], out.shape[0], block["bezel_in"], block["outer"],
			  len(np.unique(out[..., :3][out[..., 3] > 0].reshape(-1, 3), axis=0)),
			  (", threw away a painted scale at %.1f..%.1f" % (r_in, r_out)) if r_out > 0 else ""))
	print("\n  _GAUGE block for Resources/art_manifest.json:")
	print("    " + json.dumps(block))
	if not write:
		return tag + "  (pass --write to apply)"
	OUT.parent.mkdir(parents=True, exist_ok=True)
	st = artguard.save_guarded(OUT, lambda q: Image.fromarray(out, "RGBA").save(q), force)
	return tag + f" [{st}]"


def main() -> int:
	print("  " + build("--write" in sys.argv, "--force" in sys.argv))
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
