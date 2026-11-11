#!/bin/sh
# The phone, as near as this machine gets without one: OpenGL ES 3 (Mesa), the phone's screen
# (2340 x 1080, landscape), touch mode, real multi-touch events driving the stick, the look, the
# buttons and the pause menu. Screenshots go to DIR.
#   tools/phone.sh [DIR]
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$HOME/godot/Godot_v4.7-stable_linux.x86_64}"
DIR="${1:-$(pwd)/shots/phone}"
mkdir -p "$DIR"
timeout 300 xvfb-run -a -s "-screen 0 2340x1080x24" "$GODOT" --path . --rendering-driver opengl3_es --resolution 2340x1080 \
	-- --autotest --fresh --touch --phone --route=touch --start=wake --shots="$DIR" 2>&1 | grep -E "AUTOTEST|SCRIPT ERROR|OpenGL API"
