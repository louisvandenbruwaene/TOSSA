#!/usr/bin/env bash
# Opens the Godot editor for this project.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source scripts/lib.sh
require_godot
log_info "Launching Godot editor for TOSSA..."
exec "$GODOT_BIN" --editor --path "$PIXELTOSSA_ROOT"
