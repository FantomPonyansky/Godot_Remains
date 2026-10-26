# TODO — plan to finish the port

Open work only: when a step is finished, delete it here and record it in `IMPLEMENTED.md`. Work top to bottom. Each step ends with one boot check and a note in `IMPLEMENTED.md` (and `PLAYER_FEEDBACK.md` when it answers a report). Severity tags: **block** stops a run, **wrong** plays differently from the original, **look** visible but harmless, **check** unverified.

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
| 8 | Release build and cleanup | tester builds out (Windows, Linux); final cleanup left |
| 9 | Performance and size | not started |
| 10 | Steam release parity | not started |

## 0. Tester 2026-10-26 (begin, random maps, misc)

1. Verify in play: begin (4,0) term2 hack then door3 unlock; detonator chain (3 charges + wall hole); a grenade / charge opening a safe; knop1/knop2 `all_act`; trial/boss door titles.
2. Begin (0,2) first aid: it opens (`cont=med`); if it still ignores the cursor, wall-mounted loot aim.
3. Trial `buttons1` / `buttons2` (Shooting buttons / Shooting practice): port the chambers from the original.
4. Verify rbl boss doors need their key (passage lock).
5. Horseshoes that stay (Deck); raider ladder vs wall; lurk clip + stealth; mine/object tip while held (HUD already hides — verify); `work` never a container; enemy levitate struggle clip; 1-tile boxes already not shelves (verify).

## 0b. Steam Deck reports (2026-10-25)

1. Verify on Deck: world-map travel, right-stick menu cursor, trap explosion, enemy tips through walls, land backdrops, text fit at 1280×800.
2. Stamina info and effect icons often missing from the HUD (logic matches the original; get a repro).
3. Mine explosion damage lacks `(1 + locDifLevel · 0.1)`; the port has no location difficulty level yet.

## 1. Smoke-play `begin` to `surf` (block)

Nobody has played start to finish. One run covering water in the four rooms, terminals, four checkpoints, save / quit / load, a vendor, a crate, SATS, a grenade and both wheels. Check on the way:
- Y on a real rune lock and on an alarm mine; prompt glyphs for R3, Share, Y.
- Object drop shadows, indoor-door `comein`, alarm / robocell `active` frames, home-stable turrets (stills or live player-side units), door autoclose, teleport spark burst.
- Stage 2 fixes: lurking, auto-crouch, pet removed in `petoff` rooms, horseshoe sneak bonus, "Take all tasks", box damage saved, box caps multiplier, worn dropped weapons, world-map blink with `helpMess`, dodge, amulet beside the suit, falling crates, hold-with-progress on terminals and containers, stair reach, cursor name line, PipBuck log, dialogue press not leaking into gameplay.
- Enemy telekinesis grabbing the player (alicorn1–3, ghouls ss 2 / 7) and jumping free.
- Rebar walk-through, held enemy weapons and the new enemy animations.

## 2. Gameplay correctness (wrong)

1. Verify in play: Protectron jet over walls; `pole` alicorns in the talisman trial and mtn (tested only on a spawned unit).
2. Bloat death parts ignore `ctrans` (unit colour tint).

## 3. Visual parity (look)

1. Turret clips (all but the pivot and `turret0` frame 0).
2. Main menu gun animation is not smooth.
3. `pip` armour covers only the front half; facing left, suit art draws over the PipBuck (original: far-leg armour under it).
4. Held enemy weapons: recoil (`t_ret`), unit colour transform, WClub stab thrust, built-in `vweap` art for gutsy / sentinel / drones.
5. `pole2` shield-hit effect.
6. Back-wall outlines (`backOutline`).
7. Alicorn bullet look and the player alicorn's telekinetic throw. Mana-overflow bulb.
8. Fading beams should follow the horn (`weap.bulCoords`).
9. Animated debris (burning, melting, fake wall) and `fx_fake` dust; electric-room flight wobble; crowbar extra wear.
10. Swim: armour on the swim clip, bubbles, water particles.
11. Weapon stand draws the stored suit on the pony.
12. Local map ladders and platforms; enemies page portraits.
13. Object hint signs saved; important-item window on vendor buys.
14. Dialogue box and info window: `lmb` icon instead of text hints.
15. Enemy animation leftovers: roller pivot (`brain_roller.gd:83`), vortex `attack` clip choice, ant / rat / tarakan death clips (may gib), `stab` key ignored by `_frames_from_clips`.

## 4. Menus and PipBuck

1. Fit status, inventory and info sub-pages inside the frame at 1200×800.
2. Stat symbols in the right panel instead of text labels.
3. Main menu `butFile` and load-row hover.
4. Controls page: mouse icons in the key cells (symbol 943 frames 2–6).
5. Options that only save a value: `show_favs` (favourites strip), `zoom100` (one-room fit, locked scale), `err_show` (error window).
6. Verify Esc, Tab and pad Start in play (synthetic Esc did not trigger in a test).

## 5. Controller and language (Phase 7)

