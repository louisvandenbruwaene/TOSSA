# Visual component credits

TOSSA vendors small source components, with no runtime network or plugin dependencies.
Downloaded on 2026-09-11. The adjacent license files must accompany distributions.

| Upstream | Used in TOSSA | License |
| --- | --- | --- |
| [stegu/webgl-noise](https://github.com/stegu/webgl-noise/blob/master/src/noise2D.glsl), Ian McEwan / Ashima Arts and Stefan Gustavson | `Resources/shaders/simplex_noise.gdshaderinc`, unchanged 2D simplex noise for quiet venue atmosphere | MIT, `webgl-noise-LICENSE.txt` |
| [glslify/glsl-easings](https://github.com/glslify/glsl-easings/blob/master/sine-in-out.glsl), Hugh Kennedy | Sine easing translated to GDScript in `TossaPerformancePose.gd`, driving weight transfer and turn acceleration | MIT, `glsl-easings-LICENSE.txt` |
| [GDQuest godot-shaders](https://github.com/gdquest-demos/godot-shaders/blob/main/godot/Shaders/wind_uv.gdshader) | Pinned sine wind displacement adapted to the backyard foliage region in `stage_readability.gdshader` | MIT source-code license, `GDQuest-LICENSE.txt` |

The original easing and wind sources are included here for comparison. GDQuest's
noncommercial art assets are **not** included; only MIT shader code is adapted.

The theatre and circus paintings are generated specifically for this project using
the existing TOSSA backgrounds as references. They are not GitHub assets. Master
paintings and provenance are in `extras/visual_overhaul/`; the runtime versions use
the existing 48-colour palette and 640x360 density. No original character art was replaced.
