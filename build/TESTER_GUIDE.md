# Fallout Equestria: Remains — Godot port, tester guide

Thank you for testing. This is a port of the 2021 Flash release of *Fallout Equestria: Remains* to the Godot engine. The goal is a faithful port: the game should look, sound and play like the original. Anything that behaves differently from the original is a bug worth reporting, even if it seems small.

## 1. Running the game

Nothing needs installing. Windows 10/11 or Linux (64-bit) and a graphics card with Vulkan, Direct3D 12 or OpenGL 3.3 drivers.

**Windows** (`windows` folder)
- `RemainsPort.exe` is the engine and `RemainsPort.pck` is the game data; keep them together.
- Updates may come as a small `patch_NNN.pck`: put it in a `patches` folder next to `RemainsPort.exe` (create it once) and keep the earlier patches there too; each one carries only the changes since the previous. If you missed one, ask for it. A new full build replaces the `patches` folder: delete it.
- `RemainsPort.console.exe` starts the same game with a black text window that shows engine messages live. Use it if the game crashes or freezes, so you can copy what it printed. It needs `RemainsPort.exe` beside it.
- Settings, controls, saves and logs are stored next to the game: `settings\`, `saves\` and `logs\`. Delete those folders for a completely fresh start. On first start the game copies an older install from `%APPDATA%\Godot\app_userdata\FoE Remains\`. If the game folder is read-only, it uses that AppData folder instead.

**Linux / SteamOS / Steam Deck** (`linux` folder)
- `RemainsPort.x86_64` is the engine and `RemainsPort.pck` is the game data; keep them together. Patches go in `patches/` as on Windows. Mark it executable (`chmod +x RemainsPort.x86_64`, or file Properties → Permissions), then run it. Run it from a terminal to see engine messages.
- Steam Deck: in Desktop Mode, Steam → Add a Game → Add a Non-Steam Game, pick `RemainsPort.x86_64`. Do not force Proton for this build. The debug console needs a keyboard (key left of 1); use Steam's on-screen keyboard or a USB keyboard. The Deck's 1280×800 screen is not yet checked, so report any cut-off or unreadable text.
- Settings, saves and logs are stored next to the game: `settings/`, `saves/` and `logs/` (or `~/.local/share/godot/app_userdata/FoE Remains/` if the game folder is read-only).
- The language follows your system on first launch (English or Russian). Change it in PipBuck → Menu → Settings, or with the buttons at the bottom right of the main menu.

## 2. What to test first

Please go roughly in this order. The first items changed most recently and need the most eyes.

1. **A normal playthrough from a new game.** Play from the stable (`begin`) through the surface and on to the base camp without using the console. Report anything that blocks progress: a door that will not open, a trigger that does not fire, a dialogue that does not start or does not end, a room you cannot leave.
2. **Enemies with weapons.** Raiders, slavers, zebras, rangers, Enclave soldiers and griffon mercenaries now draw the weapon they actually use:
   - Unicorns float it in telekinesis (with a coloured glow if the unit has one).
   - Earth ponies, zebras and pegasi hold it in their teeth or front hooves.
   - Griffons hold it in their claws.

   Watch for weapons in the wrong place, pointing the wrong way, not following the animation, or still showing after death. Also check that shots come out of the muzzle.
3. **Enemy animations.** Jumping, falling, walking versus trotting versus running, climbing ladders, swimming, being lifted by telekinesis, and dying (on the ground and in the air). Anything that looks odd compared with the original, such as a death pose in mid-jump or sliding without moving the legs, is worth a report.
4. **The PipBuck.** Esc opens it on the Menu page. Tab (keyboard) or Back (controller) opens the page you used last. Check every page and sub-page: status, inventory (all five tabs), information (map, quests, world map, notes, enemies), menu (load, save, settings, controls, log). Look for text or elements outside the frame, buttons that do nothing, and wrong help text behind the "?" button.
5. **Settings and controls.** Change every option and check that it takes effect and is still set after restarting the game. Rebind a few keys, then use "Default" to restore them.
6. **Saving and loading.** Save in several places (checkpoints, PipBuck save slots), quit to the main menu, load, and check that the room, inventory, quests and enemies are as you left them.
7. **Controller play.** If you have a controller, play a stretch with the controller only. See section 5 for the layout.
8. **Traps.** Rebar and spike traps should hurt only when you fall onto them, not when you walk through them.
9. **Everything else:** trading, doctors, crafting, the weapon stand, hacking terminals, lockpicking, mines, the world map, trials and companions.

## 3. Reporting a bug

For each bug, please send:

- What you did, what you expected, and what happened instead.
- The land and, if possible, the room. The PipBuck map shows where you are.
- A screenshot or a short video if it is visual.
- For crashes, freezes or anything strange, the newest file in the `logs` folder next to the game (`godot_<date>_<time>.log`). The game keeps the last 30 logs.
- Your save, if the bug can be repeated from it: the `saves` folder in the same place.

## 4. The debug console

The console is for testing only. It lets you skip ahead, give yourself items, and reach a spot quickly to check a bug.

- **Open and close it** with the key left of `1`, under Esc (`~` / `` ` `` on English layouts, `Ё` on Russian). The game pauses while the console is open. Esc does not close it.
- **Type a command and press Enter.** Words are separated by spaces. Put an argument in quotes if it contains a space.
- **Select something in the world:** while the console is open, left-click a unit or object. A ring marks it, and some commands then act on it (`select`, `params`, `set`, `effect`, `eff`, `remeff`). `clear` drops the selection.
- `help` prints the full list in the game.
- All item, weapon, armour, spell, land, vendor, trial and boss IDs are listed in `TESTER_IDS.md`.

