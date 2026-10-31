# FoE Remains port — start here

Godot 4.7.2 port of Fallout Equestria: Remains (Flash). Goal: a faithful port with full controller play, all Steam languages, Windows and Linux builds.

## Documents

| File | Contents |
|---|---|
| `docs/KNOWLEDGE_BASE.md` | The original: versions (2021, Steam base, DLC), sources, art ids, AS3 mechanics, wiki check, "looks like a bug, is original". |
| `docs/IMPLEMENTED.md` | What the port has, by system, and where the code is. Gotchas at the end. |
| `docs/TODO.md` | Step-by-step plan to finish, with phase status. |
| `docs/PLAYER_FEEDBACK.md` | Reports from play and their status. |
| `docs/PORT_RULES.md` | User decisions that differ from the original. Do not revert them. |
| `docs/ENEMY_AI.md` | Enemy behaviour now (states, senses, targets, movement, engage / disengage) and the list of differences from the original. |
| `docs/MULTIPLAYER_PLAN.md` | Step-by-step refactoring plan for online co-op (after the port). |
| `docs/EDITOR_PORT_PLAN.md` | Room editor plan. Debug `map_builder` is retired in `_trash/map_builder/`. |
| `godot/DEBUG_COMMANDS.md` | Console commands. Update whenever they change. |
| `verify/README.md` | Human verify kit: one folder per hand check with a launcher straight into the situation and a verdict file. A "Verify in play" note in `PLAYER_FEEDBACK.md` should get a row here. |
| `build/TESTER_GUIDE.md`, `build/TESTER_IDS.md` | Tester onboarding and ID lists (copied into `build/windows`, `build/linux`). |

After each chunk of work: update `IMPLEMENTED.md`, tick `TODO.md`, and answer `PLAYER_FEEDBACK.md` rows it touches. New user decisions go to `PORT_RULES.md`; new facts about the original go to `KNOWLEDGE_BASE.md`.

## Paths

