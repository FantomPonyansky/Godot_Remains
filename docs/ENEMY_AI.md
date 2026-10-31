# Enemy AI — how it works now, and how it differs from the original

Written 2026-10-28 from two code reads (port: `godot/scripts/enemy.gd`, `units/unit_brain.gd`, `units/brain_*.gd`, `map/room_bounds.gd`; original: `original/reference/Remains-Source2/fe/game/domain/units/*.as`, `ai/Brain.as`, `WalkMotor.as`, `FlyMotor.as`, `GunAttack.as`). Line numbers drift; search the function name. Items in "Differences" marked *checked* were confirmed by grep; the rest come from the reads and should be checked before a fix.

## Structure

- Generic units (raiders, zebras, rangers, Enclave, mercs, ants, scorpions and other critters, hellhounds, zombies) run the state machine in `enemy.gd` (`_decide`, `_sense`, `_act`). This is the original `Brain.as` plus `UnitRaider` / `UnitZombie` / `UnitMonstrik` / `UnitAnt` / `UnitHellhound` rules.
- A catalog `"brain"` swaps that loop for `control()` in a `brain_*.gd` script (`unit_brains.gd` `SCRIPTS`): robots, turrets, bats, bloats, slimes, fish, drones, spritebots, rollers, scythes, vortexes, mines, emitters, pets, bosses. These are the original classes with their own `control()`. Brains still use the host's senses (`_sense`, `find_cel`).
- Logic runs at 30 ticks per second (`_advance_ticks`), like the original.

## Activation

- **Port:** the player's room and the 8 around it run (`room_bounds.is_active`, `ACTIVE_REACH` 1). A unit that is not calm keeps running one room further (`CHASE_REACH` 2). Other units sleep (`_fall_asleep`): physics off, state and position kept. `RoomWatch` wakes them when the player comes back in reach. Pets and `always_active` brains (thunderhead and its turrets) never sleep. Trial and back rooms do not wake their row neighbours (`_apart`). Shots die past two rooms (`SHOT_REACH`).
- **Original:** only the current room runs (`Land.step`). The room just left keeps running for 150 ticks (`stepInvis`, `loc_t`), then freezes. Coming back more than 2 visits later resets every unit (`Location.reactivate` → `Unit.setNull`): full HP, back to its start point, brain back to idle, detection delay again.

## States

Same 9 states in both (`E_AIState`; `enemy.gd` constants ~line 130): idle, patrol, search, chase, hold, surprised, flee, dash prep, dash.

- `ai_spok` (`aiSpok`) is the alertness meter: 0 calm, 1–29 searching, 30+ attacking (`MAX_SPOK`).
- When the state timer runs out, `_decide`: calm → patrol (50%, if the unit strolls) or idle for 40–90 ticks; searching → search; attacking → wake allies once, then `_pick_attack` (chase, hold or dash prep). Alert states last 100–200 ticks.
- First sight while calm → surprised for `tupizna` ticks (40; 10 for Enclave, merc, ranger, zebra; a quarter for melee), then chase if still seen, else patrol.
- Hit while calm → chase the hit point and wake allies.
- Stun → idle, no attacks, re-check every 3 ticks. Shock (`_shok`) blocks shots and swings only.
- Levitated → a calm unit wakes, shocked; it struggles toward its own goal (`levitaccel`).
- Downed → zombies lie 300 ticks then rise at full HP; buried zombies cannot sense or be hit until they dig out.
- `ai="stay"`, `quiet`, `sniper` → no patrol.

## Perception

