# Architecture refactoring plan

It prepares the code for five goals without building them. R0 to R4 are done (what was built: `IMPLEMENTED.md`); next are R5 and R6.

- **MP**: online co-op ready (no networking yet). Feature plan: `MULTIPLAYER_PLAN.md`.
- **FL**: liquid and gas simulation. Feature plan: `TODO.md` §12.5.
- **MOD**: modding. No hard-coded tuning, data files with documented schemas, readable code.
- **END**: seamless endless maps. Feature plan: `TODO.md` §12.1.
- **AI**: more complex enemy AI under directors: a spawn director (pacing, budgets, reinforcements, ambushes, composition by distance and difficulty) and tactics directors (squads, roles, attack slots, flanking, suppression, retreat, shared target memory). Current behaviour: `ENEMY_AI.md`.

Rules for every step:

- Single-player play stays the same. Each step must pass `python tools/run_checks.py` (save round trips, seeded replay against `godot/tests/fixtures/replay_golden_*.txt`) before the next one starts.
- This file holds the plan only. What a step built goes to `IMPLEMENTED.md`.
- Fixed lands (`begin`, story lands) keep their current build path until R5 has a reason to touch them.
- One writer at a time for `player.gd`, `enemy.gd`, `land_props.gd`, `bullet.gd` and `project.godot` (`HANDOFF.md`).
- Size: **S** under a day, **M** a few days, **L** a week or more. Risk is the risk to current behaviour.

## Where the code stands

- **Core.** `Run`, `Sim`, `Rng`, `LocalInput`, `Fx`, `WorldOps`, the entity contract and the versioned slot (format 4: `character.json`, `run.json`, `world.json`) exist (`ARCHITECTURE.md`, `AUTOLOADS.md`). The only autoload cycle is the WorldState ↔ Run ↔ Rng hub. GameState (1.8k lines), Effects, Travel, Vendors and Craft are still large, but their per-player state sits in `scripts/character/` behind forwarding properties.
- **Bodies.** `player.gd` (1.3k lines) and `enemy.gd` (3.7k) are bodies with components (`player_move` / `_weapons` / `_melee` / `_senses` / `_spells`, `enemy_move` / `_weapons` / `_melee` / `_senses`). They still share no base: gravity, melee, bullets and damage are written twice. Both keep `_physics_process` on the body (`move_and_slide`); cooldowns are tick counts.
- **Players.** One local player, but prepared for more: players have a `pid`, input reads take it (`LocalInput.commands` for others), `Run.character(pid)` makes a second character, screens mark the player busy (`Sim.busy`, `pause_world`), and entities carry `authority`. What step 8 of `MULTIPLAYER_PLAN.md` still wires is listed under R3.
- **World changes.** Doors, containers, locks, buttons, terminals, passages, wall cells, drops, hits, kills, triggers, travel, checkpoints, quests, trades and the stash go through `WorldOps` (applied / requested signals, `Entity.node_of` by eid). Snapshot restores and land building stay direct.
- **One land.** One `active_land` and one fog image; land and fog states are keyed by node instance id.
- **Input.** Gameplay reads the `LocalInput` command. Menus, PipBuck, the console, the HUD and the editor preview read `Input`.
- **Identity.** Authored rows keep `wid`; players, summons, drops and bullets have eids. Door, container, area and trap state is on fields (`prop_state.gd`); meta holds build identity only.
- **Presentation.** The simulation emits `Fx` events. `CamShake` and `room_activity` work from the one camera and player.
- **Data and mods.** Catalogs and tuning are JSON under `assets/data/` with schemas (`DataLib`, `DATA_SCHEMA.md`); direct JSON parsing is left only in saves, room files, the editor and the loaders. Mods overlay data per id, replace art and sound, and add rooms (`MODDING.md`).
- **Water and gas.** Each room record has water, solid and gas layers (`map/room_grid.gd`). Water flow is whole-tile and drains through broken walls and opened doors; solids cache walls and closed doors; gas density is written by room rad and rad sources and read by nothing yet. `area_fx` is rect-based.
- **Lands.** A land is one node built in full (`play_land._build`). Rooms are 48×25 tiles × 40 px on a grid rebased to the min room. Back, sky and trial rooms are folded into the same 2D grid (`back_band`, `trial_row`). `land_gen.build` is one RNG stream, so one cell cannot be rebuilt alone. Collision is merged across room borders. Rooms sleep when far (`room_bounds`) but never unload. A missing neighbour is a solid edge. Float32 world coordinates lose a pixel near ~4000 rooms.
- **Enemy AI.** Units without a catalog `brain` decide, move and shoot through `enemy.gd` and its components (`_decide` → `_act` / `_pursue` / `_aim` / `_gun_try`, int `ST_*` states, timers as body fields). The 25 catalog brains (`unit_brains.gd`) replace that loop but still call the host's senses. Senses are per unit, and the player's noise and observation are single meters in player meta (`foe_noise`, `foe_obs`); `_world_*` statics are shared once per physics frame. Units talk through direct calls, groups and meta; `enemy.gd` has no signals. Coordination today: the faction wake `_budilo` / `_alarm_from`, the room siren plus per-room `kol` reinforcements (`en_spawn.gd`, `land_props._raise_alarm`), emitter and boss summons through `UnitBrain.spawn_unit`, and Thunderhead owning its turrets. Spawning is split across `land_spawn` (build time), `en_spawn` (runtime), `spawn_unit` and boss setup (`_apply_role`). AI tuning is data (`enemies.json`, `enemy_combat.json`, `balance/ai.json`); difficulty scales HP and hearing. There are no squads, attack slots, morale or pacing.
- **Docs and names.** Nearly every script has a `##` header; comments are English. Names that mirror an original field keep it (`GLOSSARY.md`).

