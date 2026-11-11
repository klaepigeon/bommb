#!/bin/sh
# Plays the game through its real systems, headless, and checks it.
#   tools/test.sh               every route (exit 0 = all pass)
#   tools/test.sh poke kick     some
#   tools/test.sh touch         (needs a display: run under xvfb-run)
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$HOME/godot/Godot_v4.7-stable_linux.x86_64}"
ROUTES="${*:-scene_a poke kick maze shoes axe shoot service systems save monsters talk meet random building kick51 atmosphere ledge}"
FAIL=0
for r in $ROUTES; do
	LOG=${LOGDIR:-/tmp}/test_$r.log
	timeout 300 "$GODOT" --headless --path . -- --autotest --fresh --route="$r" --start="$([ "$r" = scene_a ] && echo knock || echo wake)" >"$LOG" 2>&1
	CODE=$?
	grep -E "AUTOTEST (PASS|FAIL)" "$LOG"
	grep -E "SCRIPT ERROR|^ERROR" "$LOG" | grep -v "ERR_CANT_OPEN\|ALSA" | head -5
	if [ $CODE -ne 0 ] || ! grep -q "AUTOTEST PASS" "$LOG"; then FAIL=1; echo "  ($r: exit $CODE, log $LOG)"; else rm -f "$LOG"; fi
done
exit $FAIL
