# TODO — plan to finish the port

Open work only. Finished steps go to `IMPLEMENTED.md`; play reports go to `PLAYER_FEEDBACK.md`. Work top to bottom. Each step ends with one boot check and a note in `IMPLEMENTED.md`. Severity: **block** stops a run, **wrong** plays differently from the original, **look** visible but harmless, **check** unverified.

## Phase status

| Phase | Scope | State |
|---|---|---|
| 0 | Gamepad UI, EN/RU framework, early fixes | done |
| 1 | Lands, world map, travel, saves, seamless rooms | done |
| 2 | Story, trials, alicorn form | done |
| 3 | Combat, effects, enemies | open: `pole2`, alicorn throw, flyers, held-weapon gaps |
| 4 | Vendors, crafting, stash, trade | done |
| 5 | Room flags, water, objects | open: swim visuals, animated debris, back outlines |
| 6 | Animation, sound, particles, PipBuck | open: turrets, map, hints, page fit |
| 7 | Controller and language audit | partial |
| 8 | Release build and cleanup | tester builds out; final cleanup left |
| 9 | Performance and size | partial |
| 10 | Steam release parity | not started |

## 1. Smoke-play `begin` to `surf` (block)

Nobody has played start to finish. One run: water in the four rooms, terminals, four checkpoints, save / quit / load, a vendor, a crate, SATS, a grenade, both wheels. Open play reports are in `PLAYER_FEEDBACK.md` (2026-10-25, 2026-10-26). Check on the way:

- Y on a real rune lock and on an alarm mine; prompt glyphs for R3, Share, Y.
- Object drop shadows, indoor-door `comein`, alarm / robocell `active` frames, home-stable turrets, door autoclose, teleport spark burst.
- Stage 2 fixes: lurking, auto-crouch, pet removed in `petoff` rooms, horseshoe sneak bonus, "Take all tasks", box damage saved, box caps multiplier, worn dropped weapons, world-map blink with `helpMess`, dodge, amulet beside the suit, falling crates, hold-with-progress on terminals and containers, stair reach, cursor name line, PipBuck log, dialogue press not leaking into gameplay.
- Enemy telekinesis grabbing the player (alicorn1–3, ghouls ss 2 / 7) and jumping free.
- Rebar walk-through, held enemy weapons, the new enemy animations.

## 2. Gameplay correctness (wrong)

1. **check** Protectron jet over walls; `pole` alicorns in the talisman trial and mtn (tested only on a spawned unit).
2. Bloat death parts ignore `ctrans` (unit colour tint).
3. **Raider vortex summon.** A raider placed with `emit` (`UnitRaider.as` ~409) releases that many vortices, cooldown 300 ticks, only while `kol_emit > 0` and `emit_t <= 0` (~654). Port `_vortex_left` is set only for `bossencl` (`enemy.gd` ~4607, 8 vortices, 500 ticks). Read `emit` off the room object, and use 300 ticks for plain raiders. Check: `spawn raider1` with the meta, count vortices and the gap.
4. **Overload blocks travel.** `Game.gotoLand` (~349) refuses with `nocont2` when the land is not the base and `pers.speedShtr >= 3` (hard inventory, `Pers.invMassParam` ~1785). Port `Inventory._inv_mass_param` (~666) computes it and drops it. Store it, and refuse in `Travel.goto_land` (~210). Check: `hardinv 1`, heavy items, `land surf` from rbl.
5. **Shooting a camp ally turns it hostile.** `Unit.as` ~3519 sets `priorUnit` to the bullet owner on any hit. Port `enemy.hit_by_bullet` (~1852) sets `_prior` only for a pet. A `_ground_ally` hit by the player must target the player (`_prior_target` ~2124); check melee and explosions too. Verify row V-06.
6. **Integer tick counters.** The original compares counters with `==` and `%`. The port advances many with float `delta * 30`, so a counter can skip the exact tick. Audit `enemy.gd`, `units/brain_*.gd`, `player.gd`, `land_props.gd`; list the counters in `IMPLEMENTED.md` before changing them. Keep them as integers per 30 Hz tick, or test a threshold crossing. Reference: the other port's `autoload/world.gd` tick loop.
7. **`nomed`.** While set, organ damage uses `organMult` 0.50 and fixed minimums (`Pers.as` ~1938: head 156, tors 86, legs 167, blood 113, mana 56), and the HUD hides organ status (`GUI.as` ~537). Port: `game_state.gd` ~1126, `hud.gd`. The PipBuck side is done.
8. **Enemy AI differences** (`docs/ENEMY_AI.md`, items 8–19). The room-return reset (item 7) stays omitted on purpose (`PORT_RULES.md`).
   - Speech bubbles: raiders and robots say `replic` lines (`attack`, `ear`, `find`, `vse`, `levit`, grenade, damage, death) with cooldowns (`Unit.replic`, `TextParser.repText`). Text is in `text_*.xml`. Only NPCs talk now.
   - Zebra fade: `shine` drops `vis.alpha`; below 15 they are invisible to pets, turrets and NPCs. Moving in sight or shooting raises it; infravision shows them. Port `_invis` is only the ally cast.
   - Enclave and Ranger wake allies at 2000 px (`allLink`). `ALLIED_WAKE` is declared in `enemy.gd` and never read; every raider wakes at 500.
   - Merc and Enclave `maxSpok` is 50. Port `MAX_SPOK` is 30 for everyone, so they give up sooner.
   - Hellhound: inside 400 px `look()` returns seen and skips the test; hellhounds ignore alarms. Not in the port.
   - Ranger side weapon: a rocket every 50–140 ticks, and gas with no target (`SideWeaponAttack`). Confirm it is missing, then add it.
   - Ant variant 3 breathes `antfire`. Confirm it is missing, then add it.
   - No magazine reload in the original AI. A grenadier out of ammo becomes an unarmed rammer. The port reloads for the weapon's reload time and has no rammer fallback.
   - Flying gunners hover within `stalkDist` 500. The port hovers about 70 px above the goal. Confirm, then match.
   - Re-aim chance for smart units is 0.9 in the original and 0.8 in the port. Confirm, then match.
   - Detection delay is ×0.9–1.1 on reset in the original; fixed at 100 in the port.
   - `enemyAct` has three levels (eyes only, sense, attack). The port is on or off (`GameState.enemies_think`).

