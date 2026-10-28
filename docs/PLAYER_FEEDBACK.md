# Player feedback

What the user and testers saw in play, with the current status. New reports go at the top. "Fixed" means fixed in code; "verify" means it still needs a look in play.

## 2026-10-28, user

| Report | Status |
|---|---|
| Customize appearance (main menu and PipBuck) needs work. | Open. What to change is not specified. Compare with the original and the other Godot port, then ask. |

## 2026-10-27, user

| Report | Status |
|---|---|
| Every launch builds begin first, even when loading a save made elsewhere or starting a test; it should load straight into the needed land or room. | Fixed: `game._start_land` builds only the start land; begin is built on first entry. Loads no longer rebuild the saved land a second time. Test rooms: `--room=<file>:<room>` (own land, `editor_play`), `--land=<id>`. Checked: rbl, surf save continue, test room, surf → begin. |

## 2026-10-26, tester (begin, random maps, misc)

| Report | Status |
|---|---|
| Begin (4,0): door is open from the start; the access terminal only shows a message. No access terminal is wired anywhere. | Access terminal (term2): hack the terminal (Science). On success it unlocks room objects marked hack=1 (door3, some safes), not ordinary pick-only doors. door1 is lock 0 in the xml. A failed hack only shows the fail line. Verify in play. |
| Begin (1,4): detonator fires only the top charge of three; it barely damages the wall (should blow a part away). | Fixed globally: blast `take_hit`s other charges on every land. Walls take `apply_blast` in the disk on every land (not begin-only). Safes / crowbar crates in the disk now `damage_box` like a crowbar smash. Destroy 1000 still has to beat tile `thre` / box `thre` (safe 200, hp 1200). Verify the hole and a safe in play. |
| Begin (0,2): first aid kit ignores interaction. | Partial: medbox is `tk_use`, `cont=med`, and opens. Authored items empty (loot rolls on open). Verify aim on the wall kit. |
| Shootable buttons (begin (2,1), trial "Shooting buttons"): shots do not trigger them; they should light up and act on any damage. | Fixed: `_strike` calls `take_hit` on `actdam`. begin knop2 lights up and its `scr` unlocks door3 `trMDoor` (lock 3→0); it has no `allact`. The door stays shut until opened. Trial chambers still to port. |
| Pressable buttons are not wired to anything anywhere. | Fixed: press now goes through `_on_button`, which runs `all_act` from the knop's allact/allid. |
| Random maps always build the same room layout (loot, enemies, vendors differ). | Fixed: every new Land (map travel, next level) gets a new seed; entrance rooms only before the first visit. Verify in play. |
| Random-map exit room door should behave like any other back door. | Fixed: hold (createExit `time` 20, authored exit 60), comein clip. A dest `prob` (`exit_plant`) is `gotoProb` — same land, the between-room. The door at the right end of that room (allact `exit`, no `prob`) is `goto_next_level`. Verify in play. |
| Between-level room (plant 1 → plant 2) should stay on the land it was entered from; right-end door should start the next level. | Fixed: that room is still this land (`gotoProb`). The right-end exit had no `target`, so spawn threw and never registered the use. It is now `next_level`. Verify in play. |
| Base teleport from a terminal and back: should land on that terminal and keep the map; it regenerated enemies, loot and vendors (kept "seen"). | Fixed for the return through the camp terminal: same plan, same units, player on that terminal (headless test). Map travel to the land still makes a new Land, as in the original (`beginMission` sets crea). |
| Random maps: loot, enemies, trials, bosses should scale with the room level too; a boss room on level 1 should not happen. | Partial: enemy type and container loot now use the room's locDifLevel; passed trials are skipped. Level-0 boss trials (plant ant_breeding, sewer zombies / pit, stable turrets, mane bloatking) are in the original and kept. |
| Random maps: the first level is smaller and built by slightly different rules. | Fixed: plant is 3 rows only at landStage 0 (it was always 3); the other stage-0 rules were already in. |
| Back rooms sit on the map with normal neighbour rules, linked to the room they are entered from; inside, other rooms are hidden and the camera stays in the room. | Fixed (user: rows under the map are fine if hidden and isolated): mask + camera clamp + front-room frame. A back room wakes only itself and its front room; trial rooms only themselves. Row neighbours and the map's bottom rows stay frozen (`room_bounds.is_active` / `_apart`). Verify in play. |
| Bonus horseshoe images stay ~50% of the time (Deck). | Open: not reproduced at 15 fps (headless pickup, freed in time). Suspects in `land_props` / `fog_sight`: a fog ghost left of the pic while its tile leaves sight during the vanish tween, or `land_memory.capture()` during the tween saving it as present. |
| Enemies can drop down from platforms but almost never do. | Fixed: `throu` is UnitRaider's `moving && celDY > 80` (setCel celDY), every tick they have a target below. `_at_rest` no longer skips the slide while dropping. Patrol does not drop (aiSpok 0, celDY 0). Headless: raider left a shelf toward the player in 8 frames. |
| Raiders stick in the wall climbing a ladder next to a wall. | Fixed: units stay on a stair tile (`checkStairs`), get off when that tile is gone or solid, and do not re-grab from the 36 px lip. Headless: raider and zebra both left climb at the other floor on a wall ladder and a hatch ladder. Verify in play. |
| Lurk: animation plays, then the pony stands idle with no tail, not hidden; stealth bonus unclear. | Fixed: holds the dark `un` frame (no stand pose), hair dims with the clip, unlurk plays from `un`. Box 2/3 drawn over the pony; box 1 / niche under. sneakLurk observation cut (sitting a fifth). Verify the look in play. |
| Lurk: horn, eye and PipBuck draw over the cover crate. | Fixed: puppet parts sat at z +3..+6 above the pony; the crate was raised only to 4. While lurking, `pony_puppet.set_flat_layers` keeps part order on the body's z and restores it on unlurk. Verify in play. |
| Trial "Shooting practice" completely broken; port chambers exactly. | Open. |
| Trial and boss doors show a name placeholder in the tip. | Fixed: passage `title` from `text map` (trial id). Verify. |
| rbl boss doors still not locked. | Fixed: passages ignored `lock` / `key`. rbl `doorboss` is lock 1, locktip 0, key `key_sewer` (etc.); `_spawn_passage` now stamps the lock and `_go_through` runs `_pass_lock` first (key opens, else "locked" line). Same for any locked trial door. Verify in play. |
| Mine held in telekinesis until it blows: its tip stays. Hide tips for objects in telekinesis. | Fixed: only the held object is skipped. Other names still show. The name line is always the aimed object (original `setCelObj`); use/tele lines stay range-gated. |
| Crafting table sometimes spawns as a container (lootable, no crafting, liftable). | Need repro: every `work` in the room data is a station (no `cont`); the look-alike containers are `instr1` "Tool cabinet" and `instr2` "Tools rack" (lootable, as in the original). Need land, room and a screenshot with the tip. |
| Bats (and all enemies) show sleep while held in telekinesis; the original has a struggle clip. | Fixed: held clip from `brain.animate` / class present (`derg` / `fly`). Cursor hold is Telekinesis.hold only; struggle does not push the carry velocity. |
| Player can stand on 1-tile boxes (ammo, explosive, cardboard); should not. | Fixed: shelf only if width > 40 px (original `scX < 40` still shelves a 40 px box). |

