#!/usr/bin/env python3
"""Slide a venue exterior sideways so its lit focal point lands on the frame's centre line.

WHY THIS EXISTS RATHER THAN A BETTER PROMPT (2026-08-13). Louis, on the establishing cards:
"why would there be two arenas or circus tents, or two entrances to two buildings ... I'd
like the important part centered". Getting to ONE of each was a prompt fix - crop so the
subject fills the frame and there is nowhere to put a twin. Getting that one thing CENTRED
was not, and the reason is worth writing down:

    ASKING FOR "DEAD CENTRE" MAKES THE DUPLICATION COME BACK.

Measured, repeatedly. "its lit porch and glowing front door sit at the exact middle of the
picture, the same distance from the left edge as from the right edge, perfectly centred"
returned a house with TWO front doors, one either side of the middle - the model satisfies a
request for symmetry by building a symmetric composition, and two doors is symmetric. Same
prompt shape, same failure, on the Midnight Show's archway. So the two goals fight: the
wording that gives one subject is the wording that leaves it off-centre, and the wording
that centres it gives two.

The way out is to stop asking. Generate for singularity, then move the picture here, where
it is arithmetic instead of a lottery.

WHY A SHIFT IS SAFE ON THESE AND WOULD NOT HAVE BEEN BEFORE. Every exterior is now an
extreme close-up of a CONTINUOUS FACADE - brickwork, striped canvas, stonework, a stadium's
ribbed concrete. Padding the exposed edge by reflection continues a repeating texture, which
is invisible. The earlier wide compositions (a house in a garden, a street with an alley)
would have had a window or a doorway reflected into view, which is why this was not done to
them. It is also lossless: an integer shift moves whole pixels and resamples nothing.

FINDING THE FOCAL POINT: it is the LIT thing, and it took three tries to measure properly.

  1. AXIS OF SYMMETRY. Tried first, abandoned: these facades are self-similar all the way
     across, so mirror error is nearly flat and the argmin is noise - it kept returning the
     edge of its own search range.
  2. CENTROID of the warm lit pixels. Wrong whenever the light is SPREAD: the Circus's
     entrance sits at x 535 and its string of bulbs runs the full width, so the centroid
     reported 327, dead centre, and would have shifted the picture by 7px.
  3. PEAK of a smoothed per-column profile. This is the one. A 61px box filter over the
     column sums, argmax. The entrance is the densest concentration of light, which is what
     the eye picks out too, and spread-out bulbs cannot outvote it.

WITH ONE FALLBACK, because one venue is not lit warmly at all. The Championship is a cool
concrete-and-glass facade: 149 of its 54,537 bright pixels are warm (0.00), against 0.68-1.00
for every other venue, and the warm profile then locks onto stray tint and reports x=98 for
an entrance that is at 440. Below WARM_SHARE the profile is built from plain brightness
instead, which puts it at 421-440. The two regimes are three orders of magnitude apart, so
the switch is not a tuning knob.

USAGE
  .venv/bin/python scripts/recentre_ext.py                 measure only
  .venv/bin/python scripts/recentre_ext.py --write         apply, in artifacts/paint/
Run BEFORE pixelise_paint.py --ext, which is what installs the result.
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "artifacts" / "paint"

# WHICH VENUES THIS IS ALLOWED TO TOUCH, and the list is short on purpose - every name that
# is NOT here was tried, looked at, and rejected:
#
#   the_circus      -215px, and the tent's stripes have a rhythm. The join lands mid-stripe
#                   and reads as a crease down the canvas.
#   championship    -101px. The fill starts inside the glass curtain wall and the join reads
#                   as an extra structural column that does not line up with the real ones.
#   world_arena     -112px. Worst of the three: the join cuts across the curving tiers of
#                   seating, which are the one thing in that picture the eye follows.
#   backyard        architectural (a gable and a porch), and already near enough the middle.
#   small_theatre   its marquee is the subject and its neighbours are part of the street.
#
# What the two survivors have in common is a genuinely FEATURELESS field to fill from -
# plain brick, plain stonework - where a hard join has no structure to interrupt. That is
# the real precondition, not "a continuous facade", which is what I assumed first and which
# is true of the three rejected ones as well.
NAMES = ["street_corner", "the_midnight_show"]

WARM_MIN = 110.0    # a lit entrance, not a dim brick
WARM_SHARE = 0.15   # below this share of bright pixels, the venue is not warm-lit at all
SMOOTH = 61         # box filter over the column profile, in px - about an entrance's width
MAX_SHIFT = 220     # refuse anything absurd rather than wrap a picture halfway round


def focal_x(rgb: np.ndarray) -> float | None:
	"""The x of the densest concentration of light: the entrance. See the module docstring."""
	r = rgb[..., 0].astype(float)
	b = rgb[..., 2].astype(float)
	lum = rgb.mean(axis=2)
	bright = lum > WARM_MIN
	warm = bright & (r > b + 12)
	if bright.sum() < 40:
		return None
	mask = warm if warm.sum() >= WARM_SHARE * bright.sum() else bright
	col = (lum * mask).sum(axis=0)
	ker = np.ones(SMOOTH) / SMOOTH
	return float(np.convolve(col, ker, mode="same").argmax())


def quiet_strip(rgb: np.ndarray, w: int) -> np.ndarray:
	"""The `w`-wide vertical band of this picture with the least light in it.

	REFLECTION WAS THE OBVIOUS FILL AND IT IS WRONG HERE. Mirroring the adjacent strip
	continues a texture perfectly, but it also mirrors any LANDMARK inside the shift
	distance: at -125 the Street Corner grew a second lamp post, and at -215 the Circus grew
	a second lit archway - which is precisely the "two entrances" defect this whole pass
	exists to remove. Verified by looking at the shifted output, not assumed.

	So the exposed edge is filled from the picture's own QUIETEST band instead - the run of
	columns carrying the least light, which on these facades is plain brick, plain canvas or
	plain stonework. It cannot duplicate a landmark because it is chosen for containing none.
	"""
	lum = rgb.mean(axis=2)
	col = lum.sum(axis=0)
	# cumulative sums make the sliding window exact and cheap
	cum = np.concatenate([[0.0], np.cumsum(col)])
	totals = cum[w:] - cum[:-w]
	return rgb[:, int(totals.argmin()):int(totals.argmin()) + w]


def shift(rgb: np.ndarray, dx: int) -> np.ndarray:
	"""Move the picture by dx whole pixels, filling the exposed edge from a quiet band."""
	if dx == 0:
		return rgb
	pad = abs(dx)
	fill = quiet_strip(rgb, pad)
	if dx < 0:      # picture moves left, the RIGHT edge is exposed
		return np.concatenate([rgb[:, pad:], fill], axis=1)
	return np.concatenate([fill, rgb[:, :-pad]], axis=1)


# VERTICAL LIFTS FOR BACKDROPS: RETIRED ON 2026-08-14, THE DAY AFTER THEY WERE WRITTEN.
#
# THE IDEA. The drawn podium had just been deleted and the PAINTING had become the floor, so
# each room's floor line landed somewhere different while the performer stood at a fixed 0.80
# of the viewport. This slid each painting up until its floor met his feet. Measured as the
# strongest horizontal edge in art y 250..345, the lifts came out: small_theatre 20,
# the_circus 37, world_arena 26, the_midnight_show 59.
#
# WHY IT IS THE WRONG MECHANISM, and both halves of this are worth keeping:
#
#   1. IT MEASURED THE WRONG LINE. "The strongest horizontal edge" in a painted room is the
#      floor's BACK edge, where the floor meets the wall. Putting his feet there stands him at
#      the very back of the room: on the Circus's ring wall, on the World Arena's perimeter
#      wall, on the Small Theatre's curtain hem, with the entire floor stretching away unused
#      in front of him. A painted floor is a BAND in perspective and he has to stand INSIDE
#      it. Louis, on the shipped result: "he's often floating or not standing on the right
#      place".
#   2. IT MOVES THE ART TO SUIT THE CODE. A lift throws away rows off the top, invents rows at
#      the bottom, cannot be undone without the git history, and is silently lost the moment a
#      backdrop is regenerated - which is the normal way these change. Two of the seven were
#      regenerated the following day.
#
# WHAT REPLACES IT is one float per venue in Game.gd (venue_data's `stand`, read by
# stage_floor_y): the man moves to the room instead of the room moving to the man. It is
# reversible, it is tunable in a second, and a regenerated painting needs one number
# re-measured rather than a destructive script re-run.
#
# THE FOUR LIFTS ALREADY APPLIED ARE LEFT IN PLACE, in artifacts/paint and in Assets. They are
# not doing harm: the extra rows of floor they brought into frame are exactly what a lower
# standing line wants, and the `stand` values were measured against the paintings as they now
# are. .shifted.json stays as the record that it happened.
LIFTS: dict[str, int] = {}

# THIS SCRIPT MUTATES ITS OWN SOURCE, SO IT MUST NOT RUN TWICE. Both operations here are
# relative moves - shift the picture by dx, raise it by dy - and applying either a second time
# moves it again, silently and irreversibly. recolour_hat.py has exactly this hazard and
# refuses itself; this keeps a ledger instead, because there are two axes and several names.
LEDGER = SRC / ".shifted.json"


def lift(rgb: np.ndarray, dy: int) -> np.ndarray:
	"""Raise the picture by dy whole pixels.

	Content moves up, so the dy rows exposed at the BOTTOM are filled by repeating the last
	row - and those rows sit under the stage floor, so the fill is never drawn. The dy rows
	lost off the top are uniform curtain on every venue this is applied to.
	"""
	if dy <= 0:
		return rgb
	# MIRRORED, NOT REPEATED. Repeating the last row was fine while the stage floor covered
	# the bottom fifth and the fill was never drawn; with the drawn podium gone that strip is
	# on screen, and a single row stretched 26-59px reads as vertical streaking across the
	# floor. Mirroring the bottom band continues the floor's own texture instead. It is not
	# perspective-correct - a receding floor does not really repeat - but at this size the eye
	# wants texture, not geometry, and it has neither seam nor smear.
	band = rgb[-dy:][::-1]
	return np.concatenate([rgb[dy:], band], axis=0)


def ledger() -> dict:
	import json
	return json.loads(LEDGER.read_text()) if LEDGER.exists() else {}


def note_done(key: str) -> None:
	import json
	d = ledger()
	d[key] = True
	LEDGER.write_text(json.dumps(d, indent=1, sort_keys=True))


def run_lifts(write: bool, force: bool) -> None:
	if not LIFTS:
		print("  --lift is retired: the standing line lives in Game.gd's venue_data now "
			  "(see the note above LIFTS). Nothing to do.")
		return
	done = ledger()
	for name, dy in LIFTS.items():
		p = SRC / f"{name}.png"
		if not p.exists():
			print(f"  {name}: no painting to lift")
			continue
		key = f"lift:{name}:{dy}"
		if done.get(key) and not force:
			print(f"  {name}: already lifted {dy}px - REFUSED (pass --force to repeat)")
			continue
		a = np.asarray(Image.open(p).convert("RGB"))
		tag = f"  {name}: lifted {dy}px (its floor line moves onto the standing line)"
		if not write:
			print(tag + "  (pass --write to apply)")
			continue
		Image.fromarray(lift(a, dy)).save(p)
		note_done(key)
		print(tag + " [written]")


def main() -> int:
	write = "--write" in sys.argv
	if "--lift" in sys.argv:
		run_lifts(write, "--force" in sys.argv)
		return 0
	only = [a for a in sys.argv[1:] if not a.startswith("--")]
	for name in NAMES:
		if only and name not in only:
			continue
		p = SRC / f"ext_{name}.png"
		if not p.exists():
			print(f"  ext_{name}: no painting at {p.relative_to(ROOT)}")
			continue
		a = np.asarray(Image.open(p).convert("RGB"))
		fx = focal_x(a)
		if fx is None:
			print(f"  ext_{name}: no lit focal point found - left alone")
			continue
		dx = int(round(a.shape[1] / 2.0 - fx))
		if abs(dx) > MAX_SHIFT:
			print(f"  ext_{name}: focal at {fx:.0f}, wants {dx:+d} - REFUSED, over {MAX_SHIFT}")
			continue
		tag = f"  ext_{name}: focal at x={fx:.0f} of {a.shape[1]}, shift {dx:+d}"
		if not write:
			print(tag + "  (pass --write to apply)")
			continue
		Image.fromarray(shift(a, dx)).save(p)
		fx2 = focal_x(np.asarray(Image.open(p).convert("RGB")))
		print(tag + f" -> now x={fx2:.0f} [written]")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
