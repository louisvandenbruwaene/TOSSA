#!/usr/bin/env bash
# TOSSA has no unit-test framework (e.g. GUT) because almost all logic lives
# in one integrated 23k-line script with few pure, easily-isolated functions.
# AUDIT_2026-07-26.md's own recommendation was a "non-mutating script job"
# that runs real game flows and fails on real error markers, rather than a
# conventional unit-test suite bolted on for its own sake. validate.sh IS
# that job - this is just the name people reach for out of habit.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
exec scripts/validate.sh "$@"
