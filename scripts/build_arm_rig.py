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
from"). Cut each arm at the elbow into two rigid pieces: the upper arm and the forearm+hand.
The source pose holds both arms up in a "ta-da" presentation gesture, well above where a
juggler's catching hand actually sits - so BOTH joints are re-angled per pose from a shared
rest position (see joint_angles), but the upper arm's own sweep is a fraction of the
forearm's (55deg vs 125deg across the whole reach range - see UPPER_ANGLE_*/FOREARM_ANGLE_*)
so in the common case it reads as "slight movement if any", while the forearm supplies the
"circular movement" Louis asked for. Every pose is the same source pixels moved by a rigid
rotation, so nothing is ever redrawn or reinterpreted frame to frame - the geometry, not a
statistical vote across noisy generations, is what keeps the man from twitching.

Output is written in the EXACT schema build_arm_bank.py already produces (juggle_body.png,
juggle_arms.png/.json, the _ARMS block in art_manifest.json) - Game.gd's fig_arm_pick does
a reach lookup into that schema and needs no changes.

USAGE
  .venv/bin/python scripts/build_arm_rig.py --sheet artifacts/rig_debug.png
  .venv/bin/python scripts/build_arm_rig.py --write
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

import armlib
import artguard
import build_arm_bank as bank  # reuse: snap(), _snap_rgb, head_box, artguard writer

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "Assets" / "Characters" / "showman" / "source.png"
OUT = ROOT / "Assets" / "Characters" / "showman"
PALETTE = ROOT / "Resources" / "palette" / "palette.png"

# Same coverage the shipped bank targets - see build_arm_bank.py's own header for why these
# two numbers are what they are (columns' outer lanes need 64; the game's hand line is flat).
REACH_LO, REACH_HI = 0.0, 64.0
N_POSES = 12

# How far along the shoulder->hand axis the elbow sits. Not measured per-limb; a fixed
# fraction is enough for one reference pose, and PixelLab's touch-up pass is what smooths
# the seam this approximation leaves.
ELBOW_FRAC = 0.45

# Max degrees the SHOULDER may rotate from its rest pose, only ever engaged when the
# forearm alone (fixed elbow) cannot reach a target - "slight movement if any".
SHOULDER_MAX_DEG = 12.0

# WHY A GEOMETRIC CAPSULE AND NOT SILHOUETTE SEPARATION. Measured on the actual source pose
# (scripts/arm_band_zoom.png): the sleeve is fused to the coat with NO GAP anywhere in this
# pose - the whole hand-to-hand silhouette across the shoulders is one connected blob, so
# there is no row where "torso" and "arm" are separate runs to tell apart by connectivity.
# armlib's own diff-against-a-known-body approach doesn't apply either: that body only
# exists once you already have several generations to vote across (see armlib.body_of),
# which is exactly what one clean source frame does not have.
#
# So the arm is claimed by GEOMETRY instead: every opaque pixel within a tapered corridor
# around the measured shoulder->hand segment belongs to the arm, regardless of whether it
# is topologically separable from the coat. This matches how the source art itself is
# built - a tapered capsule - and it is the same shape the game's own draw_capsule_pix
# already assumes for a live-rasterised limb.
ARM_RADIUS = (6.0, 15.0)     # corridor half-width at the shoulder, then at the hand (wide
                              # enough to cover the fully spread fingers, measured to fall
                              # short at 9 and leave stray fingertip pixels behind in body)
HAND_BOX = {"L": (0, 28, 30, 46), "R": (124, 152, 30, 46)}
SHOULDER_ROW = 29            # last row where the coat's own silhouette still grows smoothly


def hand_point(mask: np.ndarray, side: str) -> tuple[float, float]:
	"""Centroid of the opaque pixels in this side's hand box - robust to however many
	distinct skin/highlight tones the hand is shaded in, since it only looks at alpha."""
	x0, x1, y0, y1 = HAND_BOX[side]
	sub = mask[y0:y1, x0:x1]
	ys, xs = np.where(sub)
	return float(xs.mean() + x0), float(ys.mean() + y0)


