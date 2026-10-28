# V-02 — Terminal use point and the access terminal

**What is judged:** where a terminal can be used from, and what the access terminal (`term2`) does.

## What the original does
- Terminal art (`term`, `term1`…`term3`, `termh`) is a 40×40 picture standing on its bottom edge. The use point is the centre of the picture.
- The access terminal `term2` is hacked with Science. A success unlocks the room objects marked `hack=1` (`door3`, some safes). Ordinary pick-lock doors are not affected. A failure only shows the fail line.

## Steps
1. `run.cmd` (room 3,3). Aim at the terminal and walk around it. Note where the use prompt appears and disappears.
2. `run_access.cmd` (room 4,0). Use `term2` (the access terminal), then try the reinforced door to the right, at cell 43,7.

## Pass criteria
- **PASS:** the use prompt shows while aiming at the picture itself, not below it or to its right. The access terminal starts a hack. On success, the `door3` in the room unlocks. On failure, the fail line shows.
- **PARTIAL:** the use point is right but the hack result is unclear (say what you saw).
- **FAIL:** the use point is offset from the picture, or `term2` only shows a message with no hack.

## What to record
`VERDICT.md`. Note your Science skill from the PipBuck status page, and whether the hack succeeded.

## On a FAIL
Use point: `godot/scripts/land_props.gd` `_button_art` (sprite offset −20,−40) and `player.gd` `_sprite_rect`. Hack: `land_props.gd` terminal use and `hack=1` objects (`docs/PLAYER_FEEDBACK.md`, 2026-10-26, first row).
