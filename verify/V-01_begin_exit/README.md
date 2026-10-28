# V-01 — The tunnel exit to the Surface

**What is judged:** leaving the starting tunnels (`begin`) through the exit in room 3,2, healthy and with a critical organ.

## What the original does
- The exit is an area at the right end of room 3,2 (cell 46,19, 7 cells tall). Its script runs `gotoland surf`, then `passed`.
- `Game.gotoLand` refuses every land except the base camp when the head, torso, legs or blood is at 1 or below. It shows `nocont`: "Your health condition is critical, continuing mission is impossible. Seek medical attention." Damage above 1 does not block.
- There is no doctor in the tunnels, so the critical case cannot be healed there. That is original behaviour and is kept (`docs/PLAYER_FEEDBACK.md`, 2026-10-24 row 1).

## Steps
1. `run.cmd`. You start healthy a few cells left of the exit. Walk right into it.
2. `run_critical.cmd`. Same place, head at 1 hit point. Walk right into the exit.
3. In the critical run, open the console (`~`), type `heal`, close it, and walk into the exit again.

## Pass criteria
- **PASS:** step 1 fades out and loads the Surface. Step 2 shows the `nocont` line and stays in the tunnels. Step 3 then travels.
- **FAIL:** step 1 does nothing, or loads anything but the Surface. Step 2 travels anyway, or shows nothing. Step 3 still refuses.

## What to record
`VERDICT.md`, plus `evidence\V-01_nocont.png` (the message on screen).

## On a FAIL
`godot/scripts/autoload/travel.gd` `goto_land` (the organ check, `_loading`), `godot/scripts/autoload/scripts_engine.gd` (`gotoland`). If nothing happens and no message shows, the cause is not the organ check. Look for a stuck `Travel._loading` (`docs/PLAYER_FEEDBACK.md`, "Second new game: begin exit did nothing").
