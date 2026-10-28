# Knowledge base — the original game

Facts about Fallout Equestria: Remains itself: versions, sources, mechanics confirmed in the AS3, wiki checks, and behaviour that looks like a bug but is original. Nothing here describes the port; see `IMPLEMENTED.md` for that.

## Versions

| Version | Where | Notes |
|---|---|---|
| Old (2019 swf) | `original\swf\pfe.swf` | Older room set. Not the baseline. |
| 2021 release, 1.0.2 | `original\release_2021\FoE - Remains` | Port content baseline. Rooms XML, music, `text_ru.xml`, `Editor.txt`. Analysis: `original\decompiled_2021\SUMMARY.md` (1016 classes, none added or removed vs old). Plant / sewer rooms come from this swf. |
| AS3 source | `original\reference\Remains-Source2` | Built on 1.0.2. `units.xml` / `weapons.xml` in `Modules\core\AllData\`. Decompiled 2021 scripts: `original\decompiled_2021\new\scripts\fe\` (`unit/`, `weapon/`, `serv/BlitAnim.as`, `loc/Trap.as`). |
| Steam base, 1.0.2 | Steam install, e.g. `D:\Steam\steamapps\common\Remains` (app 3908900, `pfe.swf`) | Code and AllData / GameData identical to 2021. Fixes outside the swf, see below. |
| Steam DLC, 1.0.3 | same, `DLC\pfe.swf` (app 3444880) | Rebalance, see below. |
| Steam DLC UI, 1.0.4 | same, `DLC\pfeUI.swf` (launched by `DLC\application.xml`) | On top of 1.0.3: `allDamMult` v1 0.99 and its textvar, doctor heal 49 instead of 50. 1.7 MB larger than `pfe.swf`; UI art not yet compared. |

Unit animation sources (author's FLA, XFL inside, vector): `original\fla\`. `PonyAnim.fla` (AJ17, Equidroid, Protectopon, Raider1-9, Zombi0-9), `SlaverAnim.fla` (Encl1-4, EnclBoss1-3, Raider1-6/9, Ranger1-3, Slaver1-4/6, Zebra1-5), `Alicorn.fla` (blu, green, purp, red), `griffon.fla` (grif1-5). `Generator.as` renders the `all` clip into the sprite.swf blit sheets: 130 px cells, 24 × 9 grid, rows stay 2, trot 17, run 8, jump 16, die 20, die 13 (from frame 21), derg 8, plav 24, laz 12; it also prints the head point (`head.morda.mon`) and head rotation per frame. Render without Animate: `tools/xfl2svg` (github PluieElectrique/xfl2svg, plus `tools/xfl2svg_radial_gradient.patch`; upstream skips radial gradients, which most fills use) to SVG, then `tools/resvg` (0.49) to PNG at any zoom. Godot's SVG loader drops the feColorMatrix filters, so use resvg. Each unit's body clips (`Objects/Units/<name>/body_trot` etc.) render as symbol timelines; nested clips stay on frame 1, as in `Generator.as`. Known gaps: radial-gradient strokes, tweens. FLA folder names do not match the sheet numbers: FLA `Raider1` is `sprRaider3`. Map by look before use.
Sheet units with no FLA: scorp1-3, rat, molerat, ant1-3, tarakan, owl, phoenix, hellhound, necros, gutsy, gutsy1, one of protect / protect1, one slaver (6 sheets, 5 in the FLA). Mercs use the griffon sheets. Vector units (robots, turrets, drones, slimes, bloodwings, fish, mines, most bosses) come from pfe.swf and do not need these.

Other remake: Remains: Unity by Hemito (`C:\Users\Командор\Remains-Unity`, github Hemito/Remains-Unity, snapshot 2026-10-12). Own code under PolyForm Noncommercial 1.0.0 (+ donation permissions). This port is non-commercial too (user, 2026-10-26), so their code may be adapted: keep their LICENSE, LICENSING.md, ADDITIONAL_PERMISSIONS.md and the `Required Notice:` line (in `THIRD_PARTY_NOTICES` of this repo), and mark which files are based on theirs. Has: Mirror/KCP co-op (per-actor `owner`, host commits shared changes via one domain function each, JSON world snapshots, per-level pause, character vs world saves), CPU room light maps + GPU radiance cascades + projected actor shadows, `tiles-manifest.json` (908 tile symbols from the DLC swf), `pony.json` part rig, `definitions.json` (442 AllData defs), `decor-without-picture.json` (light-only decor). Content: only plant (55 rooms) and rbl (2) converted; few weapons, raider and radroach.

Steam scratch: `original/steam_decompiled` (`diff_steam.py`, `diff_2021_vs_base.txt`, `diff_base_vs_dlc.txt`, `diff_dlc_vs_ui.txt`, FFDec script exports `base/`, `dlc/`, `ui/`).

### Steam base vs 2021

- `rooms_plant`: `door1` at 28,5 removed; the `table` chest at 1,18 became `bigmed`, plus a second `bigmed` at 1,15.
- `rooms_prob`: the `bigexpl` prize box at 10,22 lost its `glycerol` item.
- `text_en` ~220 changed lines and `text_ru` ~50: typo and punctuation fixes.
- Languages: `ua`, `es`, `jp`, `tw` new; `de`, `pl`, `zh` grown; `lang.xml` lists all 9 (ru, en, ua, zh, tw, pl, de, es, jp; default en).
- `texture1.swf`: DefineBitsLossless2 ids 1139, 1141, 1143, 1145 changed (two replaced, two renumbered). Owning symbols not yet identified.
- Byte-identical: sprites, sounds, music, `texture.swf`, all other rooms (70 files).

### Steam DLC 1.0.3 vs base

Code (13 classes):
- `PipPageMed`: free doctor heal when an organ is ≤ 127 and level < 7 (base: ≤ 2 and level < 6), heal 50.
- `World.boxDamage` 0.2 → 0.3. `LootGen` power_comp chances 1 / 0.3 → 0.7 / 0.7. `Invent`: two constants (25 → 114, floor 0.3 → 0.5).
- `Pers`: `manaHPRes` 0.1 → 0.3, `shitArmor` 20 → 100, organ damage × `organMultPot`, and × (maxhp − rad) / maxhp with `radChild`.
- `Spell`: mana costs × `warlockDManaMult`.
- `Unit`: the EMP / astro vulnerability cut only for heroes; effect `v0` defaults (add/res 0, mult 1); wall-impact damage ×0.5 for non-players; combat music hold 150 → 210.
- `UnitPlayer`: regen and the mana floor stop in battle (`t_battle`); sprint-flight and run-mana without alicorn; telekinesis mana ×3 instead of /3; magic needs `throwForce > 0`; spell mana `1 / spellPower`, mana damage ×0.5; shield hp decay rule.
- `UnitSlime` `hpmult 0.01`. `Weapon` recycling checks `ammoBase`.

Data: ~200 AllData edits (punch 25, spears / lances / BFG / mines / defwave / eclipse, unit accel and brake, `rep`, prices) and GameData edits (scripts, quests, vendor stock). Values that look like test leftovers: intro smoke scene gives `xp 50000` (base 500) and comments out `control off`; turret-type units `hp='010'`; `a_magic perslvl='00'`; `test` weapon `destroy 9999`.

## Sources and art locations

- Original timing is 30 ticks/s. Port velocity is px/s, so dy per tick = velocity.y / 30.
- FFDec is in `tools\ffdec`. Never run `-export sprite`, `-selectclass` or `-selectid` on the whole `pfe.swf`; it thrashes disk and RAM. Trim with `swf_trim.Swf().trim(ids, small)`, then export `sid:1`. Script-only export of a whole swf is fine (~1–2 min).
- An svg export's `matrix(1.0, 0.0, 0.0, 1.0, tx, ty)` gives the registration anchor.
- Terminal and button art is in `texture1.swf`: `viselpanel` sid 465, `visknop1` sid 113, `visalarm` sid 469. Terminals are one 40×40 frame, anchor bottom centre, no on / off / hacked frames.
- Loading screens: visualWait 392 (sprite 383, 16 frames). Story screen visualWait.story sprite 391, lmb icon sprite 390 (frames 1–15 lit, 16–30 unlit).
- Main menu: visMainMenu, pipka 469, groza 423, city shape 425. Panels 495, slot rows 498, buttons 506, difficulty tiles 524, name box 517, button glow 474, language box 399, link icons 486, dialVid 607.
- PipBuck: fon 1131, page frame 838, page buttons 1139 / 1142, sub tabs 506 / 1007, top box 1150, help "?" 1144, help box 1158, right panel 1153. Controls page key icons: frames 2–6 of symbol 943.
- Griffon arms: visualGrifArm1–5 = sids 2245, 2237, 2229, 2221, 2214.
- Cursors: `original/ui_xfl/LIBRARY/GUI/cursor/` (`arrow`, `target`, `target1`, `target2`).
- Spells: inh 3631 (distortion field), shit / visShit (shield), cryst 3687, vismwall, tileGwall. `visbulmray` has 3 frames (child 3885).

## Mechanics confirmed in the AS3

**Player**
- Stun is cleared every tick (`UnitPlayer.as` ~1376), so player stun is visual only.
- Weapon favourites: keys 1–9, 0, -, = are cells 1–12; sprint+key is 13–24.
- Run is hold (`isRun = keyRun`). The dash jerk is innate, not a perk (`UnitPlayer.as:2390-2424`).
- Crack (`keyCrack`, `crackAction` ~1831, `Interact.needRuna` / `useRuna`): object under the cursor, in reach, not in a base or as a rat. Rune on a lock more than one level above lockpicking; `reboot` on a secure terminal; sets off an alarm trap (`mineTip 6`). Keyboard Y does nothing when unavailable.
- Lurk (`UnitPlayer.as` ~968–1086): hides in the back layer, `detecting = 0`, half visibility, `lurkDexterPlus`.
- Edge poses `getStayFrame`: stay frames 27–48 standing past 0.30 overhang, 49–70 crouched.
- PipBuck facing left: pip2 at depth 25 over flleg3 (`UnitPlayer.as:4623-4639`).
- Ladders: `checkStairs` pins the 50 px box to the rail; the far 10 px may overlap a wall. Melee on a ladder: only the base point centres (`UnitPlayer.as:3266`).
- Stairs: a body on ordinary floor walks under a stair unless already on one or holding up (`Unit.as:1480-1490`).
- Sky flight (`_sky_step` source): damp 0.9 / tick (0.96 running), cap walk × 1.3, sin wobble.
- Levitation glow: t_levitfilter / setFilters, levitFilter1 (own, fades in 2 / tick, 10 while the air jump pushes, out 1), levitFilter2 (held by a foe). Levit fall clip body_levit_484: frames 50 and 65 gotoAndPlay(17), 75 stop, 76–80 empty.
- Alicorn: death runs `gameover`, no respawn.

**World**
- `Game.gotoLand` refuses non-base lands when `dopusk()` fails (head, torso, legs or blood ≤ 1) and shows `nocont`.
- Water: per tile (`*` in the tile code) plus an optional room level; drains through broken walls (`recalcWater`). `wrad` is per room. Electric fences shock on metal, ladders and water (`electroDam`); they do not forbid interacting.
- Battle timer `GameContainer.t_battle`: 120 ticks while a foe tracks the player, −1 a tick, 30 on a foe's death, 0 on land entry.
- Lift position is not saved.
- Horseshoes (`Bonus.as take`): the last one also grants `loc.summXp` and shows `sneakBonus` when `!loc.detecting`.
- "Take all tasks": `PipPageInfo` OK on the quests page, only in a base, `addAllQuestsToGameClass` (text `pip alltask`).
- Camps (`tip base`: `rbl`, `covert`, `src`, `stable_pi`, `way`): entities stay peaceful until attacked. Map `fraction="100"` makes a unit player-side (`UnitTurret.as:115`, `UnitRaider.as:451`).
- Room editor (`original/editor_2021/`: Editor.swf, Editor.txt, decompiled `scripts/`): 48 × 25 grid of five slots per cell plus zForm, map mode by `<land serial="1"/>`, palettes from AllData `mat`/`obj`/`back` `ed` fields. Summary and port plan: `docs/EDITOR_PORT_PLAN.md`.
- Spawn cost and room flags come from `Editor.txt`; `keyloss 2` is marked "(?)" there.
- Generated lands (`Land.buildRandomLand`, `Game.enterToCurLand`): a new Land is made only when `crea` (map travel `beginMission`, `gotoNextLevel`); the camp terminal (`CheckPoint.teleport` main) returns to the kept Land at `currentCP`. Plant (conf 0) is 3 rows only at landStage 0; `beg*` entrance rows only while `act.visited` is false. A back room is `locs[x][y][1]`, built with the front cell's options (mirror, water, ramka 1 so shut) and no setDoor. `newRandomProb` takes trials with level ≤ landStage and no `prob_<id>` trigger; trials without a level count as 0, so boss trials (tip 2) such as plant `ant_breeding` can appear on the first level. `Location.createExit` writes `prob={exitProb}` (plant `exit_plant` / `exit_plant1` at stage ≥ 2). `Interact.allAct` uses that `prob` first (`Land.gotoProb`, same Land); `allact==exit` with no `prob` is `Game.gotoNextLevel`. The `exit_*` rooms_prob rooms run `refill` + `upland` on enter; their right-end `exit` has no `prob`.
- Random generation: registry `rnd="1"` (map tip may still be rnd, story, hard, or base). One room file and conf: random_plant rooms_plant conf 0 (4×6, 3 rows at stage 0); random_sewer rooms_sewer conf 2; random_stable rooms_stable conf 1; random_mane rooms_mane conf 3; random_canter rooms_canter conf 5; random_mbase rooms_mbase conf 4; bunker rooms_mbase conf 7; random_encl rooms_encl conf 6; stable_pi rooms_pi conf 10; stable_pi_atk rooms_pi conf 11.
- Every room is 48×25. There is no size class and no room `type` tag.
- An ordinary cell draws a room with no tip, or a tip other than beg0, back, roof, pass, passroof, roofpass, vert, surf, and without nornd.
- `level` must be ≤ the cell maxlevel: the land stage, except mbase is always 0, bunker always 1, and stable_pi always 10.
- Weight is kol². kol is 2, or 1 for uniq (or tip uniq), or 4 for test (level forced to 0). A weight of 4 at level 0 becomes 2 when maxlevel > 1.
- The same template is not placed to the left or above. Mbase (conf 4) sets kol to 0 after one pick, so that room is not drawn again.
- Fixed cells skip the ordinary draw and take a matching tip: plant beg0–beg3 before the first visit (conf 1, 2 and 5 use beg0); mane roof, pass, passroof; canter surf; mbase vert and end; bunker beg1, vert, end1; stable_pi beg0 and roof; stable_pi_atk pass.
- Doors are 22 widths (0 shut, 2–4 open). A missing doors row means every slot is 2. A passage is the overlap of the two facing slots; doors do not choose which room is drawn.
- Back rooms (tip back, or options.back) are a second layer, not a cell in the draw. Boss trials and the stage exit come from rooms_prob and the land exit, not from this pool.

**Traps and objects**
- `Trap.attKorp`: floor spikes (att 1) hurt only a non-flyer falling at dy > 8 px/tick, damage massa · dy / 20 · dam · (1 + dif · 0.1); ceiling spikes (att 2) only one moving up; then 30 ticks of `neujaz`.
- `Box.fracLevit` keeps the lifter's faction until the crate lands, so a crate the player dropped does not hurt the player.
- No fall damage; only a throw (`t_throw` + `damWall`) hurts on landing.
- Explosions do not damage ordinary boxes. `Bullet.explosion` only `Box.damage(destroy)`s `targetObj` when that object is a Box. `explcrack` (safe, wallsafe) is the sticky-cling flag (`PhisBullet` throwtip 2); the box still only takes blast damage if it is `targetObj`. `explDestroy` walks tiles in the disk. Port: blast disk also `damage_box`s explcrack / crowbar crates (`PORT_RULES`).

**Enemies**
- Weapons are separate sprites. `UnitPon.setWeaponPos(tip)`: krep 0 (unicorn) X + scX · storona past the body edge, Y − scY · (0.4 tip 1, else 0.7); krep > 0 at (X, Y − 0.5 · scY). `UnitRaider.setWeaponPos`: unless enclWeap, tips 1 / 2 / 4 use wPos[row][frame] {x, y, r}; tables wPosRaider1 / 2 (by sex), Zebra1, Ranger1, Encl1, Griffon1, Gutsy, Alicorn, AlicornBoss. visBmp offset = sheet offset − cell / 2.
- Guns (`Weapon.actions` / `animate`): krep > 0 snap, rot = atan2(dy, |dx| · storona); krep 0 eases (target − X) / 5 per tick and flips past the target. Melee `WClub`: gripped rotation 90 · s − 90 + r · s; levitated 40 px ahead, idle −π/2 − π/6 · s, swing curve by t_attack / rapid. telecolor GlowFilter only on a levitated weapon. `UnitMerc` draws the griffon arm over the weapon.
- Weapon tips: 1 melee, 2 light guns, 3 heavy, 4 explosives, 5 magic, 0 built-in. Gutsy, sentinel and drones use built-in `vweap` clips (visroboplasma, visrobogatl, visdronlaser).
- `UnitRaider.animate`: dying on the floor `die` (or `fall` after `death`), airborne `death`. Floor: `stay` if dx 0 or aiState 7; `run` for attackerType 0 attacking or aiState 8; `walk` for a walker in aiState ≤ 1 or 4; else `trot`. Air: derg (levit), laz, plav, else `jump` held at len · (dy · 0.6 + 8) / 16. `UnitRanger` has no derg / plav. AS3 aiState 7 = dash prep, 8 = dash.
- Flyers (`UnitRaider` with `flyer`: Enclave, mercs): take off when the target is over 80 px above, after 6 ticks airborne, or swimming; land after 20 ticks of floor contact (`turnY < 0`). A calm flyer steers to its floor line. Stalking within `stalkDist` it hovers.
- Hellhound: run |dx| > 6, walk > 1, sit / polz crouched, laz, jump stab. Zombie: run in aiState 3, trot in aiState 2 or |dx| > 6, else walk; pre / super / dig; revive plays `die` backwards over the last 20 ticks of t_res with sparks. Eqd: walk |dx| < 4, run > 9, else trot. Ant / Monstrik (rat, molerat, tarakan, scorpions): run |dx| > 5 else walk, attack restarts at t_punch 15, plav when swimming or levitated, looping jump; ant climbing walk / stay. Enclave / merc / eqd / protect play walk / trot backwards when moving away from their facing. Necros never mirrors.
- UnitProtect: ground robot, jet `fly` only while `jump_n > 5`. UnitAlicorn lands in aiState 4 and sits / walks.
- Boss raider / boss necr pick the jump pose once at jump start; boss necr has `derg`. Msp walks when levitated. A fixed turret held by telekinesis shakes ±3°.
- Vortex minions wait 500 ticks (`UnitBossEncl` `emit_t = 500`).
- Energy kills: laser burns a corpse away 50% of the time (always at −3× max HP or with no corpse); plasma always melts (`Unit.as` 3199–3216).
- Telekinesis (`Telekinesis.as`): alicorn1–3 t_tele cycle (findBox targets the enemy 25% with teleEnemy for purple, half for others); ghoul ss 2 / 7; Blood Moon attState 3. teleEnemy = 60 × effect mults.

**Presentation**
- Main menu `Displ.as`: eye blink, mane / tail displacement, pistol bob, magic rings, lightning; Flash screen blend.
- PipBuck `resizeScreen`: 1:1 at 1200×800 or larger. PipPageOpt option order: fullscreen, zoom100, quake, opt1_1..3, help_mess, dial_on, show_hit1/2, hint_tele, sys_cur, show_favs, mat_filter, err_show, autotake. Auto-pickup: 14 AutoPickupManager switches, `Item.checkAuto`; only loot created with `auto` is auto-taken.
- `harddie` is never played. World-map blink signs show only while `helpMess` is on.
- Armour on the pony: fur-class `*0_N` sprites are removed when a suit is worn (`Obj.as:167-221`). Helmets: morda 273 stops on the armour label (16 frames, 15 suits); helm sprite 31 is empty.
- Spell-II does not replace spell-I; both are kept (`ItemInteraction.addWeapon`, `Equipment.addWeapon`).
- Beams fade 4 ticks at alpha liv · 0.25 (`Bullet.as:196`) and follow the horn (`weap.bulCoords`).

- Land backdrop (`Grafon.drawFon` / `setFonSize`, `World.vfon`): symbol `land.act.fon` from texture.swf (fonCanter 106, fonDarkClouds 103, fonDefault 100, fonEnclave 98, fonFinalb 95, fonFire 92, fonRuins 89, fonWay 86, fonClear 83), screen-fixed under the world, scaled to cover the stage from the top-left. Gaps in the back layer show it under colorBmp black at alpha 170 + darkness, except in `backwall='sky'` or `transpfon` rooms (alpha restored). Room `colorfon` replaces the room colour filter on it. Exporter: `tools/swf_export/export_fon.py`. `drawBackWall(name)`: "sky" draws nothing; an empty or unknown name draws tBackWall.
- Failed disarm (`Interact.fiascoRemine`): mineTip 6 raises the alarm, else `explosion()` = `Bullet.iExpl(damage, destroy, 260)` from a fresh Unit; damage `mine · 50 · (0.8..1.2) · (1 + locDifLevel · 0.1)`.

## Wiki check (2026-10-24)

Compared with the Remains wiki (1.0.2 pages: main quest, quests, locations, gameplay, trials, endings). Quest and land content matches: the full main-quest chain and 42 side quests. Endings: alicorn death is game over; Thunderhead at reputation ≥ 70 is the good ending (not the quests page's "max 50"), otherwise neutral; the funeral is land `grave` from the last-battle script.

## Looks like a bug, is original

- Begin has no battle music: its roaches, rats and bloatsprites carry no `<snd music>`. Each land has one idle track (`Lands.xml music`), looped.
- Shooting range has no door (user confirmed).
- Water is not radioactive in every room.
- Critical-organ refusal at the `begin` exit (see `gotoLand` above) can soft-lock the tunnels; it is faithful.
