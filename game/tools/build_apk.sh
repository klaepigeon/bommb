#!/bin/sh
# Builds dist/Hysteria.apk (arm64, signed with the repo key in android/ so it installs over earlier
# builds) and refuses to finish unless it's signed and contains the game.
#   GODOT=/path/to/godot tools/build_apk.sh
# Needs Godot 4.7 + export templates, the Android SDK (build-tools, platform) and a JDK 17+, set in
# Godot's editor settings (export/android/android_sdk_path, java_sdk_path).
set -e
cd "$(dirname "$0")/.."
ROOT="$(cd .. && pwd)"
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$ROOT/android/flat47-debug.keystore"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=flat47
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=android
GODOT="${GODOT:-$HOME/godot/Godot_v4.7-stable_linux.x86_64}"
OUT="$ROOT/dist/Hysteria.apk"
mkdir -p "$ROOT/dist"
"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release Android "$OUT"
unzip -l "$OUT" | grep -q "META-INF/.*\.RSA" || { echo "APK NOT SIGNED"; exit 1; }
unzip -l "$OUT" | grep -q "assets/.*pck\|assets/project.binary\|assets/.godot" || { echo "APK HAS NO GAME DATA"; exit 1; }
ls -la "$OUT"
echo "APK signed: $OUT"
