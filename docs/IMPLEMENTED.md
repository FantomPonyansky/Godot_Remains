# Implemented — what is in the port

Key points and where to look. For how the original works, see `KNOWLEDGE_BASE.md`; for deliberate differences, `PORT_RULES.md`. Scripts are under `godot/scripts` unless a path says otherwise.

## Autoloads

- Language / UI: `Locale` (`t`, `tf`, `set_language`, `language_changed`), `OriginalLines`, `UiNav` (`add_screen(root, {default, back, tabs, page})`), `Prompts`, `InputBindings`, `UiSettings`, `PadGestures` (tap vs hold).
- World: `Travel` (`open_land`, `goto_land`, `pass_land`, checkpoints, death, hardcore, load screen), `WorldState` (`register(id, get, set)`, save format 2), `ScriptsEngine`, `Story`.
- Systems: `Effects`, `CamShake`, `Pets`, `Favorites`, `AudioManager`, `Progression`, `GameState` (difficulty table, `t_battle`, `paused`), `Inventory`, `MagicBinds`, `Stash`, `Vendors`, `Autopick`.
- Rooms: `RoomBounds` (`room_changed`, `is_active`, `room_of`).

Text: original lines in `assets/data/text_en.xml` / `text_ru.xml`; port strings in `assets/data/port_strings.json` (`{key: {en, ru}}`).

## World (Phases 1, 5)

- All 29 lands, fully seamless rooms, world map, travel, checkpoints, death and respawn, world save v2, 2021 save migration. New-game options `propusk`, hardcore + slot, `fastxp`, `rndpump`, `hardskills`, `hardinv`.
- Fog (`fog.gd`, `fog_sight.gd`): live layer plus memory layer (`MEM_LEVEL` 0.4, `MEM_SATURATION` 0.55), ghosts under `Actors/FogGhosts`; camp mode via `LandFog.camp`.
- Room flags from `Editor.txt` (`RoomFlags`): bezdna, nomap, levitoff, portoff, desoff, base, dark / color / vis / lon, radiation, electric field (`elpanel`), lifts, teleports, moving platforms, keyloss (only documented in Editor.txt: no original Interact.as reads it and no room sets it, so `lock_use.gd` handling never runs), generator. Room colour filters feather 120 px (`room_look._tint`, `room_tint.gdshader`).
- Land backdrops (`fon`): `map/land_fon.gd` + `land_fon.gdshader`, art `assets/sprites/fon/` (`tools/swf_export/export_fon.py`). One world node at z −40 over the view; a per-room cell texture carries the gap darkness (0 in sky / transpfon rooms) and undoes the room colour filter (colorfon instead). Back holes use the same shader (`hole_mat`). Replaces the old flat `BackWall` rect / sky colour in `play_land` (not `begin_land`, whose fon is fonDefault black). World position in the shader comes from screen UV and the canvas transform (`view_*` uniforms, set each frame). The old placeholder parallax `surroundings.gd` is hidden.
- Water: per-tile mask, drains through broken walls (`map/water_flow.gd`, saved as land memory "water"), splashes, floating boxes, swim tilt, bullets in water (`bullet._water_check`).
- Checkpoints from room data (`Travel._rebind_cp`, `checkpoint.activate(restored)`). On `begin`: room_2_1, room_3_2, room_2_3, room_2_0 (`begCP`, story-activated).
- Terminals: `assets/sprites/props/term*.png` + `term_anchors.json`.
- Stairs `stair_slope._feet_under`; ladders beside walls use a 28 px climb box (`player.gd` `CLIMB_BOX_W`, `_snap_to_rail`, `_box_fits`). Units match Unit.checkStairs / UnitRaider.mostLaz (`enemy.gd` `_try_stairs`, `_hold_rail`, `_end_climb`): stay only while the tile at the feet is a stair and not solid, snap X to the rail, 28 px box, platforms off while hanging, `t_laz` / `aiLaz` wait before a new grab so the 36 px lip does not re-grab. Get off at the top, bottom, or a closed hatch; an open hatch is a stair tile and they climb through.
- Tile outlines: `map/tile_outline.gd` + `tile_outline.gdshader`, masks from `tools/swf_export/export_tile_masks.py`; cached per land (meta `ol_state`, `_Outline.use`). ~0.5 s per land load.
- Spawn triggers (`allact="spawn"`) with saved counts and `emerge_glow.gd`.
- Generated lands (`map/land_gen.gd`, `land_spawn.gd`, `play_land.gd`): a new Land (map travel, next level) gets a new seed (`WorldState.forget_land`); the same Land rebuilt (terminal round trip, save) uses its stored seed, level and frozen inputs (`WorldState.build_value`: stage, visited, mbase_visited, passed trials), so rows and memory match. Plant height 3 only at landStage 0; entrance rows only before the first visit. Enemy type uses landDifLevel (player level − 1 vs act dif) + row depth; trials skip passed ones (`prob_<id>`). Back rooms take the front cell's mirror, ramka and water. Container loot reads the player's room (`loot_ctx` meta: locDifLevel, weaponLevel, biom, gameStage, lootLimit) in `loot_roll._from_room`. Land `exit` with `prob` (`exit_plant` / `exit_plant1`) is `gotoProb` on this land; the authored `exit` in that room is `gotoNextLevel` (`land_props._spawn_passage` / `_go_through`, Interact.allAct order).
- Terminal round trip on a generated land: `Travel` keeps the last checkpoint's name and spot (`cp_name`, `cp_pos` in the land act), puts the player there and re-binds it when its room spawns; the start checkpoint does not re-open itself on a rebuild.
- Back rooms and trial rooms (`map/back_room.gd`): camera limits clamp to the room (zoomed in only if the view is larger), everything outside is masked black. `player_camera._hold_in_limits` keeps the camera centre inside its limits. They sit in rows under the map (`play_land._layout`: `back_band`, `trial_row` metas); `room_bounds.is_active` runs a back room with only its front room, and a trial room alone.
- Battle timer `GameState.t_battle`.
- Camps: base containers show no tip (`hud._base_container`), NPC use boxes, `land_props._spawn_row_kind` honours `fraction="100"`, `enemy._ground_ally` for player-side raiders.

