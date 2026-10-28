# V-10 — Checkpoint: mana, autosave, no heal

**What is judged:** touching a checkpoint for the first time.

## What the original does
- `CheckPoint`: the first touch opens it, gives +50 mana and some experience, and autosaves. It does not heal. The opened state is saved.

## Steps
1. `run.cmd`. Mana is set to 100 and the head to 50, and you stand left of the checkpoint at cell 23,15 in room 2,0. Open the PipBuck status page and note mana and the head.
2. Walk into the checkpoint, then check the status page again. If it was already open, repeat at the checkpoint in room 2,1: open the console, type `tp 2 1 28 11`, and walk right.
3. Open the load screen (pause menu, Load) and look at the autosave slot.

## Pass criteria
- **PASS:** the checkpoint opens. Mana goes from 100 to 150. The head is unchanged. Experience goes up. The autosave slot has this land and time.
- **FAIL:** a heal, no mana, no autosave, or the checkpoint does not open.

## What to record
`VERDICT.md`, with the numbers before and after.

## On a FAIL
`godot/scripts/map/checkpoint.gd` (`CP_MANA`, `activate`), `godot/scripts/autoload/travel.gd` `_rebind_cp`.
