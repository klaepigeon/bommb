#!/bin/sh
# Builds ../dist/PutASockInIt.apk (arm64 + armv7, OpenGL ES), signed with the repo's key, and
# fails if the signature isn't there. Needs Godot 4.7 with its export templates installed, and
# the Android SDK's build-tools (apksigner) set in Godot's editor settings.
set -e
cd "$(dirname "$0")/.."
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$(cd .. && pwd)/android/flat47-debug.keystore"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=flat47
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=android
mkdir -p ../dist
OUT=../dist/PutASockInIt.apk
"${GODOT:-$HOME/godot/godot}" --headless --path . --export-release Android "$OUT"
"${APKSIGNER:-$(ls -d $HOME/android-sdk/build-tools/*/ | tail -1)apksigner}" verify "$OUT" && echo "APK signed: $OUT"
