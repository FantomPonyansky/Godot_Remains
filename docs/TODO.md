# TODO — plan to finish the port

Open work only. Finished steps go to `IMPLEMENTED.md`; play reports go to `PLAYER_FEEDBACK.md`. Work the phases in the order of the table. Each step ends with one boot check and a note in `IMPLEMENTED.md`. Severity: **block** stops a run, **wrong** plays differently from the original, **look** visible but harmless, **check** unverified.

## Order (re-evaluated 2026-10-31)

| # | Phase | Sections | Why this order |
|---|---|---|---|
| A | Correctness and save gaps | §1 | Changes combat, travel and saves; everything later is judged on top of it. |
| B | Visual gaps | §3, §3a, §3b | Rig import is in; these are the remaining look differences. |
| C | Menus and PipBuck | §4 | Testers live on these screens. |
| D | Controller, then EN/RU | §5 | Bindings are decided in `PORT_RULES.md`; this is the audit pass. |
| E | Checks, then smoke play | §6, §2 | One check runner before a full playthrough. |
| F | Performance and size | §8 | Profile after behaviour stops moving. |
| G | Steam parity, second smoke | §9, §10 | Text, languages, DLC mode, then a full run. |
| H | Final release | §11 | Cleanup and ship. §12 waits until the port is done. |

Done phases (gamepad UI, lands, world map, saves, story, vendors, crafting, rig import) are in `IMPLEMENTED.md`.

### Decisions to confirm with the user

- None open.

## 1. Correctness (wrong)

1. **check** Protectron jet over walls; `pole` alicorns in the talisman trial and mtn (tested only on a spawned unit). `pole2` shield hit is in (`unit_fx.gd`); check it in a window.
2. Bloat death parts ignore `ctrans` (unit colour tint).
3. **Raider vortex cooldown.** `emit` from the room object already sets `_vortex_left` (`land_props.gd`). Left: plain raiders use 300 ticks (`UnitRaider.as` ~654); the port uses 500 for everyone (`enemy.gd` `_vortex_*`), and boss setup still forces 8.
4. **Overload blocks travel.** `Game.gotoLand` (~349) refuses with `nocont2` when the land is not the base and `pers.speedShtr >= 3` (hard inventory, `Pers.invMassParam` ~1785). Port `Inventory._inv_mass_param` zeros speed but travel ignores it; `Travel.goto_land` `nocont` is `GameState.dopusk()` only. Check: `hardinv 1`, heavy items, `land surf` from rbl.
5. **Shooting a camp ally turns it hostile.** `Unit.as` ~3519 sets `priorUnit` to the bullet owner on any hit. Port `enemy.hit_by_bullet` sets `_prior` only for a pet. A `_ground_ally` hit by the player must target the player (`_prior_target`); check melee and explosions too. Verify row V-06.
6. **Integer tick counters.** The original compares counters with `==` and `%`. The port advances many with float `delta * 30`, so a counter can skip the exact tick. Audit `enemy.gd`, `units/brain_*.gd`, `player.gd`, `land_props.gd`; list the counters in `IMPLEMENTED.md` before changing them. Reference: the other port's `autoload/world.gd` tick loop.
7. **`nomed`.** While set, organ damage uses `organMult` 0.50 and fixed minimums (`Pers.as` ~1938: head 156, tors 86, legs 167, blood 113, mana 56), and the HUD hides organ status (`GUI.as` ~537). Port: `game_state.gd`, `hud.gd`. The PipBuck side is done.
8. **Enemy AI differences**: the list is `docs/ENEMY_AI.md` items 8–19 (speech bubbles, zebra fade, `allLink` 2000 px wake for Enclave/Ranger, `maxSpok` 50, hellhound sight, ranger side weapon, ant fire, no-reload rammer, flyer `stalkDist`, re-aim 0.9, detection jitter, three `enemyAct` levels). The room-return reset stays omitted (`PORT_RULES.md`).
9. **Save gaps** (audit 2026-10-31):
   - Pets: `pets.cfg` is not in `save_slots.gd` `RUN_FILES` and `Pets._load` is not called on slot load, so a load keeps the pet state of the current run.
   - Vendors: stock `kol`/`sost` is saved, `money` is not; `_make` rerolls it on load.
   - `GameState.score` (land refill progress in `vendors.gd`) and `_land_xp` are not saved; check whether `ammo` should be.
   - Provider blobs in `WorldState` (effects, story, vendors, travel) carry no version key.
