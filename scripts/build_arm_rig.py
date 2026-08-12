#!/usr/bin/env python3
"""Build the performer's arm bank from ONE clean source pose, not many noisy generations.

THE PROBLEM THIS REPLACES. build_arm_bank.py pools ~19 independent animate_image
generations and, for every frame, subtracts a majority-vote "static body" to isolate
whatever pixels moved. Every generation has its own colour drift, jitter and slightly
different coat painting, so the diff is inherently noisy - left and right arms, picked
from different generations, sometimes don't even match (Louis, viewing the atlas: "the
entire project is clutter").

THE FIX. Take the single best source frame (Assets/Characters/showman/source.png - arms
held outward, per armlib's own comment "the hand-made still the whole animation was grown
from"). Cut each arm out of it ONCE along its own measured medial line, split at the elbow
into two rigid bones, and rotate those two bones per pose. Every pose is the same source
pixels moved by a rigid rotation, so nothing is ever redrawn or reinterpreted frame to
frame - the geometry, not a statistical vote across noisy generations, is what keeps the
man from twitching.

WHY THIS FILE WAS REWRITTEN AGAIN (2026-08-12). The previous version produced a performer
whose arms were visibly SEVERED - two red sleeve blocks floating in open air either side of
a torso with torn, spiky shoulders (measured: a 23 art px hole of pure background between
the torso edge and the inner end of the sleeve, at every reach). Three separate causes, all
found by measuring the source art rather than reasoning about the geometry on paper:

 1. THE CORRIDOR THAT CLAIMS THE ARM WAS ~3x TOO WIDE. `ARM_RADIUS` had grown 6 -> 13 -> 16
    across three commits, each step chasing a "residual coat wedge" left behind at the
    shoulder. The painted arm is 12 art px THICK in total (measured column by column, see
    ARM_HALF_W) - so a half-width of 16 is a 32px corridor around a 12px limb, and what it
    cut out as "the upper arm" was a triangular wedge of coat, lapel and shoulder frill
    whose pixel mass sat nowhere near the bone. Rotating that wedge is what shredded the
    shoulders. The leftover it was chasing was the coat's PUFFED EPAULETTE, which is torso
    and is supposed to stay behind; widening a corridor to swallow it runs the fix backwards.
 2. THE UPPER ARM WAS FROZEN, SO THE HAND COULD NOT REACH. Pinning the upper arm at one rest
    angle and pivoting only the forearm leaves the hand on a circle of radius fore_len about
    a fixed elbow: reach 22..52 art px, where the game asks for 27..50 from `outer_pos` /
    `inner_pos` alone and wider still on the columns lanes. Louis's "keep the shoulder fixed"
    is about the JOINT not sliding around the body, which a two-bone solve honours - the
    shoulder POSITION is pinned to the torso and only the angles move.
 3. THE PUBLISHED HAND LINE WAS A LIE. `py` swung from 44.3 art px at full reach to 22.1 at
    mid reach - 22 art px of vertical travel - and `hand_py` was the MEDIAN of that, 22.4,
    which is head height on a 164px body. `fig_hand_pos`'s FIG_PALM_MAX guard is 7 art px,
    so nearly every entry was rejected and the prop snapped back to the simulated hand while
    the picture showed an arm somewhere else. The hand line is FLAT here by construction:
    the IK target row is a constant, so `py` cannot drift from it.

Output is written in the EXACT schema build_arm_bank.py already produces (juggle_body.png,
juggle_arms.png/.json, the _ARMS block in art_manifest.json) - Game.gd's fig_arm_pick does
a reach lookup into that schema and needs no changes. One layer now carries the WHOLE arm
(both bones), where the previous version baked the upper arm into the body; the schema is
indifferent, `ox`/`oy` and the atlas cell size are all derived.

USAGE
  .venv/bin/python scripts/build_arm_rig.py --sheet artifacts/rig_debug.png
  .venv/bin/python scripts/build_arm_rig.py --check
  .venv/bin/python scripts/build_arm_rig.py --write
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

import armlib
import artguard
import build_arm_bank as bank  # reuse: snap(), _snap_rgb, head_box, artguard writer

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "Assets" / "Characters" / "showman" / "source.png"
OUT = ROOT / "Assets" / "Characters" / "showman"
PALETTE = ROOT / "Resources" / "palette" / "palette.png"

# THE ARM'S OWN THICKNESS, MEASURED, NOT GUESSED. Walking the source pose column by column
# and taking the height of the arm's run where it is separable from the torso gives a median
# of 12 art px across x=18..40, rising to ~14 as it approaches the shoulder. So the corridor
# that claims the arm is 6 at the elbow end - half the limb - widening to 7.5 at the shoulder,
# where the sleeve thickens into the deltoid.
#
# THIS NUMBER IS THE WHOLE BUG THE REWRITE FIXES, so it is worth being blunt about the failure
# mode: too WIDE does not read as "a bit of coat came along", it reads as SHREDDED SHOULDERS,
# because the coat pixels it steals are rotated away from where the coat has to stay. Too
# NARROW reads as a thin sleeve with a fringe of coat left behind at the old angle. Between
# the two, too narrow is strictly the safer error - the fringe stays put and stays plausible.
#
# The hand end is much wider than the limb because the fingers are FULLY SPLAYED in this pose
# and fan ~12 art px either side of the palm's centre. It costs nothing to be generous there:
# past the wrist the only painted pixels within reach of the corridor are the hand itself.
ARM_HALF_W = (7.5, 6.0, 13.0)   # at the shoulder, at the elbow, at the hand

# How far along the shoulder->hand axis the elbow sits. Anatomically the upper arm and the
# forearm are near enough the same length; 0.45 gives the forearm the extra, which is right
# once the hand is counted as part of it.
ELBOW_FRAC = 0.45

# How many pixels each bone is dilated back into the other's territory at the elbow cut. A
# hard cut at one t value leaves both pieces tapered to a WEDGE TIP rather than a blunt
# cross-section (the fabric's diagonal grain does not sit perpendicular to the bone), and two
# wedge tips rotated to different angles leave a gap between two points. Dilating each piece
# into the other - clipped to real painted pixels, so it can never invent fabric over
# background - means whichever is drawn on top simply covers the join.
SEAM_OVERLAP_PX = 2

# THE SHOULDER IS PINNED INSIDE THE TORSO, NOT ON ITS EDGE, and that is what lets both bones
# rotate without opening a hole. The coat's puffed epaulette (rows 26..31 of the source) is a
# socket cap: any joint that sits UNDER it stays covered however far the arm swings, because
# the body sprite is drawn first and the cap is part of it. A joint placed on the silhouette
# edge is only covered at the one angle it was cut at.
SHOULDER_INSET = 5.0

# RAISING THE JOINT OFF THE AXIS DOES NOT STRAIGHTEN THE ARM, WHICH IS WORTH RECORDING BECAUSE IT
# LOOKS LIKE IT SHOULD. The bend is set by how far the hand is from its shoulder against the arm's
# own length - but both bones are CUT between those same two points, so moving the joint changes
# the arm's length by exactly as much as it changes the distance, and by Pythagoras the length
# wins. Measured: rise 0 -> worst bend 119 deg, rise 5 -> 118, rise 10 -> 114, i.e. slightly
# WORSE, while connectivity collapsed from 3.7% to 45% as the corridor started eating coat above
# the real arm. Left at 0.
SHOULDER_RISE = 0.0

# THE JOINT NEEDS A CAP THAT STAYS ON THE BODY, and this is the difference between an arm that
# grows out of a shoulder and one that is stuck on the side of a torso (Louis: "the shoulders
# aren't connected to the arms"). Cutting the corridor right through the joint takes a bite out
# of the coat, and a rotating rigid sleeve cannot fill that bite at every angle - what shows is a
# squared-off NOTCH in the silhouette where the epaulette should round over the joint. It is not
# a hole and not a gap along the bone, which is why check_connected never saw it: its probe walks
# from a shoulder point that sits INSIDE the torso, so it is on opaque coat the whole way.
#
# So the disc around the joint is never claimed by the arm at all. The body keeps it, the upper
# bone starts just inside its edge (SEAM_OVERLAP_PX of overlap so there is no seam to find), and
# because the bone's inner end is an arc at that same radius, the cap covers it at EVERY angle
# by construction rather than by luck.
SHOULDER_CAP_R = 9.0

# ...AND THE SOCKET HAS TO BE PAINTED, BECAUSE THE SOURCE POSE NEVER SHOWS IT. The generator drew
# this frame with the arms held straight out sideways, which leaves a real V-shaped notch of
# BACKGROUND in each armpit - measured, transparent pixels at x 54..57, y 44..47 on the left.
# Nothing erased them and no corridor width can recover them; the painting simply has a hole
# there, hidden in the source only because the horizontal arm sat across it. Swing the arm down
# to juggle and the V opens up between the coat and the sleeve, which is exactly Louis's "the
# shoulders aren't connected to the arms" - and check_connected could not see it, because its
# probe starts from a shoulder point INSIDE the torso and walks over opaque coat the whole way.
#
# Every cut-out rig has to paint what its source pose hid. This is the smallest honest version:
# morphologically CLOSE the body's silhouette in a window around the joint, which seals a notch
# without touching any outer edge, and colour whatever that fills from its NEAREST existing body
# pixel - so the fabric that arrives is the coat's own, never invented. Typically ~30 px.
SOCKET_SEAL_R = 7

# How far the PROP ANCHOR moves past the hand blob's centroid, toward the fingers, along the
# forearm's own axis - see write_bank(). The centroid sits at the heel of the palm because
# the wrist end is the denser mass; +3 lands over the palm without floating out between the
# splayed fingers.
PROP_ANCHOR_SHIFT = 3.0

# THE REACH RANGE THE GAME ACTUALLY ASKS FOR. `outer_pos` sits HAND_OUT_DX/2 = 50 art px out
# and `inner_pos` HAND_IN_DX/2 = 27, and the columns lanes spread wider either way. A two-bone
# arm covers |L1-L2| .. L1+L2 about the shoulder, which for this figure is reach ~13..60 - so
# the whole of the game's own travel is inside the bank and no pose has to be faked. The ends
# are pulled in by one px from the true kinematic limit: a bone chain drawn at full extension
# is a straight line with no elbow at all, which reads as a broken stick.
REACH_MARGIN = 1.0

# How far below the shoulder the flat hand line sits, as a fraction of the whole arm's length.
# See build() for why this is a decision and not a measurement, and why it cannot go much past
# 0.5 on this figure. 0.45 keeps the outer reach above 54 art px (the game asks for 50) while
# putting the hands at waist height.
HAND_DROP_FRAC = 0.62

# The bank does not have to serve reaches the game never visits, and the extremes are where a
# folded two-bone chain looks worst - and with the shoulder free (see SHOULDER_GAIN) the worst is
# where the SHOULDER SWING lives: measured, the sweep down to reach 20 swings it 137 degrees,
# while the same rig floored at `inner_pos` swings 73. The extra poses buy almost nothing - the
# columns dead-centre lane asks for reach under 10 and no bank has ever served it, so
# draw_figure_palm's fallback carries that case and always has (the pooled bank bottomed out at
# 30). Floor at 26, a shade inside `inner_pos`, and let the fallback have the rest.
REACH_FLOOR = 26.0

# THE SHOULDER BARELY MOVES; THE FOREARM DOES THE WORK. This is Louis's own instruction ("i want
# [the shoulder] to remain fixed. instead i want you to pivot around the elbow") and, separately,
# it is what the motion needs.
#
# A free two-bone IK solve distributes rotation between the bones however the geometry likes, and
# measured over the reach range the game actually uses (27..50), "however it likes" is: the upper
# arm swings 72.8 degrees and the ELBOW TRAVELS 21.5 ART PX, sweeping from outboard of the
# shoulder all the way across to the body's centreline as the hand comes in. Every frame of that
# is a valid, connected, correctly-reaching arm, and the sequence is a windmill (Louis: "the
# motion is completely unnatural"). Frame-at-a-time checks cannot see it - only the trajectory
# can, which is why check_smooth exists.
#
# So the IK answer is DAMPED toward a rest angle rather than used raw: the shoulder contributes a
# fraction of the rotation it would like to, and the forearm absorbs the rest. The hand then lands
# slightly off its target, which is fine and is measured - `reach` and `py` are both recorded from
# the pose the bones ACTUALLY make, never from what was asked for.
# DAMPING THE SHOULDER WAS TRIED AND MEASURED, AND IT CANNOT PAY FOR ITSELF HERE. At gain 0.25
# the elbow does go still (7.6 px of travel instead of 43), and the arm then cannot reach: the
# forearm, aiming at the target from an elbow that refused to come with it, overshoots, and the
# hand ends up 17.5 art px ABOVE its own line at the inner end while the served reach range
# collapses to 23.3..48.6 - short of the 50 `outer_pos` asks for. At 0.6 it still tops out at
# reach 28.7 and never serves `inner_pos` at 27.
#
# The reason is geometry, not tuning, and it is worth stating so nobody re-tries this: with the
# shoulder pinned, a 40 art px arm, and the hand constrained to a LEVEL line 18 px below the
# joint, going from reach 50 to reach 27 takes the hand from 87% of full extension to 48%. The
# elbow positions that satisfy those two ends are 22 art px apart. Nothing about the art or the
# solver can make that number smaller - only moving the hand off the level line can, which is a
# change to the GAME's `inner_pos`, not to this file.
SHOULDER_GAIN = 1.0
SHOULDER_MAX_DEG = 180.0
SHOULDER_REST_OUT_DEG = 10.0 # rest pose: straight down from the joint, tilted this far outboard

# THE CARRY DIPS, IT DOES NOT LIFT - and this one is counter-intuitive enough that it was got
# backwards first. A hand travelling along a dead-level line slides in and out like a telescope,
# so the arm wants a vertical component; the obvious one, and the one Louis asked for directly
# once ("make sure that the hands come back above the path they took to go inwards"), is to LIFT
# the hand as it carries inward. Measured, that is the worst of the three options for this
# figure: the shoulder joint sits only 18 art px above the hand line, so lifting the inward hand
# brings it CLOSER to its own shoulder, folds the chain tighter, and swings the upper arm harder
# (81 degrees, against 77 for a flat line). Dropping it instead keeps the hand at a more even
# distance from the joint - a pendulum carry rather than a fold - and the shoulder quiets down.
#
# THE DIP AND THE HAND-LINE DROP ARE ONE SETTING IN TWO PARTS, and they must be solved together:
# both push the hand away from the shoulder, and the arm is only 40 art px long. Set independently
# (drop 0.62 with dip 20) they put the inner hand 45 px from a 40 px arm, the solve clamps, and
# half the sweep comes back as a DEAD STRAIGHT stick - a worse read than the right angle it was
# fixing. What they are really for is to hold the hand at a NEAR-CONSTANT distance from its own
# shoulder across the whole carry: do that and the arm swings as one nearly rigid unit, which is
# both the slight even bend Louis asked for and the smallest possible elbow travel, at once.
#
#   dip 10: bend wanders 123..159 deg, elbow travels  9.8 px, shoulder swings 27.2 deg
#   dip 13: bend holds  142..147     , elbow travels 13.9   , shoulder swings 39.8   <- chosen
#   dip 16: bend 147..179 (clamps straight over the inner third)
#
# THE CEILING HERE IS 7 ART PX AND IT IS NOT AN ART DECISION. `fig_hand_pos` refuses a painted
# palm more than FIG_PALM_MAX (7 art px) from the SIMULATION's hand, and the simulation's hand
# line is dead level (`outer_pos` and `inner_pos` are both at stage_center().y, HAND_IN_LIFT is
# 0). So the bank may dip 7 and no further on its own. Everything past that needs `inner_pos` to
# dip with it, which is a change to the GAME's feel, not to this file - the numbers above say it
# would be worth asking about, since dip 20 more than halves the swing.
HAND_CARRY_DIP = 13.0

# The game's own two hand slots, in art px from the centreline: HAND_OUT_DX/2 and HAND_IN_DX/2.
# The carry profile is written between THESE, not across the bank's own range, because the
# simulated hand travels in a near-straight line from one slot to the other and the painted palm
# has to sit on that same line for FIG_PALM_MAX to accept it.
GAME_OUTER_REACH, GAME_INNER_REACH = 50.0, 27.0

# A SCOOP IS A CURVE, AND THE CURVE IS WHAT KEEPS THE ELBOW STRAIGHT. Running the carry as a
# straight line between the two slots leaves the arm at its most folded mid-travel - measured, the
# bend closes to 111 degrees around reach 40-44, which reads as the right angle Louis flagged,
# while both ends sit at a comfortable 148-157. Bowing the middle of the carry DOWNWARD moves the
# hand further from its own shoulder exactly where it was closest, so the bend stays slight all
# the way across. The bow is zero at both slots, so the endpoints still agree with the game
# exactly, and its depth is spent out of the same FIG_PALM_MAX budget as everything else.
HAND_CARRY_BOW = 2.0

# Generation is fully procedural (no PixelLab calls, no scarce AI candidates to pool), so
# density is free. 48 puts adjacent entries ~1 art px apart across the range, which is the
# density the old pooled bank reached at its best and fine enough that the picker never
# visibly SNAPS between poses during ordinary hand motion.
N_POSES = 48


def side_sign(side: str) -> float:
	"""+1 toward increasing x. The LEFT arm (as the player sees it) reaches toward -x."""
	return -1.0 if side == "L" else 1.0


def skin_blobs(frame: np.ndarray) -> dict:
	"""Each hand, as the outermost connected blob painted in the colours of his own FACE.

	A PALM IS A HAND, NOT AN EXTREMITY - armlib.py records this at length and it is why this
	does not simply take "the moving pixel furthest from the centreline" (fold the elbow and
	that is the ELBOW, measured a median of 25 art px from the real hand). Skin cannot be an
	elbow. armlib.hands() does the same job against a POOLED body's palette and returns
	nothing on a single un-pooled source frame, so the face's own colours are read straight
	off this frame instead."""
	rgb = frame[..., :3].astype(int)
	alpha = frame[..., 3] > 127
	# the head only - every colour here is hair, skin or outline, and nothing below the collar
	rows, cols = slice(6, 20), slice(66, 86)
	face = rgb[rows, cols][alpha[rows, cols]]
	vals, cnt = np.unique(face.reshape(-1, 3), axis=0, return_counts=True)
	keep = vals[cnt >= max(3, int(armlib.SKIN_MIN_SHARE * cnt.sum()))]

	skin = np.zeros(alpha.shape, bool)
	for c in keep:
		skin |= np.all(rgb == c, axis=-1)
	skin &= alpha
	skin[:24] = False                      # the head itself is not a hand

	lab, n = ndimage.label(skin)
	cx = frame.shape[1] * 0.5
	out = {}
	for side in ("L", "R"):
		best, best_d = None, -1.0
		for i in range(1, n + 1):
			ys, xs = np.where(lab == i)
			if xs.size < 12:
				continue
			d = (cx - xs.mean()) * -side_sign(side)   # how far OUT on this side
			if d > best_d:
				best, best_d = (float(xs.mean()), float(ys.mean())), d
		out[side] = best
	return out


def arm_axis(mask: np.ndarray, side: str, hand: tuple[float, float]) -> tuple[tuple, tuple]:
	"""The arm's own medial line, fitted to the columns where the limb is separable from the
	torso, and where the shoulder joint sits on it.

	WHY FIT RATHER THAN JOIN SHOULDER TO HAND. The sleeve's centre sits ~2 art px below the
	hand blob's centroid in this pose (the fingers splay upward, which lifts the centroid), so
	a straight line between the two runs above the sleeve and a corridor around it misses the
	sleeve's lower edge - leaving a fringe of red fabric behind on the body at the old angle.
	Fitting the medial line to the limb itself cannot make that mistake."""
	h, w = mask.shape
	sign = side_sign(side)
	centres = []
	for x in range(w):
		if (x - w * 0.5) * sign < 0:       # this side only
			continue
		ys = np.where(mask[:, x])[0]
		if ys.size == 0:
			continue
		runs, s, p = [], ys[0], ys[0]
		for y in ys[1:]:
			if y != p + 1:
				runs.append((s, p))
				s = y
			p = y
		runs.append((s, p))
		# the arm band only, and only where this column is not fused into the torso: a fused
		# column runs much taller than the limb, and including it drags the fit into the coat
		arm = [r for r in runs if r[0] >= 25 and r[1] <= 60 and (r[1] - r[0] + 1) <= 16]
		if len(arm) == 1:
			centres.append((float(x), (arm[0][0] + arm[0][1]) * 0.5))

	xs = np.array([c[0] for c in centres])
	ys = np.array([c[1] for c in centres])
	# only the SLEEVE, not the hand: the splayed fingers pull the medial line up several px,
	# and the sleeve is the part the corridor has to hug
	inner = np.abs(xs - w * 0.5) < abs(hand[0] - w * 0.5) - 4.0
	m, b = np.polyfit(xs[inner], ys[inner], 1)

	# the INBOARD end of the separable run is where the limb disappears into the coat, so it is
	# the torso's edge on this side; the joint is then pushed further in, under the epaulette
	torso_edge = float(xs[inner].min() if side == "R" else xs[inner].max())
	sx = torso_edge - sign * SHOULDER_INSET
	return (sx, m * sx + b - SHOULDER_RISE), (float(hand[0]), m * hand[0] + b)


def capsule_params(mask: np.ndarray, p0: tuple[float, float], p1: tuple[float, float],
		radii: tuple[float, float, float]) -> tuple[np.ndarray, np.ndarray]:
	"""(t, in_capsule) for every pixel: t is the 0..1 position along p0->p1 (clamped segment,
	not the infinite line), in_capsule is opaque AND within the corridor, whose half-width is
	interpolated through the three measured points (shoulder, elbow, hand)."""
	h, w = mask.shape
	yy, xx = np.mgrid[0:h, 0:w].astype(float)
	vx, vy = p1[0] - p0[0], p1[1] - p0[1]
	length2 = vx * vx + vy * vy
	t_raw = ((xx - p0[0]) * vx + (yy - p0[1]) * vy) / length2
	t_c = np.clip(t_raw, 0.0, 1.0)
	proj_x, proj_y = p0[0] + t_c * vx, p0[1] + t_c * vy
	dist = np.hypot(xx - proj_x, yy - proj_y)
	radius = np.interp(t_c, [0.0, ELBOW_FRAC, 1.0], list(radii))
	# t runs past 1 for the splayed fingertips, which fan out beyond the point that centres
	# them, and a little below 0 for the sleeve's cap inside the shoulder
	in_capsule = mask & (t_raw >= -0.12) & (t_raw <= 1.45) & (dist <= radius)
	return t_raw, in_capsule


def crop_piece(rgba: np.ndarray, piece_mask: np.ndarray) -> tuple[np.ndarray, int, int]:
	ys, xs = np.where(piece_mask)
	if xs.size == 0:
		return np.zeros((0, 0, 4), np.uint8), 0, 0
	y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
	out = np.zeros((y1 - y0 + 1, x1 - x0 + 1, 4), np.uint8)
	sel = piece_mask[y0:y1 + 1, x0:x1 + 1]
	out[sel] = rgba[y0:y1 + 1, x0:x1 + 1][sel]
	return out, int(x0), int(y0)


def claim(side: str, frame: np.ndarray, hand_blob: tuple[float, float]) -> dict:
	"""One side's joint geometry and the mask of every pixel that belongs to that arm."""
	mask = frame[..., 3] > 127
	shoulder, hand = arm_axis(mask, side, hand_blob)
	elbow = (shoulder[0] + ELBOW_FRAC * (hand[0] - shoulder[0]),
			 shoulder[1] + ELBOW_FRAC * (hand[1] - shoulder[1]))
	t, cap = capsule_params(mask, shoulder, hand, ARM_HALF_W)
	h, w = mask.shape
	yy, xx = np.mgrid[0:h, 0:w].astype(float)
	from_joint = np.hypot(xx - shoulder[0], yy - shoulder[1])
	socket = from_joint <= SHOULDER_CAP_R          # the body's cap - never moves
	return {"side": side, "shoulder": shoulder, "elbow": elbow, "hand": hand,
			"hand_blob": hand_blob, "t": t, "whole": cap & ~socket,
			"reachable": cap, "socket": socket}


