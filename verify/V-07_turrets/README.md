# V-07 — Turret animations

**What is judged:** turret body and gun animation: idle, turning, firing, damage, death.

## What the original does
- Turrets (`turret0`–`turret5`) hang from the ceiling. The gun turns on its pivot toward the target. Each has its own firing and death clips (`visualTurret0`–`5`).
- Compare with the original game in `original\game\` if you can run it.

## Steps
1. `run.cmd`. God mode, in tunnel room 0,3 under the turret at cell 26,1. Let it see you and fire. Move left and right under it. Shoot it until it dies (open the console and type `debug` for weapons).
2. `run_camp.cmd`. The four camp turrets in `rbl` fire at a spawned raider.

## Pass criteria
- **PASS:** the gun tracks the target on its pivot without jumping. Firing and death play once and look whole. There is no gun drawn twice, and no frame from another clip.
- **FAIL:** say which clip is wrong and how (wrong frame, offset, doubled gun, no animation).

## What to record
`VERDICT.md`, plus a short screen recording or screenshots of the wrong clip in `evidence\`.

## On a FAIL
`godot/scripts/units/brain_turret.gd`, art in `godot/assets/sprites/sheets/units/turretN.png` and `turretN_puha.png`. `turret0` frame 0 was already fixed, and a backup is at `%TEMP%\turret0_bk.png`. `docs/PLAYER_FEEDBACK.md`, 2026-10-24 row 15.