10. **Autoload order.** `Progression._load` calls `max_health()`, which calls `Effects.stat`, but `Effects` is added after `Progression` (`project.godot` [autoload]). Defer that call or move `Effects` up, then check the first-boot HP.
11. **Contact knockback.** The hurtbox knows the touching body, but `player.take_hit` drops it and `_contact_knock` scans enemies within 160 px; two foes close together can knock the wrong way.
12. **Script travel on the load screen.** `Travel.goto_land` during `_loading` returns without storing the land id, so a script-driven travel then is dropped.
13. **Unwired HUD.** `hud.gd` draws a boss HP bar, AP label, hook progress and item line, but nothing calls `set_boss_hp`, `set_ap`, `set_action_progress`, `set_item_line`, `show_subtitle`. Wire them where the original shows them (boss fights, SATS AP, hold-to-use) or drop the draw code.

## 2. Smoke-play `begin` to `surf` (block)

Nobody has played start to finish. Do after §6.1 (check runner). One run: water in the four rooms, terminals, four checkpoints, save / quit / load, a vendor, a crate, SATS, a grenade, both wheels. Open play reports are in `PLAYER_FEEDBACK.md` (2026-10-25, 2026-10-26). Check on the way:

- Y on a real rune lock and on an alarm mine; prompt glyphs for R3, Share, Y.
- Object drop shadows, indoor-door `comein`, alarm / robocell `active` frames, home-stable turrets, door autoclose, teleport spark burst.
- Stage 2 fixes listed in `IMPLEMENTED.md` (lurk, crouch, dodge, amulet, telekinesis, rebar, stairs, PipBuck log, …): confirm each in play. Vendor important-item window is still missing (§3.11).
- Enemy telekinesis grabbing the player (alicorn1–3, ghouls ss 2 / 7) and jumping free.
- The player rig: lurk, swim (armour on `body_plav`), alicorn death (`dieali`), the menu / Load previews, far-leg armour under the PipBuck (verify row V-04).

## 3. Visual parity (look)

1. Turret clips (all but the pivot and `turret0` frame 0).
2. Held enemy weapons: recoil (`t_ret`), unit colour transform, WClub stab thrust, built-in `vweap` art for gutsy, sentinel and drones.
3. Back-wall outlines (§3b.3).
4. Alicorn bullet look, the player alicorn's telekinetic throw, mana-overflow bulb.
5. Fading beams follow the horn (`weap.bulCoords`).
6. Animated debris (burning, melting, fake wall), `fx_fake` dust, electric-room flight wobble, crowbar extra wear.
7. Swim: bubbles, water particles (armour is on the rig; check in §2).
8. Weapon stand draws the stored suit on the pony.
9. Enemies page portraits (local map ladders and platforms are done).
10. Object hint signs saved.
11. Important-item window on vendor buys.
12. Dialogue box and info window: `lmb` icon instead of text hints.
13. Enemy animation leftovers: vortex `attack` clip, ant / rat / tarakan death clips, `stab` ignored by `_frames_from_clips`.
14. PipBuck pony preview (Inventory, Armor, Menu, Load) is blurry and jitters when first shown (`_freeze_pers` after 0.3 s). Recheck on the rig.

## 3a. Rig animation migration (`PORT_RULES.md` Visuals)

Import with `tools/import_rig.py <unit...>` into `assets/rigs/`, play with `scripts/rig/rig_view.gd`, compare in `tests/anim_probe.tscn` (ours left, rig right). Units already on rigs are listed in `IMPLEMENTED.md`.

1. `rig_view.gd`: art_fx `group_filters` (merged groups; only the player copy has it). Do with the unit that needs it. Check turret0's emerge clip (osn0 1–11) under its timeline mask in game.
2. Raiders, slavers, mercs, zebras, enclave, rangers, zombies and alicorns are bitmap sheets in the original and in OTHER (`visBmp`), so they stay on sheets. This is an exception to the `PORT_RULES.md` rig rule; record it there when the user confirms.
3. NPCs left on sheets:
   - vendor, doctor, vendorarmor, vendorexpl, vendorweapon (`NpcVis.SHEET_ONLY`): the converted saddlebag / medkit draws below and behind the body, the same in OTHER. Find the cause in the rig data (bone tracks of `T01_Staff_Part_01/02`?).
   - captive and ponpon are composites (cage + `pon` stills).
   - Move the rigged NPCs' sheet PNGs to `_trash` (keep `manifest.json`: it gives the clip frame counts).
   - Not imported: visualscene, vischeckpoint.