def shoulder_point(mask: np.ndarray, side: str) -> tuple[float, float]:
	"""The coat's own silhouette edge at SHOULDER_ROW - the last row before the arm's
	geometry starts dominating the row's width (see the header note)."""
	xs = np.where(mask[SHOULDER_ROW])[0]
	x = float(xs.min()) if side == "L" else float(xs.max())
	return x, float(SHOULDER_ROW)


def capsule_params(mask: np.ndarray, p0: tuple[float, float], p1: tuple[float, float],
		r0: float, r1: float) -> tuple[np.ndarray, np.ndarray]:
	"""(t, in_capsule) for every pixel: t is the 0..1 position along p0->p1 (clamped
	segment, not the infinite line), in_capsule is opaque AND within the tapered radius."""
	h, w = mask.shape
	yy, xx = np.mgrid[0:h, 0:w].astype(float)
	vx, vy = p1[0] - p0[0], p1[1] - p0[1]
	length2 = vx * vx + vy * vy
	t_raw = ((xx - p0[0]) * vx + (yy - p0[1]) * vy) / length2
	t_c = np.clip(t_raw, 0.0, 1.0)
	proj_x, proj_y = p0[0] + t_c * vx, p0[1] + t_c * vy
	dist = np.hypot(xx - proj_x, yy - proj_y)
	radius = r0 + (r1 - r0) * t_c
	# t reaches ~1.33 for this pose's own splayed fingertips (measured) - past the hand
	# CENTROID at t=1, which is expected: fingers fan out beyond the point that centres them.
	in_capsule = mask & (t_raw >= -0.08) & (t_raw <= 1.5) & (dist <= radius)
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


def extract(side: str, frame: np.ndarray) -> dict:
	"""Everything about one side of the source pose: the elbow split and the pivots needed
	to rotate the forearm later. All positions in FRAME (=body-canvas) coordinates."""
	mask = frame[..., 3] > 127
	shoulder = shoulder_point(mask, side)
	hand = hand_point(mask, side)
	elbow = (shoulder[0] + ELBOW_FRAC * (hand[0] - shoulder[0]),
			 shoulder[1] + ELBOW_FRAC * (hand[1] - shoulder[1]))
	t, cap = capsule_params(mask, shoulder, hand, *ARM_RADIUS)
	upper_mask = cap & (t < ELBOW_FRAC)
	lower_mask = cap & (t >= ELBOW_FRAC)
	upper, ux0, uy0 = crop_piece(frame, upper_mask)
	lower, lx0, ly0 = crop_piece(frame, lower_mask)
	return {
		"side": side, "shoulder": shoulder, "elbow": elbow, "hand": hand,
		"upper_len": math.hypot(elbow[0] - shoulder[0], elbow[1] - shoulder[1]),
		"fore_len": math.hypot(hand[0] - elbow[0], hand[1] - elbow[1]),
		"upper": upper, "upper_origin": (ux0, uy0),
		"upper_pivot_local": (shoulder[0] - ux0, shoulder[1] - uy0),  # shoulder, in upper's own coords
		"lower": lower, "lower_origin": (lx0, ly0),
		"lower_pivot_local": (elbow[0] - lx0, elbow[1] - ly0),  # elbow, in the forearm's own coords
	}


def rotate_about(piece: np.ndarray, local_pivot: tuple[float, float], angle_deg: float,
		pad: int = 40) -> np.ndarray:
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


