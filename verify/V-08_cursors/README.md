# V-08 — Menu arrow and target cursor frames

**What is judged:** the arrow cursor in menus, and which target frame the in-game cursor shows.

## What the original does
- Menus, the PipBuck and the pause screen show `arrow.png`, drawn above every overlay.
- In play the cursor is `target`. It turns to `target2` (action) over something the player can use within reach, or while carrying or using an object. It turns to `target1` (combat) over an enemy, and for the whole of a battle.

## Steps
1. `run_menu.cmd`. Move over the main menu and open Options and New Game.
2. `run.cmd`. A raider is ahead, with crates and a first-aid kit around. Point at empty space, a crate in reach, and the raider. Open the PipBuck and the pause menu.

## Pass criteria
- **PASS:** there is an arrow in every menu, above everything, with its tip at the click point. In play the frames change as described above.
- **FAIL:** an OS cursor, a hidden cursor, an arrow under a panel, or the wrong frame for a target. Say which.

## What to record
`VERDICT.md`.

## On a FAIL
`godot/scripts/aim_cursor.gd` `_aim_frame` and `_action_target`, menu arrow in `main_menu.gd` `_ready` and `ui_nav.gd`. Art is in `godot/assets/ui/cursor/`.