### Command list

| Command | What it does |
|---|---|
| `help` | List every command. |
| `give <id> [count]` | Add an item, weapon, armour, amulet, consumable or crafting scheme. Count defaults to 1. Example: `give pot2 5`. |
| `spell <id>` | Add a spell or magic weapon. A spell becomes the current spell; a magic weapon is equipped. Example: `spell mbul`. |
| `debug` | Once per run: every spell, weapon and armour, 60 rounds of each ammo type, 3 of each of 3 items from every consumable type, and enough level, telekinesis and perks for air jump and hover. |
| `heal` | Full health, head, torso, legs and blood; clears radiation. |
| `god [0\|1]` | God mode: no damage or radiation, magic and mana stay full, spells cost nothing. Toggle, or `god 1` / `god 0`. |
| `tp <x> <y>` | Move to room (X, Y) on the current map (near the floor). Optional extra `cell_x cell_y` for a tile. |
| `trials` | List every trial chamber ID and its land. |
| `trial <id>` | Jump to that trial chamber (rebuilds the land if needed). Example: `trial buttons1`. |
| `bosses` | List every boss arena ID and its land. |
| `boss <id>` | Jump to that boss arena. Example: `boss ant_breeding`. |
| `die` | Kill the player (the real death, then respawn at the last checkpoint; in hardcore the run ends). |
| `effect <name> [seconds]` | Apply a status: `cut`, `poison`, `igni` (fire), `ice`, `blind`, `acid`, `pink`, `stun`, `slow`, `potion_fly`, `alicorn`. Unit statuses need a selected unit; `potion_fly` and `alicorn` apply to the player. |
| `eff <id> [ticks]` | Add a game effect (for example `burning`, `drunk`, `mint`, `curse`) to the selection, or to the player when nothing is selected. 30 ticks = 1 second. |
| `remeff <id>` | End that effect on the selection or the player. |
| `select` | Print what is selected. |
| `params` | List the fields of the selection that `set` can change (for example `hp`, `lock`, `fraction`). |
| `set <field> <value>` | Change a field on the selection. Example: select an enemy, then `set hp 1`. |
| `set <node_path> <field> <value>` | Change a field on a node by path, without clicking it. |
| `clear` | Drop the selection. |
| `lands` | List all land IDs. |
| `land <id>` | Travel to a land the normal way (fade, same rules as an exit). It refuses with a badly damaged organ unless the target is the base camp. A land you already visited is kept as you left it. |
| `quiet <id>` | Travel to a land with enemy AI stopped. `quiet on` turns the AI back on without moving. |
| `openland <id\|all>` | Open a land, or all lands, on the PipBuck world map. |
| `worldmap` | Open the world map in travel mode. |
| `rep [n]` | Show or set reputation. |
| `hardcore [0\|1]` | Show or set hardcore mode (a death ends the run). |
| `hardinv [0\|1]` | Show or set limited inventory weight. |
| `refill` | Restock every vendor now. |
| `vendor [id] [inter]` | List vendor IDs, or open that vendor's trade page directly. `inter` can be `doc`, `adoc`, `vdoc` or `v`. |
| `stand` | Open the base weapon stand. |