# Both joint angles are authored curves over the sweep parameter s in [0,1], not a solved
# IK target - simpler, and it gives direct control over how much each joint moves. Degrees
# below horizontal, tilted outward (0 = arm straight out sideways, 90 = straight down).
#
# UPPER_ANGLE moves gently (80 deg at rest -> 40 deg at full reach): most of the sweep never
# needs it much extended, so in the common case it reads as "slight movement if any". It
# only opens toward horizontal for the rare wide reaches columns needs at 6-7 objects.
# FOREARM_ANGLE does the real work, swinging from tucked-under to nearly straight out - the
# "circular movement in the lower arm" Louis asked for.
UPPER_ANGLE_LO, UPPER_ANGLE_HI = 85.0, 30.0
FOREARM_ANGLE_LO, FOREARM_ANGLE_HI = 110.0, -15.0


def joint_angles(s: float) -> tuple[float, float]:
	return (UPPER_ANGLE_LO + (UPPER_ANGLE_HI - UPPER_ANGLE_LO) * s,
			FOREARM_ANGLE_LO + (FOREARM_ANGLE_HI - FOREARM_ANGLE_LO) * s)


def pose_at(d: dict, s: float) -> dict:
	"""Rotate this side's upper+forearm pieces to the joint angles for sweep position s.
	Returns world-space pivots/pieces ready to composite, plus the resulting (reach, py)."""
	side = d["side"]
	sign = -1.0 if side == "L" else 1.0   # L points toward -x (outward, away from torso)
	up_deg, fore_deg = joint_angles(s)
	up_dir = (sign * math.cos(math.radians(up_deg)), math.sin(math.radians(up_deg)))
	elbow = (d["shoulder"][0] + d["upper_len"] * up_dir[0],
			 d["shoulder"][1] + d["upper_len"] * up_dir[1])
	fore_dir = (sign * math.cos(math.radians(fore_deg)), math.sin(math.radians(fore_deg)))
	hand = (elbow[0] + d["fore_len"] * fore_dir[0], elbow[1] + d["fore_len"] * fore_dir[1])

	# PIL rotate() turns CCW for +angle in an x-right/y-down frame, i.e. visually CW; sign
	# empirically checked against the debug sheet (s=0 must reproduce ~ the baked rest pose).
	src_up_deg = math.degrees(math.atan2(d["elbow"][1] - d["shoulder"][1],
										  d["elbow"][0] - d["shoulder"][0]))
	tgt_up_deg = math.degrees(math.atan2(elbow[1] - d["shoulder"][1], elbow[0] - d["shoulder"][0]))
	up_rot = rotate_about(d["upper"], d["upper_pivot_local"], -(tgt_up_deg - src_up_deg))

	src_fo_deg = math.degrees(math.atan2(d["hand"][1] - d["elbow"][1], d["hand"][0] - d["elbow"][0]))
	tgt_fo_deg = math.degrees(math.atan2(hand[1] - elbow[1], hand[0] - elbow[0]))
	fo_rot = rotate_about(d["lower"], d["lower_pivot_local"], -(tgt_fo_deg - src_fo_deg))

	return {"side": side, "s": s, "elbow": elbow, "hand": hand,
			"upper_rot": up_rot, "forearm_rot": fo_rot}


def pose_layer(d: dict, pose: dict, pad: int = 40, margin: int = 40) -> tuple[np.ndarray, int, int]:
	"""This pose's upper+forearm pieces composited together and tight-cropped to one small
	RGBA layer, with its (ox, oy) offset back into BODY-canvas coordinates - matching the
	{layer, ox, oy} shape build_arm_bank.py's atlas entries already use. ox/oy may come out
	negative (a wide-reach pose extends further than the body cell itself, same as the old
	pipeline's own documented case) - a big enough margin keeps that from clipping."""
	work = np.zeros((999, 999, 4), np.uint8)  # oversized scratch, cropped immediately after
	sx, sy = d["shoulder"]
	paste(work, pose["upper_rot"], (int(round(sx)) - pad + margin, int(round(sy)) - pad + margin))
	ex, ey = pose["elbow"]
	paste(work, pose["forearm_rot"], (int(round(ex)) - pad + margin, int(round(ey)) - pad + margin))
	layer, lx0, ly0 = crop_piece(work, work[..., 3] > 0)
	return layer, lx0 - margin, ly0 - margin


