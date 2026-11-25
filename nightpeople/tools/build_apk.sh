#!/bin/sh
# Builds ../dist/NightPeople.apk (arm64, signed with the repo's debug key in ../android/).
# Needs Godot 4.7 + its Android export templates, the Android SDK (build-tools) and a JDK.
#   GODOT=/path/to/godot ANDROID_SDK=/path/to/sdk tools/build_apk.sh
set -e
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$HOME/godot/Godot_v4.7-stable_linux.x86_64}"
SDK="${ANDROID_SDK:-$HOME/android-sdk}"
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$(cd .. && pwd)/android/flat47-debug.keystore"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=flat47
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=android
# Godot reads the SDK and JDK paths from its editor settings.
CFG="$HOME/.config/godot/editor_settings-4.7.tres"
mkdir -p "$(dirname "$CFG")"
[ -f "$CFG" ] || printf '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n' > "$CFG"
sed -i '/^export\/android\/android_sdk_path/d; /^export\/android\/java_sdk_path/d' "$CFG"
printf 'export/android/android_sdk_path = "%s"\nexport/android/java_sdk_path = "%s"\n' "$SDK" "${JAVA_HOME:-/usr/lib/jvm/default-java}" >> "$CFG"
mkdir -p ../dist
OUT=../dist/NightPeople.apk
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release Android "$OUT"
unzip -l "$OUT" | grep -q "META-INF/.*\.RSA" || { echo "APK NOT SIGNED"; exit 1; }
ls -la "$OUT"
echo "APK signed: $OUT"
