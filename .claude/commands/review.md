---
description: General code review pass for TOSSA changes
---

Review the current diff (uncommitted, or the last commit if clean) against Game.gd. This project
has no scenes/nodes to review in the usual Godot sense - it's evaluated as GDScript logic plus
correctness against the game's own documented rules. In order:

1. Run `/godot-review` first - it covers the specific, previously-real bug classes for this file
   (queue_redraw placement, duplicate renderers, drifting card pairs, self-intersecting polygons,
   unbounded accumulators, call-count regressions).
2. Check the change against the three pillars in CLAUDE.md (skill first / juggling is real / calm
   first impression) if it touches gameplay feel or balance - these are the actual acceptance
   criteria Louis uses to accept or reject a design idea, not a style preference.
3. Check any new stat/score/pay constant against `safe_pow`'s overflow discipline and against
   whether it interacts with the exponential scoring model (a toggle trick's `p` is per-catch, a
   live trick's is per-press - conflating the two has produced multi-order-of-magnitude balance
   bugs before).
4. Check save-format changes: does `load_progress` gain a version-gated migration branch if the
   shape of `owned_wear`/`gifted`/any persisted dict changes? A save from before this change must
   not silently lose progress.
5. Run `scripts/validate.sh` (or at least `--quick`) and paste the result - don't approve a change
   that hasn't actually been run.

Report file:line, the concrete failure scenario, most severe first - same shape as `/code-review`.