def composite(body: np.ndarray, d: dict, pose: dict, pad: int = 40) -> np.ndarray:
	"""Paste this pose's rotated upper+forearm pieces onto a copy of the (armless) body.
	Each rotated piece has its own pivot fixed at local (pad,pad) by rotate_about, so it is
	placed at world_pivot - pad in both axes: the shoulder for the upper piece (constant,
	from d), the elbow for the forearm piece (this pose's own, from pose)."""
	out = body.copy()
	sx, sy = d["shoulder"]
	paste(out, pose["upper_rot"], (int(round(sx)) - pad, int(round(sy)) - pad))
	ex, ey = pose["elbow"]
	paste(out, pose["forearm_rot"], (int(round(ex)) - pad, int(round(ey)) - pad))
	return out


def main() -> int:
	argv = sys.argv[1:]
	sheet = None
	if "--sheet" in argv:
		i = argv.index("--sheet")
		sheet = Path(argv[i + 1])
		del argv[i:i + 2]

	frame = armlib.common_crop(armlib.load_frames(SRC))[0].astype(np.uint8)
	print(f"frame {frame.shape[1]}x{frame.shape[0]}")

	sides = {s: extract(s, frame) for s in ("L", "R")}

	# THE STATIC BODY: the frame with BOTH the upper-arm and forearm+hand pieces erased.
	# Neither is baked at its source angle - the source is a raised "ta-da" gesture, well
	# above where the game actually wants a catching hand, so BOTH joints are re-angled per
	# pose from a shared rest position (see joint_angles). The upper arm's own sweep is far
	# smaller than the forearm's (55deg vs 125deg across the whole reach range) - "slight
	# movement" relative to the forearm's "circular movement", not literally zero.
	body = frame.copy()
	for d in sides.values():
		for piece, origin in ((d["upper"], d["upper_origin"]), (d["lower"], d["lower_origin"])):
			x0, y0 = origin
			h, w = piece.shape[:2]
			m = piece[..., 3] > 0
			body[y0:y0 + h, x0:x0 + w][m] = 0

	bys, bxs = np.where(body[..., 3] > 0)
	torso_cx = (int(bxs.min()) + int(bxs.max())) * 0.5

	for s, d in sides.items():
		print(f"{s}: shoulder ({d['shoulder'][0]:.1f},{d['shoulder'][1]:.1f}), "
			  f"upper_len {d['upper_len']:.1f}px, fore_len {d['fore_len']:.1f}px")

	poses = {s: [pose_at(sides[s], i / (N_POSES - 1)) for i in range(N_POSES)] for s in ("L", "R")}
	for s, plist in poses.items():
		reaches = [torso_cx - p["hand"][0] if s == "L" else p["hand"][0] - torso_cx for p in plist]
		print(f"{s}: reach {min(reaches):.1f}..{max(reaches):.1f} over {N_POSES} poses")

	if sheet:
		_debug_sheet(sheet, body, sides, poses)
		print(f"debug sheet -> {sheet}")

	if "--write" in argv:
		write_bank(body, sides, poses, torso_cx, force="--force" in argv)
	return 0


