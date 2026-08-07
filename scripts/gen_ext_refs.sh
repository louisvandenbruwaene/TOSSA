#!/usr/bin/env bash
# Capture the seven VENUE EXTERIORS as the game itself draws them, for pixelise_ext.py.
#
# THE WINDOW SIZE IS THE WHOLE POINT. The reduction is an exact 2:1 box filter, so the
# capture has to be exactly 1280x720 - the project's own viewport - or the bake is a
# resample and the crispness it exists to buy is gone before it starts. Godot's window
# can come back taller than that when the desktop has room for it (measured: 1280x803 on
# this Mac), so the size is forced here rather than hoped for.
#
# --extref draws ONLY that exterior, with the dust suppressed: the bake holds the scenery
# and the motes are drawn live over it. See draw_venue_exterior.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source scripts/lib.sh
require_godot
mkdir -p artifacts/ext_ref

names=(backyard street_corner small_theatre the_circus championship world_arena the_midnight_show)
fail=0
for i in "${!names[@]}"; do
  out="artifacts/ext_ref/ext_${i}.png"
  # --shotat 30: the exterior is static under --extref, so any settled frame will do; 30
  # physics ticks is a quarter of a second and past the first-frame warm-up.
  "$GODOT_BIN" "${AUDIO_FLAGS[@]}" \
    --resolution 1280x720 --position 0,0 \
    -- --extref "$i" --shot "$out" --shotat 30 >/dev/null 2>&1 || true
  if [[ -s "$out" ]]; then
    sz="$(.venv/bin/python -c "from PIL import Image;print('%dx%d'%Image.open('$out').size)" 2>/dev/null || echo '?')"
    if [[ "$sz" == "1280x720" ]]; then
      log_ok "${names[$i]}  $sz"
    else
      log_err "${names[$i]}  $sz - NOT 1280x720, the bake would be a resample"
      fail=1
    fi
  else
    log_err "${names[$i]}  no capture"
    fail=1
  fi
done
exit "$fail"
