#!/bin/sh
# Plays Scene A headless through the real controls and checks every line, in order.
#   tools/test.sh            fast, no window
#   tools/test.sh shots DIR  real speed, renders, saves a frame per line into DIR (needs xvfb-run)
set -e
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$HOME/godot/Godot_v4.7-stable_linux.x86_64}"
if [ "$1" = "shots" ]; then
	xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 --resolution 1280x720 -- --shots="$2"
else
	"$GODOT" --headless --path . -- --autotest --fast
fi
