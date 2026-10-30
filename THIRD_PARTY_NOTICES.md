# Third-party material

## Original game

Fallout Equestria: Remains is by **Empalu**. Its art, sound, music, fonts, animations, characters, rooms, text and data, and anything exported or converted from them (mostly in `godot/assets/`), are not owned by this project and are not covered by its license. Each such material keeps its authors' rights.

## Engine and libraries

- **Godot Engine** — MIT License, https://godotengine.org/license
- **Liberation fonts** — SIL Open Font License, see `godot/theme/fonts/LIBERATION_LICENSE`

## Tools (not shipped with the game)

- **JPEXS Free Flash Decompiler (FFDec)** — GPL-3.0, expected in `tools/ffdec/`, not included in the repository.
- **xfl2svg** by PluieElectrique — MIT License, expected in `tools/xfl2svg/`, not included. `tools/xfl2svg_radial_gradient.patch` modifies it and is under the same MIT License.
- **resvg** — Apache-2.0 / MIT, expected in `tools/resvg/`, not included.

## Material from the other Godot port

Copied from **foe-remains-godot** with its author's permission (2026-10-28): the converted unit rigs in `godot/assets/rigs/` (part art, rig data, scenes, animation libraries, colour-transform shaders). `godot/scripts/rig/rig_view.gd` follows its `rig_base.gd`. The player rig (`godot/assets/rigs/player/`) and its runtime (`godot/scripts/rig/other/`: `rig_base.gd`, `player_rig.gd`, `vis_base.gd`, `rig_art_fx.gd`) are copied as they are (2026-10-31). UI art copied earlier is listed in `docs/IMPLEMENTED.md`.

## Code based on Remains: Unity

None yet. Any file adapted from Remains: Unity (https://github.com/Hemito/Remains-Unity, PolyForm Noncommercial License 1.0.0 with additional permissions) is listed here and keeps its notice:

Required Notice: Remains: Unity — независимый фанатский проект по игре Remains автора Empalu. Официальный репозиторий: https://github.com/Hemito/Remains-Unity.