## 2026-10-25, tester (begin + surf)

| Report | Status |
|---|---|
| One interact press opens a door and shuts it again. | Fixed: interact was read in `_process` and again in `_physics_process`; at 30 physics ticks the physics read saw the same press a frame later. Now read in `player._process` only. Verify in play. |
| Main menu button still crashes (every run). | Open. Tester's AppData godot.log ends on `Parameter "data.tree" is null` (no backtrace; that log is not flushed per line). Added `exit_trace.gd`: every path to main_menu.tscn logs `[exit Nms]` steps (autosave, music, change_scene), each node leaving the tree, scene_changed and 20 menu frames, through the flushed exe-local `logs\godot_*.log`. Needs a build; then the last `[exit` line before the cut shows where it dies. 2026-10-25 new-build logs (`tester_feedback/logs`) are again the AppData ones: trace reaches `change_scene_to_file returned 0`, then the same error, then the buffer cut. Tester has no `godot_*.log` (local build writes one). `user_dir` now always starts the flushed log in exported builds (AppData fallback too) and logs the chosen dir and fallback reason. Patches-folder error silenced. Both are in the autoload that mounts patches, so they ship only with the next full build (not in patch_001). Next: tester runs `RemainsPort.console.exe` from a terminal and copies the console after the crash. |
| Log: blood, sparks, drips, explosions missing in builds (`sprite1_images ... No loader found`). | Fixed: `sprite1_images` has `.gdignore`, so the export skipped it; the 17 used strips copied to `assets/fx_blits/` (`unit_fx.BLITS`, `brain_thunderhead.SPRITE`). Needs a rebuild. |
| Log: `held_prop._att_drop` bool constructor. | Already fixed in current code (old build). |
| User: teleport should reach remembered tiles out of sight. | Fixed: `player._check_port` now reads `fog.tile_seen` (live visibility or layout memory) >= 0.8, as checkPort reads `Tile.visibility`; line of sight only when a land has no fog. Verify in play behind a wall you have seen. |
| User: after a teleport the old view stays lit until the player moves. | Fixed: Location.step only relights on velocity, and a teleport has none; `fog.relight_after_jump` (called by both teleports) runs lighting for 1 / FADE = 40 ticks. Test: 64 of 187 old tiles faded while standing still, none left above the new target. |
| User: teleport should keep the player's velocity. | Fixed: the port zeroed velocity; Unit.teleport / setPos keep dx, dy and clear only levit. Both teleports now keep it. |

