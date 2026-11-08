#!/usr/bin/env bash
# Exports HYSTERIA for Android (arm64, OpenGL ES 3 via the Compatibility renderer) to
# dist/Hysteria.apk, signed with the same debug keystore as the old WebView build.
# Needs: Godot 4.7 at $GODOT (default ~/godot/godot), its Android export templates installed,
# an Android SDK at $ANDROID_HOME (default ~/android-sdk) and a JDK 17+.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-$HOME/godot/godot}
SDK=${ANDROID_HOME:-$HOME/android-sdk}
JDK=${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v javac || command -v java)")")")}
KS=$(cd .. && pwd)/android/flat47-debug.keystore
# point the editor at the SDK and JDK (merged into the editor settings file)
CFG=$HOME/.config/godot; mkdir -p "$CFG"
ES=$CFG/editor_settings-4.7.tres
[ -f "$ES" ] || printf '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n' > "$ES"
sed -i '/^export\/android\/android_sdk_path/d; /^export\/android\/java_sdk_path/d' "$ES"
printf 'export/android/android_sdk_path = "%s"\nexport/android/java_sdk_path = "%s"\n' "$SDK" "$JDK" >> "$ES"
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=$KS GODOT_ANDROID_KEYSTORE_RELEASE_USER=flat47 GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=android
mkdir -p ../dist
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Android" ../dist/Hysteria.apk
ls -la ../dist/Hysteria.apk