## 3. Visual parity (look)

1. Turret clips (all but the pivot and `turret0` frame 0).
2. `pip` armour covers only the front half; facing left, suit art draws over the PipBuck. Fix is item 1 under 3b.
3. Held enemy weapons: recoil (`t_ret`), unit colour transform, WClub stab thrust, built-in `vweap` art for gutsy, sentinel and drones.
4. `pole2` shield-hit effect.
5. Back-wall outlines. Fix is item 3 under 3b.
6. Alicorn bullet look, the player alicorn's telekinetic throw, mana-overflow bulb.
7. Fading beams follow the horn (`weap.bulCoords`).
8. Animated debris (burning, melting, fake wall), `fx_fake` dust, electric-room flight wobble, crowbar extra wear.
9. Swim: armour on the swim clip, bubbles, water particles.
10. Weapon stand draws the stored suit on the pony.
11. Local map ladders and platforms; enemies page portraits.
12. Object hint signs saved; important-item window on vendor buys.
13. Dialogue box and info window: `lmb` icon instead of text hints.
14. Enemy animation leftovers: roller pivot (`brain_roller.gd:83`), vortex `attack` clip, ant / rat / tarakan death clips, `stab` ignored by `_frames_from_clips`.
15. PipBuck pony preview (Inventory, Armor, Menu, Load) is blurry and jitters when first shown (`pony_puppet.preview` blur 3.0, `_freeze_pers` after 0.3 s). Sharp and still from the first frame.

## 3b. From the other Godot port

The other port (`C:\Users\Командор\Downloads\foe-remains-godot-master`, below: OTHER) may be copied: the author allowed it (2026-10-28). Credit him in `LICENSING.md` and note the source file in `IMPLEMENTED.md`. Do not load its `CLAUDE.md`. Its main-menu pony, PipBuck chrome and stat icons are already in.