def sweep_orphans(frame: np.ndarray, geoms: dict) -> int:
	"""THE BODY MUST BE ONE CONNECTED PIECE, and this is what makes the corridor width stop
	mattering.

	Whatever the corridor misses stays behind on the body at the pose it was painted in, and
	out at the end of an arm that means a few splayed fingertips left hanging in open air a
	limb's length from the man - which is exactly as broken as a severed arm, and far easier to
	ship because it is only a handful of pixels. Rather than tune the radius until it happens
	not to occur (the trap the previous version fell into from the other direction), take the
	fact that says it: the torso is one blob, so anything left over that does NOT touch it is
	debris, and debris this far out is arm. Give each orphan to the side it sits on.

	Returns the number of pixels rescued - normally small, and worth printing rather than
	swallowing, because a large number means the corridor has drifted off the limb entirely."""
	alpha = frame[..., 3] > 127
	left = alpha & ~geoms["L"]["whole"] & ~geoms["R"]["whole"]
	lab, n = ndimage.label(left)
	if n <= 1:
		return 0
	sizes = ndimage.sum(left, lab, range(1, n + 1))
	torso = int(np.argmax(sizes)) + 1
	cx = frame.shape[1] * 0.5
	rescued = 0
	for i in range(1, n + 1):
		if i == torso:
			continue
		blob = lab == i
		ys, xs = np.where(blob)
		side = "L" if xs.mean() < cx else "R"
		geoms[side]["whole"] |= blob
		rescued += int(blob.sum())
	return rescued