- **Sight** (`_look`, `Unit.look`): range `(visibility × stealthMult × room visMult + demask) × vision`. A still player is seen to 1500 px, a moving one (≥ 2 px per tick) to 2000. Alert vision is 1.5× calm. Behind the unit only within `detecting` (80 px) unless it is searching, chasing, fleeing or dashing. Cone units (turrets, some robots) use `v_konus`. Solid tiles block the ray. Score 20 inside `detecting`, 4 inside range, falling off out to 4× range.
- **Observation** (`_add_obs`, `UnitPlayer.observation`): each look adds to a meter on the player, scaled by sneak versus the enemy's `observ`, armour `visiMult`, stealth, lurking (−(2.5 + 0.5 × sneak level)) or sitting. At 20 the enemy locks on. It decays 0.1 per tick after 30 ticks with no look. One look from close fills it.
- **Hearing** (`_listen`, `Unit.listen`): distance only, through walls. Noise × the enemy's `ear` × room ear mult. Player footsteps: full / half / quarter of `noiseRun` above 12 / 7 / 3 px per tick, silent in the air. Shots: weapon noise (laser 300, pistol 700, shotgun 1200) plus demask 500. Noise falls 20 per tick. A loud sound puts the enemy into search (`ai_spok` 29) aimed at the player ±100 px. Raiders who only heard and never saw give up below `ai_spok` 15.
- **Alarm** (`_budilo`, `Unit.budilo`): wakes calm units of the same faction within radius × their `ear`. Raiders 500 on first alert and on a hit while calm; ants and scorpions chain 250; turrets 750. A woken unit chases a point ±125 px from the source and starts shocked (5–20 ticks).
- Spawn detection delay 100 ticks.

## Targets

- Fractions: 100 player side, 1 monster, 2 raider, 3 zombie, 4 robot. Raiders default to 2, others to 1.
- `_sense` / `findCel`: the unit that last hit it (`prior`) if it can still see it, else the player. The player is skipped while control is off (cutscenes; original `invulner`).
- Lost target: follows the real position for 6 failed looks (`TARGET_MEMORY`), then the guess drifts ±40 px every 5 failures; `ai_spok` falls 1 per failed look.
- Fraction-100 ground allies only shoot the last enemy that hit them, within 800 px and line of sight. Reprogrammed turrets pick any other-fraction unit they see. Pets pick the nearest foe in 800 px their gun can hurt.

## Movement

- Patrol: walk at 0.6× speed, turn at walls and ledges. No path and no walk home.
- Search, chase, flee, dash: run along the heading toward the goal (`_pursue`); flee 1.5×, dash 2.5× run speed. Air control 0.25 (hellhounds 1).
- Jump up when the goal is above and the landing is clear; 50% hop over gaps; step walls up to 10 px, else hop, then turn after 5–24 ticks.
- Drop through shelves while the goal is more than 80 px below (`throu`).
- Ladders: raiders, ants, hellhounds. Hellhounds also climb walls and crawl under low ceilings.
- Doors: raiders open unlocked doors they walk into.
- Flyers (`_fly_toward`): steer at the goal, gunners hover above it, calm flyers land.
- Water: swimming replaces gravity; ants do not chase in water; fish stay under the water line.
- **Across rooms (port only):** same room → aim at the player. Other room → a clear eye ray, else a side gap at chest or feet height, else the floor or ceiling hole nearest the player (`_player_goal`, `_opening_goal`), recomputed every 5 ticks.

## Engage and disengage

- Guns fire in hold, flee, and chase (if the type shoots while chasing). Single shots 10% per tick when seen, 3% blind. Spread 5° standing, 16° moving, 25° levitated. Snipers have no spread and never fire blind. Shock blocks single shots.
- Gunners: 70% hold when the target was seen recently and within `ai_dist` (1000); 60% hop back when closer than 200 px.
- Melee: stop 50–100 px away, ±80 px height, swing at 30% per tick. Scorpions hold and claw.
- Flee is **not** HP or morale. Raiders flee a grenade they can see within ~400 px (20% every 10 ticks) or a levitated mine within 400, for 20–84 ticks, still shooting.
- Giving up: `ai_spok` drains to 0, then idle or patrol where they stand.

## Per-type notes (port)

