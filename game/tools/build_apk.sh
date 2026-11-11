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
# Godot's export signs with v2/v3 only (and leaves stale v1 files behind). Some installers and
# file managers only look at the v1 (JAR) signature and call the APK unsigned, so: strip it,
# re-align, and sign with all three schemes, then make Android's own verifier confirm each one.
SDK="${ANDROID_SDK:-$HOME/android-sdk}"
BT="$(ls -d "$SDK"/build-tools/* | sort -V | tail -1)"
TMP="$(mktemp -d)"
cp "$OUT" "$TMP/in.apk"
zip -q -d "$TMP/in.apk" 'META-INF/*' || true
"$BT/zipalign" -f -p 4 "$TMP/in.apk" "$TMP/aligned.apk"
"$BT/apksigner" sign --ks "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH" --ks-key-alias "$GODOT_ANDROID_KEYSTORE_RELEASE_USER" \
	--ks-pass pass:"$GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD" --key-pass pass:"$GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD" \
	--min-sdk-version 21 --v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled true \
	--out "$OUT" "$TMP/aligned.apk"
rm -rf "$TMP" "$OUT.idsig"
V="$("$BT/apksigner" verify --min-sdk-version 21 --verbose "$OUT" 2>&1)"
for scheme in v1 v2 v3; do
	echo "$V" | grep -q "Verified using $scheme scheme.*: true" || { echo "APK NOT SIGNED ($scheme)"; echo "$V"; exit 1; }
done
"$BT/zipalign" -c -p 4 "$OUT" || { echo "APK NOT ALIGNED"; exit 1; }
unzip -l "$OUT" | grep -q "assets/project.binary" || { echo "APK HAS NO GAME DATA"; exit 1; }
ls -la "$OUT"
echo "APK signed (v1+v2+v3) and verified: $OUT"