def cut_bones(frame: np.ndarray, g: dict) -> dict:
	"""Split one side's claimed pixels at the elbow into two rigid bones, with the pivots
	needed to rotate them later. All positions in FRAME (=body-canvas) coordinates."""
	side, cap, t = g["side"], g["whole"], g["t"]
	# the bone may grow back UNDER the cap by the seam overlap, but no further
	inner = ndimage.binary_dilation(cap, np.ones((3, 3), bool),
		iterations=SEAM_OVERLAP_PX) & g["reachable"]
	shoulder, elbow, hand, hand_blob = g["shoulder"], g["elbow"], g["hand"], g["hand_blob"]
	upper_mask = cap & (t < ELBOW_FRAC)
	lower_mask = cap & (t >= ELBOW_FRAC)
	grow = np.ones((3, 3), bool)
	upper_mask = ndimage.binary_dilation(upper_mask, grow, iterations=SEAM_OVERLAP_PX) & inner
	lower_mask = ndimage.binary_dilation(lower_mask, grow, iterations=SEAM_OVERLAP_PX) & cap
	upper, ux0, uy0 = crop_piece(frame, upper_mask)
	lower, lx0, ly0 = crop_piece(frame, lower_mask)
	return {
		"side": side, "shoulder": shoulder, "elbow": elbow, "hand": hand,
		"hand_blob": hand_blob,
		"whole": cap,
		# THE FOREARM'S END EFFECTOR IS THE HAND BLOB, NOT THE FITTED AXIS END. The medial line
		# is fitted to the SLEEVE so that the corridor hugs it (see arm_axis), and the splayed
		# fingers sit a few px off that line - so solving the chain to put the AXIS end on the
		# flat hand row leaves the actual hand swinging around it as the forearm rotates.
		# Measured: 11.1 art px of spread in the published `py`, against a FIG_PALM_MAX guard of
		# 7, which is the same class of bug as the hand line this rewrite was fixing. Driving
		# the solve from the blob makes the flat row exact by construction.
		"upper_len": math.hypot(elbow[0] - shoulder[0], elbow[1] - shoulder[1]),
		"fore_len": math.hypot(hand_blob[0] - elbow[0], hand_blob[1] - elbow[1]),
		"upper": upper, "upper_origin": (ux0, uy0),
		"upper_pivot_local": (shoulder[0] - ux0, shoulder[1] - uy0),
		"lower": lower, "lower_origin": (lx0, ly0),
		"lower_pivot_local": (elbow[0] - lx0, elbow[1] - ly0),
		# the hand blob as an OFFSET FROM THE ELBOW, so the prop anchor rides the forearm
		# through every rotation instead of being hunted for again in each rotated bitmap.
		# An offset needs no coordinate frame, which is the point: the same vector is correct
		# in source, local, padded-canvas and world coordinates alike.
		"blob_off": (hand_blob[0] - elbow[0], hand_blob[1] - elbow[1]),
	}


