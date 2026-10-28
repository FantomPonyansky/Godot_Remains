# V-09 — Shootable and pressable buttons, the detonator

**What is judged:** wall buttons and the detonator in the tunnels.

## What the original does
- A shootable button (`knop2`) lights up on any damage and runs its script. In room 2,1 it unlocks the `door3` below (`trMDoor`, lock 3 to 0). The door stays shut until you open it.
- A press button (`knop1`) runs its `allact` on use.
- The detonator fires every charge wired to it. The blast breaks the weak wall around them.

## Steps
1. `run.cmd`. In room 2,1, weapons are in the bag. Shoot the button at cell 8,17, then go down to the door at cell 12,23 and open it.
2. `run_press.cmd`. In room 4,1, press the button at cell 28,22 and watch what changes.
3. `run_detonator.cmd`. In room 1,4, use the detonator at cell 16,18 and watch all three charges.

## Pass criteria
- **PASS:** the shot button lights up, the door is unlocked and opens on use, the press button acts, all three charges explode, and part of the wall is gone.
- **FAIL:** say which step failed.

## What to record
`VERDICT.md`, plus `evidence\V-09_wall.png` (the wall after the blast).

## On a FAIL
`godot/scripts/land_props.gd` `_strike` (`actdam`) and `_on_button` (`all_act`). Blast: `apply_blast` and the charge `take_hit` (`docs/PLAYER_FEEDBACK.md`, 2026-10-26).
