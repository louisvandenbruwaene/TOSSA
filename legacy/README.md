# legacy/ — the code-drawn TOSSA, archived

`tossa-vector/` is the original TOSSA exactly as it stood at commit `d8e8102`
("CLAUDE.md: three gotchas that cost this session real time"), the last commit
before the pixel-art work began. Every picture in it is drawn in code: there are
no sprites, no palette, no art manifest.

It is kept because Louis asked for it to be kept (2026-08-15: *"make sure to keep
the older debug and non debug tossa (non pixellated) somewhere in the gitrepo,
just not executed anywhere, just to have in case i want to revisit it later"*).

**Nothing here is built, run, imported or referenced.** `legacy/.gdignore` makes
Godot skip this whole directory, so the second `Game.gd`, `Main.tscn` and
`project.godot` in here can never be parsed, imported or launched by accident —
which is the only way a duplicate `project.godot` inside a project tree is safe.

There is no separate "debug" copy to archive, and that is not an omission: the
debug build was never a different program. It is the same `Game.gd` launched with
`--debug`, which switches the save file to `tossa_debug.cfg` and unlocks free stat
editing and the F-key venue jumps. `install_apps.sh` in here is the script that
built both launchers, so both are reconstructible from this directory alone.

## Running it again, if you ever want to

    cp -r legacy/tossa-vector /tmp/tossa-vector
    godot --path /tmp/tossa-vector                 # normal
    godot --path /tmp/tossa-vector -- --debug      # debug build

Copy it OUT of this repo first. Its `project.godot` sets `config/name="TOSSA"`,
so it reads `app_userdata/TOSSA/`'s `tossa_*.cfg` saves — the careers Louis played
on it, still sitting there untouched. The pixel game lives in that same folder now
but writes `pixeltossa_*.cfg`, so the two sets of saves never collide. See
`OLD_NAMES` in the live `Game.gd` for why that filename was deliberately not
renamed.