## Story (Phase 2)

Dialogues, script commands, cutscenes (`scene` pauses the land; dialogs only take control via `Travel.set_control` → `player.set_control_off`), trials (waves, countdown, doors, prize boxes), player alicorn form, intro story screen (`intro_screen.gd`), weapon favourites (`Favorites`). Story NPCs (`npc.gd`): script `fly` cells are room-local (`_room_origin`); `UnitNPC` aiTip `agro` shoots units of another fraction in the room with the npc's `weap` (busy = no talk), then sinks and lands (surf Calamity). Enemies lose the player while `control_off` (`Unit.findCel` skips invulner).

## Combat and effects (Phase 3)

- Status effects and traps; trap art; bear traps liftable. Rebar / spike traps: `land_props._trap_touch` (Trap.attKorp).
- SATS: pause, hit labels, queue, undo, perks. Knockback, grenades (bounce, `bumc`, `lip`, radio `x37`), wall debris chunks.
- Perks tested: fastreload, oak, rungun, fortune, friendly, grenader, security, spell_port.
- Player hooks in `player.gd`: hoof vs `trap_units`, crowbar `break_crate`, vote, shadow / rat forms, flight potion, holster. Worn suit / amulet damage multipliers in `_amount`; `Progression.throw_force`.
- Dodge: `Progression.player_dexter`, `player.dexter_now` / `dodge_roll`, `assets/data/armor_dexter.json`. Amulet slot `Inventory.amulet`.
- Lurk `player._tick_lurk` / `_try_lurk`; auto-crouch `_auto_sit`. `_lurk_layer` flattens the puppet parts onto the body's z (`pony_puppet.set_flat_layers`) so the raised box covers the horn, eye and PipBuck. The puppet plays `lurkN` to label `un` and holds there; unlurk plays `unlurkN` (un..end). Hair, eye, horn and helm take the clip's per-frame dim (`pony_puppet._LURK_DIM`, from the swf colour transforms). Layer (`_lurk_layer`): lurk 1 in a box puts the pony at z −4 (a hiding-spot niche −9); lurk 2/3 keep the pony at 0 and raise the box to z 4, restored on exit. Stealth: `enemy._add_obs` subtracts sneakLurk (2.5 + 0.5 × sneak level) × `player.lurk_cut()` (1 lurked, 0.2 sitting), as in UnitPlayer.observation.
- Spells: `fx_clip.gd` (inh, shield, crystal), `MagicAura` blood shield, `magic_barrier`, `blast` / `gwall` / `slow` parts. Beams in `bullet.gd` (`_finish_flight`).
- Levitation glow: `MagicAura.attach(host, color)`, `player._tick_levit_glow`, meta `levit_by`.
- Enemy telekinesis: `units/unit_telekinesis.gd` (only grab path); `enemy._setup_tele` / `_tick_tele`; player `_tick_held`, `_tick_throw_wall`. Held struggle clip via `_lev_anim` (`brain.animate` / class). `_steer_tele` is Telekinesis.hold only (teleAccel toward the cursor); struggle does not add to carry velocity.
- Blood on hit (`enemy._blood_fx`, `player._blood_fx`), robot stun `discharge`, acid melee `buma`.