def rotate_about(piece: np.ndarray, local_pivot: tuple[float, float], angle_deg: float,
		pad: int = 48) -> np.ndarray:
	"""Rotate a piece by angle_deg about local_pivot, returning a (2*pad)^2 canvas in which
	the pivot sits at exactly (pad, pad) - before AND after rotation. Padding to a fixed
	square first (rather than PIL's expand=True) means the pivot's position never has to be
	recovered from the rotated bounding box: place this canvas at (world_x-pad, world_y-pad)
	and the pivot lands exactly on world_x, world_y, every time."""
	ph, pw = piece.shape[:2]
	canvas = np.zeros((pad * 2, pad * 2, 4), np.uint8)
	ox, oy = pad - int(round(local_pivot[0])), pad - int(round(local_pivot[1]))
	canvas[oy:oy + ph, ox:ox + pw] = piece
	im = Image.fromarray(canvas, "RGBA").rotate(
		angle_deg, resample=Image.NEAREST, center=(pad, pad))
	return np.asarray(im)


def rotate_offset(v: tuple[float, float], angle_deg: float) -> tuple[float, float]:
	"""The same transform rotate_about applies to pixels, applied to one offset vector - so
	the hand blob can be carried along the bone instead of hunted for again in the rotated
	bitmap. PIL's rotate(a) turns the IMAGE by a, which moves content by -a in array
	coordinates, hence the negation."""
	a = math.radians(-angle_deg)
	return (v[0] * math.cos(a) - v[1] * math.sin(a),
			v[0] * math.sin(a) + v[1] * math.cos(a))


