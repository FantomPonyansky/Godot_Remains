# Port rules — deliberate differences from the original

Every decision here was made by the user on purpose. Do not "fix" these back to the original. Anything not listed should match the original (see `KNOWLEDGE_BASE.md`).

If an earlier request blocks an accurate port or causes bugs or performance issues, ignore it. If a new request would, explain the consequences and wait for confirmation.

## Content and versions

- Content baseline is the 2021 release (1.0.2) plus the Steam base fixes (rooms, text, languages, `texture1`).
- The Steam DLC 1.0.4 rebalance is a selectable mode beside the base game, not a replacement. Ask the user about each value that looks like a test leftover before copying it.
- Languages: all 9 Steam languages. System language on first launch, then the player's choice is remembered.

## Project

- Fully non-commercial (user, 2026-10-26). Own code: PolyForm Noncommercial 1.0.0 with the same kind of additional permissions as Remains: Unity (`LICENSE`, `LICENSING.md`, `ADDITIONAL_PERMISSIONS.md`). List any adapted file in `THIRD_PARTY_NOTICES.md`. Code adapted from Remains: Unity (PolyForm Noncommercial) is allowed with its notices; see `KNOWLEDGE_BASE.md` "Other remake".

## Future multiplayer (2026-10-26, user)

Planned after the port is finished, as a separate mode: true online co-op, P2P, several players, via Steam. Do not implement it now. When making architectural choices, prefer the option that does not block it:

- New per-character state (stats, inventory, effects, binds, pets) goes in an object a player owns, not in a new global singleton. Callers pass the player; avoid new "the player" lookups.
- Keep input apart from simulation: read input in one place and turn it into commands; the simulation acts on commands.
- New gameplay randomness (hits, loot, AI choices; not purely visual effects) goes through one seeded source rather than a bare `randf()`.
- Things that matter to world state (doors, loot, kills, flags) change through one function each, so they can later be run by the host and sent to others.
- "Near the player" rules (room activation, sight, music) should take a set of positions where cheap.
- Do not add new world pauses for UI unless the original has them.

## Movement

- A ladder that ends at a hatch (a door wider than tall) continues through it: one rail tile inside the hatch, usable only while it is open (`play_land` door cells, `begin_land._hatch_ladders`).

## World

- Camera (2026-10-25, user): not locked on the player. A free circle of 1/3 screen height diameter; past it the view catches up faster the farther out (`player_camera.gd`). The original shows the whole room when it fits the screen and only follows the player, clamped to the room, when it does not (Camera.calc); seamless rooms cannot do that, so the free zone stands in for it.
- Seamless rooms: camera and fog flow across room edges; enemies, bullets and objects cross rooms.
- Enemies are not reset when the player returns to a room (user, 2026-10-28). The original restores them to full HP, at their start point and calm, after more than two other visits (`Location.reactivate`, `Unit.setNull`). Here they stay as they were left.
  - Exception (2026-10-26, tester): back rooms and trial rooms show only themselves and the camera stays in the room, as in the original (`map/back_room.gd`).
  - Exception (2026-10-25, user chose B): enemies in a room whose scripted area is still enabled do not see or hear the player outside that room until they are aware of the player (surf end raiders).
- Fog layout memory: remembered layout and static objects stay visible, dimmed. Trial rooms with `retdark` (`labirint`, `floating`) hide everything outside line of sight.
- Camps (`tip base`): normal fog, but seen tiles never fade and line-of-sight hiding is off. The full camp reveal was tried and reverted.
- Line-of-sight fog never hides the object the player holds with telekinesis.
- Lift positions are saved (the original does not).
- Begin and Surf are linked both ways: the begin exit always leads to Surf, and the far-left end of the Surf arrival tunnel (room 0,1, cell 0) leads back to the begin exit (`play_land.SURF_TO_BEGIN`, `game.BEGIN_EXIT`). The original never lets you return.

## Visuals

- Levitation glow on everything held by telekinesis, matching the weapon glow.
- Melee weapons stop at walls between the chest and the grip, and blades back off along their axis (`player._keep_out_of_walls`), beyond the original's target clamp.
- UI text and art draw with linear filtering; world art stays nearest.
- Units (player, enemies, NPCs) move to OTHER's part rigs: bone nodes with part sprites driven by an AnimationLibrary, armour swapped on the bones. Pre-baked per-clip, per-armour sheets are retired as each unit passes the side-by-side check in `tests/anim_probe.tscn` (user, 2026-10-28: priority; sheets cost memory and cause blur and broken frames).
- Pony bosses' guns (raider boss carbine / flamer) stay on the side mount every tick (user, 2026-10-31). The original's krep 0 gun eases to weaponX / weaponY by 1/5 a tick and trails behind a moving boss (`Weapon.actions`). It still mirrors by the target's side.
- Buch's carbine ("The Last Argument", carbine^1) draws the red-striped Patriot art `visassr_1` (user, 2026-10-29). The original has no `viscarbine_1` and falls back to the plain carbine (`Weapon.getXmlParam`). His stats and drop stay carbine^1.

