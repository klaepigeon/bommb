# Building

Godot **4.7 stable**, GL Compatibility renderer.

## Android APK

Needs: the 4.7 export templates (only `android_release.apk`, `android_debug.apk`,
`android_source.zip` and `version.txt` from the `.tpz`, in
`~/.local/share/godot/export_templates/4.7.stable/`), a JDK 17+, and Android SDK
build-tools (for `apksigner`). Point Godot at them in
`~/.config/godot/editor_settings-4.7.tres`:

```
export/android/android_sdk_path = "/opt/android-sdk"
export/android/java_sdk_path = "/usr/lib/jvm/java-21-openjdk-amd64"
```

```
godot --headless --export-release "Android" build/MEAT_PARTY.apk
```

Package `com.klaepigeon.meatparty`, arm64-v8a, min SDK 24, landscape, immersive.
Permissions: internet, network/Wi-Fi state, Wi-Fi multicast (LAN room codes).

Signing: `android/meatparty.keystore`, alias `meatparty`, password `meatparty1999`.
It's committed so builds are reproducible; anyone with the repository can sign with it,
so make your own for a public release.

## Desktop

```
godot --headless --export-release "Windows" build/windows/MEAT_PARTY.exe
godot --headless --export-release "Linux" build/linux/MEAT_PARTY.x86_64
```

(needs the Windows/Linux templates from the same `.tpz`; not built yet.)
