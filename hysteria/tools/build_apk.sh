#!/bin/sh
# Builds ../dist/Hysteria.apk, signed with the project's key (an unsigned APK won't install),
# and refuses to finish if the signature isn't there.
set -e
cd "$(dirname "$0")/.."
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$(cd .. && pwd)/android/flat47-debug.keystore"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=flat47
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=android
"${GODOT:-$HOME/godot/godot}" --headless --path . --export-release Android ../dist/Hysteria.apk || true
unzip -l ../dist/Hysteria.apk | grep -q "META-INF/FLAT47.RSA" || { echo "APK NOT SIGNED"; exit 1; }
echo "APK signed: ../dist/Hysteria.apk"
