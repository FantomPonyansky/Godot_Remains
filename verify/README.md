# Verify kit — checks only a person can judge

One folder per check. Each has a `README.md` you can follow without knowing the code, one or more double-clickable `run*.cmd`, and a `VERDICT.md` to fill in. A run drops you straight into the situation, past the main menu, in a fresh new game with the console commands it needs already applied. A FAIL names the file and function that own the fix, so it can go straight into a narrow fix.

Runs use their own user folder, `tmp\verify_user\`. Your real settings and saves are never touched. Each run clears that folder's saves first. Settings you change there (controls, language) are kept for the next run.

## How to take a check
1. Read the row's `README.md`.
2. Double-click its `run.cmd`, or whichever `run_*.cmd` the README names.
3. Fill `VERDICT.md`. **Result** is `PASS`, `FAIL` or `PARTIAL`. The first line under **Observations** is a one-line summary. For a FAIL or PARTIAL say what differed, where, and how badly.
4. Save screenshots in the row's `evidence\` folder (create it) under the names the README asks for.

The console (`~`) stays available during a check, for example `heal`, `god 1` or `tp`. The command list is `godot/DEBUG_COMMANDS.md`.

## Rows

| Row | What |
|---|---|
| V-01 | The tunnel exit to the Surface, healthy and with a critical organ |
| V-02 | Terminal use point and the access terminal hack |
| V-03 | Reinforced doors open on a held interact |
| V-04 | Stable jumpsuit at the start, worn armour on the pony |
| V-05 | Bloatsprites: wings, walls, nest, split |
| V-06 | Camps: nobody starts hostile, allies fight intruders |
| V-07 | Turret animations |
| V-08 | Menu arrow and target cursor frames |
| V-09 | Shootable and pressable buttons, the detonator |
| V-10 | Checkpoint: mana, autosave, no heal |
| V-11 | Lurking behind cover |
| V-12 | Main menu pony animation |

## Collecting the verdicts

```
python verify\_shared\collect.py           the table of every row
python verify\_shared\collect.py --check   lists rows without a valid Result (exit 1 if any)
python verify\_shared\collect.py --write   also writes verify\RESULTS.md
```

A FAIL becomes a row in `docs/PLAYER_FEEDBACK.md` with the owner from the README. A PASS lets the "Verify" note on that feedback row be dropped.

## Adding a row
Copy a row folder, then edit `README.md` (what is judged, what the original does, steps, pass criteria, what to record, on a FAIL) and the `run*.cmd` line. `run_case.cmd` takes console lines separated by `;`:

```
call "%~dp0..\_shared\run_case.cmd" "god 1; land rbl; tp 0 0 24 22; spawn raider1"
```

A line that travels (`land`, `quiet`, `trial`, `boss`, `surfend`, `arena`) waits for the next land before the rest run. Useful lines: `tp <room_x> <room_y> [cell_x cell_y]`, `spawn <unit_id> [count]`, `set /root/GameState <field> <value>`, `debug`, `heal`, `god 1`. Set `VERIFY_BOOT=menu` to start on the main menu, `cont` to continue the sandbox's last save, or `slot=N` to load slot N. Set `VERIFY_KEEP=1` to keep the previous run's saves. Set `VERIFY_LAND=<id>[:room_x:room_y]` to open the new game on that land (the stable is not built), or `VERIFY_ROOM=<file>:<room>` to open one room alone as its own test land (`begin:3:2` is `rooms_begin` `room_3_2`; leaving it goes to the room editor). Copy `_shared\VERDICT_TEMPLATE.md` as the new `VERDICT.md`.

Launch flags behind it, for use outside the kit: `--user-dir=<path>` (`user_dir.gd`), `--boot=new|cont|slot=N` (`main_menu._boot_from_args`), `--land=<id>[:x:y]` (`game._start_land`), `--room=<file>:<room>` (with `--boot=new`, through `editor_play`), and `--cmd="a; b"` (`debug_console._read_launch_args`). `VERIFY_QUIT=N` makes a run quit after N frames and wait, for a scripted smoke test of the runners.