4. Memory check: VRAM and RAM before and after dropping a unit's sheets.

## 3b. From the other Godot port

The other port (`C:\Users\Командор\Downloads\foe-remains-godot-master`, below: OTHER) may be copied: the author allowed it (2026-10-28). Credit him in `THIRD_PARTY_NOTICES.md` and note the source file in `IMPLEMENTED.md`. Do not load its `CLAUDE.md`.

1. **look** Customize appearance (`appearance_screen.gd`, also PipBuck page 8). The user is not happy with it (2026-10-28) and has not said what to change. Compare with the original and OTHER, then ask. Report in `PLAYER_FEEDBACK.md`.
2. **Flash filters as shaders** (tile edges, glows, back-wall outlines). Original filters in `Grafon.as`: Glow on `cont_th`, Bevel + Glow on `plitka`, DropShadow + Bevel on `dyrka` / `cloud`, one global drop shadow, colour-matrix presets, blur under SATS. OTHER's reference shaders are `shaders/flash/{glow,bevel,drop_shadow}_compose.gdshader`, baked per room. Ours outline front faces only (`map/tile_outline.gd`). Bake our own into the room's tile canvas. Mind weak GPUs.
3. PipBuck pages still to match against OTHER in a running game: trade, doctor, craft, vault.

## 4. Menus and PipBuck

1. Fit status, inventory and info sub-pages inside the frame at 1200×800.
2. Main menu `butFile` and load-row hover.
3. Controls page: mouse icons in the key cells (symbol 943, frames 2–6).
4. Options that only save a value: `show_favs`, `zoom100`, `err_show`.
5. **check** Esc, Tab and pad Start in play (synthetic Esc did not trigger).
6. Status Main tooltips: `Pers.factor` lists what changed each stat (`pip_params.gd`). Needs the port to record the source of every change (perks, skills, effects, trauma, armour).
7. Status Main resistance rows: `pip_params._vulner` approximates the original. Check against `Pers.setParameters` / `armorParameters`.
8. Inventory vs PipPageInv: amulet tooltip icon (`amul_*`, OTHER `Objects/Items/amulN` composed to one PNG); row sort (`sort1/2/3/nazv`, current ammo first); `ramka` frame on the held weapon, spell and suit; new-item marks `☩` / `+` and the inactive-weapon `☩`; weapon `vis_icomult`; magazine rounds in the ammo count. `pip_info.gd` skips lines whose data the port lacks: ammo damage, pierce, armour, accuracy and wear; weapon `critCh`, `destroy`, `expl_kol`, `opt.perk`, `lvl_nouse`; armour crit and radiation resist; effect requirements, addiction, the hard-inventory weight bonus and the `#1` fill.

## 5. Controller and language

1. Pad layout is decided in `PORT_RULES.md` (Controller). Left: button glyph art, and any action that section leaves unbound.
2. The first pad press after keyboard only switches glyphs; it should also act.
3. EN/RU audit of every screen; story key names (`keyMagic`, `keyPunch`). The main-menu about box hard-codes `Music CC-BY License` in English (`main_menu.gd`).
4. Sky-flight feel.

## 6. Checks to build

1. **One check runner.** `tools/run_checks.py`: each check prints `CHECK <name>: ok N fail M`; ignore the harmless lines in `HANDOFF.md`; fail on `SCRIPT ERROR`, a fail count or a timeout. Options `--only`, `--skip`, `--list`. Reference `OTHER/tools/run_suite.py`. Start with `tests/test_room_xml.gd`, `tests/test_editor_validate.gd`, `tests/test_room_pool.gd`, `tools/test_room_codec.py`, and a load-every-script compile check (the headless boot does not compile lazily loaded scripts).
2. **Every-land soak.** For each land and trial chamber: `--headless --path godot res://scenes/game.tscn --quit-after N -- --user-dir=tmp/soak --land=<id>`, then `tp` through every room. Count script errors, missing textures and units that fell out. A few fixed seeds for generated lands.
3. **Save round trip.** Sandbox `--user-dir`, script a state (items, worn suit, pet, vendor cash, quest, checkpoint, damaged crate, visited land, reputation), save, restart `--boot=slot=N`, compare `WorldState.to_save()` and each autoload's file. One save in `begin`, one in a story land, one in a generated land. Covers §1.9.
4. **Deviation register.** `docs/DEVIATIONS.md`: one row per known difference (what, why, evidence, owner file). "Awaiting a human check" links a `verify/` row. `PORT_RULES.md` stays the source for user decisions.

