# Autoloads

One line each: purpose, Sim phase (`—` if it does not register), depends on, depended by. Names are the other autoloads it calls. Cycles still in the graph are marked on the line.

Load order in `project.godot` is the `_ready` order. An autoload's `_ready` only uses autoloads above it. `WorldState` is first after `UserDir` so `Run`, `Sim` and `Rng` register and read the seed after `reset_run`. `InputBindings` is before `LocalInput` so the action list exists. `Effects` and `Inventory` are before `GameState` so `GameState._ready` can subscribe. `Rng` stays after `Sim`, `Fx` after `Rng`. The boot `run_reset` fires before listeners connect; `Rng._ready` applies that seed itself, and `game.gd` resets again before play.

Character autoloads do not call `GameState`, `Travel` or `Story`. Body changes and item use are signals (`Effects.player_harm`, `player_heal`, `player_stam_empty`, `params_dirty`, `player_spared`; `Inventory.consume_query`, `consumed`; `Progression.rescale_health`). Difficulty rows are `scripts/difficulty.gd` (`GameState.difficulty` and `dif_value` forward). `Run.torso_hp_mult`, `Run.player_dead` and `Run.alicorn` are written by `GameState` and `ScriptsEngine`. `Progression._info` and `Inventory.use` / `is_consumable` keep their names.

