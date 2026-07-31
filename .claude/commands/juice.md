---
description: Add or review "juice" (game feel/tactile feedback) for TOSSA, Balatro-bar quality
---

TOSSA's explicit bar for feel is Balatro (Louis's own standard, "visually, musically and for
enjoyment") - chunky, tactile feedback on every number that matters, dopamine from catch/drop
sounds, streaks, tricks and unlocks, never from flash. Before adding juice to a system:

1. **Respect `reduce_motion`.** Every screen-shake, hit-stop `freeze`, and `spawn_parts` burst
   must scale down (not ignore) when it's on - it suppresses shake, cuts freeze to one tick, and
   halves particle bursts. It deliberately does NOT touch slow-mo (that's a gameplay aid, not a
   flourish) - don't conflate the two.

2. **Prefer a drawn OBJECT that fills/glints/overflows over a percentage bar or flat rectangle.**
   The money-hat rework and the goal-stem/flower bloom are the reference examples: Louis
   explicitly said prefer this shape whenever a number is driving tension.

3. **A flat fill beats a painted highlight for small/round objects.** THE ROUND PROPS ARE FLAT
   and THE BALL/EGG/CLUB entries are hard-won: shaded discs, bounce arcs, hot cores and rim
   wedges all shimmer at small sizes on a moving object and were deliberately ripped out twice.
   One flat body, one darker-all-the-way-round rim, done.

4. **Batch anything that repeats and doesn't change shape.** A flower pile, a chain of links, a
   torch handle - bake once, transform and re-emit per frame. Rebuilding per-instance GDScript
   geometry every frame costs about what the draw calls it replaces cost (measured, twice).

5. **A triangle-array edge needs an explicit feather** (one extra row/column at alpha 0, offset
   along the local normal - not a flat pixel offset, which under-softens anywhere the silhouette
   curves hard). There is no automatic AA on `canvas_item_add_triangle_array`.

6. **Test what you built, muted, using `scripts/screenshot.sh` or `scripts/run_scene.sh`** - juice
   is inherently a visual/feel judgment call that only a real capture (or Louis's own eyes) can
   confirm; don't declare a juice pass done from reading the code.

Ask first before touching the juggler figure's stance/proportions, hand IK targets, prop layering,
or hitboxes as a side effect of a juice change - those are explicitly off-limits collateral
damage per CLAUDE.md.
