#!/usr/bin/env bash
# Builds the Android app (a signed APK) without Gradle: javac + d8 + aapt2 + apksigner,
# straight from the Android SDK. Needs ANDROID_HOME with build-tools;35.0.0 and
# platforms;android-35, and a JDK 17+.
#   android/build.sh            → android/build/Flat47-<version>.apk
set -euo pipefail
cd "$(dirname "$0")"
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/android-sdk}}"
BT="$SDK/build-tools/35.0.0"
JAR="$SDK/platforms/android-35/android.jar"
VERSION=$(sed -n 's/.*android:versionName="\([^"]*\)".*/\1/p' AndroidManifest.xml)
OUT=build; rm -rf "$OUT"; mkdir -p "$OUT/classes" "$OUT/res" "$OUT/assets" "$OUT/dex"

# the game itself: the one-file web build
( cd .. && node build.mjs )
cp ../dist/index.html "$OUT/assets/index.html"

"$BT/aapt2" compile --dir res -o "$OUT/res.zip"
"$BT/aapt2" link -o "$OUT/unsigned.apk" -I "$JAR" --manifest AndroidManifest.xml -A "$OUT/assets" "$OUT/res.zip" --java "$OUT/gen" --auto-add-overlay
javac -source 8 -target 8 -nowarn -Xlint:-options -bootclasspath "$JAR" -classpath "$JAR" -d "$OUT/classes" $(find src "$OUT/gen" -name '*.java')
"$BT/d8" --min-api 24 --lib "$JAR" --output "$OUT/dex" $(find "$OUT/classes" -name '*.class')
( cd "$OUT/dex" && zip -q -j ../unsigned.apk classes.dex )
"$BT/zipalign" -f -p 4 "$OUT/unsigned.apk" "$OUT/aligned.apk"
# always sign with the project's own key, so every build installs over the last one
KS=flat47-debug.keystore
[ -f "$KS" ] || keytool -genkeypair -keystore "$KS" -storepass android -keypass android -alias flat47 -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Flat 47 debug" >/dev/null 2>&1
"$BT/apksigner" sign --ks "$KS" --ks-pass pass:android --key-pass pass:android --out "$OUT/Flat47-$VERSION.apk" "$OUT/aligned.apk"
"$BT/apksigner" verify "$OUT/Flat47-$VERSION.apk"
rm -f "$OUT/unsigned.apk" "$OUT/aligned.apk"
ls -la "$OUT/Flat47-$VERSION.apk"
cp "$OUT/Flat47-$VERSION.apk" ../dist/Flat47.apk
