# V-05 — Bloatsprites: wings, walls, nest, split

**What is judged:** bloatsprite movement and animation, the nest (`ebloat`), and big bloatsprites splitting on death.

## What the original does
- Bloatsprites flap their wings all the time and fly around walls, not into them.
- The nest breathes (idle animation) and releases bloatsprites while the player is near. It bursts on death.
- `UnitBloat` splits on death: `bloat3` into two `bloat0` (four if it is a hero), and `bloat8` and above into two of the size below. Others do not split.

## Steps
1. `run.cmd` (room 3,3: two bloatsprites, nest at cell 28,3). Watch for a minute: wings, flight near walls, the nest.
2. Kill the nest, using the weapons from step 3 if needed.
3. `run_split.cmd`. God mode is on, every weapon is in the bag, and a `bloat3` and a `bloat8` are in front of you. Kill each one and count what comes out.

## Pass criteria
- **PASS:** wings always move. No bloatsprite sits inside a wall for more than a moment. The nest breathes and spawns, and bursts on death. `bloat3` leaves two `bloat0`, and `bloat8` leaves two `bloat7`.
- **FAIL:** any of these is missing. Say which.

## What to record
`VERDICT.md`. How many came out of each split.

## On a FAIL
`godot/scripts/units/brain_bloat.gd` (flight, walls), `brain_emitter.gd` (nest), `godot/scripts/enemy.gd` `_bloat_split`. `tools/build_enemies.py` can overwrite the hand-edited bloat rows in `enemies.json`, so check those first.
