# Architecture

This is a scannable structural entry point. For the narrative history of *why* things are the
way they are, `CLAUDE.md` is the primary source - it is long (2800+ lines) on purpose, and this
file deliberately does not duplicate it. Read this file first for orientation, then CLAUDE.md
for the reasoning behind any specific system.

## The one-file shape

Godot 4.7, GDScript, one scene (`Main.tscn`), one script (`Game.gd`, ~28k lines, ~700 functions),
zero addons, zero autoloads. This is a deliberate, reviewed tradeoff (see
`AUDIT_2026-07-26.md`), not neglect - the file is internally organized into ~100 `#region`
blocks grouped **by game system**, not by declaration type (consts/vars/funcs for the throw
model sit together, separately from the shop's, separately from the tailor's). `.gdlintrc`
disables the lint rules that would fight this (`class-definitions-order`, `max-file-lines`,
`max-public-methods`, `max-returns`) - see that file's comments for the reasoning.

Systems living in the one file, roughly top-to-bottom as they appear:
- Throw/catch physics model, timing bands, stat effects (accuracy/strength/endurance/speed)
- The score model (exponential, per-run multiplier, ante ladder, goal time-floors)
- Props (identity, hitboxes, drawing) and patterns (geometry, per-pattern road math)
- Input handling (keyboard + gamepad, remapping)
- The day loop (hub, drawers, venues, shop, tailor, skills)
- Save/load (`save_progress` / `load_progress`, versioned migrations)
- Screen drawing (`_draw_screen` dispatch - see `docs/scenes.md`)
- Procedurally-generated audio (`gen_sfx`)
- Dev/test harness (all `--flag`-gated: `--demo`, `--booking`, `--collcheck`, `--fps`, etc.)

## Incremental extraction boundary

`Game.gd` remains the runtime orchestrator. New files are allowed only when they have a
small, explicit contract that can be checked outside a live act. The first seam is
`scripts/TossaFormat.gd`: pure number/score formatting, exercised by
`tests/test_format.gd` (`make test-format`). `Game.gd` keeps tiny forwarding helpers so
existing callers do not need a mechanical, conflict-prone rename.

Follow this order for future extractions:

1. Pure formatting and immutable catalog data, each with a focused test.
2. Save schema/migration helpers, with committed fixture saves before moving behavior.
3. Geometry/calibration helpers, with collision-harness coverage.
4. Only then consider a screen or simulation component; do not split rendering or live
   juggling simply to reduce line count.

## No scene tree, no autoloads

There is nothing to inspect via Godot's usual node/scene tooling - a Godot MCP server's scene-
tree/node-property tools have limited value here for exactly that reason (see the root
`.mcp.json` / README notes on the `godot` MCP server: it's installed for editor launch, run, and
debug-output capture, which *do* apply).

## Persistence

`ConfigFile`-based saves (`user://tossa_slot{N}.cfg`, `user://tossa_settings.cfg`), one section
per subsystem (`stats`, `day`, `prog`, `wear`, ...). Migrations are version-gated
(`wear.ver`, `prog.skill_ver`, `pattern_ver`) and read old keys once to seed the new shape -
some old keys are deliberately still *written* (never read back) purely so an older build's
migration path keeps working; see `scripts/validate.sh`'s save/load symmetry check for why a
"key exists in save but not load" finding there is not automatically a bug.

## Validation and tooling

There is no unit-test framework - almost nothing in this file is a small, pure, easily-isolated
function, and `AUDIT_2026-07-26.md` recommends a behavioral harness over unit tests for that
reason. `scripts/validate.sh` is that harness: parse check, a real booked act, a daily act, a
collision sweep, two static "mechanical sweeps" (uncalled functions, save/load key symmetry),
and a windowed screenshot smoke test. See `docs/coding_guidelines.md` for the rules that keep
changes safe in a file this size, and the repo root README for the full script/command index.
