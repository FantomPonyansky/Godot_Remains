# V-11 — Lurking behind cover

**What is judged:** hiding behind a crate or in a niche: the look, the layers, and whether enemies lose you.

## What the original does
- Standing still at cover and tapping up starts lurking. The pony moves behind the cover (`lurk1`–`lurk3`) and holds the dark frame. It is not detected while still, and is half as visible.
- Large crates (box 2, 3) are drawn over the pony. Small cover and niches are drawn under it. Unlurk plays the clip back.

## Steps
1. `run.cmd`. You are by the crates of room 3,0. Stand still at a crate, tap up, wait, and tap up again (or move) to leave. Try each crate. Some are not hiding spots.
2. `run_enemy.cmd`. Same, with a raider. Lurk before it reaches you and watch whether it walks past.

## Pass criteria
- **PASS:** the pony goes behind the cover and stays dark, with no stand pose, a visible tail and dimmed hair. The horn, eye and PipBuck are not drawn over the crate. Unlurk plays. The raider loses you while you stay still.
- **FAIL:** say what looks wrong. Note which crate and whether it was large or small.

## What to record
`VERDICT.md`, plus `evidence\V-11_lurk.png`.

## On a FAIL
`godot/scripts/player.gd` `_try_lurk`, `_lurk_layer` and `lurk_cut`, `godot/scripts/pony_puppet.gd` `set_flat_layers` (`docs/PLAYER_FEEDBACK.md`, 2026-10-26, the two lurk rows).