## R0. Safety net: done

`python tools/run_checks.py` runs the compile check, boots, room checks, save round trips (`begin`, `surf`, `random_mane`), slot migration and seeded replays (`begin`, `surf`, `perf_arena`) against goldens.

## R1. Shared core: done

`Run`, `Sim`, `Rng`, entity contract with `HitInfo`, `Fx`, slot format 3, `LocalInput`, prop state on fields, no autoload cycles except the WorldState ↔ Run ↔ Rng hub (`tools/autoload_graph.py`).

## R2. Data and modding: done

`DataLib` with schemas, tuning and content tables in `assets/data/`, player options from data, mod overlay (`MODDING.md`, user rules in `PORT_RULES.md` "Modding"), docs set, headers, long functions split, player and enemy components. Glossary rows are checked against the original; names that mirror an original field keep it.

## R3. Character and commands (MP)

Follows `MULTIPLAYER_PLAN.md` steps 2–4 and 8; listed here for order.

Steps 1–5 are done. What `MULTIPLAYER_PLAN.md` step 8 still wires, each in one place:

- **Second player's state.** `Run.character(pid)` already makes one per player. Code that should act on any player (damage, pickup, trade) switches from the autoload facades to `player.character()` / `Run.character(WorldOps.actor)`; the facades stay for the local UI.
- **SATS and loot rules** (user decisions at the end of `MULTIPLAYER_PLAN.md`). SATS: the `sats` entry in `Sim.PLAYER_REASONS` with `Sim.pause_world` decides whether it stops the world. Loot: `WorldOps.take_loot(drop, pid)` reaches `ground_loot.pickup` / `land_props.grant_dropped` with `WorldOps.actor` set; the rule goes there.
- **Network.** Connect `WorldOps.requested` (client to host) and `LocalInput.set_command` (remote input); set `WorldOps.authority` and entity `authority` false on clients.

## R4. Cell grid (FL)

Done (`ARCHITECTURE.md` "Room grid"). Next on this line is `TODO.md` §12.5: a simulator in `Sim` for active rooms behind one off-by-default switch.

## R5. Chunked lands (END; also MP load positions)

1. **Room address** separate from the y-fold. A room is `(chunk, lx, ly, layer)`, where `layer` is `main`, `back`, `sky` or `trial`. Fixed lands keep `_layout` to map addresses to pixels; chain chunks use their own origin. `play_land.gd`, `land_spawn.gd`, `room_bounds.gd`, `land_memory.gd`. M, medium.
2. **Per-cell generation.** `land_gen` derives each cell's RNG from `hash(chunk_seed, lx, ly)` and stores the cell record (template, mirror, frame, doors, XP). A cell can then be rebuilt alone. Freeze-on-first-plan (`build_value`) moves to per chunk. M, medium (lands reshuffle once; tag old saves so a loaded land is not rebuilt).
3. **Per-room nodes.** Each room is one subtree for tiles, collision, actors and dressing. Merge colliders only inside a room, and let the joint between two loaded rooms own the seam wall. `land_props` splits into a land-wide service (alarms, uid index, scripts) and per-room actor holders. Unloading a room runs `capture` for that room into land memory. L, high.
4. **Fog and maps per room.** Fog textures per room (saves already are), with no `map_px` image. The PipBuck map draws from per-room tiles. Camera limits come from the loaded room set. Fog, audio, vendors and `room_activity` key by room address, not node instance id. M, medium.
5. **Streaming.** Load rooms within `CHASE_REACH` (2) of every load position (`Run.players()`), and unload beyond 3 after capture. Treat an unloaded room as solid only while its load is pending (async build on a worker, nodes added on the main thread). Cross-room references (doors, triggers, alarms, scripts, chasing units, bullets) resolve through entity ids and tolerate an unloaded target. L, high.
6. **Chain and distance.** `goto_next_level` appends a chunk aligned to the between room's right exit instead of `forget_land` + `queue_free`. The `landStage` readers (plan freeze, plant height, `maxlevel`, trials, `exit` vs `exit1`, checkpoint teleport, title) take chunk distance from one function. Fixed lands keep `Travel.land_stage`. M, medium. This is where `TODO.md` §12.1 starts.
7. **Coordinates.** Gameplay addresses use room plus tile integers. Keep the render origin near the camera's chunk (shift `Run` world origin when the player crosses a chunk) so float32 never sees large x. S–M, medium.

