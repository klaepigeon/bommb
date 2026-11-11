#!/bin/sh
# Builds ../dist/Hysteria.apk (arm64, GL Compatibility), signed with the repo's key (android/), and
# refuses to finish unless the signature is there. Needs Godot 4.7 + its export templates, the
# Android SDK (build-tools) and a JDK, named in Godot's editor settings.
set -e
cd "$(dirname "$0")/.."
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$(cd .. && pwd)/android/flat47-debug.keystore"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=flat47
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=android
GODOT="${GODOT:-$HOME/godot/Godot_v4.7-stable_linux.x86_64}"
OUT=../dist/Hysteria.apk
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release Android "$OUT"
unzip -l "$OUT" | grep -q "META-INF/.*\.RSA" || { echo "APK NOT SIGNED"; exit 1; }
ls -la "$OUT"
echo "APK signed: $OUT"
