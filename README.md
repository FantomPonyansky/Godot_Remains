# Fallout Equestria: Remains — Godot port

A faithful port of the Flash game *Fallout Equestria: Remains* to **Godot 4.7**. The aims are full controller support, all the Steam languages, and native Windows and Linux builds.

This is a non-commercial fan project. It is not affiliated with the authors of the original game. The art, sound, music and text in `godot/assets` come from the original and belong to their authors.

The project's own code is under the [PolyForm Noncommercial License 1.0.0](LICENSE) with [additional permissions](ADDITIONAL_PERMISSIONS.md) (voluntary donations, monetised videos and streams, free mirrors). What is and is not covered: [LICENSING.md](LICENSING.md), [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Status

Playable from the start of the game through the story lands: generated and hand-made levels, combat, magic and perks, the PipBuck, inventory, trade, crafting, the world map, saves, and English and Russian text. `docs/TODO.md` lists the open work, and `docs/IMPLEMENTED.md` describes what the port has, system by system.

## Running

1. Install [Godot 4.7.2](https://godotengine.org/) (standard build, not .NET).
2. Clone the repository (about 600 MB, mostly art and audio).
3. Open `godot/project.godot` in Godot and press Play. The first import takes a while (about 23,000 images).

On Windows, `Launch Remains Port.bat` starts the project if Godot is in `tools/godot/`.

Controls and debug console: `build/TESTER_GUIDE.md` and `godot/DEBUG_COMMANDS.md`.

## Building

Use the export presets in `godot/export_presets.cfg` ("Windows Desktop" and "Linux"). For the exact commands and patch builds, see the "Export" section of `HANDOFF.md`.

## Repository layout

| Path | Contents |
|---|---|
| `godot/` | The Godot project: scripts, scenes, shaders, and assets converted from the original |
| `docs/` | Knowledge base on the original game, port status, plan, player feedback, port rules |
| `tools/` | Python data extractors and helpers |
| `tools/swf_export/` | FFDec-based art exporters for the original swf files |
| `build/` | Tester guide and ID lists (builds themselves are not committed) |
| `HANDOFF.md` | Working notes: paths, rules, how to check and export |

## Working with the original files

The extraction tools expect the original game files in a local `original/` folder, which is gitignored. Its layout is listed in `HANDOFF.md` under "Paths": for example, `original/swf/pfe.swf` and `original/reference/Remains-Source2` (the AS3 source). FFDec ([JPEXS Free Flash Decompiler](https://github.com/jindrapetrik/jpexs-decompiler)) goes in `tools/ffdec/`. Exporters never render from a whole swf; `tools/swf_export/swf_trim.py` cuts out the symbols they need first.

The runtime does not need `original/`; everything the game loads is already in `godot/assets`.
