#!/bin/sh
# Plays the game headless through the real controls and checks it: Scene A (every line, in the
# owner's order), the wardrobe and the hole, then the town, out by each of its three ways.
#   tools/test.sh                 all three routes, from the first knock (exit code 0 = all pass)
#   tools/test.sh talk|kill|sneak one route
#   tools/test.sh super           the stairwell and The Super
#   tools/test.sh touch           the touch controls, with real touch events
#   tools/test.sh shots DIR [route] [--start=town]   real speed, rendered, a frame per line in DIR
set -e
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$HOME/godot/Godot_v4.7-stable_linux.x86_64}"
if [ "$1" = "shots" ]; then
	xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 --resolution 1280x720 -- --shots="$2" --route="${3:-talk}" $4
	exit
fi
if [ "$1" = "touch" ]; then      # fingers on glass: stick, look, pause, resume (needs a display: xvfb)
	LOG=$(mktemp)
	timeout 120 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 --resolution 1280x720 -- --autotest --touch >"$LOG" 2>&1 || true
	grep -E "AUTOTEST" "$LOG"; grep -q "AUTOTEST PASS" "$LOG"; exit
fi
if [ "$1" = "super" ]; then      # the stairs, the Super's rounds, bullets, the grab
	LOG=$(mktemp)
	"$GODOT" --headless --path . -- --autotest --fast --super --start=door >"$LOG" 2>&1 || true
	grep -E "AUTOTEST" "$LOG"; grep -q "AUTOTEST PASS" "$LOG"; exit
fi
ROUTES="${1:-talk kill sneak}"
for r in $ROUTES; do
	LOG=$(mktemp)
	if "$GODOT" --headless --path . -- --autotest --fast --route="$r" >"$LOG" 2>&1; then
		grep -E "AUTOTEST" "$LOG"
	else
		grep -E "AUTOTEST|SCRIPT ERROR|lines said|state" "$LOG"; rm -f "$LOG"; echo "FAILED: $r"; exit 1
	fi
	rm -f "$LOG"
done