def write_bank(body: np.ndarray, sides: dict, poses: dict, torso_cx: float,
		force: bool = False) -> None:
	"""Assemble the exact schema build_arm_bank.py writes (juggle_body.png, juggle_arms.png
	/.json, the _ARMS block in art_manifest.json) so Game.gd's fig_arm_pick needs no change."""
	pal = np.asarray(Image.open(PALETTE).convert("RGB")).reshape(-1, 3).astype(int)
	body_s = bank.snap(body, pal)
	body_pal = np.unique(body_s[body_s[..., 3] > 0][:, :3], axis=0)

	entries = []  # each: side, reach, layer(snapped), ox, oy, px(hand x), py(hand y), flat
	for s in ("L", "R"):
		for p in poses[s]:
			layer, ox, oy = pose_layer(sides[s], p)
			if layer.size == 0:
				continue
			layer = bank.snap(layer, body_pal)
			reach = torso_cx - p["hand"][0] if s == "L" else p["hand"][0] - torso_cx
			entries.append({"side": s, "reach": float(reach), "layer": layer,
				"ox": ox, "oy": oy, "px": float(p["hand"][0]), "py": float(p["hand"][1])})

	aw = max(e["layer"].shape[1] for e in entries)
	ah = max(e["layer"].shape[0] for e in entries)
	cols = 8
	rows = (len(entries) + cols - 1) // cols
	atlas = np.zeros((rows * ah, cols * aw, 4), np.uint8)
	meta = {"cell_w": body.shape[1], "cell_h": body.shape[0], "atlas_cols": cols,
			"atlas_w": aw, "atlas_h": ah, "body_cx": round(float(torso_cx), 1),
			"hand_py": 0.0, "head": bank.head_box(body_s), "left": [], "right": []}
	for n, e in enumerate(entries):
		r, k = divmod(n, cols)
		lay = e["layer"]
		atlas[r * ah:r * ah + lay.shape[0], k * aw:k * aw + lay.shape[1]] = lay
		rec = {"slot": n, "reach": round(e["reach"], 2), "ox": int(e["ox"]), "oy": int(e["oy"]),
			   "px": round(e["px"], 1), "py": round(e["py"], 1), "flat": 1.0}
		meta["left" if e["side"] == "L" else "right"].append(rec)
	meta["left"].sort(key=lambda r: r["reach"])
	meta["right"].sort(key=lambda r: r["reach"])
	pys = [r["py"] for r in meta["left"] + meta["right"]]
	meta["hand_py"] = round(float(np.median(pys)), 1) if pys else round(body.shape[0] * 0.5, 1)
	print(f"hand line (median) at row {meta['hand_py']} of {body.shape[0]}")

	# THE PERFORMER'S OWN PALM, cut from a mid-reach entry, for the columns central-lane
	# case (draw_figure_palm / fig_palm_far) - same purpose and box size as build_arm_bank.py.
	left_entries = [e for e in entries if e["side"] == "L"]
	if left_entries:
		e = min(left_entries, key=lambda x: abs(x["reach"] - 30))
		lay = e["layer"]
		lpx, lpy = e["px"] - e["ox"], e["py"] - e["oy"]
		x0 = max(0, int(lpx - bank.PALM_BOX[0] // 2 + bank.PALM_SHIFT))
		y0 = max(0, int(lpy - bank.PALM_BOX[1] // 2))
		x1 = min(lay.shape[1], x0 + bank.PALM_BOX[0])
		y1 = min(lay.shape[0], y0 + bank.PALM_BOX[1])
		patch = bank.snap(lay[y0:y1, x0:x1], body_pal)
		meta["palm"] = {"w": int(patch.shape[1]), "h": int(patch.shape[0]),
						 "ax": round(float(lpx - x0), 1), "ay": round(float(lpy - y0), 1)}
		artguard.save_guarded(OUT / "palm_l.png",
			lambda q: Image.fromarray(patch, "RGBA").save(q), force)
		artguard.save_guarded(OUT / "palm_r.png",
			lambda q: Image.fromarray(patch[:, ::-1], "RGBA").save(q), force)
		print(f"palm patch {patch.shape[1]}x{patch.shape[0]} from the reach-{e['reach']:.0f} pose")

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


def _debug_sheet(path: Path, body: np.ndarray, sides: dict, poses: dict) -> None:
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
		frame_img = body.copy()
		for s in ("L", "R"):
			frame_img = composite(frame_img, sides[s], poses[s][i])
		im = Image.fromarray(frame_img.astype(np.uint8), "RGBA").resize((cw * Z, ch * Z), Image.NEAREST)
		out.paste(im, ((i % cols) * cw * Z, (i // cols) * ch * Z), im)
	out.save(path)


if __name__ == "__main__":
	raise SystemExit(main())
