# Archive

Everything here is the obsolete implementation, kept **for reference only**. The rebuild
(`game/`) does not load, import or depend on anything in this folder.

| Folder | What it was |
|---|---|
| `hysteria/` | The first Godot build. |
| `hysteria2/` | The second Godot build, Godot 4.7, v0.8 (Scene A, the town, Flat 48). Its last APK is `hysteria2/Hysteria-0.8.apk`. |
| `web/` | The original browser build, Three.js (`src/`, `dist/index.html`), and its Android WebView wrapper (`web/android/`, `web/dist/Flat47.apk`). |
| `README-previous.md` | The repository README before the rebuild. |

The rebuild preserves only these assets from `hysteria2/`: Kurt's model (`scripts/art/arm_rig.gd`,
`kurt_body.gd`, `kurt_textures.gd`), Socko's model and rigged animations
(`scripts/art/sock_rig.gd`, `scripts/socko/socko.gd`, `socko_clips.gd`) and the monster models
(`scripts/art/marta_model.gd`, `scripts/infected/*`, `scripts/actors/super_rig.gd`). They were copied
into `game/preserved/` together with the few helpers and shaders they need to draw themselves.