## 7. Smoke play

Run §2 once §6.1–6.3 run clean.

## 8. Performance and size

Goal: playable on a weak GPU (tester: parts of the map draw as plain colour). Done work is in `IMPLEMENTED.md` "Performance"; harness (`perf_arena`, `physhz`) is described there.

1. Left per 30 Hz step in `perf_arena`: enemies ~4.9 ms (up to ~78 awake), crate batch ~2.4 ms, `stair_slope` ~1.2 ms; merging static colliders per room is untried; `aim_cursor._foe_tracking` walks every enemy each frame; chase (`pursue` + `_aim`) ~1 ms per alert unit.
2. FPS, frame time and memory in the debug console.
3. Hot paths from the 2026-10-31 audit (measure before and after each):
   - Physics queries allocated per call: `player._ceiling_blocks_stand` (every grounded frame), `_touch_melee` (every 9 px of a swing), `bullet.gd` ray loops, `pony_puppet._point_solid`. Reuse one query object each.
   - Group scans: `enemy` shot/grenade sense, `_budilo` / `_alarm_from` chains, brainless friendlies' `_nearest_foe` every frame, `brain_turret.find_cel`, trap triggers and alarm buttons over all enemies, `audio_manager._watch_units`, `fog_sight` units/shots and `_poll_fx` scene walk, `bullet` blasts over all `destructibles`, `land_props` `begin_traps` twice per frame.
   - `magic_aura` walks the host's sprite tree every frame; cache the list.
   - `fog.gd` uploads the whole fog image on each dirty tick; upload changed rows.
   - HUD every frame: `_refresh_weapon`, `_tick_prompt` / `_place_tip`, `_bars.queue_redraw`, `_refresh_effects`, `_tick_eye` armour scan; PipBuck Effects/Health pages rebuild rows at 4 Hz; right panel rewrites labels at 4 Hz; `local_map_page` redraws every frame.
   - JSON parsed twice: `rooms_begin.json` in `land_props` (`_begin_checkpoints`, `_load_room_index`), `fog.begin_rooms()` per call, `term_anchors.json` in `land_props` and `prop_art`, `objs.json` in three editor scripts, `effects.json` in `effects.gd` and `scripts_engine.gd`.
4. Build size: BPTC made builds ~1.5 GB. Basis Universal for big art if download size matters (user to decide).
5. Trim and repack sprite sheets; keep anchors, `_sheet_offset` and wPos tables.
6. Watch for a first-sight hitch on rare objects with load on demand.
7. Lossy WebP on disk for big opaque art.
8. Music re-encode check (OGG Vorbis; 174 MB).
9. Duplicate art: 14 images exist in both `sprites/env` and `sprites/tiles` (surroundings uses `env`, the map uses `tiles`); `env/87.png` = `fon/fonRuins.png`. Point both users at one copy.

## 9. Steam parity

1. Import the `rooms_plant` / `rooms_prob` changes and corrected `text_en` / `text_ru`; re-export `texture1.swf` bitmaps 1139, 1141, 1143, 1145.
2. Languages `ua`, `de`, `pl`, `es`, `jp`, `zh`, `tw`: text import, `lang.xml`, settings and main-menu picker, CJK font fallback, UI fit.
3. DLC 1.0.4 rebalance as a mode: data overrides, the 13 code changes, a new-game switch, saves tagged with the mode. Ask about the odd values first (`KNOWLEDGE_BASE.md`).
4. Compare `pfeUI.swf` UI art against `pfe.swf`.

## 10. Second smoke-play

A full run to an ending, controller only, in the base game; then a shorter run in the DLC mode.

## 11. Final release

