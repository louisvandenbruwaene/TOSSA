# scripts/

The remaster brief asked for a `Scripts/` folder. **It cannot exist here, and this folder is
the answer to it.** macOS's default filesystem (APFS, case-insensitive) treats `Scripts/` and
this pre-existing lowercase `scripts/` as one and the same directory - `mkdir Scripts`
succeeds and silently does nothing. Renaming this one to satisfy the capital letter would
break the `Makefile`, `.githooks/`, `docs/`, the root `README.md` index and every path inside
`lib.sh`, which is a large blast radius to buy a capital S. So there is one scripts folder,
this one, and it holds both kinds of thing.

## Dev/build tooling (pre-existing - not shipped)

`validate.sh`, `screenshot.sh`, `profile.sh`, `lint.sh`, `format.sh`, `test.sh`,
`run_game.sh`, `run_editor.sh`, `run_scene.sh`, `reimport.sh`, `clean_cache.sh`,
`bootstrap.sh`, `lib.sh`. Indexed in the root `README.md`; `lib.sh` bakes in the muted +
windowed conventions every run needs.

## Remaster tooling (new on PIXELTOSSA)

- **`gen_placeholders.gd`** - writes one placeholder PNG per art seam key, plus a
  ready-to-use `Resources/art_manifest.placeholder.json` that registers them all.

  ```
  godot --headless --script res://scripts/gen_placeholders.gd
  ```

  Sizes are derived from the live drawing constants (`BALL_RADIUS_PX` and friends), so if a
  prop is rescaled in `Game.gd`, **regenerate** rather than hand-editing a number.

## Runtime GDScript

There is none outside `Game.gd`, by decision - see `Scenes/README.md`. If that ever changes,
the new script does **not** belong here (this folder does not ship). Put it in a folder whose
name does not collide with an existing one: `Runtime/`.