1. Pad bindings for quick spells 1–4, magic attack, SATS extras, pet command; button glyph art.
2. The first pad press after keyboard only switches glyphs; it should also act.
3. EN/RU audit of every screen; story key names (`keyMagic`, `keyPunch`).
4. Sky-flight feel.

## 6. Steam parity (Phase 10)

1. Base fixes: import the `rooms_plant` / `rooms_prob` changes and corrected `text_en` / `text_ru`; identify and re-export the `texture1.swf` bitmaps 1139 / 1141 / 1143 / 1145.
2. Languages `ua`, `de`, `pl`, `es`, `jp`, `zh`, `tw`: text import, `lang.xml` list, settings and main-menu picker, CJK font fallback, UI fit per language.
3. DLC 1.0.4 rebalance mode: AllData / GameData diffs as overrides, the 13 code changes, a mode switch at new game, saves tagged with the mode. Ask the user about the odd values first (see `KNOWLEDGE_BASE.md`).
4. Compare `pfeUI.swf` UI art and layout against `pfe.swf`.

## 7. Second smoke-play

A full run to an ending, controller only, in the base game; then a shorter run in the DLC mode.

## 8. Performance and size (Phase 9)

Goal: playable on a weak GPU (tester: parts of the map draw as plain colour). Music is 174 MB.
1. Left per 30 Hz step in `perf_arena`: enemies ~4.9 ms (up to ~78 awake within player ± 1 room), crate batch ~2.4 ms, `stair_slope` ~1.2 ms (could wake on contact); merging static colliders per room is untried; `aim_cursor._foe_tracking` walks all enemies each frame; enemy chase (`pursue` + `_aim`) ~1 ms per alert unit is suspect. User to judge 30 Hz feel with `physhz`.
2. FPS, frame time and memory readout in the debug console; profile heavy rooms (big fights, particles, fog, lighting) and GDScript hot paths (`enemy.gd`, `bullet.gd`, `held_weapon.gd`); compare with the original. Harness: a test that sets `WorldState.run_seed`, erases `_builds` / `_lands` for the land, travels, then times each processing node's `_process` / `_physics_process` grouped by script (held_prop needs `_batch_frame = -1`); use `perf_arena` with `GameState.god = true`, player at spawn + (rx × 1920, ry × 1000) per room.
3. Build size: BPTC made builds ~1.5 GB; Basis Universal for big art if download size matters (user to decide).
4. Trim and repack sprite sheets; keep anchors, `_sheet_offset` and wPos tables correct.
5. Watch for a first-sight hitch on rare objects with load on demand.
6. Lossy WebP on disk for big opaque art.
7. Music re-encode check (OGG Vorbis at a sensible bitrate).

Runtime vectors were considered and rejected: Godot rasterizes SVG anyway, and Flash filters, masks and colour transforms do not survive.

## 9. Final release (Phase 8)

1. Remove `controls_ui.gd` and the pause panel in `pause_menu.gd` (no longer shown).
2. Resources-in-use warning at exit (menu music stream), harmless.
3. Empty `_trash/` after the user checks it (repo reorganised 2026-10-26). Delete user-data probe files and `saves\slot9`.
4. Export Windows and Linux, smoke-test both, update `build/TESTER_GUIDE.md`.

## 10. After the port (separate modes, not started)

### 10.1 Seamless random lands (option or mode)

Generated lands grow as one chain: each next level attaches at the right exit of the between room instead of replacing the land (`gotoNextLevel` today makes a new seed and forgets the old one). Needs a `PORT_RULES.md` entry when started.

1. Remember every level: keep each level's seed and frozen inputs (`WorldState.build_value`) instead of `forget_land`, plus per-room changes (containers, kills, doors, pickups) in a compact save format.
2. Chunked build: `play_land._build` makes the whole level at once with merged collision. Split it into per-level chunks (own collision, tiles, dressing, doors) that load near the player and unload far away, rebuilt from seed on return. Load around a set of positions (see "Future multiplayer").
3. Generator joint: open the edge wall, match door slots across the joint, align levels of different heights (plant 3 rows at stage 0).
4. Difficulty by distance (user, 2026-10-26): each chunk gets its own difficulty from how far it is from the start, rising slowly. The chunk value replaces the per-level `landStage` everywhere it is read: enemy type (`_land_dif`, row depth), container loot (`loot_ctx`: locDifLevel, weaponLevel, lootLimit), trial choice (level ≤ stage), plant height, `exit_plant` at stage ≥ 2. Decide the chunk size (one level-sized grid or smaller) and the distance-to-difficulty curve. No stage-up in this mode (user, 2026-10-26): `upland` is skipped; distance is the only difficulty source. Whether the between-level (`exit_*`) rooms stay as rest stops is open; if they do, one belongs to the chunk it was entered from. Anything else that reads `landStage` (quest or story conditions, saves, map or HUD text) reads the chunk value instead; check each. Keep or drop `refill` separately. Stage-bound story or boss events fire at distance thresholds.
5. Adapt fog memory, PipBuck local map (long strip), back and trial rows, checkpoints, respawn, terminal round trip.

### 10.2 Online co-op

P2P via Steam, several players. Rules for current work: `PORT_RULES.md` "Future multiplayer".
