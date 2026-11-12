#!/bin/sh
# Renders the trailer (tools/trailer.gd) in three parts through Godot's Movie Maker, trims the
# loading off the front of each, and joins them into ../dist/PutASockInIt_trailer.mp4 (1280x720,
# 30 fps, H.264 + AAC), plus a 12-second, 480p GIF of the scare for posting.
# Needs a display (xvfb-run on a headless machine) and ffmpeg.
#   ./tools/trailer.sh
set -e
if [ -z "$DISPLAY" ]; then exec xvfb-run -a -s "-screen 0 1280x720x24" "$0" "$@"; fi
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$HOME/godot/godot}"
TMP="${TMPDIR:-/tmp}/sock_trailer"
mkdir -p "$TMP" ../dist
LIST="$TMP/list.txt"; : > "$LIST"
for part in flat maze card; do
	START=$("$GODOT" --rendering-driver opengl3 --path . --resolution 1280x720 \
		--write-movie "$TMP/$part.avi" --fixed-fps 30 -s tools/trailer.gd -- part=$part 2>&1 \
		| sed -n 's/^TRAILER_START //p' | head -1)
	echo "$part: shots start at ${START}s"
	ffmpeg -y -loglevel error -ss "$START" -i "$TMP/$part.avi" -c:v libx264 -preset slow -crf 18 \
		-pix_fmt yuv420p -c:a aac -b:a 192k -ar 48000 -ac 2 "$TMP/$part.mp4"
	echo "file '$TMP/$part.mp4'" >> "$LIST"
done
# joined, and the sound brought up to the usual level for the web (-14 LUFS)
ffmpeg -y -loglevel error -f concat -safe 0 -i "$LIST" -c:v copy -af loudnorm=I=-14:TP=-1.0:LRA=11 -c:a aac -b:a 192k -ar 48000 ../dist/PutASockInIt_trailer.mp4
# the scare, as a GIF (no sound): the push-in on her and the lunge
ffmpeg -y -loglevel error -ss 11 -t 12 -i "$TMP/flat.mp4" \
	-vf "fps=15,scale=480:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=96[p];[b][p]paletteuse=dither=bayer" \
	../dist/PutASockInIt_scare.gif
ls -la ../dist/PutASockInIt_trailer.mp4 ../dist/PutASockInIt_scare.gif
