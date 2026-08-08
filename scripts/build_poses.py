#!/usr/bin/env python3
"""The performer's FOUR POSITIONS and the transitions between them.

LOUIS'S MODEL (2026-08-08). Per hand there are four positions, all sharing an upper arm
that barely moves - the forearm does the work:

        in_high  ....  out_high        up/down is always legal
           |              |            crossing sides is legal ONLY along the low row
        in_low  -----  out_low

...and that rule is not an arbitrary constraint, it is the juggler's scoop written down.
A cascade hand catches OUT and high, absorbs DOWN, carries ACROSS while low, throws from
IN going UP, and comes back the same way:

    out_high -> out_low -> in_low -> in_high -> in_low -> out_low -> out_high

You never carry a prop across the body at head height; you scoop it. Forbidding the
in_high <-> out_high shortcut is what makes the animation do that, and it is why the graph
is a PATH and not a square.

WHAT THIS SCRIPT DOES. It picks, from every candidate the nineteen generations offer, the
best arm for each of the four positions and for a ladder of frames along each of the three
edges - then writes them as one bank keyed by state and transition rather than by reach.

WHAT IT CANNOT DO. Two of the four corners barely exist in the source: measured over the
pool there are 17 usable in_low arms and 22 out_high ones - the cascade's own diagonal -
against 2 in_high and 1 out_low. So the corners this fills from existing art are honest
placeholders and the transitions through them are thin. See artifacts/chargen/quad/README.md
for the generation brief that fixes it.

USAGE
  .venv/bin/python scripts/build_poses.py            report only
  .venv/bin/python scripts/build_poses.py --write    ...and write _POSES into the manifest
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import armlib                                                   # noqa: E402
from build_arm_bank import gather                               # noqa: E402

ROOT = Path(__file__).resolve().parent.parent

# The two slots are the game's own (HAND_IN_DX 54 screen px, HAND_OUT_DX 100) in art px,
# and the two heights are the game's hand line and a lift above it.
REACH = {"in": 27.0, "out": 50.0}
LIFT = 0.13                       # of the figure's height, ~21 art px - the top of the sweep
STATES = ["in_low", "in_high", "out_low", "out_high"]

# The only legal moves. Everything else is a path through these.
EDGES = [("in_low", "in_high"), ("out_low", "out_high"), ("in_low", "out_low")]
STEPS = 4                         # intermediate frames per edge; 1 would read as a cut


def target(state: str) -> tuple[float, float]:
    side, height = state.split("_")
    up = armlib.GAME_HAND_UP + (LIFT if height == "high" else 0.0)
    return REACH[side], up


def cost(c: dict, want_r: float, want_up: float) -> float:
    """How wrong this candidate is for a wanted position.

    Reach and height are the position; palm-up and a horizontal forearm are the QUALITY,
    and they are worth real weight rather than a tie-break - a pose in exactly the right
    place with the hand hanging knuckles-out is not the pose anybody asked for.

    REACH IS WEIGHTED HARDER THAN HEIGHT, because the side is structural and the height is
    a matter of degree. An "inward" pose that is not inward is not that position at all,
    while one that is only half-raised still reads as the top of the stroke. Left even, the
    fitter answers "nothing exists at inward-and-high" by walking OUTWARD to find something
    high - measured, the in_low -> in_high ladder drifted from reach 25 to 39, so the arm
    swung out across the body on a move that is supposed to be a straight lift."""
    arm_flat = c["layer"].shape[1] / max(1.0, float(c["layer"].shape[0]))
    return (abs(c["reach"] - want_r) / 3.0
            + abs(c["up"] - want_up) / 0.05
            - round(c["flat"] * 4) * 0.25
            - round(arm_flat * 4) * 0.15)


def main() -> int:
    write = "--write" in sys.argv
    body, cands = gather(sorted((ROOT / "artifacts" / "chargen").glob("anim_*")))
    if body is None:
        raise SystemExit("no frames found")
    print(f"\n{len(cands)} candidates\n")

    picks: dict[str, dict] = {}
    for st in STATES:
        wr, wu = target(st)
        best = min(cands, key=lambda c: cost(c, wr, wu))
        picks[st] = best
        near = sum(1 for c in cands
                   if abs(c["reach"] - wr) <= 5 and abs(c["up"] - wu) <= 0.02)
        print(f"{st:9} want reach {wr:4.0f} up {wu:.3f}  ->  {best['src']} f{best['frame']} "
              f"{best['side']}  reach {best['reach']:5.1f} up {best['up']:.3f} "
              f"palm {best['flat']:.2f}   ({near} close candidates in the pool)")

    print()
    trans: dict[str, list] = {}
    for a, b in EDGES:
        ra, ua = target(a)
        rb, ub = target(b)
        seq = []
        for i in range(1, STEPS + 1):
            t = i / float(STEPS + 1)
            wr, wu = ra + (rb - ra) * t, ua + (ub - ua) * t
            seq.append(min(cands, key=lambda c: cost(c, wr, wu)))
        trans[f"{a}>{b}"] = seq
        got = ", ".join(f"{c['reach']:.0f}/{c['up']:.2f}" for c in seq)
        print(f"{a:9} -> {b:9}  {STEPS} frames: {got}")

    if not write:
        print("\n(pass --write to store this in the manifest)")
        return 0

    # Stored as the CHOICE, not as pixels: each entry names the generation, the frame and
    # the side it came from, so build_arm_bank can cut the layers and this file stays a
    # description of the animation rather than a second copy of the art.
    def rec(c: dict) -> dict:
        return {"src": c["src"], "frame": int(c["frame"]), "side": c["side"],
                "reach": round(float(c["reach"]), 2), "up": round(float(c["up"]), 4)}

    man = ROOT / "Resources" / "art_manifest.json"
    doc = json.loads(man.read_text())
    doc["_POSES"] = {
        "_README": [
            "The performer's four positions and the legal moves between them.",
            "up/down is always legal; crossing sides is legal ONLY along the low row,",
            "which is what makes the animation scoop a prop across instead of carrying",
            "it at head height. See scripts/build_poses.py.",
        ],
        "states": STATES,
        "edges": [list(e) for e in EDGES],
        "steps": STEPS,
        "pose": {k: rec(v) for k, v in picks.items()},
        "transition": {k: [rec(c) for c in v] for k, v in trans.items()},
    }
    man.write_text(json.dumps(doc, indent=2) + "\n")
    print(f"\nwrote _POSES into {man.name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