1. Remove `controls_ui.gd` and the pause panel in `pause_menu.gd` (no longer shown).
2. Empty `_trash/` after the user checks it (`_trash/unused`, `_trash/dead_code`, `_trash/pony_frames`, …). Delete user-data probe files and `saves\slot9`.
3. Static textures without a quit hook (`weapon_vis.gd`, `weapon_fx.gd`, `units/unit_fx.gd`, `enemy.gd` sheet cache whose `drop_cache` does not wait for its loader tasks) can crash the exit the way `pony_puppet` once did. Give them the `_drop_on_quit` pattern if an exit crash shows up.
4. Export Windows and Linux, smoke-test both, update `build/TESTER_GUIDE.md`. Ship `LICENSE`, `LICENSING.md`, `ADDITIONAL_PERMISSIONS.md`, `THIRD_PARTY_NOTICES.md` in both folders.

## 12. After the port (not started)

Architecture debt to take on only with tests in place (§6): `player.gd` and `enemy.gd` are ~5k lines each (movement, weapons, melee, senses, spells); SATS calls private player methods by name (`_razn`, `_body_center`, `_aim_rect`, `_skill_mult`), and SATS aim (`player._body_center`) and AI aim (`enemy` feet + `body_size`) can disagree; player and enemy each build bullets and parse `weapons.json`; the grenade bounce is copied in `sats.gd` and `bullet.gd`; ten scripts parse JSON with their own helper; `game_state.gd` mixes combat, magic, organs, doctor and consumables.

### 12.1 Seamless random lands

Generated lands grow as one chain: the next level attaches at the right exit of the between room instead of replacing the land. Needs a `PORT_RULES.md` entry when started.

1. Keep every level's seed and frozen inputs (`WorldState.build_value`) instead of `forget_land`, plus per-room changes, in a compact save.
2. `play_land._build` builds the whole level at once. Split into chunks that load near the player and unload far away, rebuilt from seed. Load around a set of positions (`PORT_RULES.md` "Future multiplayer").
3. Open the edge wall, match door slots across the joint, align levels of different heights.
4. Difficulty by distance (user, 2026-10-26): the chunk's distance replaces `landStage` everywhere it is read (enemy type, loot, trials, plant height, `exit_plant`). No `upland`. Decide the chunk size and the curve. Whether `exit_*` rooms stay as rest stops is open. Stage-bound story events fire at distance thresholds.
5. Fog memory, PipBuck map, back and trial rows, checkpoints, respawn, terminal round trip.

### 12.2 Online co-op

P2P via Steam. Rules: `PORT_RULES.md` "Future multiplayer". Plan: `docs/MULTIPLAYER_PLAN.md`.

### 12.3 Trial definitions in the editor

Deferred (user, 2026-10-27); see `IMPLEMENTED.md` (Room editor). Needs `mods/lands/`.

### 12.4 Local LLM room assistant (dev-only)

User, 2026-10-28. A local model (Ollama or LM Studio, localhost only, a 14B–32B coder model, JSON schema) edits a room through editor commands. Raw 48×25 grids come out broken.

1. Editor menu entry, `HTTPRequest` to localhost, dev switch, out of tester builds.
2. Commands (fill rect, platform, ladder, door, place object) run through the editor's own edits, so undo and Check work.
3. Reachability: walk, jump and climb from the entry to every exit. Useful for hand-made rooms too.
4. Apply, Check, send problems back, retry; the user accepts or undoes.
5. Examples from shipped rooms. One room first; map assembly through `land_gen` later.

### 12.5 Fluid and gas simulation (optional mode)

User, 2026-10-30. Differs from the original (whole-tile water in `map/water_flow.gd`, fixed gas areas), so it needs a `PORT_RULES.md` entry when started. One switch, off by default. Room data stays whole-tile and Editor.swf-compatible.

1. Water: partial levels with pressure, replacing `water_flow.gd`. Packed arrays per room, only active cells, 30 Hz. Needs fill-level art and a compact save in the "water" land memory.
2. Heavy gas on the same grid, fed by the existing gas sources.
3. Buoyancy and drag for boxes and units, plus walking on ice, through the existing swim and float code.
4. Later, and design first: reactions (gas ignition, electrolysis, condensation, freezing).

Do 1 and 2 first and play-test them before 3 and 4.