def paste(dst: np.ndarray, piece: np.ndarray, top_left: tuple[int, int]) -> None:
	x0, y0 = top_left
	ph, pw = piece.shape[:2]
	dh, dw = dst.shape[:2]
	sx0, sy0 = max(0, -x0), max(0, -y0)
	dx0, dy0 = max(0, x0), max(0, y0)
	w = min(pw - sx0, dw - dx0)
	h = min(ph - sy0, dh - dy0)
	if w <= 0 or h <= 0:
		return
	src = piece[sy0:sy0 + h, sx0:sx0 + w]
	m = src[..., 3] > 0
	dst[dy0:dy0 + h, dx0:dx0 + w][m] = src[m]


def solve_two_bone(shoulder: tuple[float, float], target: tuple[float, float],
		l1: float, l2: float, sign: float) -> tuple[float, float]:
	"""Where the ELBOW goes so the two bones reach `target` from a fixed `shoulder`.

	Textbook two-bone IK: the elbow sits at one of the two intersections of the circle of
	radius l1 about the shoulder with the circle of radius l2 about the hand.

	CHOOSING BETWEEN THE TWO IS THE PART THAT NEEDS CARE, AND IT MUST NOT BE A SCORE. Every
	world-space test - "take the one below the shoulder->hand line", "take the one furthest
	outboard", or any weighted blend of the two - is a comparison whose winner can CHANGE as the
	hand moves, and the frame it changes on is a frame where the elbow teleports to the mirror
	solution. Measured on the scored version: at reach 38, dead in the middle of the range the
	game uses most, the elbow jumped 30 art px and the upper arm swung 246 degrees between two
	adjacent bank entries. Every single frame passed the connectivity check and looked fine on
	its own; the defect only exists in the MOTION (Louis: "the motion is completely unnatural").

	The fix is to make the branch a fixed property of the side rather than anything measured. A
	human elbow stays on ONE side of the shoulder->hand line - a juggler's points down and out,
	away from the ribs, and it never crosses over mid-catch. `sign * (-uy, ux)` is exactly that
	side, mirrored for the two arms, and it is a continuous function of the arm's direction, so
	the elbow now moves continuously by construction and there is no tie left to break."""
	dx, dy = target[0] - shoulder[0], target[1] - shoulder[1]
	d = math.hypot(dx, dy)
	d = max(abs(l1 - l2) + 1e-3, min(l1 + l2 - 1e-3, d))
	ux, uy = dx / max(d, 1e-6), dy / max(d, 1e-6)
	a = (d * d + l1 * l1 - l2 * l2) / (2.0 * d)
	hgt = math.sqrt(max(0.0, l1 * l1 - a * a))
	# ...and it is the OUTBOARD side, away from the ribs (Louis: "elbows pointing outwards").
	# The other branch tucks the elbow in behind the forearm, which at this size reads as an
	# angular chicken wing rather than an arm hanging off a shoulder - A/B'd on the figure.
	nx, ny = sign * uy, -sign * ux
	return (shoulder[0] + a * ux + hgt * nx, shoulder[1] + a * uy + hgt * ny)


def pose_at(d: dict, reach: float, torso_cx: float, hand_row: float) -> dict:
	"""Both bones rotated so the hand lands at this reach, on the FLAT hand line."""
	sign = side_sign(d["side"])
	shoulder = d["shoulder"]
	l1, l2 = d["upper_len"], d["fore_len"]
	target = (torso_cx + sign * reach, hand_row)

	# THE SHOULDER IS DAMPED, NOT DRIVEN. Take the angle the free solve wants, keep only
	# SHOULDER_GAIN of its departure from rest, and cap that - see the constants for the
	# measured windmill this replaces. The forearm then takes up the slack, which is the
	# division of labour a juggler's arm actually uses.
	el_free = solve_two_bone(shoulder, target, l1, l2, sign)
	th_free = math.degrees(math.atan2(el_free[1] - shoulder[1], el_free[0] - shoulder[0]))
	th_rest = 90.0 - sign * SHOULDER_REST_OUT_DEG
	off = (th_free - th_rest + 180.0) % 360.0 - 180.0        # shortest way round
	off = max(-SHOULDER_MAX_DEG, min(SHOULDER_MAX_DEG, off * SHOULDER_GAIN))
	th = math.radians(th_rest + off)
	elbow = (shoulder[0] + l1 * math.cos(th), shoulder[1] + l1 * math.sin(th))

	# THE HAND IS WHERE THE BONES PUT IT, not where it was asked for - and with the shoulder
	# damped it genuinely is not where it was asked for: the forearm points AT the target from
	# a slightly different elbow, so it lands a little short or long of it. That is the trade
	# for a still shoulder and it costs nothing, because every number the bank publishes is
	# read back off the pose the bones actually make. Recording the TARGET instead is the bug
	# class that had the shipped bank publishing a hand line 20 art px from any hand it had
	# painted; `reach` and `py` below both come from `hand`.
	ux, uy = target[0] - elbow[0], target[1] - elbow[1]
	ulen = math.hypot(ux, uy) or 1.0
	hand = (elbow[0] + d["fore_len"] * ux / ulen, elbow[1] + d["fore_len"] * uy / ulen)

	def delta(src_a: tuple, src_b: tuple, tgt_a: tuple, tgt_b: tuple) -> float:
		s = math.degrees(math.atan2(src_b[1] - src_a[1], src_b[0] - src_a[0]))
		t = math.degrees(math.atan2(tgt_b[1] - tgt_a[1], tgt_b[0] - tgt_a[0]))
		return -(t - s)

	up_deg = delta(d["shoulder"], d["elbow"], shoulder, elbow)
	fo_deg = delta(d["elbow"], d["hand_blob"], elbow, hand)
	boff = rotate_offset(d["blob_off"], fo_deg)
	return {
		"side": d["side"], "shoulder": shoulder, "elbow": elbow, "hand": hand,
		"upper_rot": rotate_about(d["upper"], d["upper_pivot_local"], up_deg),
		"forearm_rot": rotate_about(d["lower"], d["lower_pivot_local"], fo_deg),
		# the hand blob's centre in BODY-CANVAS coordinates - painted skin by construction,
		# which is what both the prop anchor and the connectivity check want
		"wrist": (elbow[0] + boff[0], elbow[1] + boff[1]),
	}


def paste_arm(dst: np.ndarray, pose: dict, off: tuple[int, int] = (0, 0), pad: int = 48) -> None:
	"""Both bones onto dst. The upper arm goes down FIRST so the forearm covers the elbow
	seam - the two overlap there by SEAM_OVERLAP_PX and whichever is drawn last wins."""
	sx, sy = pose["shoulder"]
	ex, ey = pose["elbow"]
	paste(dst, pose["upper_rot"], (int(round(sx)) - pad + off[0], int(round(sy)) - pad + off[1]))
	paste(dst, pose["forearm_rot"], (int(round(ex)) - pad + off[0], int(round(ey)) - pad + off[1]))


