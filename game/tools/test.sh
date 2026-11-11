#!/bin/sh
# HYSTERIA automated tests. Exit code 0 = every check passed.
#   tools/test.sh            check (compile everything), smoke (build every level), then all suites
#   tools/test.sh SUITE      one suite: systems | scene_a | routes | ai
#   tools/test.sh shots DIR  a rendered tour (needs xvfb)
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$HOME/godot/Godot_v4.7-stable_linux.x86_64}"
LOG=$(mktemp)
run() { timeout -s KILL "${2:-400}" "$GODOT" --headless --path . $1 > "$LOG" 2>&1; R=$?; grep -E "AUTOTEST|CHECK|SMOKE|SCRIPT ERROR|CHAPTER1_END" "$LOG"; return $R; }
if [ "$1" = "shots" ]; then
	timeout -s KILL 300 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 --resolution 1280x720 -- --autotest=shots --shots="$2" $3
	exit $?
fi
"$GODOT" --headless --path . --import > /dev/null 2>&1
run "res://tools/check.tscn" 120 || exit 1
if [ -z "$1" ]; then
	run "res://src/tests/smoke.tscn" 120 || exit 1
	run "-- --autotest=all --fast" 900; exit $?
fi
run "-- --autotest=$1 --fast" 600
