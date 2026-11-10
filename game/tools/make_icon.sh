#!/bin/sh
# Makes the app icon: Socko. Renders him (tools/icon.tscn, needs xvfb-run and Godot), then
# composes icon/: adaptive foreground + background (432), the legacy launcher icon (192), and
# the project icon (512). Needs Python with Pillow.
set -e
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$HOME/godot/Godot_v4.7-stable_linux.x86_64}"
TMP=$(mktemp -d)
xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 res://tools/icon.tscn -- --out="$TMP" >/dev/null 2>&1
[ -f "$TMP/socko_raw.png" ] || { echo "icon render failed"; exit 1; }
mkdir -p icon
python3 - "$TMP/socko_raw.png" icon <<'PY'
import sys, math
from PIL import Image, ImageDraw, ImageFilter
raw = Image.open(sys.argv[1]).convert("RGBA")
out = sys.argv[2]

def background(n):
    # oxblood, like the padded door of 47: lit in the middle, going to black at the edges
    bg = Image.new("RGB", (n, n))
    px = bg.load()
    c0 = (124, 30, 30); c1 = (30, 7, 9)
    for y in range(n):
        for x in range(n):
            d = math.hypot((x - n * 0.5) / (n * 0.5), (y - n * 0.46) / (n * 0.5))
            k = min(1.0, d / 1.25) ** 1.4
            px[x, y] = tuple(int(c0[i] + (c1[i] - c0[i]) * k) for i in range(3))
    return bg

fg = raw.resize((432, 432), Image.LANCZOS)
fg.save(f"{out}/adaptive_foreground.png")
bg = background(432)
bg.save(f"{out}/adaptive_background.png")

def composite(n, radius_frac):
    b = background(n).convert("RGBA")
    f = raw.resize((n, n), Image.LANCZOS)
    # a soft shadow under him so he sits on the red
    sh = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    sh.paste((0, 0, 0, 150), (0, 0), f.split()[3])
    sh = sh.filter(ImageFilter.GaussianBlur(n * 0.025))
    b.alpha_composite(sh, (int(n * 0.012), int(n * 0.02)))
    b.alpha_composite(f)
    if radius_frac > 0:
        mask = Image.new("L", (n * 4, n * 4), 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, n * 4 - 1, n * 4 - 1), radius=int(n * 4 * radius_frac), fill=255)
        b.putalpha(mask.resize((n, n), Image.LANCZOS))
    return b

# the one-colour version (Android 13 themed icons tint it): his shape, with the pupils and the
# inside of his mouth cut out so it still reads as him
mono = Image.new("RGBA", fg.size, (255, 255, 255, 0))
src = fg.load(); dst = mono.load()
for y in range(fg.size[1]):
    for x in range(fg.size[0]):
        r, g, b, a = src[x, y]
        luma = 0.299 * r + 0.587 * g + 0.114 * b
        pupil = luma < 48
        mouth = r > 110 and r > g * 1.9 and r > b * 1.9
        dst[x, y] = (255, 255, 255, 0 if (pupil or mouth) else a)
mono.save(f"{out}/adaptive_monochrome.png")

composite(192, 0.22).save(f"{out}/icon_192.png")
composite(512, 0.0).convert("RGB").save(f"{out}/icon.png")
print("icons written to", out)
PY
rm -rf "$TMP"
