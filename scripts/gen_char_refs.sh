#!/usr/bin/env bash
# Render every reference the juggler's sprites are derived from.
#
#   scripts/gen_char_refs.sh [outdir]      (default: artifacts/char_refs)
#   .venv/bin/python scripts/pixelise_char.py <outdir>
#
# WHY THIS IS A SCRIPT AND NOT A COMMAND. It is eight renders in two wardrobe states,
# and every one of them is a place to get a detail wrong silently.
#
# TWO WARDROBE STATES, because gear OCCLUDES what it covers:
#   bare   - head, both bare hands, the torso regions and the legs. The head must come
#            from here: with a top hat on, the hat covers the crown and a head derived
#            from that render is missing its top.
#   geared - hat, glasses, boots, both gloves. These keys are only REACHED when the
#            piece is worn (see wearing()), so a bare pass derives nothing for them.
#
# ONE SUPPRESSED KEY PER RENDER. The isolation difference (full minus without-this-part)
# is only valid while the part being isolated is the only thing missing. Suppressing all
# char/* at once was fine while just the head and hands existed and did not overlap; with
# the wardrobe on, the hat and the glasses both sit inside the head's box, and a single
# all-at-once difference bakes a hat and spectacles into the head sprite.
#
# --shot LIES WHEN THE WINDOW IS NOT FOCUSED - it hands back the last PRESENTED frame,
# which can be seconds stale - so every capture is backgrounded and then given focus.
# The --artboxes pass is run in the FOREGROUND instead, because it prints rather than
# captures and its output has to be piped somewhere reliable.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
GODOT=${GODOT:-/opt/homebrew/bin/godot}
OUT="${1:-artifacts/char_refs}"
mkdir -p "$OUT"
rm -f "$OUT"/*.png "$OUT"/boxes.txt

shoot () {   # shoot <name> <flags...>
	local name="$1"; shift
	"$GODOT" --audio-driver Dummy --path . -- "$@" --shot "$OUT/$name.png" --shotat 200 \
		>/dev/null 2>&1 &
	sleep 2
	osascript -e 'tell application "System Events" to set frontmost of (first process whose name contains "Godot") to true' 2>/dev/null || true
	sleep 7
}

# BOXES COME FROM BOTH PASSES, because neither alone sees every key: the geared figure
# reaches the hat, glasses, boots and gloves, and hides the BARE hands behind those
# gloves. Merged, with the bare pass first so its hand boxes win the dedupe.
# Foreground on purpose: these print, they do not capture, so they need no window focus.
for pass_flags in "--charref" "--charref --chargear" "--charref --chargear --charhide hat" "--charref --charback"; do
	# shellcheck disable=SC2086
	"$GODOT" --audio-driver Dummy --path . -- $pass_flags --artboxes \
		--shot "$OUT/_boxes_tmp.png" --shotat 200 2>&1 | grep '^BOX' || true
done | awk '!seen[$2]++' > "$OUT/boxes.txt"
echo "boxes: $(wc -l < "$OUT/boxes.txt") element(s)"

# --- bare pass -------------------------------------------------------------------
shoot juggler        --charref
shoot juggler_id     --charref --charid
shoot off_char_head        --charref --charsuppress char/head
shoot off_char_hand_closed --charref --charsuppress char/hand_closed
# The OPEN mitt is a separate seam key from the closed one, and which of the two a
# capture reaches depends on where hclose happens to sit that tick. --charopen pins it,
# so the open variants stop coming out empty for reasons that look like a script bug.
shoot juggler_open         --charref --charopen
shoot off_char_hand_open   --charref --charopen --charsuppress char/hand_open

# --- geared pass -----------------------------------------------------------------
shoot juggler_gear         --charref --chargear
shoot juggler_gear_open    --charref --chargear --charopen
for k in hat_top glasses boot glove_closed; do
	shoot "off_char_$k" --charref --chargear --charsuppress "char/$k"
done
shoot off_char_glove_open  --charref --chargear --charopen --charsuppress char/glove_open

# --- the two pieces neither pass above can see -----------------------------------
# The HELMET loses to the top hat in the drawing, so with everything worn its seam key
# is never reached. --charhide hat takes the winner off.
shoot juggler_helm         --charref --chargear --charhide hat
shoot off_char_helmet      --charref --chargear --charhide hat --charsuppress char/helmet
# The BACK of the head and the back of the coat are only drawn mid-Spin, which is a
# handful of frames out of a whole turn and not something a capture can reliably land on.
shoot juggler_back         --charref --charback
shoot off_char_head_back   --charref --charback --charsuppress char/head_back
# The back of the coat has its OWN costume regions, so it needs its own ID map.
shoot juggler_back_id      --charref --charback --charid

rm -f "$OUT/_boxes_tmp.png"
echo "wrote $(ls -1 "$OUT"/*.png | wc -l | tr -d ' ') render(s) to $OUT"
