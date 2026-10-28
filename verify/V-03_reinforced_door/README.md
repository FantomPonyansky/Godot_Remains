# V-03 — Reinforced doors open on a held interact

**What is judged:** reinforced doors need the interact key (or pad button) held, not a tap.

## What the original does
- `stdoor`, `basedoor`, `door3`, `door4`, `encldoor` and `enclpole` have a use `time` of 15 ticks (half a second). Interact must be held until the bar fills. Letting go early cancels it.
- One press opens or closes a door once. It does not open and shut it again.

## Steps
1. `run.cmd`. You stand left of the `door3` at cell 38,15 in room 2,0.
2. Tap interact once. Then hold it until the door opens. Then hold again to close it.
3. Hold and let go halfway.

## Pass criteria
- **PASS:** a tap does nothing, or only starts and cancels the bar. A hold of about half a second shows progress and opens the door. Letting go early cancels it. Each completed hold toggles the door once.
- **FAIL:** a tap opens it, a hold never completes, or one hold opens and shuts it.
- If the tip says the door is locked, note it and repeat on the `door3` in room 4,0 (`V-02 run_access.cmd`).

## What to record
`VERDICT.md`. Say whether you used keyboard or pad.

## On a FAIL
`godot/scripts/land_props.gd` `_use_door` and `action_ticks` (`act_time`), `godot/scripts/lock_use.gd` door templates. Double toggle: `player._process` interact read (`docs/PLAYER_FEEDBACK.md`, 2026-10-25, first row).