## Combat

- Explosives on every land damage walls in the blast disk (`wall_span.apply_blast`). They also smash `explcrack` safes and crowbar-eligible crates in that disk (`land_props.blast_boxes`). Original `Bullet.explosion` only `Box.damage`s the aimed / sticky `targetObj`; ordinary boxes still take no blast.

## Controls

Keyboard follows the original `Ctr.as keyXML`, except: arrows removed from gameplay (menu focus only), shoot is left mouse only (J is quests), telekinesis is Q and right mouse.

Pad (Xbox names; the original has no pad):

| Action | Pad |
|---|---|
| Move / climb / crouch | Left stick (D-pad removed from gameplay) |
| Jump / levitate | A |
| Shoot / melee / telekinesis | RT / RB / LT |
| Attack spell / defensive spell | D-pad Left / Right |
| Throw grenade | LB |
| Interact | X (B is not interact) |
| Y | Tap: crack if available on the object under the cursor, else reload. Hold: pet command |
| Next / prev weapon | D-pad Up / Down tap |
| Weapon + attack-spell wheel | D-pad Up hold: world frozen, right stick picks, release applies, centred cancels, LB / RB pages of 12 |
| Defensive-spell wheel | D-pad Down hold, same rules |
| SATS | B in gameplay; B is back in menus |
| Sprint / PipBuck / pause | L3 (tap latches run) / Back / Start |
| Quick heal / quick mana | R3 tap / R3 hold |
| Armour ability | Share / View |
| Menus | D-pad and left stick, LB / RB tabs, LT / RT pages, right stick moves the mouse, then A clicks |

- Dash: sprint pressed twice within 300 ms (Shift or L3), toward facing.
- Use item, next / prev item, camera look and zoom, and the quests page stay keyboard / PipBuck only on a pad.
- The cursor tooltip shows Y when a crack action is available.
- Options extras: language, camera distance, pad binding column, stick dead zone, cursor speed, aim assist.

## Menus and PipBuck

- Main menu: Exit is a sixth button below Credits. Controls moved into PipBuck options. The debug tools (enemy lab, map editor) sit top right and only exist in dev runs. Exception (2026-10-27): the ported room editor (`docs/EDITOR_PORT_PLAN.md`) ships to everyone, and rooms saved with it in `mods/rooms/` of the user dir plug into the game without a rebuild. The editor must only produce rooms and maps fully compatible with Editor.swf and the original game (2026-10-27): no new cell tokens, tile shapes or attributes the original cannot read (for example, partial tiles stay bottom-filled zForm 1–3 only).
- The pause panel is retired: pause opens the PipBuck on Menu; Tab / pad Back reopens the last page and sub-page. "Main menu" sits right of the Menu sub tabs.
- In game, the crystal ball opens the appearance window as PipBuck page 8 (user confirmed).
- The PipBuck page button for pip `main5` reads "Menu" / "Меню" (`port_strings` `pip_menu_tab`), not the original "Main menu" (user, 2026-10-28).
- Save slots also store the hero's look, worn suit, play time (`play_ms`, Game.t_save) and version, so Menu / Load shows the OTHER/original showSaveInfo card with a pony preview. Slots saved before this have no preview look (live appearance) and no play time.
- Intro story screen text is `intro_story` in `port_strings.json` (not in the original text files).

## Builds and tools

- Debug console is always available (key left of 1). Debug hotkeys F1, F6–F8 need the `--debug-keys` launch flag. Dev scenes are excluded from builds.
- Release builds are one executable per platform (Windows `RemainsPort.exe` plus a console wrapper, Linux x86_64) and one shared base `RemainsPort.pck` (not embedded). Small changes ship as patch pcks; the base pck is rebuilt from time to time (user, 2026-10-31). File logging is on, capped at 5 files (user, 2026-10-31). The room editor ships in tester and user builds (user, 2026-10-31); keep `scenes/room_editor.tscn` and `scripts/editor/` out of the export excludes.
- Load-on-demand of art (Phase 9) must sit behind one switch: project setting, console command and launch flag. Off means preload as now. Default on (2026-10-25, user approved the plan).