1. **Armour on the rig, per clip** (fixes 3.2 and the swim half of 3.9). OTHER swaps suit frames on the body bones and stores draw order per bone per clip, so far-leg armour stays under the PipBuck (`rig_base.gd` `_apply_variant`; read `OTHER/Godot_Transpilation/04_player_rig/04_0_rig_semantics/01_layering.md`). Ours draws one overlay above the body (`pony_puppet.gd` `set_armor`). Take the depth order from each `body_*` clip, including `body_plav`. Check verify row V-04.
2. **look** Customize appearance (`appearance_screen.gd`, also PipBuck page 8). The user is not happy with it (2026-10-28) and has not said what to change. Compare with the original and OTHER, then ask. Report in `PLAYER_FEEDBACK.md`.
3. **Flash filters as shaders** (tile edges, glows; also 3.5). Original filters in `Grafon.as`: Glow on `cont_th`, Bevel + Glow on `plitka`, DropShadow + Bevel on `dyrka` / `cloud`, one global drop shadow, colour-matrix presets, blur under SATS. OTHER's reference shaders are `shaders/flash/{glow,bevel,drop_shadow}_compose.gdshader`, baked per room. Ours outline front faces only (`map/tile_outline.gd`). Bake our own into the room's tile canvas. Mind weak GPUs.
4. PipBuck pages still to match against OTHER in a running game: trade, doctor, craft, vault.

### Checks to build

5. **One check runner.** `tools/run_checks.py`: each check prints `CHECK <name>: ok N fail M`; ignore the harmless lines in `HANDOFF.md`; fail on `SCRIPT ERROR`, a fail count or a timeout. Options `--only`, `--skip`, `--list`. Reference `OTHER/tools/run_suite.py`. Start with `tests/test_room_xml.gd` and `tools/test_room_codec.py`.
6. **Every-land soak.** For each land and trial chamber: `--headless --path godot res://scenes/game.tscn --quit-after N -- --user-dir=tmp/soak --land=<id>`, then `tp` through every room. Count script errors, missing textures and units that fell out. A few fixed seeds for generated lands. Reference `verify_room_runtime.tscn`.
7. **Save round trip.** Sandbox `--user-dir`, script a state (items, worn suit, quest, checkpoint, damaged crate, visited land, reputation), save, restart `--boot=slot=N`, compare `WorldState.to_save()` and each autoload's file. One save in `begin`, one in a story land, one in a generated land. Reference OTHER `verify_save_compat`.
8. **Deviation register.** `docs/DEVIATIONS.md`: one row per known difference (what, why, evidence, owner file). "Awaiting a human check" links a `verify/` row. `PORT_RULES.md` stays the source for user decisions. Reference `OTHER/Godot_Transpilation/26_integration/deviation_register.md`.

## 4. Menus and PipBuck

1. Fit status, inventory and info sub-pages inside the frame at 1200×800.
2. Main menu `butFile` and load-row hover.
3. Controls page: mouse icons in the key cells (symbol 943, frames 2–6).
4. Options that only save a value: `show_favs`, `zoom100`, `err_show`.
5. **check** Esc, Tab and pad Start in play (synthetic Esc did not trigger).
6. Status Main tooltips: `Pers.factor` lists what changed each stat (`pip_params.gd`). Needs the port to record the source of every change (perks, skills, effects, trauma, armour).
7. Status Main resistance rows: `pip_params._vulner` approximates the original. Check against `Pers.setParameters` / `armorParameters`.
8. Inventory vs PipPageInv: amulet tooltip icon (`amul_*`, OTHER `Objects/Items/amulN` composed to one PNG); row sort (`sort1/2/3/nazv`, current ammo first); `ramka` frame on the held weapon, spell and suit; new-item marks `☩` / `+` and the inactive-weapon `☩`; weapon `vis_icomult`; magazine rounds in the ammo count. `pip_info.gd` skips lines whose data the port lacks: ammo damage, pierce, armour, accuracy and wear; weapon `critCh`, `destroy`, `expl_kol`, `opt.perk`, `lvl_nouse`; armour crit and radiation resist; effect requirements, addiction, the hard-inventory weight bonus and the `#1` fill.

## 5. Controller and language (Phase 7)

1. Pad bindings for quick spells 1–4, magic attack, SATS extras, pet command; button glyph art.
2. The first pad press after keyboard only switches glyphs; it should also act.
3. EN/RU audit of every screen; story key names (`keyMagic`, `keyPunch`).
4. Sky-flight feel.

## 6. Steam parity (Phase 10)

1. Import the `rooms_plant` / `rooms_prob` changes and corrected `text_en` / `text_ru`; re-export `texture1.swf` bitmaps 1139, 1141, 1143, 1145.
2. Languages `ua`, `de`, `pl`, `es`, `jp`, `zh`, `tw`: text import, `lang.xml`, settings and main-menu picker, CJK font fallback, UI fit.
3. DLC 1.0.4 rebalance as a mode: data overrides, the 13 code changes, a new-game switch, saves tagged with the mode. Ask about the odd values first (`KNOWLEDGE_BASE.md`).
4. Compare `pfeUI.swf` UI art against `pfe.swf`.