| What | Where |
|---|---|
| Godot project | `D:\Games\FoE Remains Port\godot` |
| Godot console exe | `D:\Games\FoE Remains Port\tools\godot\Godot_v4.7.2-stable_win64_console.exe` |
| Original game (local only, gitignored) | `original\`: `swf\` (pfe, sprite, texture, sound swf), `text\` (text_*.xml, lang.xml), `game\` (pfe.exe, Flash player, pfe1.zip), `release_2021\`, `reference\` (AS3 source), `decompiled_2021\`, `steam_decompiled\`, `ui_xfl\`, `tile_extract\` (symbol lists), `extracted_swf\` (FFDec work dirs), `extracted_images\`, `music_2019\`, `menu_screenshots\`, `fla\` (author's unit animation sources, see `KNOWLEDGE_BASE.md`). Versions: `docs/KNOWLEDGE_BASE.md` "Versions" |
| Extraction scripts | `tools\swf_export\` (exporters, `swf_trim.py`), `tools\*.py` (data extractors), `godot\tools\pack_*.gd` (packers). Paths are relative to the repo root. |
| Share pack for Remains: Unity | `python tools\share_unity_pack.py` writes `build\share_remains_unity\` (their Resources layout; README from `tools\share_unity_pack_README.md`). |
| Scratch | `tmp\` (gitignored). Screenshots go to `tmp\shots\`. `_trash\` holds files waiting for the user to delete. |
| User test launcher | `Launch Remains Port.bat` (runs the project directly) |
| Builds | `build\windows\RemainsPort.exe` (+ `.console.exe`), `build\linux\RemainsPort.x86_64` |
| Object-art audit | `docs\OBJECT_ART_AUDIT.md` |

## Working rules

- Plain git repo, no LFS (user decision; files stay under 100 MB each). Never commit or push unless the user asks. No network unless the user asks for a download.
- Never put original-game files outside `godot/assets` into the repo; they live in `original/`.
- Do not rebuild or export builds unless the user asks.
- Online co-op via Steam is planned after the port. Follow "Future multiplayer" in `docs/PORT_RULES.md` when choosing an architecture; do not build it now.
- One writer at a time for `player.gd`, `land_props.gd`, `enemy.gd`, `bullet.gd`, `project.godot`. Re-read `player.gd` before saving.
- FFDec: never export sprites from a whole swf; trim to symbol ids (see `KNOWLEDGE_BASE.md`).
- Back up `%APPDATA%\Godot\app_userdata\FoE Remains` (copy at `%TEMP%\foe_ud_bk_main`) before test runs and restore it after. The shared user data has a damaged player; reset HP and organs at the start of damage tests. Move `godot/tests/tmp_*` to `_trash/` afterwards (user: nothing is deleted, only moved). The headless boot does not compile lazily loaded scripts; after removing code, `load()` each edited script from a throwaway `-s` test.
- Do not pipe a long Godot export into `Select-Object -First`; it kills the export. Send its output to a file.

## How to check the game

Headless boot (autoloads load; `-s` / `--check-only` scripts do not, so their autoload errors are false):

```
& $g --headless --path godot res://scenes/game.tscn --quit-after 240
& $g --headless --path godot res://scenes/main_menu.tscn --quit-after 120
& $g --headless --path godot -s res://tests/test_room_xml.gd
& $g --headless --path godot -s res://tests/test_editor_validate.gd -- --user-dir="$env:TEMP\foe_editor_validate"
& $g --headless --path godot -s res://tests/test_room_pool.gd -- --user-dir="$env:TEMP\foe_room_pool"
# Windowed editor play/preview probe, screenshot to tmp/play_probe.png. Args: file room|*|EMPTY seconds [as_name] [preview|preview2|editor|play] [burst] [layerpop] [drag: LMB drag 2 s before the shot, prints camera vs screen centre]
# --user-dir=<path> is our flag (user_dir.gd), not Godot's: always after --, always with =. "--user-dir <path>" makes Godot run the path as the scene (main menu) and writes to AppData.
& $g --path godot res://tests/play_probe.tscn -- rooms_comm room_1_0 8 rooms_comm editor --user-dir="$env:TEMP\foe_probe"
# Windowed main menu shot to tmp/shots/menu.png. Arg: seconds.
& $g --path godot res://tests/menu_probe.tscn -- 10 --user-dir="$env:TEMP\foe_probe"
# Windowed PipBuck shot to tmp/shots/pip.png. Args: page sub [skill points]. New art needs `--headless --path godot --import` first.
& $g --path godot res://tests/pip_probe.tscn -- 1 1 5 --user-dir="$env:TEMP\foe_probe"
# Animation test: ours in game (left) vs OTHER rig (right), every clip held 5 s. shot=N saves tmp/shots/anim_probe.png and quits.
& $g --path godot res://tests/anim_probe.tscn -- unit=bloat1,bloat10 --user-dir="$env:TEMP\foe_probe"
# Rig units in a real land, 3 shots to tmp/shots/rig_game_*.png.
& $g --path godot res://tests/rig_game_probe.tscn -- --land=begin "--cmd=god 1" units=bloat1,bloat10,bloat7 wait=14 --user-dir="$env:TEMP\foe_probe"
# Frame-by-frame match: ours and OTHER's runtime on the same layout, stacked into tmp/shots/frames_compare.png; crop_cmp.gd x y w h zooms one cell.
$rows="rows=fly:0,1,2,3,4,5;die:0,4,8,12,16,19"; $o="C:\Users\Командор\Downloads\foe-remains-godot-master\foe-remains-godot-master\Godot_project"
& $g --path godot res://tests/rig_frames_probe.tscn -- unit=bloodwing $rows --user-dir="$env:TEMP\foe_probe"
# Player rig: re-copy OTHER's player rig and runtime (scripts/rig/other/, stubs/ stand in for its EntityEffects etc.), then --import.
python tools/import_player_rig.py
# Room editor stills of rigged units (assets/sprites/rig_stills). Rerun after a rig changes; units=a,b for some.
& $g --path godot -s res://tests/rig_stills.gd -- --user-dir="$env:TEMP\foe_probe"
& $g --path $o -s "D:/Games/FoE Remains Port/tools/rig_compare/other_frames.gd" -- unit=bloodwing $rows
& $g --headless --path godot -s "D:/Games/FoE Remains Port/tools/rig_compare/compose_frames.gd" -- h=720
```

Filter for `SCRIPT ERROR|Parse Error|Compile Error|ERROR:`. After adding assets or `class_name` scripts, run `--headless --import` first. To compile a lazily loaded script, `load()` it from a test that starts `game.tscn`.

## Export

```
& $g --headless --path godot --export-release "Windows Desktop" "D:/Games/FoE Remains Port/build/windows/RemainsPort.exe" *> "$env:TEMP\foe_exp_win.log"
& $g --headless --path godot --export-release "Linux" "D:/Games/FoE Remains Port/build/linux/RemainsPort.x86_64" *> "$env:TEMP\foe_exp_lin.log"
```

About 10 minutes each. Copy the tester docs into both folders afterwards. The pck is not embedded (`embed_pck=false`): each folder has the executable plus `RemainsPort.pck`. The Windows and Linux pck are byte-identical (checked 2026-10-25), so one base and one patch set serve both. After a full build, copy `build/windows/RemainsPort.pck` to `build/base/RemainsPort.pck`.

Patches: testers drop them in `patches/` next to the exe; `user_dir._load_patches` mounts `patches/*.pck` in name order, each over the last. Incremental (default): `--patches` lists the base and every earlier patch, so `patch_NNN` holds only changes since the previous one and testers keep them all. Keep each shipped patch in `build/patch/`; the same file goes to Windows and Linux testers. When the stack grows or a tester falls behind, ship a full build and restart numbering.

```
$b="D:/Games/FoE Remains Port/build"
# First patch after a full build; later ones add every earlier patch to --patches.
& $g --headless --path godot --export-patch "Windows Desktop" "$b/patch/patch_001.pck" --patches "$b/base/RemainsPort.pck" *> "$env:TEMP\foe_patch.log"
```

Shipped: full build 2026-10-31 (player rig, frame clips retired; `build/base` updated). Before that: 2026-10-26 (changes in `build/BUILD_2026-10-26_CHANGES.txt`, includes the `user_dir.gd` changes). Testers delete their old `patches/` folder. Patch numbering restarts: the next patch is `patch_001` with `--patches "$b/base/RemainsPort.pck"`. Old `patch_001` (2026-10-25) is superseded. `user_dir.gd` is the autoload that mounts patches, so a patch cannot replace it.

Cumulative alternative: list only the base; then testers keep just the newest patch.

Needs a full build instead: engine upgrade, `project.godot` (settings, autoloads, input defaults), new `class_name` scripts. Known harmless warnings: "1 resources still in use at exit" (menu music); shader-sampler errors in headless runs.

## Agents

Earlier agents (ids in the parent chat `8accc6d4-eeff-4762-b997-242345332fa3`) ran partly on a fallback model. Spot-check anything they reported as "matches the original" against the AS3. Do not resume old agents; start a new one with a short prompt and the relevant document section.
