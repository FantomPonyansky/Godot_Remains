# Architecture

Godot 4.7.2. Gameplay state sits on autoloads, and things in the world are duck-typed entities. The autoload list, load order, and who calls whom: [`AUTOLOADS.md`](AUTOLOADS.md). This file is the map for the shared core (R1) plus where a save and a check live.

## Autoloads

Load order in `project.godot` is `_ready` order. An autoload's `_ready` uses only autoloads above it. `WorldState` is first after `UserDir`. `InputBindings` is before `LocalInput`. `Effects` and `Inventory` are before `GameState`. `Rng` is after `Sim`. `Fx` is after `Rng`.

`python tools/autoload_graph.py` reads `project.godot` and the autoload scripts (comments ignored) and prints each dependency list and the strongly connected sets. The only cycle is `Rng`, `Run`, `WorldState` (`WorldState` calls `Rng` and `Run`; each of those calls `WorldState`). `--write` refreshes the Depends on / Depended by / cycle tails in `AUTOLOADS.md`. The script prints the sets; it does not exit non-zero when a new cycle appears.

`Run` is the player list (`players`, `local_player`, `by_id`, `nearest_player`), the active land, and the local camera. `register_player` stamps eid `p<id>` starting at 1. `land()` returns the cached land while it is in group `active_land`, otherwise the current member of that group. `torso_hp_mult` and `player_dead` are written by `GameState`. `alicorn` is written by `ScriptsEngine`. `sost`, `cur_land_id`, and `exit_state` are written by `Travel`.

## Sim tick

`Sim` (`scripts/autoload/sim.gd`) is a 30 Hz clock. When physics is 30 Hz, one physics frame is one tick. Any other rate accumulates time and runs at most `MAX_CATCH_UP` (5) ticks per callback.

Phases, in order: `INPUT`, `PLAYERS`, `UNITS`, `PROJECTILES`, `WORLD`, `STORY`, `EFFECTS`, `PRESENTATION`. Callables in one phase run in registration order. `PROJECTILES` has no subscriber.

Registered today:

| Phase | Who |
|---|---|
| `INPUT` | `LocalInput._freeze` |
| `PLAYERS` | `GameState` |
| `UNITS` | `Pets` |
| `WORLD` | `Travel`, `fog`, `water_flow` |
| `STORY` | `ScriptsEngine` |
| `EFFECTS` | `Effects` |
| `PRESENTATION` | `AudioManager`, `CamShake` |

`tick` counts every step, including a paused step that only runs `PRESENTATION`. `run_tick` counts steps whose gameplay phases ran, and resets on `WorldState.run_reset`. `frame_steps` is how many gameplay steps the physics callback just ran (1 at 30 Hz, 0 while paused). `ticks_from_ms` is `round(ms * 30 / 1000)`. `Sim` is `PROCESS_MODE_ALWAYS`, so the clock runs while the tree is paused.

Pause is a set of reasons. `set_paused(on, reason)` adds or removes one; the tree stays paused while any remain. `get_tree().paused` follows the set. `pause_changed` is what `GameState.paused` listens to. Reasons in use: `pipbuck`, `menu`, `console`, `dialogue`, `craft`, `sats`, `wheel`, `intro`, `stand`, `game`.

The screen reasons (`PLAYER_REASONS`: `pipbuck`, `menu`, `sats`, `dialogue`, `stand`, `craft`, `wheel`) also mark a player busy: `set_paused(on, reason, pid)` with pid 0 for the local player, read by `busy(pid)`. They pause the world only while `pause_world` is true (single player); the other reasons always pause.

While any reason is set, every phase except `PRESENTATION` is skipped. `AudioManager._tick` still runs; unit-art stepping waits on `Sim.paused()`, and the music fade does not. `CamShake._sim_tick` returns immediately when paused.

## Local input

`LocalInput` (`scripts/autoload/local_input.gd`) stays in process while the tree is paused. It samples actions in `_input` and `_process`, and at phase `INPUT` freezes a `PlayerCommand`: `tick`, `held`, `pressed`, `released`, `strength`, `aim`.

`held`, `just_pressed`, and `just_released` read that command inside a physics frame. Outside physics they read the live device, and a `_process` reader sees each edge once. `axis` and `aim` read the command. A press and a release between two ticks are both edges; `held` is the latest state. `inject_down` and `inject_up` write a synthetic edge; the next freeze still has it, and a `_process` reader sees it on that frame.

