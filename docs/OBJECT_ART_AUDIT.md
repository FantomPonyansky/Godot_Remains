# World object art audit

Scope: every object placed by the room XMLs (`original\release_2021/FoE - Remains/Rooms/*.xml` plus the imported 2021 plant/sewer rooms, 33 files), every `<obj>` in AllData `objs.xml` (202 defs, 198 placed; checkpoint2–5 never placed), every `<back>` id (172 placed), the xp bonus and trap visuals, and unit stand-ins.

Method: a temp runner entered every `Travel.lands` land (random lands built once), forced every pending room to spawn, and classified each spawned node under `land_props` and `Doors` as art (a textured Sprite2D / AnimatedSprite2D) or placeholder (untextured Polygon2D / ColorRect quad / label). Invisible logic nodes (areas, room bounds, trials, spawn markers) are listed separately.

Skipped on purpose: `term`, `term1`, `term2`, `term3`, `termh` and the begin-land checkpoints (handled by the environment agent).

## Totals

| | Before | After |
|---|---|---|
| Spawned nodes scanned (random lands vary per run) | 13 663 | 13 835 |
| Drawn with original art | 10 303 | 13 561 |
| Placeholders | 3 078 | 0 |
| Back ids placed in rooms but not in `backs.json` (not drawn) | 22 | 0 |

## Coverage by object family

| Family | Before (placeholder count, ids) | Art source now | How the port draws it |
|---|---|---|---|
| Enemies, NPCs, pets | art | `sheets/units`, npc sheets | unchanged |
| Crates / containers (woodbox, box, mcrate1–5, bigbox, medbox, lockers, safes…) | art | `props/<id>.png` | unchanged |
| The 19 earlier doors (door1…platform1, indoor1–4 as doors) | art | `sprites/doors/` | unchanged |
| Checkpoints, terminals, platforms, trap units, lasers | art | earlier exports | unchanged (term*/checkpoints not touched) |
| Doors alib1, alib2, basedoor, encldoor, enclpole, stdoor | 273 grey panels (stdoor 115, basedoor 71, encldoor 54, enclpole 27, alib1 4, alib2 2) | texture1 `vis<id>`, frames close / open / die | `door_art.gd` SPEC + `ObjArt` frames by label; hp/thre from objs.xml |
| Furniture: aaa, barst, bed, brspr, camp, couch, longtable, moln1, niche1, radbarrel, radbigbarrel, reactor, smotr, table1, table2, table4, tomb | 666 grey boxes | texture1 `vis<id>` (aaa 2 frames, moln1 8 with close/open/moln) | `land_object.gd` sprite at the Box origin (bottom centre); moln1 frames driven by the other agent's `moln_trap.gd` |
| Stations: himlab, p_luna, stand, stove, table3, vault, wmap, work | 151 grey boxes | texture1 `vis<id>` | `land_object.gd` |
| Transitions: door_st1/2, doorboss, doorout, doorprob, exit, inbasedoor, indoor1–4, inencldoor, instdoor | 412 grey boxes | texture1 `vis<id>` (in* 11–20 frames, `comein` label) | `land_object.gd`, closed frame |
| Gas clouds pcloud1, tcloud1 | 101 grey boxes | texture1 `vis<id>` | `land_object.gd` |
| Levitating boxes couch, radbarrel, work | 7 brown polygons | texture1 `vis<id>` | `held_prop.gd` sprite, new `art_at` meta for the clip offset |
| robocell | 8 untextured bodies | texture1 `visrobocell` (close / open / active) | `_spawn_loot` via `_prop_png` fallback; opened frame on loot |
| Buttons alarm, detonator, dsph, elpanel, knop1–4 | 236 red quads | texture1 `vis<id>` (knop 15 frames, close/open) | `_button_art` fallback; open/close frame follows the toggle and autoclose |
| Begin medbox button | 1 red quad | `props/medbox.png` | bottom-centred when it has no `term_anchors.json` entry |
| Begin hazards expl1 ×3, trap ×2 | 5 brown quads | `sheets/traps` damexpl1, mtrap | `_spawn_hazards` |
| Spikes / ceiling spikes | 349 grey quads | pfe `vistrapspikes(2)`, `vistrapfspikes(2)`, random frame each | `_spawn_traps`, back layer z −1, `*2` layer in front z 2 |
| XP bonus | 849 green diamonds | pfe `visualBonus`, 20 frames | `_spawn_bonus` frame 1; frames 2–20 play on pickup (`gotoAndPlay(2)`) |
| Home-stable turrets (turret, hturret, wturret, landturret, armturret, enc1→turret0) and sentinel | 20 grey boxes | unit sheet stay frame + part frame 0 | `land_object.gd` still (they stay non-live: player fraction AI is not ported) |
| Backs bio, vpipes, metal, vpipe, vpipel, vpiper, barf, illum, bannerl, vitrina, minst, stbanner, opora, h109, bar (t + l), qgraff, snar, orudie | not drawn | texture1 `back_<id>_t/_l` | new `backs.json` kinds |
| Backs lyellow, lacid, lcyan, lpurple (+ lwhite) | not drawn | existing `back_lcolor_l` frames | new `backs.json` kinds with `tid lcolor` |
| Spawn markers (tip `up`: enl1, enl2, enf1, enc1, lov), enspawn, spawnpoint | no visual in the original either | — | invisible |
| Areas | 187–192 invisible, 36 with art | — | invisible by design (Area.as has no vis) |

## What still differs from the original

- Box drop shadow (`shad` filter) is not drawn under the new object sprites.
- `comein` (indoor transitions), `active` (alarm, robocell) and `die` frames are exported and in the manifest, but nothing triggers them yet: those behaviours are not ported.
- The home-stable turrets/sentinel are stills; the live player-fraction turrets are not spawned.
- Everything else placed by the rooms now draws original art.

## Files

- Export: `tools/swf_export/export_objects.py` (trimmed swf per batch, marker origin; `finish` writes the manifest and back kinds), `godot/tools/pack_objects.gd` (crop + offsets).
- Art: `godot/assets/sprites/objects/<id>/<frame>.png` + `manifest.json` (61 clips, 267 frames); `godot/assets/sprites/backs/back_<id>_<t|l>/`.
- Code: `scripts/map/obj_art.gd` (new), `door_art.gd`, `map/land_object.gd`, `held_prop.gd`, `land_props.gd` (traps, hazards, loot fallback, buttons, bonus).
- Screens: `_trash/_shots/objart_*.png` (not kept).