## R6. Enemy directors (AI)

The default directors reproduce today's behaviour exactly (the replay check must match). New behaviour is opt-in per mode or difficulty through data, and needs a `PORT_RULES.md` entry when turned on by default. Director tuning lives in `assets/data/ai/*.json` beside `balance/ai.json`, so mods can change it.

1. **AI blackboard.** An `AiWorld` service moves the `_world_*` statics (room, vision, sneak, grenade list) and the player's `foe_noise` / `foe_obs` / `foe_demask` meters out of `enemy.gd` and player meta, with the same math. It holds one set of meters per player (`Run.players()`) and per-faction shared knowledge: last seen position and time of each target, alarm state per room. Units read it instead of the meta. S–M, low.
2. **Unit events.** `enemy.gd` and the brains emit `saw`, `lost`, `heard`, `damaged`, `died`, `alarmed` and `spawned` from `_on_seen`, `_lose`, `_listen`, `_apply_damage`, `_begin_death`, `_alarm_from` and the spawn paths, through the `Fx` bus (an AI channel). Nothing listens yet except a debug log. S, low.
3. **Unit registry.** Stable entity ids for every unit, with indexes by room, faction and squad kept up to date on spawn, death and room change. `_budilo`, `_nearest_foe`, turret `find_cel`, pet loops, alarm boxes and zombie heal read the index instead of scanning the `enemies` group. Also removes the hot scans in `TODO.md` §8.3. S–M, low.
4. **Spawn director.** One `SpawnDirector` per land (per chunk in R5) owns every way a unit appears: build-time plans (`land_spawn._set_random_units` / `_random_unit`, same tables), runtime room spawners (`en_spawn` `signal_room` / `tick` / `spawn`), siren reinforcements (`land_props._raise_alarm`), and summon requests from emitters, vortex, bosses and Thunderhead (`UnitBrain.spawn_unit`). The default policy keeps `kol`, the child caps, timers and the emerge tween. Later policies add a budget per room or distance, pacing (intensity rises and falls), ambush placement out of sight, and composition by distance and difficulty (feeds R5.6). Uses the `Rng` `spawn` stream. M, medium (alarm timing and the emerge tween).
5. **Brain interface.** Every unit runs `control()` on a `UnitBrain`. The generic loop leaves `enemy.gd` for `brain_generic.gd`, which keeps `ST_*`, the consts and the call order (`_decide`, `_act`, `_pursue`, `_aim`, `_gun_try`). `enemy.gd` becomes the motor and body: movement, guns, damage, animation, water. Brains get their senses from `AiWorld` and their orders from the tactics director (step 6). Tuning stays in `balance/ai.json`. L, high: do it after 1–4, with the replay as the gate, building on the enemy components (`enemy_move.gd`, `enemy_weapons.gd`, `enemy_melee.gd`, `enemy_senses.gd`).
6. **Tactics director.** A `TacticsDirector` per faction per land groups awake units into squads (by faction and room first), assigns roles (point, support, flanker, sniper) and hands out orders the brains may take: move to a position, hold, suppress a spot, fall back, regroup, call help. **Attack slots:** a unit asks for a slot before `_gun_try` or a melee swing. The default grants every request, so nothing changes; a policy can cap simultaneous attackers per target. The default policy is `_budilo` (radius, faction, shock, one wake) and nothing else. M, medium.
7. **Behaviour modules.** Optional per brain id or per policy, off unless the catalog or the mode asks: flank (path to a side cell out of the target's facing), suppression fire at the last known position, morale and retreat (by HP, losses and squad size), search patterns around the last seen position, cover use (needs cover cells from the R4 `grid_solid` layer), and coordinated alarm runs to the siren. Utility scoring or a small behaviour tree per module; one decision per unit per 10 ticks like today's `SENSE_INTERVAL`. L, high if any module becomes a default.
8. **Debug view.** A console toggle that draws squads, roles, orders, slots, last-seen markers and the spawn budget per room. S, low. Needed before tuning 6–7.

## Order and dependencies

| Step | Needs | Goals |
|---|---|---|
| R0–R4 | done | all |
| R3 step 8 wiring | networking, user decisions (`MULTIPLAYER_PLAN.md`) | MP |
| §12.5 simulator | R4 | FL |
| R5.1–5.2 | — | END |
| R5.3–5.5 | R5.1 | END MP |
| R5.6–5.7 | R5.5 | END |
| R6.1 blackboard | — | AI MP |
| R6.2 unit events | — | AI MOD |
| R6.3 unit registry | — | AI, perf |
| R6.4 spawn director | R6.3 | AI END MOD |
| R6.5 brain interface | R6.1–6.3 | AI MOD |
| R6.6 tactics director | R6.5 | AI |
| R6.7 behaviour modules | R6.6, R4 `grid_solid` for cover | AI |
| R6.8 debug view | R6.4 | AI |

R5.1–5.2 and R6.1–6.3 can start now and run side by side; every line stops for a failing check. The gameplay plan (`TODO.md` A–H) continues in parallel. Prefer correctness fixes that land on the new seams over doing them twice.
