# Theatre and circus art masters

Generated 2026-09-11 with the imagegen skill's built-in image generation tool.
Reference images: the existing `Assets/Backgrounds/small_theatre.png` and
`Assets/Backgrounds/the_circus.png`, respectively. Original backgrounds remain available.

Direction: clean pixel clusters, burgundy velvet, antique gold trim, visible practical
lights, dark quiet central juggling area, clear stage floor, no characters or UI.
The theatre replaces its painted garden with a blue-green rear curtain, moon and
star ornaments. The circus keeps its canopy, audience galleries and sawdust ring,
with richer crimson and gold cloth and more readable architectural shapes.

To reproduce the runtime conversion:

```sh
godot --headless --path . --script scripts/import_theatre_art.gd
```

The import downsamples the masters to 640x360 and maps every pixel to TOSSA's locked
48-colour palette without diffusion noise. `Resources/art_manifest.json` selects the
resulting `_v2.png` files. These masters are development sources, not runtime dependencies.
