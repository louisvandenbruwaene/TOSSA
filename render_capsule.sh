#!/bin/zsh
# Render one capsule picture straight into store/concepts/, which is the file you are
# already looking at. Usage:  ./render_capsule.sh 4
# The important part is GODOT: it must be the command-line binary, NOT the Godot app.
# Launching the app just opens the project manager, the arguments after -- never reach a
# running game, and nothing is ever written - which looks exactly like "it opened Godot,
# I closed it, and nothing changed".
GODOT=${GODOT:-/opt/homebrew/bin/godot}
N=${1:-4}
cd "$(dirname "$0")"
OUT="$PWD/store/concepts/cap$N.png"
"$GODOT" --path . --audio-driver Dummy --resolution 1232x706 -- --capsule "$N" --shot "$OUT" --shotat 40 >/dev/null 2>&1
if [[ -f "$OUT" ]]; then
	echo "wrote $OUT"
	open "$OUT"
else
	echo "nothing was written - check that $GODOT is the CLI binary (godot --version should print a version)"
fi
