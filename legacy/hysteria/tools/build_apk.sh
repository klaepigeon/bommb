#!/bin/sh
# Builds ../dist/Hysteria.apk, signed with the project's key (an unsigned APK won't install),
# and refuses to finish if the signature isn't there.
#   tools/build_apk.sh          the OpenGL ES (Compatibility) build
#   tools/build_apk.sh vulkan   ../dist/Hysteria-Vulkan.apk: the Mobile (Vulkan) renderer, its own
#                               app id and name, so it installs beside the other to compare
set -e
cd "$(dirname "$0")/.."
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$(cd .. && pwd)/android/flat47-debug.keystore"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=flat47
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=android
OUT=../dist/Hysteria.apk
if [ "$1" = "vulkan" ]; then
	OUT=../dist/Hysteria-Vulkan.apk
	cp project.godot /tmp/hysteria_project.godot.bak; cp export_presets.cfg /tmp/hysteria_presets.bak
	trap 'cp /tmp/hysteria_project.godot.bak project.godot; cp /tmp/hysteria_presets.bak export_presets.cfg' EXIT
	sed -i "s/^renderer\/rendering_method=.*/renderer\/rendering_method=\"mobile\"/; s/^renderer\/rendering_method.mobile=.*/renderer\/rendering_method.mobile=\"mobile\"/" project.godot
	sed -i 's/^package\/unique_name=.*/package\/unique_name="com.klaepigeon.hysteria.vulkan"/; s/^package\/name=.*/package\/name="HYSTERIA Vulkan"/' export_presets.cfg
fi
"${GODOT:-$HOME/godot/godot}" --headless --path . --export-release Android "$OUT" || true
unzip -l "$OUT" | grep -q "META-INF/FLAT47.RSA" || { echo "APK NOT SIGNED"; exit 1; }
echo "APK signed: $OUT"