### Useful recipes

- **Stuck after a fall in the tunnels?** A badly damaged head, torso, legs or blood blocks travel, as in the original, and the tunnels have no doctor. Type `heal`, then use the exit again.
- **Test a late land quickly:** `debug`, then `openland all`, then `worldmap`, or `land <id>`.
- **A trial or boss:** `trials` or `bosses` for IDs, then `trial buttons2` or `boss bloatking`. IDs are also in `TESTER_IDS.md`.
- **A room on this map:** `tp 2 1` for room (2, 1).
- **God mode:** `god` (or `god 1`). Endless HP, full magica, mana does not run out.
- **Look at enemies without being shot:** `quiet <id>`.
- **Test a weapon:** `give <weapon id>` and `give <ammo id> 200`. Weapon ammo IDs are in `TESTER_IDS.md` under Ammo.
- **Kill something fast:** open the console, click the enemy, `set hp 1`, close the console.

### Extra debug keys (optional)

Start the game with `RemainsPort.exe -- --debug-keys` (from a shortcut or a command prompt) to enable:

- **F6 / F7 / F8:** place a cooking stove / lab / workbench next to you.
- **F1** (controller Y) in the stable: show the stable map overlay.

## 5. Controls

Every key can be changed in PipBuck → Menu → Controls. These are the defaults.

| Action | Keyboard and mouse | Controller (Xbox names) |
|---|---|---|
| Move, climb, crouch | W A S D | Left stick |
| Jump, levitate (hold in the air) | Space | A |
| Shoot | Left mouse | RT |
| Melee | F | RB |
| Telekinesis | Q or right mouse | LT |
| Attack spell / defensive spell | T / C | D-pad left / right |
| Throw grenade | G | LB |
| Interact (hold for locks and mines) | E | X |
| Reload | R | Y tap |
| Pet command | U | Y hold |
| Burglar rune / electronic lockpick on a lock | Y | Y tap (when available) |
| Next / previous weapon | Mouse wheel | D-pad up / down tap |
| Favourite weapons and spells wheel | 1–9, 0, -, = (Shift + key for the second set) | D-pad up hold |
| Defensive spell wheel | — | D-pad down hold |
| SATS | V or middle mouse | B |
| Run (hold) / dash (double tap) | Shift | L3 |
| Quick heal / quick mana potion | H / B | R3 tap / R3 hold |
| Armour ability | N | View / Share |
| PipBuck (last page) / PipBuck Menu | Tab / Esc | Back / Start |
| Quests | J | PipBuck |
| Use item, next / previous item | P, ] / [ | PipBuck |
| Look around / zoom | ; / ' | — |

In menus: arrows or the D-pad and left stick move, Enter or A selects, Esc or B goes back, LB / RB switch tabs, and LT / RT switch pages.

## 6. Known differences

These are known and do not need a report:

- There is no fall damage, as in the original. Only being thrown against something hurts on landing.
- The favourites strip at the screen edge, the "zoom 100%" option and the error window option only save their value for now.