## Enemies

- `enemy.gd` plus brains in `scripts/units/brain_*.gd` (`UnitBrain` base).
- Held weapons: `units/held_weapon.gd` (child `HeldWeapon` of raider-type units) with `WeaponVis`; points from `assets/data/unit_wpos.json` (`tools/swf_export/export_unit_wpos.py`); griffon arms `assets/sprites/units/grif_arm/` (`export_grif_arm.py`). Bullets leave `HeldWeapon.muzzle()`.
- Class animators: `enemy._present_class` with `_anim_class_of` (pony, hellhound, zombie, eqd, encl, merc, ant, monstrik); `_corpse_anim`; zombie revive in the downed branch; stunned units show `stay`.
- Flyers: `enemy._tick_flyer` (Enclave, mercs and alicorns take off and land; a calm alicorn lands on touch, UnitAlicorn aiState 4). Protectrons are walkers with a jet (`enemy._jet`, UnitProtect.jump: jump_n 90 / hero 500, lifts jumpdy / 4 a tick while pushing into a wall).
- Ground loot `auto` (Loot.auto): autopick only takes LootGen drops; items the player drops are not auto.
- Bloatsprites: `brain_bloat.gd`, `brain_emitter.gd` (`ebloat` nests), `enemy._bloat_split`; art `tools/swf_export/export_bloat.py`. Death parts `fx_shmatok` / `fx_bloat_kap` (`export_fx.py`, `UnitFx` param `frame`): UnitBloat.expl shmatok ×4 frame 2 + bloat_kap ×4–6, nest shmatok / schep ×16 frame 2. bloat6 cling drops on knockback (`UnitBrain.on_knock`); bloat7–9 add no kill count. Parts ignore `ctrans`.
- Pole alicorns (UnitAlicorn.pole): `enemy._pole_hold` / `_pole_release`, meta `pole` from room attrs. Still, no reaction, 'unlock' sparks every 5 ticks; under 70% hp or on death `all_act` unlock + open on its allid.
- Knops: press and shot (`actdam` / `take_hit`) both run `_on_button` → `all_act` and the knop's `scr` steps. begin (2,1) knop2 has no `allact`; it `unlock`s door3 `trMDoor`. Charges in a blast `take_hit` and chain (every land). One-tile floor boxes are not shelves. Trial/boss doors show `text map` title.
- Blast disk: walls via `apply_blast` (physics gather plus every `destructibles` span). `explcrack` safes and crowbar-eligible crates take `damage_box` / `break_crate` (`land_props.blast_boxes`).
- `rbl` and `src` turrets shoot hostiles; rangers fire only once hit (Unit.findCel priorUnit), as in the original.
- Turret pivot fix in `unit_brain.make_part`; levitated fixed turret shake in `brain_turret.gd`.

## Economy (Phase 4)

Vendors, doctors, crafting, vault, weapon stand (`^1` cycle, armour stored), reputation, hardinv, pickup repair and `^1` upgrade, PipBuck right-click / pad X rules, trade and inventory filters (`assets/ui/trol/`), auto-pickup switches (`Autopick.wants`, `ground_loot.try_autopick`).

## Presentation (Phase 6)

- Camera: `player_camera.gd` on `Player/Camera2D` (top_level, own follow): free zone radius view_h / 6, catch-up 4 × overshoot per second, hard limit 0.4 view_h, snaps on a jump over 400 px. Look-ahead and showOn still use `offset`.

