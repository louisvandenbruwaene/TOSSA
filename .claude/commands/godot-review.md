---
description: Review recent Game.gd changes for TOSSA-specific Godot pitfalls
---

Review the diff (`git diff` if uncommitted, else the last commit) against Game.gd for these
specific, previously-real bugs in this codebase - not generic Godot advice:

1. **`queue_redraw()` outside `_process`.** This project's single largest performance bug
   (see CLAUDE.md's PERFORMANCE entries) was a `queue_redraw()` sitting in `_physics_process`
   (120Hz), which silently ran `_draw()` 120 times a second regardless of display refresh -
   4.3 fps measured, invisible in the `draws/s` counter, only visible in `engine fps`. Any new
   `queue_redraw()` call must be in `_process`, never `_physics_process`.

2. **A second renderer for an existing thing.** CLAUDE.md records this exact mistake twice
   (`draw_falling`'s default case drawing a ball for an unhandled prop kind; `draw_glow_in_dark`
   hard-coding a flame angle instead of calling `prop_spin_angle`). If a prop/skill/screen gets
   a new code path, check whether an existing shared function should have been extended instead
   of a parallel one written.

3. **Two copies of one card/screen drifting apart.** This has happened repeatedly: shop's grid
   vs row card, `draw_settings` vs `draw_settings_cards`, `draw_pause` vs `draw_pause_cards` all
   have a documented invariant that both must carry the *same* rows in the *same* order because
   one shared index (`menu_sel`/`sheet_sel`) drives both. If you see two draw functions for what
   should be one concept, check whether editing one without the other just happened.

4. **Self-intersecting polygons.** `canvas_item_add_triangle_array` / `draw_polygon` silently
   draws NOTHING on a self-intersecting shape - no error dialog, just an `Invalid polygon data,
   triangulation failed` log spam. Watch for hand-listed vertex arrays where corner order might
   not be perimeter order, and for two edges built by an outgoing pass and a returning pass whose
   angles could cross (this exact bug hit the shop hat's brim, the Energy Helmet, and a
   ballerina's arm on the skill deck).

5. **Unbounded numeric growth.** Check any new `const` multiplier/exponent against `safe_pow`'s
   ceiling discipline, and check any accumulator keyed on a clock against whether it should stop
   once its subject is at rest (the "AN OBJECT AT REST DOES NOT TURN" bug class - a rotation or
   scale driven by `tick - born` with no clamp keeps growing forever).

6. **Allocation/call-count regressions.** This codebase's own measured rule: draw cost is ~5us
   *per engine call*, not per vertex - a hand-built `PackedVector2Array` per frame per object is
   the expensive move, not more triangles in one call. New per-frame-per-object drawing of
   anything that doesn't change shape tick to tick should probably be baked once (see
   `_saw_bake`, `_torch_bake`, the flower-pile triangle soup) and just transformed/re-emitted.

7. **`.gdlintrc` categories that are real signal here**: `unused-argument`, `class-variable-name`
   (a `var` that should probably be a `const`), `function-variable-name`. Line length, class
   member ordering, return-count and public-method-count are deliberately disabled for this file
   - do not suggest reorganizing around them.

Report findings the same way `/code-review` does: file:line, the concrete failure scenario, most
severe first. Don't flag anything already called out as an accepted/documented tradeoff in
CLAUDE.md (e.g. Half Shower/Tennis's near-zero collision clearance, the 8 legacy save keys).
