# Scenes

Empty on purpose, and that is worth explaining rather than leaving as a mystery.

TOSSA has exactly one scene (`Main.tscn`, a bare `Node2D` with `Game.gd` attached) and one
script. Screens are not scenes here: `game_state` holds an `ST_*` value and `_draw_screen()`
dispatches on it. See `docs/scenes.md`.

The remaster brief asked for drawing to move into dedicated nodes/scenes. That was weighed
against this repo's own standing rule - `docs/coding_guidelines.md` lists splitting `Game.gd`
into multiple files/classes/autoloads under *"off-limits without asking first"*, on the back
of `AUDIT_2026-07-26.md`'s P3 finding - and the decision (Louis, 2026-07-31) was to get the
same guarantee **without** the split, via the render seam in `Game.gd`'s
`#region PIXEL-ART RENDER SEAM`. Every visual element is already replaceable without touching
gameplay code; a file boundary would have added risk to a 23k-line file with no unit tests
and bought nothing the seam does not already provide.

## What this folder is for

The first thing that genuinely needs a scene rather than a draw call. The clearest candidate
is animation: `char/hand_open` / `char/hand_closed` is a two-frame approximation of a hand
that actually opens and closes continuously (`hclose` is a float), and an `AnimatedSprite2D`
driven by that float would be a real improvement rather than a reorganisation. When that
happens, it lives here and `draw_hand`'s seam call is what it replaces - nothing else in the
file has to know.

Reach for this folder when a scene earns its place. Not before.