- **UserDir** — settings, saves and log paths. Phase —. Depends on —. Depended by —.
- **WorldState** — lands, run document, `run_reset`. Phase —. Depends on Rng, Run. Depended by Condition, Effects, Favorites, GameState, Inventory, Pets, Progression, Rng, Run, ScriptsEngine, Sim, Stash, Story, Travel, Vendors. **In a cycle via Rng, Run.**
- **Run** — players, land, camera; torso mult, dead flag, alicorn flag. Phase —. Depends on WorldState. Depended by AudioManager, CamShake, CameraDistance, Condition, Craft, DebugConsole, Effects, Favorites, Fx, GameState, Inventory, LocalInput, MagicBinds, Pets, Progression, ScriptsEngine, Stash, Story, Travel, Vendors, WorldState. **In a cycle via WorldState.**
- **Sim** — 30 Hz phases and pause reasons. Phase — (it is the clock). Depends on WorldState. Depended by AiWorld, AudioManager, CamShake, Craft, DebugConsole, Effects, Fx, GameState, LocalInput, Pets, Travel.
- **InputBindings** — saved controls. Phase —. Depends on Locale. Depended by ControlsUI, Favorites, LocalInput, MagicBinds, Prompts.
- **LocalInput** — per-frame input, one command per tick. Phase INPUT. Depends on InputBindings, Run, Sim. Depended by Condition, Craft, Favorites, MagicBinds, Pets.
- **Rng** — seeded gameplay streams. Phase —. Depends on WorldState. Depended by AudioManager, CamShake, Condition, Effects, GameState, Progression, SfxBank, Stash, Travel, Vendors, WorldState. **In a cycle via WorldState.**
- **Fx** — presentation events. Phase —. Depends on Run, Sim. Depended by AudioManager, CamShake, Condition, Craft, Effects, Favorites, GameState, Inventory, Pets, Progression, SfxBank, Story, Travel.
- **Effects** — timed effects, cut and poison. Phase EFFECTS. Depends on Fx, Rng, Run, Sim, Units, WorldOps, WorldState. Depended by GameState, Inventory, Pets, Progression, ScriptsEngine.
- **Inventory** — carried items. Phase —. Depends on Effects, Fx, Run, WorldState. Depended by Autopick, Condition, Craft, Favorites, GameState, MagicBinds, Pets, Progression, ScriptsEngine, Stash, Story, Travel, Vendors.
- **GameState** — HP, magic, pools, difficulty forwarders. Phase PLAYERS. Depends on Condition, Effects, Fx, Inventory, Pets, Progression, Rng, Run, Sim, WorldState. Depended by MagicBinds, ScriptsEngine, Stash, Story, Travel, Vendors.
- **AudioManager** — music. Phase PRESENTATION. Depends on CamShake, Fx, Rng, Run, Sim, Units. Depended by ScriptsEngine, Travel.
- **SfxBank** — sound playback for Fx. Phase —. Depends on Fx, Rng. Depended by ControlsUI.
- **Locale** — language. Phase —. Depends on —. Depended by Autopick, CameraDistance, ControlsUI, Craft, InputBindings, Story, Travel.
- **Prompts** — button glyphs. Phase —. Depends on InputBindings, UiNav. Depended by ControlsUI, Craft.
- **UiNav** — menu focus. Phase —. Depends on —. Depended by ControlsUI, Craft, Prompts, Travel.
- **Sight** — aim assist option. Phase —. Depends on —. Depended by —.
- **CameraDistance** — zoom option. Phase —. Depends on Locale, Run. Depended by ControlsUI.
- **Autopick** — loot filter. Phase —. Depends on Inventory, Locale, Stash, Vendors. Depended by ControlsUI.
- **ControlsUI** — controls screen. Phase —. Depends on Autopick, CameraDistance, InputBindings, Locale, Prompts, SfxBank, UiNav. Depended by —.
- **Progression** — level, skills, perks, max HP. Phase —. Depends on Effects, Fx, Inventory, Rng, Run, WorldState. Depended by Condition, Craft, GameState, Pets, ScriptsEngine, Story, Vendors.
- **MagicBinds** — quick spells. Phase —. Depends on GameState, InputBindings, Inventory, LocalInput, Run. Depended by Favorites, Stash.
- **Condition** — weapon and armor wear. Phase —. Depends on Fx, Inventory, LocalInput, Progression, Rng, Run, WorldState. Depended by Craft, GameState, Vendors.
- **Craft** — stations. Phase —. Depends on Condition, Fx, Inventory, LocalInput, Locale, Pets, Progression, Prompts, Run, Sim, Stash, Story, Travel, UiNav, Vendors. Depended by —.
- **DebugConsole** — cheat console. Phase —. Depends on Run, Sim, Travel. Depended by —.
- **Travel** — lands, death, control lock. Phase WORLD. Depends on AudioManager, Favorites, Fx, GameState, Inventory, Locale, Rng, Run, Sim, UiNav, WorldOps, WorldState. Depended by AiWorld, Craft, DebugConsole, ScriptsEngine, Stash, Story, Vendors.
- **Story** — quests, notes, info line. Phase —. Depends on Fx, GameState, Inventory, Locale, Progression, Run, Travel, WorldOps, WorldState. Depended by Craft, ScriptsEngine, Stash, Vendors.
- **ScriptsEngine** — story commands. Phase STORY. Depends on AudioManager, CamShake, Effects, Favorites, GameState, Inventory, Progression, Run, Story, Travel, WorldOps, WorldState. Depended by —.
- **CamShake** — camera shake. Phase PRESENTATION (after AudioManager). Depends on Fx, Rng, Run, Sim. Depended by AudioManager, ScriptsEngine.
- **Pets** — phoenix and owl. Phase UNITS. Depends on Effects, Fx, Inventory, LocalInput, Progression, Run, Sim, Units, WorldState. Depended by Craft, GameState, Vendors.
- **Favorites** — hotbar. Phase —. Depends on Fx, InputBindings, Inventory, LocalInput, MagicBinds, Run, WorldState. Depended by ScriptsEngine, Travel.
- **Vendors** — shops and stock. Phase —. Depends on Condition, GameState, Inventory, Pets, Progression, Rng, Run, Story, Travel, WorldOps, WorldState. Depended by Autopick, Craft, Stash.
- **Stash** — base vault. Phase —. Depends on GameState, Inventory, MagicBinds, Rng, Run, Story, Travel, Vendors, WorldOps, WorldState. Depended by Autopick, Craft.
- **AiWorld** — enemy blackboard: per-player meters, sense facts, faction knowledge. Phase —. Depends on Sim, Travel. Depended by —.
- **Units** — unit registry: cached `enemies` group in group order, room buckets. Phase —. Depends on —. Depended by AudioManager, Effects, Pets.

`PROJECTILES` has no subscriber yet.
