#!/usr/bin/env bash
# One-command setup for a fresh checkout of TOSSA. Idempotent - safe to re-run.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source scripts/lib.sh

log_head "TOSSA dev environment bootstrap"

require_godot
log_ok "Godot found at $GODOT_BIN"

if [[ ! -x "$GTIMEOUT_BIN" ]]; then
  log_info "Installing coreutils (for gtimeout, used by scripts/lib.sh)..."
  brew install coreutils
else
  log_ok "gtimeout present."
fi

if ! command -v gdformat >/dev/null 2>&1 || ! command -v gdlint >/dev/null 2>&1; then
  log_info "Installing gdtoolkit (gdformat/gdlint) via pipx..."
  command -v pipx >/dev/null 2>&1 || brew install pipx
  pipx install gdtoolkit --backend pip || log_warn "gdtoolkit install failed - format.sh/lint.sh will be unavailable."
else
  log_ok "gdformat/gdlint present."
fi

chmod +x scripts/*.sh .githooks/pre-commit 2>/dev/null || true
git config core.hooksPath .githooks
log_ok "Git hooks path set to .githooks/"

echo
log_info "Manual step remaining: the godot MCP server is registered project-scoped"
log_info "(.mcp.json) but Claude Code requires you to approve new project MCP"
log_info "servers once - run 'claude' in this project and approve it when prompted,"
log_info "or check status any time with: claude mcp list"

echo
log_ok "Bootstrap complete. Try: make validate"
