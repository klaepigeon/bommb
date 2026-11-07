#!/bin/sh
# Parse-check every GDScript file (a parse error in a scene's script otherwise just hangs).
cd "$(dirname "$0")/.." || exit 1
fail=0
for f in $(find scripts tests server -name '*.gd' 2>/dev/null); do
  out=$(timeout 60 godot --headless --check-only --script "res://$f" 2>&1 | grep -E "SCRIPT ERROR|Parse Error" | grep -v -E "Identifier \"(Assets|Audio|Settings|Seats|Net|Lighting|Content|Sfx|Profile|Ui|Saves)\" XX|Identifier not found: (Assets|Audio|Settings|Seats|Net|Lighting|Content|Sfx|Profile|Ui|Saves)|Failed to compile depended")
  if [ -n "$out" ]; then echo "== $f"; echo "$out" | head -5; fail=1; fi
done
exit $fail