## 7. Second smoke-play

A full run to an ending, controller only, in the base game; then a shorter run in the DLC mode.

## 8. Performance and size (Phase 9)

Goal: playable on a weak GPU (tester: parts of the map draw as plain colour). Music is 174 MB. Done work is in `IMPLEMENTED.md` "Performance".

1. Left per 30 Hz step in `perf_arena`: enemies ~4.9 ms (up to ~78 awake), crate batch ~2.4 ms, `stair_slope` ~1.2 ms; merging static colliders per room is untried; `aim_cursor._foe_tracking` walks every enemy each frame; chase (`pursue` + `_aim`) ~1 ms per alert unit. Judge 30 Hz feel with `physhz`.
2. FPS, frame time and memory in the debug console. Profile heavy rooms and `enemy.gd`, `bullet.gd`, `held_weapon.gd`. Harness: set `WorldState.run_seed`, erase the land's builds, time each node's process grouped by script; `perf_arena` with `GameState.god`, player at spawn + (rx × 1920, ry × 1000).
3. Build size: BPTC made builds ~1.5 GB. Basis Universal for big art if download size matters (user to decide).
4. Trim and repack sprite sheets; keep anchors, `_sheet_offset` and wPos tables.
5. Watch for a first-sight hitch on rare objects with load on demand.
6. Lossy WebP on disk for big opaque art.
7. Music re-encode check (OGG Vorbis).

## 9. Final release (Phase 8)

1. Remove `controls_ui.gd` and the pause panel in `pause_menu.gd` (no longer shown).
2. Resources-in-use warning at exit (menu music), harmless.
3. Empty `_trash/` after the user checks it. Delete user-data probe files and `saves\slot9`.
4. Export Windows and Linux, smoke-test both, update `build/TESTER_GUIDE.md`. Ship `LICENSE`, `LICENSING.md`, `ADDITIONAL_PERMISSIONS.md`, `THIRD_PARTY_NOTICES.md` in both folders.

## 10. After the port (not started)

### 10.1 Seamless random lands

Generated lands grow as one chain: the next level attaches at the right exit of the between room instead of replacing the land. Needs a `PORT_RULES.md` entry when started.

1. Keep every level's seed and frozen inputs (`WorldState.build_value`) instead of `forget_land`, plus per-room changes, in a compact save.
2. `play_land._build` builds the whole level at once. Split into chunks that load near the player and unload far away, rebuilt from seed. Load around a set of positions (`PORT_RULES.md` "Future multiplayer").
3. Open the edge wall, match door slots across the joint, align levels of different heights.
4. Difficulty by distance (user, 2026-10-26): the chunk's distance replaces `landStage` everywhere it is read (enemy type, loot, trials, plant height, `exit_plant`). No `upland`. Decide the chunk size and the curve. Whether `exit_*` rooms stay as rest stops is open. Stage-bound story events fire at distance thresholds. Check every reader of `landStage`.
5. Fog memory, PipBuck map, back and trial rows, checkpoints, respawn, terminal round trip.

### 10.2 Online co-op

P2P via Steam. Rules: `PORT_RULES.md` "Future multiplayer". Plan: `docs/MULTIPLAYER_PLAN.md` (steps 1–8 keep single player unchanged; 9–14 are the mode).

### 10.3 Trial definitions in the editor

Deferred (user, 2026-10-27). Rooms in `rooms_prob` are editable, but a trial's `<prob>` and `<con>` live on the land (`lands.json`), so a new trial room cannot join a land and Play room runs it without trial rules. Needs `mods/lands/`. Recorded in `IMPLEMENTED.md`.

### 10.4 Local LLM room assistant (dev-only)

User, 2026-10-28. A local model (Ollama or LM Studio, localhost only, a 14B–32B coder model, JSON schema) edits a room through editor commands. Raw 48×25 grids come out broken.

1. Editor menu entry, `HTTPRequest` to localhost, dev switch, out of tester builds. 1–2 days.
2. Commands (fill rect, platform, ladder, door, place object) run through the editor's own edits, so undo and Check work. 3–5 days.
3. Reachability: walk, jump and climb from the entry to every exit. Useful for hand-made rooms too. 2–4 days.
4. Apply, Check, send problems back, retry; the user accepts or undoes.
5. Examples from shipped rooms. One room first; map assembly through `land_gen` later.

Test with `tests/test_editor_validate.gd`, the play probe, and the reachability check.
