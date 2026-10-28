# Multiplayer refactoring plan

Goal (user, 2026-10-26): online co-op as a separate mode after the port, P2P over Steam, several players. This file is the step-by-step plan. The short rules for current work are in `PORT_RULES.md` "Future multiplayer"; the TODO entry is 10.2.

## Target model (same as Remains: Unity)

The Unity remake is not truly hostless. Its `PROJECT_STATUS.md` says "host/client and direct connection": one player's game is the host and there is no dedicated server. We use the same model:

- **Host**: one player's game. It owns the world: lands, units and AI, loot, doors, flags, story, random rolls, saves of the world.
- **Owner per actor**: each player's game owns its own pony: movement, aim and firing. It sends its state, so its own controls never wait for the network. The host owns everything else.
- **Shared changes through one function each**: a client asks; the host applies the change and sends it to everyone. In single player the same function applies the change directly.
- **Join and resync by snapshot**: a land seed plus the `WorldState` JSON snapshot, then a stream of changes.
- **Saves**: a character save per player (pony, inventory, perks) apart from the world save (the host's).
- **Transport**: Steam P2P (GodotSteam `SteamMultiplayerPeer`: Steam relays and NAT traversal, lobbies, invites), with ENet for LAN and two-process tests on one PC.

"Hostless" in the stronger sense, where the game survives the host leaving, is step 13 (host migration from the last snapshot). A design with no host at all (lockstep or distributed authority) is not planned: the AI, physics and roughly 600 random calls make lockstep impractical.

## Where the code stands (2026-10-26 count)

| Assumption | Size |
|---|---|
| One player looked up directly (group `player`, `.player`) | ~110 uses in ~50 files; `land_props.gd` 15, `hud.gd` 6, `trap_unit.gd` 5 |
| Per-player data held in global autoloads | Inventory, Progression, Condition, Effects, MagicBinds, Pets, Favorites, Craft, Stash; `player.gd` makes 168 calls to them |
| Input read inside gameplay | 38 `Input.` / `_input` uses in `player.gd` |
| Global random numbers (`randi`/`randf`/`shuffle`) | ~600; `land_spawn` 94, `enemy` 83, `loot_roll` 47, `land_gen` 17 |
| Whole-world pause | 12 files (PipBuck, pause menu, SATS, trade, stand, imp_mess, intro, weapon wheel, craft) |
| "Near the player" rules | `room_activity` (camera + 1 room), `room_bounds` (player ± 1 room), fog, `art_cache`, land build |

## Steps

Steps 1 to 8 change no behaviour in single player and can be done during or right after the port, one at a time, with the usual boot checks. Steps 9 to 14 are the multiplayer mode itself. Effort is a rough guess in focused days.

### 1. Player registry (3–5 days)
- New autoload `Players`: `all()`, `local()`, `nearest(pos)`, `in_room(room)`, `by_id(id)`; each player has a numeric `peer_id`.
- Replace every direct player lookup with it. Enemies choose a target from `Players.all()` (UnitBrain `findCel` over the set). Traps, triggers, area effects and loot pick-up use the player that touched them, not "the" player.
- With one player everything behaves as now. This is the biggest mechanical step; `land_props.gd` and `enemy.gd` stay single-writer.

### 2. Per-player character state (5–8 days)
- New `Character` object (a RefCounted, one per player) holding: inventory, worn and held items, ammo, level, XP, skills, perks, HP and limbs, effects, radiation, mana, quick slots, magic binds, pets, favourites, appearance.
- The autoloads keep their names and act on `Players.local().character`, so the PipBuck and HUD need no rewrite.
- Gameplay code that acts on a given player (damage, effects, loot) takes that player's `Character`.
- Split the save: `character.json` per player plus the world save (lands, flags, story, vendors, stash). Old saves load as world plus one character. The same split works for single player.

### 3. Input as commands (3–4 days)
- `PlayerCommand` per physics tick (30 Hz): move axis, jump, crouch, aim point, fire, reload, use, the action edges, chosen weapon or spell.
- `LocalInput` fills it from `Input` / `InputBindings`; `player.gd` reads only the command. The 38 direct reads move into `LocalInput`.
- Commands from the UI (use item, equip, drop, craft, trade, buy) go through the `Character` / world functions, never by editing state directly from the UI.
- This also makes bots and replays possible, which are useful for tests.

### 4. One function per world change (5–8 days)
- New autoload `World` (or `WorldOps`) with one entry per change: `open_door`, `unlock`, `break_object`, `move_crate`, `spawn_loot`, `take_loot`, `damage_unit`, `kill_unit`, `set_trigger`, `activate_checkpoint`, `use_terminal`, `trade`, `story_step`, `travel`.
- Every gameplay path goes through it (`land_props`, `lock_use`, `held_prop`, `ground_loot`, `loot_roll`, `bullet` hits, `ScriptsEngine` triggers, `Travel`, `Vendors`, `Stash`).
- In single player each function applies the change at once. In multiplayer, a client's call becomes a request and the host's result is applied on every machine.
- Any write to world state outside `World` is a bug to fix during this step.

### 5. Stable ids for everything in the world (2–3 days)
- Authored or generated things: land id + seed + room + index (`WorldState` snapshots already key many of these).
- Things spawned at runtime (loot, debris that matters, summoned units, projectiles that can hit): a host counter with a peer prefix.
- `World` functions take ids, not node references.

### 6. Random-number discipline (4–6 days)
- Gameplay random rolls (land build, spawns, loot, crits, misses, AI choices, trap timing) use explicit `RandomNumberGenerator` streams: `Rng.land(seed)`, `Rng.loot`, a per-unit stream, all run only by the host.
- Cosmetic random rolls (particles, sound variants, menu, dust, blinking) use a free local stream; their result never reaches world state.
- Check that a land built from the same seed is the same on two machines: compare a hash of rooms, units and loot. Joining depends on this.

### 7. Simulation split from presentation (6–10 days)
- `enemy.gd` gets an authority/replica switch. The authority runs the brain, physics and damage. A replica only interpolates the received position, facing and animation state, and plays effects from events.
- The same switch for moving platforms, traps, turrets, pets and crates that move.
- `player.gd`: the local pony is the authority. A remote pony is a replica fed by its owner's state (position, velocity, pose, aim, weapon, effects).
- Bullets: the owner fires and resolves its own shots (co-op trust, as in Unity) and sends hits to the host through `World.damage_unit`. Enemy shots are simulated by the host; clients show replicas.

### 8. Pause, SATS and time (2–4 days, plus a user decision)
- Single player keeps the original pauses.
- In multiplayer the world never pauses: PipBuck, inventory, trade, dialogs and stands show while the world runs. A player in a menu can be marked as busy (the original has no such state, so this is a design choice).
- SATS slows time for the whole world in the original. In multiplayer it needs a variant: no slow-down, or slow-down only for the player using it.
- Story scenes and the intro block only the player watching them.

### 9. Several positions for "near" rules (3–5 days)
- `room_activity`, `room_bounds`, fog memory, `art_cache` and the land build (later the seamless chunks, TODO 10.1) take the set of player positions; the union is awake.
- Camera, fog sight, HUD and aim cursor stay on the local player only.
- Decision: the party stays in one land, and leaving needs all players at the exit or a vote. Unity keeps everyone on one level.

### 10. Network layer (5–8 days)
- `Net` autoload over Godot's `MultiplayerPeer`: ENet for LAN and tests, `SteamMultiplayerPeer` for Steam.
- Message kinds:
  - **reliable:** `World` requests and results, chat, join snapshot, travel;
  - **unreliable, 20 Hz:** player states and unit snapshots in the players' rooms.
- Own binary or JSON serialization, not `MultiplayerSynchronizer` per node; there are too many dynamic nodes.
- Interpolation buffer about 100 ms for replicas; client-side correction of one's own pony is not needed, since the owner is the authority.

### 11. Join, leave and saves (4–6 days)
- Join: lobby, then the host sends the land seed and snapshot; the client builds the land, applies the snapshot, then live changes. The joining player brings their `Character` save.
- Leave: the departing pony is removed and their items stay with their character.
- World saves are written only by the host. Each player saves their own character locally.

### 12. Steam (3–5 days)
- GodotSteam plugin, lobby create, join, invite and friends list, the overlay, a rich-presence status.
- Main-menu entries "Host co-op" and "Join co-op"; the single-player menu is unchanged.

### 13. Host migration, optional (5–8 days)
- The host sends a full snapshot every N seconds (most of it is `WorldState` already).
- If the host drops, the peer with the lowest id becomes host, rebuilds from the last snapshot, and the others reconnect to it. The last few seconds are lost.

### 14. Testing (ongoing from step 10)
- Two processes on one PC (as Unity tests) with a command-line flag `--host` / `--join 127.0.0.1`.
- Scripted bots via `PlayerCommand`.
- A desync check: host and clients hash the world state per room each second and log mismatches.

## Decisions needed from the user before step 8

- Loot: shared (first to take) or per player.
- Difficulty: enemy HP and count by number of players.
- Friendly fire and explosions on allies.
- What a busy player (in PipBuck) is: invulnerable, or not.
- SATS in multiplayer.
- Story progress: whose save advances; what a joiner who has not done the story sees.
- Death: respawn at the checkpoint, revive by an ally, or wait.
