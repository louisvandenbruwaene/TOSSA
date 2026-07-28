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