def pose_layer(pose: dict, pad: int = 48, margin: int = 56) -> tuple[np.ndarray, int, int, tuple]:
	"""This pose's WHOLE arm, tight-cropped to one small RGBA layer, with its (ox, oy) offset
	back into BODY-canvas coordinates - matching the {layer, ox, oy} shape the atlas entries
	already use - and the hand blob's position in body-canvas coordinates. ox/oy may come out
	negative (a wide-reach pose extends past the body cell itself, same as the old pipeline's
	own documented case); the margin keeps that from clipping."""
	work = np.zeros((999, 999, 4), np.uint8)   # oversized scratch, cropped immediately after
	paste_arm(work, pose, (margin, margin), pad)
	layer, lx0, ly0 = crop_piece(work, work[..., 3] > 0)
	return layer, lx0 - margin, ly0 - margin, pose["wrist"]


def composite(body: np.ndarray, pose: dict) -> np.ndarray:
	out = body.copy()
	paste_arm(out, pose)
	return out


def check_connected(body: np.ndarray, pose: dict) -> float:
	"""THE INVARIANT SIX COMMITS LACKED: how much of the arm is background.

	Walks the shoulder->elbow->hand polyline of a composited pose and counts the samples that
	land on a transparent pixel. An arm that is properly joined to its torso reads 0.0 here at
	every reach; the version this rewrite replaces read 0.35-0.45 (a 23 art px hole between
	the torso and the sleeve), which is what "the arms look horrible" was.

	THE CHAIN ENDS AT THE HAND BLOB, NOT AT THE AXIS ENDPOINT. The medial line is fitted to the
	SLEEVE (see arm_axis) and the fingers splay upward off it, so its far end sits a few px
	below the painted hand and lands in the open air between two fingers - which the first run
	of this check duly reported as a 4% gap on almost every pose. That is the probe missing,
	not the arm breaking; the blob's centre is painted skin by construction."""
	img = composite(body, pose)
	alpha = img[..., 3] > 0
	# START AT THE SOCKET RIM, NOT AT THE JOINT. The joint is pinned INSIDE the torso and the
	# body's own cap covers everything within SHOULDER_CAP_R of it, so those samples are opaque
	# by construction and say nothing - while the straight line from the joint to a swung elbow
	# clips the armpit, which the cap does not owe anything to. Walking from the rim measures the
	# part that is actually in question: the bone, from where it leaves the socket.
	sx, sy = pose["shoulder"]
	ex, ey = pose["elbow"]
	blen = math.hypot(ex - sx, ey - sy) or 1.0
	k = min(1.0, SHOULDER_CAP_R / blen)
	rim = (sx + (ex - sx) * k, sy + (ey - sy) * k)
	pts = [rim, pose["elbow"], pose["wrist"]]
	miss = total = 0
	for a, b in ((pts[0], pts[1]), (pts[1], pts[2])):
		n = max(2, int(math.hypot(b[0] - a[0], b[1] - a[1]) * 2))
		for i in range(n + 1):
			x = int(round(a[0] + (b[0] - a[0]) * i / n))
			y = int(round(a[1] + (b[1] - a[1]) * i / n))
			total += 1
			if not (0 <= y < alpha.shape[0] and 0 <= x < alpha.shape[1] and alpha[y, x]):
				miss += 1
	return miss / max(1, total)


def check_smooth(poses: list) -> dict:
	"""THE INVARIANT THAT CATCHES A BAD ANIMATION RATHER THAN A BAD FRAME.

	check_connected looks at one pose at a time and cannot see a sequence that jumps: the scored
	elbow-branch version passed it on all 96 entries while the elbow teleported 30 art px between
	two adjacent ones, because both endpoints of the jump were perfectly good arms. The bank is a
	table the game steps along as the hand moves, so ADJACENT ENTRIES ARE ANIMATION FRAMES and
	the thing that matters is how far anything moves between two of them.

	Reports the worst step and the total travel. Big STEP = a pop; big TRAVEL = a windmill, even
	if every step is small. Both have shipped."""
	out = {"elbow_step": 0.0, "elbow_travel": 0.0, "upper_step": 0.0, "upper_swing": 0.0}
	ang = []
	prev = None
	for p in sorted(poses, key=lambda q: q["hand"][0]):
		sh, el = p["shoulder"], p["elbow"]
		a = math.degrees(math.atan2(el[1] - sh[1], el[0] - sh[0]))
		# UNWRAP, or atan2's seam at +-180 is reported as a 360-degree windmill. The upper arm
		# genuinely does cross that seam on this figure (it points down-and-outward, which is
		# near 180 for the left arm), so this is not a corner case.
		if ang:
			a = ang[-1] + ((a - ang[-1] + 180.0) % 360.0 - 180.0)
		ang.append(a)
		if prev is not None:
			out["elbow_step"] = max(out["elbow_step"],
				math.hypot(el[0] - prev[0][0], el[1] - prev[0][1]))
			out["elbow_travel"] += math.hypot(el[0] - prev[0][0], el[1] - prev[0][1])
			out["upper_step"] = max(out["upper_step"], abs((a - prev[1] + 180) % 360 - 180))
		prev = (el, a)
	out["upper_swing"] = max(ang) - min(ang) if ang else 0.0
	return out


def seal_sockets(body: np.ndarray, joints: list) -> int:
	"""Close the armpit notch at each shoulder and paint it from the coat's nearest pixel.

	See SOCKET_SEAL_R for why this is necessary at all. Restricted to a window around each joint
	so it can never quietly reshape the coat, the hem or the silhouette anywhere else - the
	juggler's stance and proportions are settled and a fix elsewhere must not move them."""
	alpha = body[..., 3] > 0
	want = np.zeros_like(alpha)
	h, w = alpha.shape
	for jx, jy in joints:
		y0, y1 = max(0, int(jy) - 14), min(h, int(jy) + 16)
		x0, x1 = max(0, int(jx) - 16), min(w, int(jx) + 16)
		win = alpha[y0:y1, x0:x1]
		closed = ndimage.binary_closing(win, ndimage.generate_binary_structure(2, 1),
			iterations=SOCKET_SEAL_R)
		want[y0:y1, x0:x1] |= closed & ~win
	if not want.any():
		return 0
	# nearest opaque pixel supplies the colour, so the fabric is always the coat's own
	idx = ndimage.distance_transform_edt(~alpha, return_distances=False, return_indices=True)
	body[want] = body[idx[0][want], idx[1][want]]
	body[..., 3][want] = 255
	return int(want.sum())