- Player puppet `pony_puppet.gd`: death / res / lurk clips, edge poses (`_overhang`, `_edge_frame`), PipBuck upper layer (`_place_upper`, `export_body_clips.py --upper`), armour overlay `clips/<clip>/<id>/` (lazy `_worn_frames` / `_worn_tex` caches), helmets `_place_helm` (`export_helms.py`), held-gun snap after teleports, HD preview `PonyPuppet.preview`.
- Sounds: 126 added (`sound.swf` 100/107, `sound_unit.swf` 67/70, `sound_weapon.swf` 52/68). Weapon sounds from `weapons.json` `sound` / `snd_prep`.
- Particles: gas, steam, bubbles, sparks, red ray, magic symbol, explosions, snow, zzz, unlock, plasma cap, disintegration, `sign1`; fx sheets via `tools/swf_export/export_fx.py` + `tools/pack_units.gd`.
- Hints: 84 menu tips, important-item window, object hint signs.
- Cursors: `aim_cursor.gd` (arrow on layer 128 while paused; target / target1 / target2), art `assets/ui/cursor/`.
- Loading screen `travel.show_load_screen` (`assets/ui/loading/N.png`, `export_loading.py`).
- Main menu: `main_menu.gd` on a 1920×1080 `Stage`, art `assets/ui/menu/art/` (`export_menu_art.py`), animation `menu_displ.gd` (`export_menu_anim.py` + `tools/pack_menu_anim.gd`, shaders `menu_screen_*`, `menu_overlay`, `menu_displace`).
- Appearance window `appearance_screen.gd` (dialVid), also PipBuck page 8.
- PipBuck `pipbuck.gd`: frame `_fit`, art `assets/ui/pip/` (`export_pip_art.py`), pages status, inventory, info (local map, quests, world map, notes, enemies), menu (options `_fill_options`, log, controls `_kb_edit`, auto-pickup `_opt_auto`), help box.
- UI smoothing `UiNav._smooth_ui`; mouse wheel and right-stick cursor in `UiNav`.
- Object art: 0 placeholders. `map/obj_art.gd`, `assets/sprites/objects/`; pipeline `tools/swf_export/export_objects.py` → `tools/pack_objects.gd` → `export_objects.py finish`.

## Controller (Phase 7, partial)

`input_bindings.gd` (layout version 8), `pad_gestures.gd` (PAIRS, `_sprint_tap` dash), `quick_keys.gd` (use item, heal, mana, armour ability, crack `crack_ready` / `_need_runa`, look, zoom, fullscreen), `weapon_wheel.gd`. Alarm-trap crack: `land_props.trip_alarm`.
Aim assist (`aim_cursor.gd`): no lock; near a target the cursor slows (`assist_slow`, default 25%) and, only while the stick moves, is nudged toward it (`assist_pull`, default 100% = `ASSIST_NUDGE` 3). Both are sliders under the toggle in Controls and the PipBuck options page.

## Builds (Phase 8, partial)

- Export presets `Windows Desktop` and `Linux` (pck embedded, release templates 4.7.2 in `%APPDATA%\Godot\export_templates\4.7.2.stable`). Excludes: `*.py *.md *.txt`, `tools/*`, three unused `assets/extracted` subfolders, `tests/*`, `tmp_tests/*`, `_tmp*`, dev scenes. Main-menu dev buttons need `OS.is_debug_build()` and the scene file.
- User data (`user_dir.gd`, first autoload): an exported build writes `settings/`, `saves/` (run files + `slotN/`) and `logs/` (own Logger, 30 kept, flushed per line) next to the executable; first run copies an older AppData install. Editor binary (the launcher .bat, tests) keeps `user://` unless `--user-local`; `--user-appdata` or a read-only folder forces `user://`. Godot's own log still goes to AppData too.
- Tester docs: `build/TESTER_GUIDE.md`, `build/TESTER_IDS.md` (`tools/make_tester_ids.py`). Console: `godot/DEBUG_COMMANDS.md`. `tp x y` is a room; `trial` / `boss` jump to chambers; `god` keeps HP, magic and mana.

## Performance (Phase 9, partial)

