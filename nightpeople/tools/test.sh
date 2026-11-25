#!/bin/sh
# Headless checks of the first playable milestone (tests/autotest.gd). Exit code 0 = pass.
#   tools/test.sh            run the autotest
#   tools/test.sh shots DIR  render the fixed views in tests/shots.gd to DIR (needs xvfb-run)
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$HOME/godot/Godot_v4.7-stable_linux.x86_64}"
if [ "$1" = "shots" ]; then
	xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 --resolution 1280x720 -- --shots="$2" $3
	exit
fi
"$GODOT" --headless --import --path . >/dev/null 2>&1
LOG=$(mktemp)
timeout 900 "$GODOT" --headless --fixed-fps 60 --path . -- --autotest >"$LOG" 2>&1
CODE=$?
grep -E "AUTOTEST|SCRIPT ERROR|Parse Error|ERROR: .*res://" "$LOG"
rm -f "$LOG"
exit $CODE
