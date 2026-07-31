#!/usr/bin/env bash
# Removes .godot/ (Godot's editor/import cache). Safe: it is regenerated
# automatically on next editor/game launch, and .gitignore already excludes
# it from version control.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source scripts/lib.sh
if [[ -d .godot ]]; then
  size=$(du -sh .godot | cut -f1)
  rm -rf .godot
  log_ok "Removed .godot/ ($size freed). It regenerates on next launch."
else
  log_info "No .godot/ cache present - nothing to clean."
fi