- A land you leave is freed (`game.enter_land`, not the stable); WorldState rebuilds it from seed and snapshot.
- Load on demand (`art_cache.gd`; setting `foe/art/load_on_demand` default on, console `artcache`, flags `--art-on-demand` / `--art-preload`): `game.enter_land` empties the land art caches (enemy sheets, obj_art, back_decor, door_art, checkpoint, wall_span, npc_vis, room_file, tile_outline) and enemy sheets load synchronously during the build (worker-thread `ResourceLoader.load` kept every sheet alive). Begin → 5 lands → begin: 160 MB texture memory (316 off); peak 267 (359 off). Player, weapon, projectile, fx, loot and UI caches stay.
- `map/tile_canvas.gd`: tile patch and lip slices of one room / z draw from one node (`Tiles_x_y_z`, group `room_hide`) instead of a Sprite2D each (play_land and begin_land `_add_slice`).
- `map/room_activity.gd` (child of every land): hides `room_hide` nodes outside camera + one room; `near(tree, group)` is the Camera2D view + 600 px, cached 200 ms (`player._pick_aimed`, `aim_cursor`, HUD tips). HUD names the aimed object at any range (`setCelObj`); use/tele lines stay at 200 px. Units, loot and crates sleep in `room_bounds.gd` (player ± 1 room); frozen crates are also out of the physics space (process_mode disabled).
- Physics runs at 30 Hz (the original's logic rate; player gravity 900 / jump -360 are its 1 and 12 per tick) with physics interpolation on and at most 4 steps per frame (`project.godot` [physics]). Interpolation is off for nodes posed in `_process`: `held_weapon`, HUD, aim cursor, fog. Teleports call `reset_physics_interpolation()` (game.place_player, land_props portal, area_fx port, WorldState resume). Console `physhz [30|60] [interp 0|1]` compares at runtime.
- Dev stress land `perf_arena` (`tools/make_perf_arena.py` → `rooms_perf_arena.json`, excluded from exports, registered by `land_registry` in debug builds only): 12 busiest rooms_mane rooms in a 4 × 3 grid, a different enemy_type per room, extra units, stacked crates, side walkways at rows 19–22. ~100 enemies, ~240 crates. Console `arena` (heal + `god` + travel); `god` blocks all player damage and radiation (`GameState.god`). Arena at 30 Hz: 16–20 ms per room (60 Hz: 17–73 ms, one room 150).
- Enemies: `_commit_move` skips `move_and_slide` for a still unit on a static floor (not a crate or AnimatableBody2D, no platform velocity) or a `fixed` unit, with a real move every `REST_RECHECK` (8) calls, except while `throu` (a shelf drop must slide); `UnitBrain.check_water` skips the env lookup while the unit stays in a dry room; `_player_goal` returns the player directly in the same room and redoes the cross-room opening search (rays) every `GOAL_EVERY` (5) ticks. UnitRaider `throu = moving && celDY > 80` (`enemy.gd` `_refresh_throu` / `_apply_throu`): celDY is setCel's `celY - Y + scY`; patrol (no target) does not drop.
- `held_prop` batch skips frozen crates before sorting; `held_weapon` keeps its pose while its host sleeps; `trial._room_nodes` cached by prop count.
- `tools/set_texture_compression.py` sets `compress/mode=2` and `compress/high_quality=true` (desktop BPTC) on large art: `fon*`, tiles, room backs, portraits, unit/object sheets, pony frames, menu and loading pictures. Mipmaps stay off except `assets/ui/menu/art/495.png`. Lossless: PipBuck skin and pages, HUD icons, cursor, trade and message icons, the title logo, the world map, tile masks (`tile_outline.gd` reads alpha), loot icons (`ground_loot.gd` calls `get_image()`), tile/env images that are not a multiple of 4 (a 10 px floor strip), pony frames and parts (`assets/sprites/pony/`: compressed, the player's clips jittered), and anything 32 px or smaller. Begin texture memory 97 MB (was 223), random_mane 193 MB (was about 500–580).

## Gotchas

- `tools/build_enemies.py` can overwrite the hand-edited bloat rows in `enemies.json`.
- Rerunning `export_projectiles.py` drops the hand-added `visbulmray_2/3.png`; its `_export_polz` helper is missing, as is `export_units.py`'s pyc.
- Threaded texture preload stalled the main thread for seconds; do not use it.
- Port enemy states ST_DASH 7 / ST_DASH_PREP 8 are swapped against AS3 aiState 8 / 7.
- A doc comment in `player._sky_step` may still say walk × 3; the code is × 1.3.
- Wide fx art (past 300 px) needs a WIDE box in the packer or the origin marker is not found.
- `brain_boss_alicorn.gd` uses `held_body` (clashed with `UnitBrain.held()`).
- Freed lands leave freed objects in Variant fields: test `is_instance_valid(x)` before `x is Node` (that order errors on a freed instance).
- Land rooms sit at world `(gx * 1920, gy * 1000)` with `gy` from the land grid, not the file's room name (surf `room_10_1` is at y 0).
- `BackBufferCopy` rect mode partly off screen leaves stale buffer: room tints use one viewport copy.
- Scripts are CRLF: deleting a whole line with an edit that starts at `\n` can glue the next line onto the previous one.