## 2026-10-25, user (surf, last build)

| Report | Status |
|---|---|
| Open doors draw above units. | Fixed: door sprite z -3 (`door_art.gd`; Box.as puts wall objects in visObjs[0], boxes in sloy 1). 2026-10-26: crates were drawn behind doors (door was -1, crates -2); now doors -3, under crates. Verify. |
| Some XP horseshoes stay visible after pickup. | Not reproduced: 134 pickups in random_mane, none stuck. Need the map and whether the land was re-entered. |
| Begin tips show @1 / @2 instead of keys. | Fixed: `OriginalLines.keys_of` keeps s1..s5 attrs; `land_props._txt` runs `StoryText.add_keys`. |
| Remove the L3 sprint toggle. | Done: sprint only while held, pad included (`player._poll_run`). |
| Breath never drains under water. | Fixed: `GameState._swimming` was never set; `player_water.check` now calls `set_swimming(is_plav)`; drain uses h2oPlav × the worn suit's h2oMult (`Progression.armor_h2o_mult`: antirad, antihim 0.25). Water-breathing potion (`potion_swim`): no drain, and `player_water.swim` now reads speedPlavMult ×2 and ddyPlav 0 (no sinking). |
| Surf end raiders spot the player from room 11 and attack before the scene. | Fixed: scene-room guards ignore the player in other rooms (`enemy._scene_pending`); all damage is blocked while control is off (`GameState.apply_damage_f`, like `Unit.damage` invulner). Console `surfend` / `tp` to test. |
| Exiting to the main menu may crash the game. | Not reproduced: 24 scripted exits from six lands (both art modes), no crash. The user's log was overwritten by test runs; `max_log_files` is now 30. Need the log of the next crash. |
| After the texture reimport the protagonist animates less smoothly: walk loop first/last frames differ, clips and the still pose differ slightly in size. | Fixed: pony frames (19.7k files, 94% not a multiple of 4) back to lossless (`set_texture_compression.py` rule `pony`); BPTC 4x4 blocks blurred each frame's edge differently. Verify; 1766 other compressed sprites (enemy sheets, fon) are also unaligned. |
| Solid blue band at the bottom of the screen on the surf bridge. | Fixed: per-room `BackBufferCopy` rects partly off screen left stale back buffer under the colour filter (`color` rooms), drawn as flat colour. `room_look._tint` now uses one viewport copy under all tint rects. Possibly also the tester's "plain colour" parts. |
| Surf end: raiders attack during the Calamity dialogue. | Fixed: `Unit.findCel` skips an invulnerable player and `controlOff` sets invulner; `enemy._sense` now loses the player while `control_off`. |
| Surf end: Calamity never appears; the exit to `rbl` never comes. | Fixed: `fly` cells are room-local, the port used them as world coordinates, so she flew to room 0. Also ported `UnitNPC` aiTip `agro` (shoots units of another fraction in her room with her `weap`, busy = no talk, then sinks and lands). Talking to her then runs `dialCalam2` (passed + openland rbl, travel). Verify in play. |

