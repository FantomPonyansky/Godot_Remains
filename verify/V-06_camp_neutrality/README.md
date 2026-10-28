# V-06 — Nobody in a camp starts hostile; allies fight intruders

**What is judged:** in a camp nobody attacks the player first, and camp allies fight enemies that come in.

## What the original does
- Camps are the base lands: `rbl` (Prancing Pony), `covert` (Covertsign), `src` (Water treatment plant), `stable_pi` (Stable Pi), `way` (Somewhere along the way to Canterlot).
- Camp units and turrets are on the player's side (`fraction="100"`). They attack only units of another side, or whoever attacked them.

## Steps
1. `run.cmd`. Arrive in `rbl` and walk the whole camp for a minute without shooting.
2. `run_raider.cmd`. God mode, weapons, and a raider spawned beside you in the camp. Watch who shoots whom.

## Pass criteria
- **PASS:** step 1 has no attacks on you and no hostile name tips. In step 2, the turrets and armed ponies fire at the raider, not at you.
- **PARTIAL:** step 1 passes, but nobody reacts to the raider.
- **FAIL:** anyone in the camp attacks you unprovoked.
- Optional: repeat step 1 in `src` (console `land src`) and check that the rangers stay friendly.

## What to record
`VERDICT.md`.

## On a FAIL
`godot/scripts/enemy.gd` (fraction, `_sense`), the room `fraction="100"` data, `godot/scripts/units/brain_turret.gd`.
