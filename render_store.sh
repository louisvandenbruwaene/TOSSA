#!/bin/zsh
# Render the WHOLE Steam store set into store/, from the in-engine key art.
# Usage:  ./render_store.sh [variant]      (variant 1..5, default 1)
#
# Two things this script exists to get right, both learned the hard way:
#
# 1. RENDER AT THE SLOT'S OWN ASPECT, then downsample. The key art scales off
#    k = min(s.x/1280, s.y/720), so a render at the wrong aspect does not crop - it
#    re-lays-out, and the wordmark comes out the wrong size for the frame.
#
# 2. macOS CLAMPS A WINDOW to the usable desktop (measured 1920x1016 here) and Godot
#    cannot screenshot headless, since there is no viewport texture. Asking for
#    3840x1240 therefore returns a CLAMPED, WRONG-ASPECT frame that sips then squashes
#    to size - which is distortion, the one thing a store capsule must not have. So
#    every render box below fits inside the desktop AND matches its target's aspect,
#    and the only slot that is ever upscaled is the 3840x1240 library hero, which is
#    also the slot most tolerant of it (a wide atmospheric banner Valve lays the logo
#    over).
GODOT=${GODOT:-/opt/homebrew/bin/godot}
VAR=${1:-1}
cd "$(dirname "$0")"
OUT="$PWD/store"
TMP=$(mktemp -d)
mkdir -p "$OUT"

# name        render WxH    final WxH
SLOTS=(
	"header    1840x860     460x215"
	"small     1848x696     231x87"
	"main      1760x1008    616x353"
	"vertical  840x1006     374x448"
	# 1:1 deliberately - 1438x810 is an awkward 1.7753, and every larger box that fits
	# the desktop rounds to a height a pixel off it, which is a (tiny, but needless)
	# stretch. The art is vector and already antialiased, so rendering at the final size
	# costs nothing and cannot distort.
	"page_bg   1438x810     1438x810"
	"hero      1920x620     3840x1240"
)

for row in $SLOTS; do
	set -- ${=row}
	name=$1; render=$2; final=$3
	rw=${render%x*}; rh=${render#*x}
	fw=${final%x*};  fh=${final#*x}
	"$GODOT" --path . --audio-driver Dummy --resolution "$rw"x"$rh" -- \
		--capsule "$VAR" --shot "$TMP/$name.png" --shotat 40 >/dev/null 2>&1
	if [[ ! -f "$TMP/$name.png" ]]; then
		echo "FAILED  $name (no frame written - is $GODOT the CLI binary?)"
		continue
	fi
	got=$(sips -g pixelWidth -g pixelHeight "$TMP/$name.png" | awk '/pixel/{printf "%s", $2"x"}' | sed 's/x$//')
	if [[ "$got" != "$render" ]]; then
		echo "WARNING $name: asked for $render, got $got - the window was clamped, so this"
		echo "        frame is the wrong ASPECT and will be distorted. Pick a smaller box."
	fi
	sips -z "$fh" "$fw" "$TMP/$name.png" --out "$OUT/$name.png" >/dev/null 2>&1
	echo "wrote   store/$name.png  ($final, rendered $got)"
done
rm -rf "$TMP"
