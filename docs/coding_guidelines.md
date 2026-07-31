# Coding guidelines

A checklist distilled from CLAUDE.md's many hard-won, narrated lessons - this file is the
scannable rulebook; CLAUDE.md is where each rule's origin story and evidence live. When a rule
here feels unmotivated, its story is in CLAUDE.md, usually findable by searching for a phrase
from the rule.

## Before editing

- `git status` clean, commit first. Never run a DOTALL (`re.S`) regex to cut a range out of
  Game.gd - it has destroyed 16,099 lines this way once already. Use two explicit string anchors
  that fail loudly, or a real diff/patch tool.
- Group new consts/vars/funcs **by game system**, next to the code they belong with - not by
  declaration type. `.gdlintrc` intentionally disables the lint rule that disagrees.

## Drawing / UI

- Any string whose length is DATA goes through `fit_text` (trims + marks it), `draw_wrap_fit`
  (wraps into a box), or `fit_size` (shrinks font size). **Numbers/amounts always use
  `fit_size`** - never truncate a number, an ellipsis on a number reads as a different number.
- One colour per card (the border/accent colour). No second-tone "gradient" fill, no accent bar
  across the top - both were tried project-wide and removed.
- A box interior must be **lighter** than what's behind it, or it reads as a hole, not a recess.
- Round props are flat: one body colour, one rim darker all the way round, no painted highlight/
  bounce/hot-core - all of those shimmer at small size on a moving object and were reverted twice.
- `canvas_item_add_triangle_array` / `draw_polygon` **silently draws nothing** on a
  self-intersecting shape (a log line, no crash, no dialog). Check vertex winding order and
  outgoing/returning edge pairs whenever building a shape from raw points.
- A triangle-array edge needs an explicit feather (extra row/column, alpha 0, offset along the
  local normal) - there's no automatic AA on it.

## Performance

- Draw cost here is ~5us **per engine call**, not per vertex. Fewer calls beats simpler
  polygons - a hand-built `PackedVector2Array` per frame per object has measurably made things
  *slower*, not faster.
- Anything that repeats and doesn't change shape frame to frame (a chain, a torch handle, a
  flower pile) should be baked once and re-emitted via transform, not rebuilt per frame.
- `queue_redraw()` belongs in `_process`, never `_physics_process` (120Hz) - that exact
  misplacement once cost a 4.3fps regression that went undiagnosed for a session because the
  wrong counter (`draws/s`, not `engine fps`) was being trusted.
- `engine fps` is meaningless on an unfocused/backgrounded window (macOS throttles presentation);
  `draws/s` only tells you how often `_draw` ran, not the real frame rate. Use both together.

## Numbers / persistence

- Anything unbounded (a score multiplier, an exponent) needs an explicit ceiling
  (`safe_pow`-style) - `pow()` reaches `INF` long before a float actually overflows, and one
  `INF` poisons every downstream goal/record/pay check silently.
- An accumulator keyed on a running clock (`tick - born`) must stop once its subject is at rest,
  or it keeps growing forever ("an object at rest does not turn" - found as a bug class twice).
- A new persisted field needs a version-gated migration path in `load_progress` if it changes
  the shape of an existing save. Some old keys are deliberately write-only (kept only so an old
  build's migration can read them back) - see `docs/architecture.md`'s Persistence section.

## Testing

- Always run muted and backgrounded: `--audio-driver Dummy` before the bare `--`, dev flags
  after it (without `--`, Godot's user args are invisible and the game sits at the menu
  forever - looks exactly like a hang). `scripts/lib.sh` bakes this in; use it rather than
  shelling out to `godot` directly.
- `godot --check-only` is a fast first filter, not a reliable one - it has missed a real parse
  error before (only surfaced when the game actually ran). Always also run
  `scripts/validate.sh`, which greps a real run's stderr for `SCRIPT ERROR`/`Parse Error`.
- Back up real save data before any test harness run that isn't behind `--demo`
  (`~/Library/Application Support/Godot/app_userdata/TOSSA/`) - do it before running, not after
  noticing something looks wrong.

## Off-limits without asking first

- Splitting Game.gd into multiple files/classes/autoloads (see `.claude/commands/refactor.md`
  and `AUDIT_2026-07-26.md`'s P3 finding - incremental extraction only, and only with tests).
- Reshaping the juggler figure's stance/proportions, hand IK targets, prop layering, or hitboxes
  as a side effect of an unrelated fix.
- Running `gdformat --write` across Game.gd (see `scripts/format.sh`'s header - it rewrites
  ~95% of the file's lines, almost entirely stripping intentional comment alignment).
