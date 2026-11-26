#!/bin/sh
# Headless checks of the first playable milestone (tests/autotest.gd). Exit code 0 = pass.
#   tools/test.sh            run the autotest (all routes)
#   tools/test.sh shots DIR  render the fixed views in tests/shots.gd to DIR (needs xvfb-run)
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$HOME/godot/Godot_v4.7-stable_linux.x86_64}"
if [ "$1" = "shots" ]; then
	xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 --resolution 1280x720 -- --shots="$2" $3
	exit
fi
"$GODOT" --headless --import --path . >/dev/null 2>&1
for f in $(find . -name "*.gd" -not -path "./.godot/*"); do
	if "$GODOT" --headless --path . --check-only -s "$f" 2>&1 | grep -q "Parse Error"; then
		"$GODOT" --headless --path . --check-only -s "$f" 2>&1 | grep -A1 "Parse Error"; exit 1
	fi
done
# Routes: night (the whole night, nobody interferes with the story), prevent (steal the box),
# warn (talk Abe out of it), rescue (under the street). `tools/test.sh warn` runs one.
CODE=0
for ROUTE in ${1:-night prevent warn rescue}; do
	LOG=$(mktemp)
	timeout 900 "$GODOT" --headless --fixed-fps 60 --path . -- --autotest --route=$ROUTE >"$LOG" 2>&1 || CODE=1
	echo "--- route: $ROUTE"
	grep -E "AUTOTEST|SCRIPT ERROR|Parse Error|ERROR: .*res://" "$LOG"
	rm -f "$LOG"
done
exit $CODE