def build() -> dict:
	"""Everything the writers and the debug sheet need, from the one source frame."""
	frame = armlib.common_crop(armlib.load_frames(SRC))[0].astype(np.uint8)
	blobs = skin_blobs(frame)
	geoms = {s: claim(s, frame, blobs[s]) for s in ("L", "R")}
	rescued = sweep_orphans(frame, geoms)
	sides = {s: cut_bones(frame, geoms[s]) for s in ("L", "R")}

	# THE STATIC BODY: the frame with each arm's whole corridor erased. The coat's puffed
	# epaulette is OUTSIDE that corridor and stays exactly where it was painted, which is
	# both correct (it is torso) and load-bearing (it caps the joint at every angle).
	body = frame.copy()
	for d in sides.values():
		body[d["whole"]] = 0
	sealed = seal_sockets(body, [d["shoulder"] for d in sides.values()])

	bys, bxs = np.where(body[..., 3] > 0)
	torso_cx = (int(bxs.min()) + int(bxs.max())) * 0.5

	# THE HAND LINE IS FLAT, BECAUSE THE GAME'S IS. `outer_pos` sits at stage_center().y at
	# every reach, and `fig_hand_pos` refuses a painted palm more than FIG_PALM_MAX (7 art px)
	# from it. Letting the row follow the art describes the poses honestly and is still wrong:
	# the guard then rejects them, the prop snaps back to the simulated hand, and the player
	# sees a raised arm with its ball low and left. An empty bucket is strictly better than a
	# lying one - so the IK target row is a CONSTANT and `py` cannot drift from it.
	#
	# WHICH ROW IS A REAL DECISION, and taking the source's own is wrong. The generator paints
	# this pose with the arms held straight out SIDEWAYS, so its hands sit 6 art px below the
	# shoulder - armpit height. Juggling on that line looks bad for a reason that is geometric
	# rather than aesthetic: every inward pose then has to put the hand almost directly beneath
	# the shoulder, and a two-bone chain reaching a point that close to its own root has to
	# throw the elbow far out to fold that tightly. Measured at the inner end of the sweep, it
	# came back as a shrug - the upper arm cocked up and outward like a chicken wing.
	#
	# Dropping the line to ~45% of the arm's own length below the shoulder puts the hands at
	# waist height, where a juggler's are, and keeps the elbow comfortably inside its range at
	# every reach the game asks for. It cannot go much further: the whole arm is only 40 art px
	# and the shoulder sits 40 px above the game's canon hand line, so a line at hip height is
	# one this painting's arms could only reach dead straight, with no elbow left to bend.
	# CLAUDE.md records the same tension from the other side - the model will not paint tucked
	# hands at hip height, five attempts, every phrasing.
	l_arm = float(np.mean([d["upper_len"] + d["fore_len"] for d in sides.values()]))
	hand_row = float(np.mean([d["shoulder"][1] for d in sides.values()])) + HAND_DROP_FRAC * l_arm

	# THE REACH RANGE IS READ OFF THE BONES, not hand-tuned into a pair of constants the
	# geometry then has to be argued into (which is how the version this replaces ended up
	# with REACH_HI sitting exactly on a fixed elbow's own most-extended point, where reach
	# barely changes with angle and height changes fast - so ordinary reaches came back with
	# the hand near his collar).
	#
	# Along a horizontal line `dy` below the shoulder, the two-bone chain can put its hand
	# anywhere whose distance from the shoulder is between |l1-l2| and l1+l2. Intersecting
	# that annulus with the line gives the band directly, and sampling strictly inside it
	# means every pose is genuinely solvable - no target is ever clamped, so no entry can
	# record a reach or a hand row it did not actually achieve.
	l1 = float(np.mean([d["upper_len"] for d in sides.values()]))
	l2 = float(np.mean([d["fore_len"] for d in sides.values()]))
	shoulder_off = float(np.mean([abs(d["shoulder"][0] - torso_cx) for d in sides.values()]))
	dy = hand_row - float(np.mean([d["shoulder"][1] for d in sides.values()]))
	outer = math.sqrt(max(0.0, (l1 + l2) ** 2 - dy * dy))
	inner = math.sqrt(max(0.0, (l1 - l2) ** 2 - dy * dy))
	reach_hi = shoulder_off + outer - REACH_MARGIN
	# `inner` is the dead zone the folded chain cannot enter. Once the hand line is dropped it
	# usually vanishes entirely (the vertical offset alone already exceeds |l1-l2|), and then
	# the band runs unbroken through the shoulder and out the far side - so the floor is a
	# judgement about what is worth drawing, not a limit.
	reach_lo = max(REACH_FLOOR, shoulder_off - outer + REACH_MARGIN)
	if inner > 0.0:
		reach_lo = max(reach_lo, shoulder_off - inner - REACH_MARGIN)

	reaches = [reach_hi - (reach_hi - reach_lo) * i / (N_POSES - 1) for i in range(N_POSES)]

	def row_at(reach: float) -> float:
		"""The carry: level at the catch, dipping as the hand comes in.

		LINEAR BETWEEN THE TWO SLOTS, AND CLAMPED OUTSIDE THEM, because that is what the game
		does. `hand_target` lerps hpos toward whichever slot it wants, so the simulated hand
		runs down a near-straight line between them; a smoothstep here would be a prettier
		curve that disagrees with the hand it is supposed to be holding, and the disagreement
		is exactly what FIG_PALM_MAX measures."""
		t = max(0.0, min(1.0, (GAME_OUTER_REACH - reach)
			/ (GAME_OUTER_REACH - GAME_INNER_REACH)))
		return hand_row + HAND_CARRY_DIP * t + HAND_CARRY_BOW * math.sin(math.pi * t)

	poses = {s: [pose_at(sides[s], r, torso_cx, row_at(r)) for r in reaches] for s in ("L", "R")}
	return {"frame": frame, "body": body, "sides": sides, "poses": poses, "row_at": row_at,
			"torso_cx": torso_cx, "hand_row": hand_row, "rescued": rescued, "sealed": sealed,
			"reach_lo": reach_lo, "reach_hi": reach_hi}


def main() -> int:
	argv = sys.argv[1:]
	sheet = None
	if "--sheet" in argv:
		i = argv.index("--sheet")
		sheet = Path(argv[i + 1])
		del argv[i:i + 2]

	r = build()
	body, sides, poses = r["body"], r["sides"], r["poses"]
	print(f"frame {r['frame'].shape[1]}x{r['frame'].shape[0]}  torso_cx {r['torso_cx']}")
	for s, d in sides.items():
		print(f"{s}: shoulder ({d['shoulder'][0]:.1f},{d['shoulder'][1]:.1f})  "
			  f"elbow ({d['elbow'][0]:.1f},{d['elbow'][1]:.1f})  "
			  f"hand ({d['hand'][0]:.1f},{d['hand'][1]:.1f})  "
			  f"bones {d['upper_len']:.1f}+{d['fore_len']:.1f}px  "
			  f"arm {(d['upper'][..., 3] > 0).sum()}+{(d['lower'][..., 3] > 0).sum()}px")
	print(f"orphan pixels swept back into the arms: {r['rescued']} "
		  f"(the body is one connected piece)")
	print(f"armpit notch sealed with {r['sealed']} px of the coat's own fabric")
	print(f"hand line (flat) at row {r['hand_row']:.1f} of {body.shape[0]}")
	print(f"reach {r['reach_lo']:.1f}..{r['reach_hi']:.1f} over {N_POSES} poses "
		  f"(game wants 27..50 from inner_pos/outer_pos)")

	worst = 0.0
	for s in ("L", "R"):
		for p in poses[s]:
			worst = max(worst, check_connected(body, p))
	print(f"arm connectivity: worst gap along the bones {worst * 100:.1f}% "
		  f"({'OK' if worst < 0.02 else 'BROKEN'})")
	sm = {s: check_smooth(poses[s]) for s in ("L", "R")}
	step = max(v["elbow_step"] for v in sm.values())
	travel = max(v["elbow_travel"] for v in sm.values())
	swing = max(v["upper_swing"] for v in sm.values())
	print(f"arm motion: worst elbow step {step:.2f} art px between adjacent entries "
		  f"({'OK' if step < 3.0 else 'POPS'}); elbow travels {travel:.1f} px and the "
		  f"shoulder swings {swing:.1f} deg across the whole sweep "
		  f"({'OK' if swing < 45.0 else 'WINDMILLS'})")   # 45: a real shoulder does move

	if sheet:
		_debug_sheet(sheet, body, poses)
		print(f"debug sheet -> {sheet}")

	if "--write" in argv:
		write_bank(body, poses, r["torso_cx"], force="--force" in argv)
	return 0 if worst < 0.02 else 1


