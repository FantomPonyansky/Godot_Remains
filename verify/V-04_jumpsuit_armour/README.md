# V-04 — Stable jumpsuit at the start and worn armour on the pony

**What is judged:** a new game starts wearing the stable jumpsuit, and worn armour is drawn on the pony.

## What the original does
- The opening script `beginBeg` gives the jumpsuit (`takeArmor pip`) and puts it on (`armor pip`).
- Worn armour is drawn over the body. The far-side legs' armour sits under the PipBuck leg, so the PipBuck stays visible when facing left.

## Steps
1. `run.cmd`. Look at the pony as the game starts. Open the PipBuck inventory and check which armour is equipped. Face right, then left.
2. `run_all_armour.cmd`. Every armour is in the bag. Wear three or four different suits one after another and look at the pony each time, facing both ways. Walk, jump and climb a ladder in one of them.

## Pass criteria
- **PASS:** the jumpsuit is equipped and drawn from the first frame. Each suit is drawn on the body and follows the animation. The PipBuck stays visible facing left.
- **PARTIAL:** suits are drawn, but the PipBuck is covered when facing left. That is already known (`docs/TODO.md`, "`pip` armour covers only the front half"). Note it and any other layering error.
- **FAIL:** no suit at the start, or a worn suit not drawn.
- No armour on the swim animation is a known gap, not a FAIL.

## What to record
`VERDICT.md`, plus `evidence\V-04_right.png` and `evidence\V-04_left.png` for one suit.

## On a FAIL
`godot/scripts/pony_puppet.gd` `set_armor` (armour overlay, layer order), `scripts.json` `beginBeg` and `ItemInteraction.addBegin` (start kit).