## 2026-10-25, first tester

| Report | Status |
|---|---|
| Next room shows solid red (`begin`, likely elsewhere). Not seen on the user's PC or Deck; probably a weak GPU. | Likely cause: the fog shader fails there, so the raw fog bitmap (memory in its red channel) is drawn. Fallback now draws black fog (`fog.gd` `_sprite.self_modulate`). Ask the tester for `godot.log` and the GPU model. |
| Surf background ruined by square building textures after the backdrop change. | Fixed: they were the old port placeholder `surroundings.gd` (z −40), hidden until now by the opaque sky rect; it is no longer drawn (`game._add_surroundings`). Also: back holes looked up the wrong room (`MODEL_MATRIX` is not world space for batched sprites); `land_fon.gdshader` now maps screen UV to world. |
| Plant: back wall missing, posters / vents / doors hang over the sky. Random lands always start in the same room. | Fixed: `backwall=""` (52 of 55 plant rooms) painted nothing; `Grafon.drawBackWall` falls back to tBackWall for an empty or unknown name, now `play_land._paint_backwall` does too. Same start room is original: each rooms_*.xml has exactly one `tip="beg0"` entrance, placed unmirrored; the rest is random. |
| random_mane: stairs broken (steps lean against the beams between them). | Fixed: mirrored random rooms flipped cell order but not the mat `m` pairs (ladder sides А/Б, stairs В/Г … С/Т). `RoomFile.mirror_rows` now swaps them for every generated land; land_preview no longer swaps a second time. |
| Severe slowdown; parts of the map drawn as plain colour. | Partly: heavy random_mane / stable_pi layouts went from 130–186 ms per frame to 17–24 ms (crate batch, frozen crates out of physics, per-frame cursor and prompt scans, tile canvases). Texture memory: VRAM compression (BPTC) cut begin 223 → 97 MB, random_mane ~580 → 193 MB. Not in the 2026-10-25 tester build. |
| Second new game: begin exit did nothing. | Fixed: loading a save made in the land on screen left `Travel._loading` set, so every `goto_land` was swallowed. Also added the permanent begin ↔ Surf link (PORT_RULES, World). |
| Ladders with hatches are hard to climb. | Fixed (port rule): ladders run on through an open hatch (`play_land` door cells, `begin_land._hatch_ladders`). Verify. |
| Tips show wrong buttons and flip rapidly between pad and keyboard. | Flicker fixed: the in-game stick cursor's mouse warp counted as mouse use (`aim_cursor._move` sets `UiNav.warped_frame`); idle triggers at −1 counted as pressed (`Prompts._axis_on`). PipBuck page help now shows the current device. Still open: actions with no pad binding fall back to the keyboard key (pad scheme for them is Phase 7). |

## 2026-10-25, Steam Deck (Linux build)