def write_bank(body: np.ndarray, poses: dict, torso_cx: float, force: bool = False) -> None:
	"""Assemble the exact schema build_arm_bank.py writes (juggle_body.png, juggle_arms.png
	/.json, the _ARMS block in art_manifest.json) so Game.gd's fig_arm_pick needs no change."""
	pal = np.asarray(Image.open(PALETTE).convert("RGB")).reshape(-1, 3).astype(int)
	body_s = bank.snap(body, pal)
	body_pal = np.unique(body_s[body_s[..., 3] > 0][:, :3], axis=0)

	entries = []
	for s in ("L", "R"):
		for p in poses[s]:
			layer, ox, oy, hand_world = pose_layer(p)
			if layer.size == 0:
				continue
			layer = bank.snap(layer, body_pal)
			reach = (torso_cx - p["hand"][0]) if s == "L" else (p["hand"][0] - torso_cx)
			# THE PROP ANCHOR IS NOT THE HAND CENTROID. The blob averages fingers AND wrist,
			# which pulls it back toward the denser heel of the palm, short of where a held
			# prop sits. Nudge the ANCHOR ONLY (never `reach`, which must stay the true
			# kinematic position the lookup matches against) out along the forearm's own axis.
			ex, ey = p["elbow"]
			dx, dy = hand_world[0] - ex, hand_world[1] - ey
			dlen = math.hypot(dx, dy) or 1.0
			entries.append({
				"side": s, "reach": float(reach), "layer": layer, "ox": ox, "oy": oy,
				"px": hand_world[0] + dx / dlen * PROP_ANCHOR_SHIFT,
				"py": hand_world[1] + dy / dlen * PROP_ANCHOR_SHIFT,
			})

	aw = max(e["layer"].shape[1] for e in entries)
	ah = max(e["layer"].shape[0] for e in entries)
	cols = 8
	rows = (len(entries) + cols - 1) // cols
	atlas = np.zeros((rows * ah, cols * aw, 4), np.uint8)
	meta = {"cell_w": body.shape[1], "cell_h": body.shape[0], "atlas_cols": cols,
			"atlas_w": aw, "atlas_h": ah, "body_cx": round(float(torso_cx), 1),
			"hand_py": 0.0, "head": bank.head_box(body_s), "left": [], "right": []}
	for n, e in enumerate(entries):
		row, col = divmod(n, cols)
		lay = e["layer"]
		atlas[row * ah:row * ah + lay.shape[0], col * aw:col * aw + lay.shape[1]] = lay
		meta["left" if e["side"] == "L" else "right"].append({
			"slot": n, "reach": round(e["reach"], 2), "ox": int(e["ox"]), "oy": int(e["oy"]),
			"px": round(e["px"], 1), "py": round(e["py"], 1), "flat": 1.0})
	meta["left"].sort(key=lambda r: r["reach"])
	meta["right"].sort(key=lambda r: r["reach"])
	# HAND_PY IS THE CATCH LINE, NOT A MEDIAN OVER THE SWEEP. `stage_center` places the whole
	# figure so this row lands on the game's own hand line, and that line is `outer_pos` - the
	# level one. A median taken over a carry that dips 20 art px would sit half a dip below the
	# catch, so the man would be drawn 10 art px low at the very moment the catch is judged, and
	# `fig_hand_pos` would refuse the palm on the poses that matter most. Read it off the entry
	# nearest the outer slot instead.
	outer = min(meta["left"], key=lambda r: abs(r["reach"] - GAME_OUTER_REACH))
	meta["hand_py"] = round(float(outer["py"]), 1)
	# THE NUMBER THAT MATTERS IS NOT THE SPREAD, IT IS THE DISAGREEMENT. The palm is SUPPOSED to
	# travel now - it dips 20 art px with the carry - so a raw spread says nothing. What
	# FIG_PALM_MAX actually measures is the gap between the painted palm and the simulated hand
	# at the SAME reach, and the simulation dips too (HAND_IN_DIP), so compare against that.
	def game_row(reach: float) -> float:
		t = (GAME_OUTER_REACH - reach) / (GAME_OUTER_REACH - GAME_INNER_REACH)
		return float(meta["hand_py"]) + HAND_CARRY_DIP * max(0.0, min(1.0, t))
	resid = max(abs(r["py"] - game_row(r["reach"])) for r in meta["left"] + meta["right"])
	print(f"hand line at row {meta['hand_py']} (the catch) of {body.shape[0]}; painted palm vs "
		  f"the simulated hand at the same reach: worst {resid:.1f} art px "
		  f"({'OK' if resid <= 7.0 else 'OVER'}, FIG_PALM_MAX allows 7)")

	# THE PERFORMER'S OWN PALM, cut from a mid-reach entry, for the columns central-lane case
	# (draw_figure_palm / fig_palm_far) - same purpose and box size as build_arm_bank.py.
	mid = min((e for e in entries if e["side"] == "L"), key=lambda x: abs(x["reach"] - 30))
	lay = mid["layer"]
	lpx, lpy = mid["px"] - mid["ox"], mid["py"] - mid["oy"]
	x0 = max(0, int(lpx - bank.PALM_BOX[0] // 2 + bank.PALM_SHIFT))
	y0 = max(0, int(lpy - bank.PALM_BOX[1] // 2))
	patch = bank.snap(lay[y0:y0 + bank.PALM_BOX[1], x0:x0 + bank.PALM_BOX[0]], body_pal)
	meta["palm"] = {"w": int(patch.shape[1]), "h": int(patch.shape[0]),
					"ax": round(float(lpx - x0), 1), "ay": round(float(lpy - y0), 1)}
	artguard.save_guarded(OUT / "palm_l.png",
		lambda q: Image.fromarray(patch, "RGBA").save(q), force)
	artguard.save_guarded(OUT / "palm_r.png",
		lambda q: Image.fromarray(patch[:, ::-1], "RGBA").save(q), force)
	print(f"palm patch {patch.shape[1]}x{patch.shape[0]} from the reach-{mid['reach']:.0f} pose")

	s1 = artguard.save_guarded(OUT / "juggle_body.png",
		lambda q: Image.fromarray(body_s, "RGBA").save(q), force)
	s2 = artguard.save_guarded(OUT / "juggle_arms.png",
		lambda q: Image.fromarray(atlas, "RGBA").save(q), force)
	(OUT / "juggle_arms.json").write_text(json.dumps(meta, indent=2) + "\n")
	man = ROOT / "Resources" / "art_manifest.json"
	doc = json.loads(man.read_text())
	doc["_ARMS"] = meta
	man.write_text(json.dumps(doc, indent=2) + "\n")
	print(f"wrote body {body.shape[1]}x{body.shape[0]} [{s1}] and {len(entries)} arms in a "
		  f"{cols * aw}x{rows * ah} atlas [{s2}], and _ARMS into {man.name}")


def _debug_sheet(path: Path, body: np.ndarray, poses: dict) -> None:
	"""A grid, one cell per pose index, both sides at the SAME sweep position (symmetric) -
	this is a geometry check, not a play-accurate frame; antiphase pairing is judged later
	from the game itself. Native 4x: a downscaled strip has read as a torn figure before on
	this project, so nothing here is judged smaller than it will be drawn."""
	ch, cw = body.shape[:2]
	cols = min(6, N_POSES)
	rows = (N_POSES + cols - 1) // cols
	Z = 4
	out = Image.new("RGBA", (cw * cols * Z, ch * rows * Z), (26, 24, 34, 255))
	for i in range(N_POSES):
		img = body.copy()
		for s in ("L", "R"):
			paste_arm(img, poses[s][i])
		im = Image.fromarray(img.astype(np.uint8), "RGBA").resize((cw * Z, ch * Z), Image.NEAREST)
		out.paste(im, ((i % cols) * cw * Z, (i // cols) * ch * Z), im)
	out.save(path)


if __name__ == "__main__":
	raise SystemExit(main())