Robot (robobrain, sentinel: jump jets, rockets past 160 px), turret (hidden / sweep / windup / fire / lost; hacked turrets fight other fractions), bat (roost, dash bite), bloat (drift and dive; bloat6 clings), slime (crawl, drip, lie as a trap), fish, drone (dron3 sidesteps slow bullets), msp (sleeps on walls, explodes at 100 px), roller (rolls, slams; roller2 bursts), scythe, pet, vortex, mine, emitter (hatches up to five), pylon, transmitter (hurts inside 400 px), spritebot, thunderhead and its turrets, wild phoenix, and the bosses (raider, ultra, drone, necromancer, alicorn) each have their own `brain_*.gd`.

## Differences from the original

### Deliberate (seamless rooms, `PORT_RULES.md`)

1. **Activity:** 3×3 rooms plus chasers one room further, against the original's one room plus 150 ticks for the room just left.
2. **Sight and hearing cross room borders.** Original `findCel` only takes a player in the same room. Port sight is capped at one room width (`SIGHT_CAP`, no AS3 source). Hearing is distance only.
3. **Alarms cross room borders** (*checked*: `_budilo` has no room test). Original `budilo` only wakes `loc.units`.
4. **Cross-room pathing** (`_player_goal`, `_opening_goal`) does not exist in the original; there the player is never in another room.
5. `_scene_pending`: guards of a room with a pending script area ignore a player outside that room until aware (surf end raiders).
6. Performance shortcuts: rest skip of `move_and_slide`, shared gap scan, senses and world values computed once per frame.
7. **No room-return reset** (user, 2026-10-28, `PORT_RULES.md`). Original `Unit.setNull`: re-entering a room after more than 2 other visits restores enemies to full HP at their start point, calm. The port leaves them as they were. Deliberate.

### Not ported, or different (to fix; see `TODO.md` section 2)

8. **Enemy speech bubbles** (*checked*: no `replic` outside `npc.gd` / `story_text.gd`). Original raiders and robots say lines on alert (`attack`), hearing (`ear`), finding (`find`), giving up (`vse`), levitation, grenades, damage and death, with cooldowns, via `Unit.replic` and `TextParser.repText`. The text is likely already in `text_*.xml`.
9. **Zebra fade** (*checked*: no `shine`). Original zebras fade (`shine`, `vis.alpha`) and turn invisible to pets, turrets and NPCs when `shine` < 15; moving in the player's sight or shooting raises it; infravision shows them. Port `_invis` is only the ally invisibility cast.
10. **Enclave and Ranger `allLink` wake radius 2000** (*checked*: the port has no such radius; an unread `ALLIED_WAKE` const was removed 2026-10-31). The port uses 500 for every raider type.
11. **`maxSpok` 50 for mercs and Enclave.** Port `MAX_SPOK` is a constant 30 for all, so they give up sooner.
12. **Hellhound close sense:** original sees the player automatically inside 400 px and ignores alarms; not found in the port.
13. **Ranger side weapon:** rocket every 50–140 ticks and gas with no target (`SideWeaponAttack`); not found by name in the port. Check.
14. **Ant variant 3 fire breath** (`antfire`); not found by name. Check.
15. **Magazine reload:** port enemies reload for the weapon's reload time; the original AI has no magazine reload. A grenadier out of ammo becomes an unarmed rammer in the original; not found in the port.
16. **Flying gunners:** original raider-family flyers hover within `stalkDist` 500; the port read reports a 70 px hover above the goal. Check.
17. **Re-aim chance:** smart units 0.9 in the original, 0.8 in the port read. Check.
18. **Detection delay** is randomised ×0.9–1.1 on reset in the original; fixed 100 in the port.
19. `enemyAct` has three levels in the original (eyes only / sense / attack); the port has an on/off switch (`GameState.enemies_think`).

Neither version gives explosions a hearing noise of their own (only the shot that fired them).
