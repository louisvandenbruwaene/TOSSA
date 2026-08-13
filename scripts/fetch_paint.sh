#!/usr/bin/env bash
# Download a finished PixelLab job into artifacts/paint/<name>.png.
#
# The MCP tool hands back a job id and a download URL; this is the one step that has to
# happen outside it, because the reducer works on a file. Kept as a script rather than an
# inline curl so a re-bake of any backdrop is one documented command - see the USAGE block
# in scripts/pixelise_paint.py.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source scripts/lib.sh

[[ $# -eq 2 ]] || { echo "usage: scripts/fetch_paint.sh <job-id> <name>" >&2; exit 2; }
job="$1"; name="$2"
mkdir -p artifacts/paint
out="artifacts/paint/${name}.png"

curl -fsSL "https://api.pixellab.ai/mcp/images/${job}/download" -o "$out"
# A failed job still returns 200 with a JSON body, so check what actually landed.
file "$out" | grep -q "PNG image data" || { log_err "$job did not return a PNG:"; head -c 200 "$out" >&2; echo; rm -f "$out"; exit 1; }
log_ok "$name <- $job  $(file -b "$out" | cut -d, -f2)"
