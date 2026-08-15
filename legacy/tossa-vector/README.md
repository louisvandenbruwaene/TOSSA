# TOSSA

A skill-based juggling game wrapped in a light performer-career sim. Godot 4.7,
one self-contained GDScript file (`Game.gd`), code-only art, original music.

Throw and catch are separate, per-hand, timing-strict inputs. Height is how long
you hold the throw. Juggling means at least one prop in the air at all times -
the game knows the difference. Performances are single continuous acts with
three goals; cash in when you dare, collapse and you keep only what you locked.

Everything about the design, systems, verification workflow, and open work lives
in [CLAUDE.md](CLAUDE.md) - the one working document. History lives in git.

Run it: open the project in Godot 4.7, or `godot --path .` from this folder.

## Development

One-time setup: `make setup` (installs gdtoolkit, coreutils, wires git hooks; then approve the
project's `godot` MCP server the first time you launch Claude Code here - see
`docs/architecture.md`). After that:

| | |
|---|---|
| `make validate` | full headless check: parse, a booked act, a daily act, a collision sweep, two static sweeps, a screenshot smoke test - see `scripts/validate.sh` |
| `make quick-validate` | the fast subset of the above (skips the collision sweep and screenshot) |
| `make run` | play normally (windowed, real audio) |
| `make scene ARGS='--day work'` | jump straight to a dev-flag-selected screen, windowed + muted |
| `make screenshot` / `make profile` | capture screens / a perf sample to `artifacts/` |
| `make format` / `make lint` | gdformat/gdlint (both advisory - see their script headers for why) |

A git pre-commit hook (`.githooks/pre-commit`, wired via `core.hooksPath`) runs a fast parse
check automatically when `Game.gd` is staged; `make validate` is the full pipeline and is not
run on every commit because it launches real Godot processes.

Architecture, the screen-state mechanism, and a distilled coding-guidelines checklist live in
`docs/`; `CLAUDE.md` remains the narrative source of truth these complement rather than repeat.
Claude Code slash commands (`/godot-review`, `/juice`, `/performance`, `/fix-ui`, `/refactor`,
`/review`) are in `.claude/commands/` and are already scoped to this project's own hard-won rules.