| Report | Status |
|---|---|
| World-map travel does not load the land, in both the Windows and Linux builds. | Fixed (user verified in editor run): the empty PipBuck list ate the clicks (`pipbuck.gd` `_scroll.mouse_filter`). In builds of 2026-10-25. |
| World-map land icons too big, overlapping. | Fixed: they were drawn at texture size (84 px) instead of the original 42 px (`world_map_page._rect` set size before `expand_mode`). Verify. |
| Factory (and every land) has no background; looks suspended in vacuum. | Fixed: land `fon` backdrops ported (`map/land_fon.gd`). Verify; Factory gaps stay dark by the original's maths (fonDarkClouds under 67 % black), so compare with the original if it still looks wrong. |
| Main-menu cursor does not react to the right stick. | Fixed, verify on Deck: stick cursor keeps its own point; Gamescope ignores `warp_mouse`, so hover / A-click use that point and a software arrow is drawn when `SteamDeck` / `GAMESCOPE_WAYLAND_DISPLAY` is set (`ui_nav._move_cursor`). |
| Some text does not fit at 1280×800 (e.g. the starting scene). | Fixed, verify on Deck: the UI asked for Windows fonts (Arial, Lucida Console, Consolas) via SystemFont; SteamOS substitutes wider ones. Now bundled Liberation Sans / Sans Italic (Arial metrics) and Liberation Mono (Lucida Console widths) in `theme/fonts/` (`hud_sans.tres`, `intro_screen`, `main_menu`, `travel`); the 1280×800 viewport is the 720 layout plus 80 px height, so fonts were the only difference. |
| Stamina info and effect icons often do not appear. | Open: HUD logic matches the original (stamina shows under 500, 980 in battle); needs a repro. |
| A failed disarm on a booby-trapped safe or object damages the player, but no explosion plays. It should explode once and then no longer be trapped. | Fixed: `land_props._blast` fires a real explosion bullet (Interact.explosion / Bullet.iExpl); the mine is cleared on the fumble. Verify. |
| Enemy name tips and the red target cursor show for enemies the player cannot see, revealing them through walls. | Fixed: units hidden by fog sight (`fog_layer` meta) are skipped by the HUD tip, the cursor target and aim assist. Verify. |

## 2026-10-24, tester-build prep

| Report | Status |
|---|---|
| Everything seems playable; PipBuck pages look fine; controller works. | — |
| Rebar debris hurts when walking through it; it should only hurt when falling on it. | Fixed (`land_props._trap_touch`). Verify. |
| Raiders don't use weapons in fight (build stopper). | Fixed: held weapon sprites per body type (`held_weapon.gd`). |
| Weapons must be held, not baked in: unicorns in telekinesis, pegasi in teeth / front hooves, griffons in claws, earth ponies in teeth. | Fixed. Gaps: no recoil, no colour tint, no stab thrust, no art for robots' built-in guns. |
| Raiders use parts of the fall animation in jumps; check all enemy animations. | Fixed for raider kin and 15 audited classes. Open: protectrons and alicorns never land. |

## 2026-10-24, first play round (starting land `begin` unless noted)

| # | Report | Status |
|---|---|---|
| 1 | Possible soft-lock: a critical organ blocks the exit to the base camp, with no doctor in the tunnels. | Faithful to the original, left as is. Console `heal` clears it. |
| 2 | Bloatsprite nests don't breathe or spawn. | Fixed (`brain_emitter.gd`). |
| 3 | Bloatsprites don't move their wings. | Fixed. |
| 4 | Bloatsprites get stuck in walls. | Fixed (`brain_bloat.gd`). |
| 5 | Big bloatsprite should split in two on death. | Fixed (`enemy._bloat_split`). Death parts, knockback cling break and nest burst added 2026-10-25. |
| 6 | Terminal use point sits below and right of the picture. | Fixed. |
| 7 | Reinforced doors should need the interact key held. | Fixed (`_use_door` honours `act_time`). |
| 8 | Player should start in the stable jumpsuit. | Fixed. |
| 9 | Worn armour is not drawn on the pony. | Fixed (armour overlay). Verify `pip` covers only the front half. |
| 10 | Main menu animation. | Done. Open: the gun animation is not smooth. |
| 11 | PipBuck background, frame and size. | Done. |
| 12 | Menus should show the arrow cursor, above overlays. | Done. |
| 13 | Target cursor should change colour by target. | Done. |
| 14 | Camps: nobody starts aggressive. | Fixed (`fraction="100"`). Verify camp allies hit back. |
| 15 | Turret animations are all wrong. | Partly: pivot and `turret0` frame 0 fixed; other clips unchecked. |
| — | Crystal-ball appearance page: side buttons dead. | Mouse clicks work in a test; verify keyboard and pad focus. |
| — | Stable Pi run bug. | Not reproduced. |
| — | Invisible border at a land's start room. | Fixed: port-only "StableExit" strip removed. |
| — | Magic beam (user, 2026-10-27): a second beam image is drawn perpendicular to the real one, going straight up from the horn while the beam goes sideways. | Open. Likely the beam sprite's rotation or the length scale is applied on the wrong axis for one of the two segments. |
