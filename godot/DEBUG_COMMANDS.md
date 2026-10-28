Update this file whenever a command is added or changed.

help — List every command and what it does.
give <item_id> [count] — Add a catalog item, weapon, armor, consumable, or schematic. Count defaults to 1.
spell <id> — Add that spell or magic weapon. A spell becomes the current spell (cast with the cast key), a magic weapon is equipped.
perk <id> — Grant one rank of a perk from perks.xml without a perk point or its requirements (spell_port = teleport). Port debug only.
effect <name> [seconds] — Apply a status the game already has: cut, poison, igni, ice, blind, acid, pink, stun, slow, potion_fly, or alicorn. Seconds set the duration, or the stack added for cut and poison. Defaults are cut 5, poison 5, igni 7, stun 2, slow 5, potion_fly 120, alicorn 20, and 15 for ice, blind, acid, and pink. Unit statuses need a selection that has that status. potion_fly and alicorn apply to the player when the player is selected or nothing is. Unknown names are rejected.
eff <id> [ticks] — Add an effs.xml effect (burning, drunk, mint, f_hp, curse, ...) through Effects.add, as the original console 'eff'. It goes on the selected unit, or the player when the player or nothing is selected. Ticks (30 a second) override the effs.xml duration.
remeff <id> — End that effect on the selection or the player (Effects.remove; a chem leaves its post effect).
select — Print the current selection.
params — List the selection's settable fields: exported properties, script variables, and metadata that already exist, such as hp, lock, and fraction.
set <field> <value> — Set a number, bool, or string field on the selection.
set <node_path> <field> <value> — Set that field on a node by path, without clicking it.
clear — Drop the selection.
debug — Once per run, grant every magic spell, every carried weapon, and every armor, 60 rounds of each ammo type, and 3 of each of 3 items from every consumable type. Raises level, Telekinesis, and the levitation and selflevit perks to the original minimums for that magic and for air jump and hover.
lands — List the land ids from Lands.xml that land accepts.
land <id> — Go to that land the way a land exit does (fade, Game.gotoLand rules: refused with a damaged organ unless it is the base camp). A land already visited this run is kept as it was left; begin is the stable.
quiet <id> — Go to that land and stop enemy AI. Enemies already there, and any that spawn after, stay put. quiet on turns AI back on without moving. A new game turns it back on.
openland <id|all> — Open that land on the PipBuck world map (script openland), or every land.
worldmap — Open the PipBuck world map in travel mode, as the map table does.
die — Kill the player: the original death, then respawn at the last checkpoint (in hardcore, the end of the run).
heal — Fill hit points and set head, torso, legs, and blood to full. Clears radiation, which otherwise caps hit points.
tp <room_x> <room_y> [cell_x] [cell_y] — Put the player in that room of the current land (rooms 48 x 25 cells; room y from the top). Two numbers land near the floor of the room; four pick a cell. Port debug only.
spawn <unit_id> [count] — Put that enemy (enemies.json id: bloat3, turret0, alicorn1, ...) calm, 3 cells in front of the player. Count defaults to 1. Port debug only.
trials — List every trial (tip 1) id and the land that can hold it.
trial <id> — Go to that trial chamber (rebuilds the land and plants the room if it is missing). Port debug only.
bosses — List every boss arena (tip 2) id and the land that can hold it.
boss <id> — Go to that boss arena. Port debug only.
surfend — Rebuild surf and put the player in room 11,0 just left of the surfStory trigger (raiders + Calamity scene); Calamity's rep is reset to 0. Port debug only.
artcache [0|1] — Print or set load on demand: on a land change, art only the old land used is freed (setting foe/art/load_on_demand, default on; launch flags --art-on-demand / --art-preload). Prints texture memory. Takes effect at the next land change.
physhz [30|60] [interp 0|1] — Show or set the physics tick rate (default 30, the original's logic rate) and physics interpolation (default on). Runtime only, not saved.
god [0|1] — Toggle (or set) god mode: no damage or radiation, magic and mana stay full, spells cost nothing. Port debug only.
arena — Heal, turn god mode on and go to perf_arena, the dev-only stress land (12 busy Mane rooms, mixed enemies, stacked crates). Port debug only.
hardcore [0|1] — Print or set hardcore mode for this profile. In hardcore a death ends the run.
hardinv [0|1] — Print or set limited inventory for this run, with carried weight against each limit (weapons, spells, equipment, ammo, other).
rep [n] — Print or set the reputation (pers rep), shown with its title on the PipBuck status page.
refill — Restock every vendor now, as a visited land does (Game.refillVendors): stock tops up, waiting tasks open, info 'refill'.
vendor [id] [inter] — List the Vendors.xml ids, or open that vendor's Торговля page without its pony. inter is the npc type (doc, adoc, vdoc, v), default none.
stand — Open the base weapon stand screen.
