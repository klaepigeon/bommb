#!/bin/sh
# Builds ../dist/Hysteria-vulkan.apk: the same game on Godot's Vulkan "Mobile" renderer instead of
# GL Compatibility, as a separate app (HYSTERIA VK, com.klaepigeon.hysteria.vk) so it installs beside
# the OpenGL one. For phones whose OpenGL ES driver misbehaves. The project files are restored after.
set -e
cd "$(dirname "$0")/.."
cp project.godot /tmp/hysteria_project.godot.bak
cp export_presets.cfg /tmp/hysteria_export_presets.cfg.bak
restore() { cp /tmp/hysteria_project.godot.bak project.godot; cp /tmp/hysteria_export_presets.cfg.bak export_presets.cfg; }
trap restore EXIT
sed -i 's/^renderer\/rendering_method="gl_compatibility"/renderer\/rendering_method="mobile"/; s/^renderer\/rendering_method.mobile="gl_compatibility"/renderer\/rendering_method.mobile="mobile"/' project.godot
sed -i 's/^package\/unique_name="com.klaepigeon.hysteria"/package\/unique_name="com.klaepigeon.hysteria.vk"/; s/^package\/name="HYSTERIA"/package\/name="HYSTERIA VK"/; s#^export_path="../dist/Hysteria.apk"#export_path="../dist/Hysteria-vulkan.apk"#' export_presets.cfg
grep -q 'rendering_method.mobile="mobile"' project.godot || { echo "renderer not switched"; exit 1; }
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$(cd .. && pwd)/android/flat47-debug.keystore"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=flat47
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=android
GODOT="${GODOT:-$HOME/godot/Godot_v4.7-stable_linux.x86_64}"
OUT=../dist/Hysteria-vulkan.apk
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release Android "$OUT"
unzip -l "$OUT" | grep -q "META-INF/.*\.RSA" || { echo "APK NOT SIGNED"; exit 1; }
ls -la "$OUT"
echo "APK signed: $OUT"