Every reader takes an optional player id (the player's `pid`, set by `Run.register_player`); player code passes its own. Id 0 or `Run.local_id()` reads the local command as above. Any other id reads `commands[pid]`, set with `set_command` and dropped with `drop_command`; a player without one gets an empty command.

`Sim` does not run `INPUT` while paused, so a paused tick freezes from `_physics_process`. Edges are kept when the sim is live, and when the local player's SATS node is active. Any other pause drops them.

## Rng

`Rng` streams: `build`, `spawn`, `loot`, `ai`, `combat`, `tactics`, `fx`. All but `fx` reseed with `hash([run_seed, land_id, stream_name])` on `WorldState.run_reset` and when the active land changes (`bind_land`). `fx` is `randomize()`d per run and is not reseeded per land.

`seed_build` sets the `build` stream to a land's stored seed. `randf_legacy` is one `randi` narrowed to float32, the global `randf` sequence for that seed. `for_land` returns a fresh generator and does not move the active streams. Draws on a named stream: `randf`, `randi`, `randf_range`, `randi_range`, `randfn`, `pick`, `shuffle`. An unknown name pushes an error and draws from `fx`.

## Entities

`scripts/entity/entity.gd` is not a base class. A node meets the contract when it has `eid`, `kind`, `faction` (units keep `fraction`; `faction_of` reads both), `take_hit(hit)`, `snapshot()`, and `restore(data)`. `kind_of` uses the property or meta, then the groups `player`, `story_npc`, bullets, traps, `ground_loot`, enemies / allies / pets, and a door meta. Anything else with `is_alert` is a unit; the rest are props.

`Entity.node_of(eid)` finds a live node by eid (claimed nodes and players).

## World operations

`WorldOps` (`scripts/autoload/world_ops.gd`) is the one entry for world changes:

| Group | Ops | Goes to |
|---|---|---|
| Land objects | `open_door`, `unlock`, `pick_lock`, `open_container`, `break_object`, `damage_object`, `break_cell`, `press_button`, `use_object`, `use_terminal`, `pass_through`, `run_actions` | the target's `land_props` (parent walk) |
| Entities | `take_loot`, `damage`, `kill` | the target |
| Run | `set_trigger`, `travel`, `activate_checkpoint` | `Travel` |
| Story | `add_quest`, `close_quest`, `inc_quests`, `add_note`, `set_npc_rep` | `Story` |
| Trade and stash | `trade`, `sell`, `sell_all`, `take_weapon`, `take_all_tasks`, `store_armor` | `Vendors`, `Stash` |

A target is a node or an eid. Owners register handlers in `_ready`, so `WorldOps` depends on no owner. After a change it emits `applied(op, args)`. With `WorldOps.authority` off, or a target without authority, it only emits `requested`. Ops a player does take `pid`; while the handler runs it is `WorldOps.actor`, and that player's state is `Run.character(actor)`. `WorldOps.applies(op, args)` is the same gate for host-only code: `ScriptsEngine.start` returns on a client.

Direct writes that stay: snapshot restores, land building, `Resistances` passing a resolved hit back to its target, a script op running inside an op that already went through (`_on_button` runs its terminal), and debug commands. Loot a change spawns is made inside that change. Moving bodies (thrown crates, traps, falling drops, units, bullets, players) are simulation and branch on `authority` in their ticks.

`Run.character(pid)` gives a second player its own character; the facades and `character.json` stay on the local one. `player.character()` returns its own.

Each entity script has `authority` (true in single player; `Entity.has_authority` treats a node without it as true). With it false, the player, unit and bullet physics ticks return before simulation, and a bullet's fade still runs.

Ids:

- An authored `wid` is the eid (`eid_of` reads the property, then meta `eid`, then meta `wid`).
- A player is `p<id>` from `Run.register_player`.
- Anything else claimed with `Entity.claim` gets `<owner eid>/s<n>` from `Run.alloc_eid`. An empty owner is `run`. The counter is the run provider `eids` (`{"version", "next"}`).

`HitInfo` (`scripts/entity/hit_info.gd`): `amount`, `tip`, `source`, `source_eid`, `knock`, `direction`, `crit`, `sneak`, `weapon_id`, `bullet_id`, `effect_id`, `effect_amount`, `effect_chance`, and flags `explosion`, `melee`, `contact`, `tt`, `resisted`, `from_bullet`, `from_player`, `pier`, `desintegr`. Builders `make`, `plain`, `touching`, `melee_hit`, `dot`, and `of_bullet` do not draw `Rng`. `touching` marks `contact` so knock comes from the touching body. `tt` is damage over time (no armour, no shock). `of_bullet` copies the projectile's type, weapon, eid, dop, pierce, and desintegr; the 0.7–1.3 roll stays inside `enemy.take_hit`. `Resistances.apply(target, amount, damage_type)` builds one with `make` and scales it in `apply_hit`.

`snapshot` / `restore`: the player stores `GameState.get_state()` and `get_pools_state()` (the `game` and `body` providers). An enemy stores `Entity.captured`, which calls `land_props.capture_one`, and restores through `apply_one`. Doors store `PropState.door_record`.

## Room grid

`map/room_grid.gd` keeps three 48×25 byte layers (index `j * 48 + i`) on each room's `RoomFlags` record, so they live and are saved with it:

| Layer | Bytes | Written by | Read by |
|---|---|---|---|
| `grid_water` | 0 dry to 255 full; wet when ≥ 128. Empty when the room has no water. `grid_water0` is the built copy. | `RoomFlags.row_of` (tile `*` and `wlevel`), `water_flow` | `RoomFlags.water_at` / `in_water` / `water_y`, `room_look`, `fog`, `unit_brain`, `water_flow` |
| `grid_solid` | 1 live wall cell or closed door, 2 wall cell that broke, 0 free | filled on first use from `Solids` walls (`cell_rects`) and `land_props._doors`; dropped by `water_flow.forget_solids` when a wall breaks or `DoorArt` changes a door | `water_flow` (a free cell still asks physics for crates and lifts) |
| `grid_gas` | density, 4 per unit of rad per tick, capped at 255 | room `rad`, `rad_source` (radiation, gas and pink-cloud boxes; taken back when it leaves) | nothing yet |

Water flow stays whole-tile: cells are 0 or 255, and the land memory flag `water` saves the changed cells as 0 / 1 against the built rooms. An opened or broken door wakes the water like a broken wall (`land_props._on_world_op` on `WorldOps.applied`, `water_flow.door_opened`). `area_fx` stays rect-based. A partial-level simulator (`TODO.md` §12.5) would write levels between 0 and 255 into `grid_water` behind its own switch; until it is on, saves keep the 0 / 1 delta.

## Room addresses

`map/room_address.gd` names a room `chunk:lx:ly:layer` apart from where `play_land._layout` folds it into the pixel grid. `layer` is `main`, `back` (z = 1), `sky` (a sky block room and its filler parts; `lx`/`ly` are the block's map position × 1000 plus the part offset) or `trial` (`lx` is the trial column). Fixed lands are chunk 0. `stamp` writes `chunk`, `layer` and `addr` on each room row and the land metas `room_addr` (cell → address) and `room_cell` (address → cell); `at`, `cell_of`, `layer_at`, `twin` (main ↔ back) and `group_at` read them. `room_bounds.is_active` wakes the back or front twin of the player's room and the neighbours in the same group (the main map or one sky block); back and trial rooms are groups of their own. Room state is still keyed by pixel cell until R5.4.

Generated lands draw per cell: `LandGen.cell_rng(chunk_seed, x, y, z, salt)` is `hash` of those, salt 0 for `land_gen` (mirror, template pick, enemy type, the cell's right and down doors, XP spots) and 1 for `land_spawn._plan_random` (the room's objects and units, z 1 for its back room; cell (−1, −1) for the land-wide trial picks). `chunk_seed` is the land's stored build seed. The template bag (`kol`) and used trials stay land-wide, so a cell's draws do not depend on other cells but its template choice still does. The first plan stores a record per cell in the build info (`cells`: `t` template, `m` mirror, `r` ramka, `d` setdoor picks, `xp`, `w` water, `e` enemy type); a rebuild replays the records, so a land keeps its layout even if the seed or the generator changes. Build info carries `gen` (`LandGen.GEN_VERSION`, 2); on load, a generated land below it loses its memory and checkpoint spot (`WorldState.replanned`, `Travel.set_state`). Fixed lands still draw `randf_legacy` on the build stream.

Room ownership: the land roots stay flat (`Solids`, `Platforms`, `Ladders`, `Slopes`, `Doors`, `RoomDressing`, `Actors`), because bullets, drops and spells tell colliders apart by their parent's name. `map/room_nodes.gd` indexes which rooms own a node (`own`, `nodes_of`; meta `rooms`): every collision body is owned by each room its mesh rect (meta `tiles`, a `Rect2i` in tiles) covers, so a wall merged across a border belongs to both rooms. Doors are owned by their room; `dressing_of` finds tile canvases, back walls and dim layers by their `room_x` / `room_y`. `play_land` keeps the tile maps it meshed (`_cell_maps`) and the loaded set (`set_loaded`, `is_loaded`); `remesh(rooms)` frees the bodies those rooms own and meshes their tiles again inside the loaded rooms, then breaks remembered cells again (`land_memory.restore_broken_in`) and drops the grid's solid cache. A whole build is meshed in one go as before. `land_props.unload_room(cell)` captures the room's remembered nodes, runtime units and drops into land memory and frees them (queued rows of that room wait there too); `reload_room(cell)` spawns them back through the plan rows by wid. Saves made while a room is out include its records, runtime units and drops. `save_roundtrip_rnd` cycles one far room and compares memory and collision tiles.

Streaming (`map/room_stream.gd`, generated lands only): every 0.25 s the rooms within `LOAD_REACH` 2 of any player (`Run.players()`, plus the back or front twin of a player's room) are loaded and rooms beyond `UNLOAD_REACH` 3 unload their actors, up to 40 freed nodes per tick; rooms whose rows never spawned park for free, so a land comes up with only its near rooms spawned. Loads queue rows on `land_props._pending`, and rooms next to the player spawn on the next frame. Collision, doors and dressing stay built. `RoomStream.enabled` or the user arg `nostream` turns it off. Fog saves key rooms by address (`fog._cell_keys` reads both); music keys the room by address; `game._bounds` takes camera and sky limits from `play_land.bounds_px` (the loaded rooms).

Chunks: `WorldState.chunk_info(land_id, chunk)` is a chunk's build info (chunk 0 is the land's own; others live under `chunks` with a seed from the land's). `begin_build(land_id, chunk)` sets `LandGen.chunk` and `chunk_seed`, so frozen inputs (`build_value`) and cell records (`build_cells` / `keep_cells`) are per chunk. `Travel.land_stage(id, chunk)` adds the chunk distance. Land memory names rows with `chunk` > 0 apart (`c<n>|` prefix). `Travel.chain_lands` (off) sends `goto_next_level` to `play_land.append_chunk`, which is a stub returning false, so the land is replaced as before.

## Player and enemy components

The player and enemy bodies keep the node, the tick sequence in `_physics_process`, damage, and `snapshot` / `restore`. Behaviour sits in component scripts on the same node, each holding a back-reference to the body:

- Player: `player_move.gd`, `player_weapons.gd`, `player_melee.gd`, `player_senses.gd`, `player_spells.gd`, `player_water.gd`.
- Enemy: `enemy_move.gd`, `enemy_weapons.gd`, `enemy_melee.gd`, `enemy_senses.gd`, `unit_water.gd`. AI brains (`unit_brain.gd`, `brain_*.gd`) drive the body. The body calls its brain through `_ai()`: the unit's `UnitBrain` (`_brain`), or the generic brain (`units/brain_generic.gd`). Both answer the same methods: `physics`, `start`, `release`, `command`, `dop_test`, `targets_player`, `held` / `acts_held`, `animate` / `flips_sprite`, `levit_pull`, `on_damage`, `hit_anim`, `on_die`, `died`, `drop_loot`, and `always_active`. `_brain` stays the custom brain only; code that looks for a custom method such as `hack` or `use_object` reads it.

The generic brain is the original Brain:

- the downed/stunned/senses/move dispatch;
- `decide`, `pick_attack` and `act`;
- `aim`, `reaim`, `hold_if_close` and `back_off_if_crowded`;
- `hold` and `pursue`, which run the WalkMotor step and then the attack tick;
- `tick_attacks`, and the ground-ally and pet loops.

The components are the motor and attacks: `enemy_move` (step, `_patrol`, `_hold`, `_pursue`, jump, climb, fly) and `enemy_weapons` (`_gun_try`, fire, arm). The body forwards `_decide`, `_act` and `_tick_attacks` for the components.

Other scripts call the body; it forwards to the component. New code inside a component calls sibling components through the body.

## AI blackboard

`AiWorld` (`scripts/autoload/ai_world.gd`) holds what the enemies share. `AiWorld.meters(player)` holds one `Meters` per `pid`: `noise`, `obs`, `is_obs`, `demask`. A new player node with the same pid starts from zeros. `AiWorld.facts(player)` holds the per-tick reads of that player (`room`, `vis_mult`, `sneak`, `stealth`, `visi`, `crit_invis`), which `enemy_senses._tick_world_senses` refreshes once per tick. `room`, `danger` (live grenades) and `known_shots` are land-wide. `_budilo` still sets the unit's own `foe_noise` meta. Faction knowledge: `note_seen` / `last_seen` (from `_on_seen`) and `note_alarm` / `alarmed_at` (from `_alarm_from` and the siren under `AiWorld.SIREN`); it is cleared on `Travel.land_entered`, it is not saved, and nothing reads it yet.

`Units` (`scripts/autoload/units.gd`) is the unit registry: a cached copy of the `enemies` group with the same units in the same (tree) order, and the same list bucketed by 1920×1000 room. It rebuilds once per physics tick, or after `Units.touch()`. An enemy calls `touch()` on entering or leaving the tree, and the code that takes it out of the group (`_ready` for friendlies, death, `brain_destr`, `brain_thunderhead`) calls it too; new group changes must call it as well. The queries:

- `enemies()`: the whole list, read only;
- `in_rect(rect)` and `near(at, radius)`: candidates from the rooms touched, padded by one room so units that moved this tick are still included, returned in group order. Callers keep their own exact test.

`max_ear` bounds the `_budilo` reach. Ids are the existing eids (`Units.of(eid)` = `Entity.node_of`). On `Units` now: enemy and trap `_budilo`, `_nearest_foe`, zombie heal, `_hurt_radius`, turret and pet target search, pet `_battle`, alarm buttons, siren wake, trap triggers and jaws, `audio_manager._watch_units`, `aim_cursor._foe_tracking`, the grenade sensor, SATS targets, the blast and slow spells, moonblade, the inhibitor, thrown crates, pet orders, contact knockback, electric traps, and the wall-span hit point. Filter by faction at the call; squads are on the tactics director.

## Spawn director

`SpawnDirector` (`scripts/ai/spawn_director.gd`) is one per land, held by `land_props` as `_en_spawn`. Every way a unit appears goes through it and asks its `SpawnPolicy` (`scripts/ai/spawn_policy.gd`):

- build plans: `land_spawn._set_random_units` asks `room_count(loc, tip, kol)` for each `kol_en` tip and for `"hidden"`;
- the room spawners in `en_spawn.gd` (the siren chain `alarm`, allact `trigger`, trial `wave`) ask `allow_room(key, source, left)` before spending the room's kol, and the siren asks `alarm_delay(key, delay)`;
- brain summons (`UnitBrain.spawn_unit` → `SpawnDirector.summon`) ask `allow_summon(owner, uid)`; with no land (a test arena) they use the current policy.

The base class is the default: it grants everything, changes nothing and draws no random numbers. `assets/data/ai/spawn.json` (mods override it) may name a subclass in `script`. `SpawnPolicy.use(p)` swaps it, and `use(null)` reloads the config. A policy that draws randomness uses the `spawn` stream. The director counts what appeared in `by_source` and `by_room`, for the R6.8 view. `en_spawn` gets the policy and a note Callable rather than the director, so the two RefCounted objects do not hold each other.

Console `aiview` toggles `AiView` (`scripts/ai/ai_view.gd`), an overlay on the current scene that only reads, redrawing at 10 Hz. It draws:

- per unit: its state and fraction, and a line to its goal while it tracks;
- `AiWorld` last-seen marks;
- rooms alarmed within the last 10 s;
- per spawner room: kol left and units spawned;
- per squad: spokes to its members, `sq<id> f<fraction> n<count>`, each member's role and order (dashed to the order's spot), and the slots granted and denied near the player.

## Tactics director

`TacticsDirector` (`scripts/ai/tactics_director.gd`) is one per land, made by `land_props` and published as `AiWorld.tactics`. Every `regroup_ticks` (default 30) it groups awake, live, hostile units from `Units.enemies()` into squads by fraction and room, then asks its `TacticsPolicy` (`scripts/ai/tactics_policy.gd`):

- `roles(squad)`: a unit-to-role map, roles from `TacticsPolicy.ROLES` (point, support, flanker, sniper). `roles_for(unit)` reads which roles a unit type may take from `tactics.json` `units` (by catalog id; `enemies.json` stays the original's);
- `order(unit, squad, role)`: `{kind, at, ...}`, kind from `TacticsPolicy.ORDERS` (move, regroup, fall_back, hold, suppress, call_help); the director drops other kinds with a warning. The order goes to the unit's brain (`_ai()`) only if its `takes_order(kind)` says yes, and is cleared when the policy stops giving it. The generic brain takes `hold` (`pick_attack` holds) and `move` / `regroup` / `fall_back` (goal = `at`); `UnitBrain` takes none until a catalog brain overrides it. An empty order is today's behaviour;
- `grant(unit, target, kind, attackers)`: asked through `TacticsDirector.ask` in `brain_generic.tick_attacks` before the gun, melee and ram attacks, with the count already granted on that target this tick. Catalog brains can ask the same through `UnitBrain.attack_slot(kind, target)`; none does yet.

A squad carries `key` (fraction and room, stable across regroups), `members`, `centre`, `target` (the player a member tracks) and `losses` (deaths of that fraction in that room on this land, counted at regroup). Squads are not saved: they are rebuilt from unit state. A policy that rolls uses the `tactics` Rng stream.

The base class gives no roles or orders and grants every slot, so the default changes nothing. Config `assets/data/ai/tactics.json` (`policy`, `script`, `regroup_ticks`, `units`); `TacticsPolicy.use(p)` swaps it, `use(null)` reloads it. `_budilo` stays the faction wake. Faction and squad indexes live here, not on `Units`.

## Prop state

`scripts/prop_state.gd` holds door, container, area, and trap use-timer fields. `put`, `getv`, `hasv`, `clear`, `absorb`, `record`.

`put` writes the property when the node has `_field_set` and that key. Nodes without it (walls, platforms, slopes, room edges, NPCs, checkpoints, unit brains) keep the key in meta. `hasv` is true when `put`, `absorb`, or a `set_meta` from before `_ready` wrote that key. `getv` reads the property when the set-mark is on, else meta, else the caller's fallback. Builders may `set_meta` before `_ready`; `absorb` copies those keys once and drops the meta. `record` is the row land memory stores.

Field names: `door_open`, `lock`, `hp`, `thre`, `breakable`, `dead`, `usable`, `blocks_sight`, `mine`, `hackable`, `locktip`, `lock_hp`, `lock_level`, `lock_att`, `mine_tip`, `allact`, `allid`, `once`, `act_time`, `lock_key`, `keyloss`, `fun`, `sec`, `user_action`, `hold_use`, `spent`, `opened`, `box_hp`, `vis_state`, `enabled`, `touched`, `box_open`, `close_at`, `cool`, `taken`, `damage`, `ceiling`, `prize_locked`.

Meta that stays meta: build identity, trap `dead` (the remembered flag), drop `taken`.

## Fx

`Fx` (`scripts/autoload/fx.gd`) emits `sound`, `shake`, `float_number`, `notice`, `particles`, `blood`, and `flash`. Each event carries the source eid and `local` (true for a world event, or one whose player is the local player). Listeners run in the same call. `SfxBank`, `CamShake`, the HUD, and `UnitFx` play them. A later peer skips HUD events whose `local` is false.

The AI channel `Fx.ai(kind, unit, opts)` emits `ai_event(kind, eid, at, opts)`. It carries sim facts, so listeners must not change the sim. The kinds:

- `saw`, when tracking starts;
- `lost`, when the tracking memory runs out;
- `heard`, on each heard look;
- `damaged`, from `_apply_damage`;
- `died`, from `_begin_death`;
- `alarmed`, from `_alarm_from`;
- `spawned`, from enemy `_ready`, so a room reloaded by the stream spawns again.

The only listener is the console toggle `ailog`.

`Fx.prep` plays the weapon prep loop. `Fx.quake_left` is the quake timer `CamShake` exposes. `blood` also counts as `particles`.

## Run document

A slot is format 4 (`SaveSlots.FORMAT`). Files: `character.json` (the player's character), `run.json` (run providers), `world.json` (lands and world providers), `slot.cfg` (the load menu). The autoloads still keep `inventory.cfg`, `progression.cfg`, `condition.cfg`, and `body_pools.cfg` in the run dir for boot.

The character state lives in `scripts/character/` (`Run.character()`: body, inventory, effects, progression, magic binds, condition, pets, favourites, stash). `GameState`, `Inventory`, `Effects`, `Progression`, `MagicBinds`, `Condition`, `Pets`, `Favorites` and `Stash` keep their fields as forwarding properties onto it.

`character.json` version is `WorldState.CHARACTER_VERSION` (1). Apply order (`CHARACTER_ORDER`):

| Provider | What it stores |
|---|---|
| `progression` | level, skills, perks |
| `condition` | weapon and armour wear |
| `inventory` | carried items |
| `body` | head, torso, legs, blood, rad, stam, breath, mana |
| `pets` | phoenix and owl |
| `game` | health, magic, score, ammo |
| `stash` | stash, hidden items, stored armour |
| `effects` | active effects |
| `favorites` | favourite slots |

A provider id in `CHARACTER_ORDER` goes to the character registry whether it registers through `register` or `register_run`, and a format 3 `run.json` or `world.json` that still holds one is routed there on load.

`run.json` version is `WorldState.RUN_VERSION` (2). Providers: `vendor_meta` (vendor money and land xp), `eids` (next spawn counter, registered from `Run`), `mods`.

`world.json` version is `WorldState.VERSION` (2). Besides land snapshots it has providers `vendors`, `alicorn`, `story`. Each blob carries its own `version`. A provider that is not registered this run is kept and written again.

Signals on `WorldState`: `run_reset` (a new run), `restored` (a slot applied), `resumed` (the saved spot is applied, or given up). A land snapshot is taken by `land_props` when the land leaves the tree and when a slot is saved. A rebuild uses the per-land seed stored here.

`SaveSlots` also accepts format 3 (no `character.json`), format 2 (the cfg copies plus `world.json`) and format 1 (no `world.json`: the player loads and the run starts in the stable). Slot 0 is the autosave, written on leaving to the main menu and on a land change. Slots 1–10 are the PipBuck slots. A hardcore run autosaves into the slot chosen at the start (`World.autoSaveN`).

## Checks

`python tools/run_checks.py` runs one sandbox user dir per check, writes `tmp/checks/<name>.log`, prints `CHECK <name>: ok N fail M`, and exits 1 on any failure. Options: `--list`, `--only`, `--skip`, `--import`.

- `compile_all`, `boot_game`, `boot_menu`
- `room_xml` (fails when mismatches go above 11), `editor_validate`, `room_pool`, `room_codec`
- `save_roundtrip` (begin), `save_roundtrip_story` (`land=surf`), `save_roundtrip_rnd` (`land=random_mane`)
- `save_migrate` (fixture `tests/fixtures/slot_format2`)
- `replay`, `replay_story`, `replay_arena`

Replays use `--fixed-fps 60` and `golden=godot/tests/fixtures/replay_golden_<land>.txt` for `begin`, `surf`, and `arena`. `replay_check.gd` records a missing golden (one hash per line) and compares an existing one. `EXPECT_SAME` fails the run when the two passes drift or the golden mismatches. `xfail` in a `CHECK` line is a known gap, not a failure.

## Data loader

`scripts/data_lib.gd` (`DataLib`, static, works in `-s` runs) reads every `res://` JSON asset file:

- `DataLib.load(path)`: parsed once per process, cached, deep read-only (a write is an engine error).
- `DataLib.copy(path)`: writable deep copy for code that changes the table.
- `DataLib.rows(path)` / `DataLib.by_id(path)`: the same data as an array of rows with `id`, or an `id`-keyed object.
- Schemas in `scripts/data_schemas.gd` (required keys, types, unique ids). A miss is reported once with file and id through `push_error`, and `push_error` fails a check.
- `_merge_overlays(path, base)` merges enabled mods' `data/` files over a copy of the built-in value (`MODDING.md`); the result is validated and cached read-only like the rest.

Tuning lives in `assets/data/balance/` (`player`, `ai`, `difficulty`, `progression`, `sats`, `water`, `vision`, `options` for player-option defaults). Content tables that extend a catalog sit next to it (`unit_loot`, `species_fractions`, `unit_parts`, `door_opac`, `unit_classes`, and `maps/` for crate art, door art, held-prop mass, lock templates, tile catalog, world-map marks). Scripts read them once into members, not per frame.

Saves, settings, room files and the editor's open file are read directly, not through `DataLib`.
