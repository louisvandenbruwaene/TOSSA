#!/usr/bin/env bash
# Runs gdlint against Game.gd using .gdlintrc (tuned for this project - see
# that file's header for which rules are disabled and why). Advisory: prints
# findings and returns nonzero if any exist, but nothing in this repo treats
# a nonzero lint exit as commit-blocking (see scripts/pre-commit and
# docs/coding_guidelines.md) because several remaining categories
# (mixed-tabs-and-spaces, short math variable names) reflect accepted
# in-codebase convention rather than defects.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source scripts/lib.sh

if ! command -v gdlint >/dev/null 2>&1; then
  log_err "gdlint not found. Install with: pipx install gdtoolkit --backend pip"
  exit 1
fi

log_info "gdlint Game.gd (config: .gdlintrc)"
if gdlint Game.gd; then
  log_ok "No lint findings."
  exit 0
else
  n=$(gdlint Game.gd 2>&1 | grep -c ":" || true)
  log_warn "$n lint finding(s) above - advisory only, see script header."
  exit 1
fi
