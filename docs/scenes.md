# Scenes

TOSSA has exactly **one** Godot scene: `Main.tscn` (a bare root node with `Game.gd` attached).
There is no scene tree to speak of, no autoloads, and no addons - "scenes" in the usual Godot
sense don't describe this project. What plays the role of a scene graph is a screen-state enum
and a single dispatch function.

## The mechanism

```
var game_state: int          # holds one ST_* value
func _draw_screen() -> void: # match game_state: -> draw_<screen>(font, viewport_size)
```

Every screen is a `draw_*` function called from one `match game_state:` block in
`_draw_screen()`. Switching "scenes" means setting `game_state` to a different `ST_*` constant;
there is no `change_scene_to_file`, no packed scenes, no `_ready`/`_exit_tree` per screen.

## Known screen states (grep `ST_` in Game.gd for the authoritative, current list - this project
adds/removes them; treat this table as a map, not a contract)

| Constant | Screen |
|---|---|
| `ST_MENU` | Title / main menu |
| `ST_DAY` | The day hub (TONIGHT / REST / PREPARE drawers) |
| `ST_PLAY` | An in-progress act (the stage) |
| `ST_SETTINGS` | Settings |
| `ST_SLOTS` | Save-slot picker |
| `ST_REMAP` | Controls / key remapping |
| `ST_STATS` | The talent sheet (stat cards / growth columns) |
| `ST_ESTABLISH` | Venue establishing card |
| `ST_GAMEOVER` | Results card |
| `ST_CREDITS` | Credits |
| `ST_DEMO_WALL` | Scoped-demo wishlist wall |
| `ST_PURIST_LEGEND` | Purist Legend payoff card |
| `ST_CAPSULE` | Pure key-art render (no UI) for store assets |

Screens reached through other means (Shop, Skills, Tailor, Pause) are drawn as overlays/sub-modes
rather than separate `ST_*` states in some cases - check the dev flag it's reached through
(`--shop`, `--skills`, `--pause`) if you need to jump straight to one; see
`scripts/screenshot.sh` for a working set of examples.

## Why no split

`AUDIT_2026-07-26.md` already considered and explicitly rejected an eager scene/file split (see
its P3 finding); `docs/coding_guidelines.md` and `.claude/commands/refactor.md` carry that
forward. This file describes what exists today, not a target to migrate toward.
