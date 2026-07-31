---
description: Profile and optimize TOSSA using its own established measurement method
---

Use `scripts/profile.sh [seconds] [dev flags...]` to capture a real sample before and after any
change - this wraps the game's own `--fps` probe. Read the report as:

- **`DRAW us`** and **`calls`** are the numbers that matter. This codebase's own measured rule:
  draw cost is almost exactly the number of engine calls x ~5us; vertex/primitive counts barely
  register. The fix for a slow screen is fewer calls (batch static geometry into one
  `canvas_item_add_triangle_array`), never simpler polygons - a hand-rolled low-poly shape built
  in GDScript per frame previously made things 30% *slower*.
- **`draws/s`** vs **`engine fps`**: trust `draws/s` only as "how often did _draw run", and
  `engine fps` only when the window has focus - a backgrounded/unfocused window's presented-frame
  rate is throttled by macOS and does not reflect real performance. The project's own history
  contains a full session lost to reading this backwards (see CLAUDE.md's PERFORMANCE entries) -
  don't repeat it. If the two numbers disagree, suspect whichever one doesn't respond to load.
- A `queue_redraw()` anywhere in `_physics_process` (120Hz) rather than `_process` will make
  `draws/s` pin near 120 regardless of actual display rate - that exact bug cost this project a
  4.3 fps regression that went undiagnosed for a while. Check for it first if `draws/s` looks
  wrong.

Baseline to compare against (MacBook Air M5, 1920x1016, full wardrobe, worst case - fifteen
torches at the World Arena): ~2.85ms draw, ~533 calls, ~26k primitives, ~45% of one core at
100fps. A typical five-prop session measures ~1.7ms. See CLAUDE.md's MINIMUM REQUIREMENTS section
for the full spec-floor derivation if a regression needs to be sized against min-spec headroom.

Report before/after numbers from real `scripts/profile.sh` runs, not estimates.
