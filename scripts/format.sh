#!/usr/bin/env bash
# Checks (or applies) gdformat against Game.gd.
#
# IMPORTANT: gdformat's opinionated style does NOT preserve this file's
# hand-aligned trailing comments, which are used throughout as inline
# documentation (see CLAUDE.md). A full-file gdformat run rewrites roughly
# 22,000 of Game.gd's 23,000 lines - almost entirely comment realignment, not
# bugs. Default mode is therefore --diff (report only). Pass --write only if
# you specifically intend to accept that realignment.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source scripts/lib.sh

if ! command -v gdformat >/dev/null 2>&1; then
  log_err "gdformat not found. Install with: pipx install gdtoolkit --backend pip"
  exit 1
fi

MODE="check"
[[ "${1:-}" == "--write" ]] && MODE="write"

if [[ "$MODE" == "check" ]]; then
  log_info "gdformat --diff Game.gd (report only; pass --write to apply - not recommended, see header)"
  if gdformat --diff Game.gd 2>&1 | grep -q "would reformat"; then
    log_warn "gdformat would reformat Game.gd (expected - comment realignment, not bugs)."
    exit 0
  else
    log_ok "Game.gd already matches gdformat's style."
  fi
else
  log_warn "Reformatting Game.gd in place. This WILL disturb hand-aligned comments."
  log_warn "Review the diff (git diff Game.gd) carefully before committing."
  gdformat Game.gd
  log_ok "Formatted. Now go read the diff."
fi
