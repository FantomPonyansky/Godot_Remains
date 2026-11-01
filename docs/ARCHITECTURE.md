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

`Rng` streams: `build`, `spawn`, `loot`, `ai`, `combat`, `fx`. The first five reseed with `hash([run_seed, land_id, stream_name])` on `WorldState.run_reset` and when the active land changes (`bind_land`). `fx` is `randomize()`d per run and is not reseeded per land.

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

## Player and enemy components

The player and enemy bodies keep the node, the tick sequence in `_physics_process`, damage, and `snapshot` / `restore`. Behaviour sits in component scripts on the same node, each holding a back-reference to the body:

- Player: `player_move.gd`, `player_weapons.gd`, `player_melee.gd`, `player_senses.gd`, `player_spells.gd`, `player_water.gd`.
- Enemy: `enemy_move.gd`, `enemy_weapons.gd`, `enemy_melee.gd`, `enemy_senses.gd`, `unit_water.gd`. AI brains (`unit_brain.gd`, `brain_*.gd`) drive the body.

Other scripts call the body; it forwards to the component. New code inside a component calls sibling components through the body.

## Prop state

`scripts/prop_state.gd` holds door, container, area, and trap use-timer fields. `put`, `getv`, `hasv`, `clear`, `absorb`, `record`.

`put` writes the property when the node has `_field_set` and that key. Nodes without it (walls, platforms, slopes, room edges, NPCs, checkpoints, unit brains) keep the key in meta. `hasv` is true when `put`, `absorb`, or a `set_meta` from before `_ready` wrote that key. `getv` reads the property when the set-mark is on, else meta, else the caller's fallback. Builders may `set_meta` before `_ready`; `absorb` copies those keys once and drops the meta. `record` is the row land memory stores.

Field names: `door_open`, `lock`, `hp`, `thre`, `breakable`, `dead`, `usable`, `blocks_sight`, `mine`, `hackable`, `locktip`, `lock_hp`, `lock_level`, `lock_att`, `mine_tip`, `allact`, `allid`, `once`, `act_time`, `lock_key`, `keyloss`, `fun`, `sec`, `user_action`, `hold_use`, `spent`, `opened`, `box_hp`, `vis_state`, `enabled`, `touched`, `box_open`, `close_at`, `cool`, `taken`, `damage`, `ceiling`, `prize_locked`.

Meta that stays meta: build identity, trap `dead` (the remembered flag), drop `taken`.

## Fx

`Fx` (`scripts/autoload/fx.gd`) emits `sound`, `shake`, `float_number`, `notice`, `particles`, `blood`, and `flash`. Each event carries the source eid and `local` (true for a world event, or one whose player is the local player). Listeners run in the same call. `SfxBank`, `CamShake`, the HUD, and `UnitFx` play them. A later peer skips HUD events whose `local` is false.

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
