# V-12 — Main menu pony animation

**What is judged:** the animated pony on the main menu.

## What the original does
- The menu pony blinks, its mane and tail move, and it levitates a pistol with a green magic glow around the gun and the horn. The glows only brighten what is under them. They never draw a dark box.
- Reference stills of the original menu are in `original\menu_screenshots\`.

## Steps
1. `run.cmd`. Watch the menu for a minute at your normal window size, then maximised.

## Pass criteria
- **PASS:** eyes, mane, tail and the floating gun all move smoothly, with no dark box or disc around the glows.
- **PARTIAL:** everything moves, but the gun motion is not smooth (already known in `docs/PLAYER_FEEDBACK.md`, 2026-10-24 row 10). Describe the jerk: a jump at one point of the loop, or uneven all the time.
- **FAIL:** a part that should move does not, or glows draw dark boxes.

## What to record
`VERDICT.md`, plus a short screen recording in `evidence\` if the gun stutters.

## On a FAIL
`godot/scripts/main_menu.gd` (pony build, `_pers`, `_displ` / `MenuDispl`).
