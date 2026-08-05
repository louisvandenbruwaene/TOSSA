#!/usr/bin/env bash
# Launches TOSSA normally: windowed, real audio, for actual play/testing.
# Any dev flags are forwarded after Godot's bare '--' separator.
# For muted/backgrounded automated runs use validate.sh, screenshot.sh, or
# profile.sh instead - this script is the one meant to make sound.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source scripts/lib.sh
require_godot
log_info "Launching TOSSA (windowed, real audio)$( [[ $# -gt 0 ]] && echo " -- $*" )"
exec "$GODOT_BIN" --path "$PIXELTOSSA_ROOT" -- "$@"
