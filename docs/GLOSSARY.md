# Glossary

Flash names kept in `godot/scripts` so a call site can be matched to the original. Mostly Russian transliteration, plus short original tokens (`tip`, `uid`, `pier`). English Flash names (`walkSpeed`, `keyRun`, `jumpdy`) are not listed.

`docs/PORT_RULES.md` "Modding": a later rename touches a name only when **mirrors original field** is `no`, and keeps an alias for one release. `yes` includes a name with no ActionScript field in a `##` comment or in `docs/KNOWLEDGE_BASE.md`.

## Combat

| Name | English | Where it comes from | Mirrors original field |
|---|---|---|---|
| `tip` | type (damage, heal, item, land, icon) | `HitInfo.tip`; `UnitPlayer.heal` tip; item and land `tip` | yes |
| `pier` | armour the shot ignores | `Bullet.pier` (`bullet.gd`) | yes |
| `desintegr` | chance to burn a near-dead unit away | `Bullet.desintegr` | yes |
| `dop` | extra: on-hit effect, or a skill that scales with raw points (`dop='1'`) | weapon `dop_*`; `skills.xml`; `Unit.dopTest` (bullet flies on through) | yes |
| `effect_dop` | that extra effect's amount on a hit | `HitInfo.effect_amount`, copied from the bullet's `dop_damage` | no (renamed to `effect_amount`) |
| `otbros` | knockback | `Bullet.otbros`, `Unit.otbros` | yes |
| `sila` | knock scale: random 0.8–1.2 times knocked/massa, at most 3 | `Unit.otbros` | yes |
| `shok` | shock | enemy `_shok` / `nshok`, cap `MAX_SHOK` | yes (Unit.shok) |
| `neujaz` | invulnerability, in ticks | `Unit.neujaz`, `Pers.neujazMax`; `Trap.attKorp` applies 30 | yes |
| `pinok` | stumble: blocks jump and a ladder grab; damage raises it | `UnitPlayer` (`player.gd` `_pinok`) | yes |
| `razn` | weapon level minus the skill; the gap that cuts confidence | `player.gd` `_razn`; PipPage `skillConf` | yes (Sats.razn) |
| `skok` | share of speed a throw keeps when it bounces (0.4) | `WThrow` `skok`; `bullet.gd`; `sats.gd` `SKOK` | yes |
| `tormoz` | brake: a throw keeps 0.6 of its horizontal speed; the effect is ground friction | `WThrow` `tormoz`; `Effect` `tormoz` (`game_state.gd`) | yes |
| `mtip` | melee shape: 0 swing, 1 thrust, 2 saw | `weapons` `mtip` (`player.gd`) | yes |
| `tipdam` | damage-type index on the weapon card | PipBuck `tipdam`; `Resistances.parseDamageType` | yes |
| `phis` | thrown body: passes units, bounces off solid tiles | `PhisBullet` (`bullet.gd` `phis`) | yes |
| `rashod` | rounds spent per shot | weapon magazine (`unit_gun.gd`) | yes |
| `dkol` | burst length | weapon `burst` (`unit_gun.gd` `dkol`) | yes (Weapon.dkol) |
| `att_korp` | contact hit when the boxes overlap | `Unit.attKorp` / `BodyAttack.attKorp` (`unit_brain.gd`) | yes |
| `krep` | weapon mount: 0 floats (unicorn), above 0 is gripped | `UnitPon.setWeaponPos` (`held_weapon.gd`, enemy `_krep`) | yes |

## Movement and body

| Name | English | Where it comes from | Mirrors original field |
|---|---|---|---|
| `porog` | step-up threshold, in pixels | `Unit.porog`; `porog_jump` is 10 while running or holding up before a jump | yes |
| `tele_porog` | mass the current Telekinesis level can lift | `Progression.TELE_POROG` | yes (Pers.telePorog) |
| `throu` | drop through a one-way shelf | `Unit.throu` (down+jump, swim, or `celDY` over 80 on a raider) | yes |
| `plav` | swim, or a crate's float | anim clip `plav`; `Box.isPlav` / `isPlav2` / `fixPlav`; `objs.xml` `plav` is `ddyPlav` | yes |
| `jumpp` | jump-hold ticks still left | `UnitPlayer` `maxjumpp` (`player.gd` `_jumpp`) | yes |
| `levidy` | upward acceleration while flying | `UnitPlayer` `levidy` | yes |
| `storona` | facing; left is −1 | `Unit.storona` | yes |
| `napr` | heading a brain steers | `ai_napr`, `ai_v_napr` | yes (Unit.aiNapr, Unit.aiVNapr) |
| `laz` | climb | anim clip `laz`; `UnitRaider` `t_laz` / `aiLaz` / `r_laz` | yes |
| `namok` | soaked, counted while swimming | `Unit` `namok` (`player_water.gd` `_namok_t`) | yes |
| `massa` | mass; an explicit crate value is xml/50, loot is 0.10 | `Box.massa`, `Loot.massa`, `Obj.massa` | yes |
| `sost` | state: a corpse, an item's hp/maxhp, or the alicorn form | unit `sost`; `Item` `sost`; `Run.sost` (Travel) | yes |
| `osnova` | crate this one is standing on | `held_prop.gd` `_osnova` | yes (Box.osnova) |
| `pers` | the character record | `Pers.as` (`Run` flags, `Progression.pers`) | yes |

## AI and senses

| Name | English | Where it comes from | Mirrors original field |
|---|---|---|---|
| `cel` | aim point or current target | `Unit.setCel` (`celX`, `celY`, `celDY`); `Sats` cel | yes |
| `ai_tch` | AI clock, one step per tick | Brain `aiTCh` | yes |
| `ai_tip` | room AI mode, such as `stay` | unit `ai` attribute (`npc.gd`) | yes (Unit.aiTip) |
| `budilo` | shout that wakes allies of the same fraction | `Unit.budilo` | yes |
| `fraction` | side; 100 is the player | `Unit.fraction`; map `fraction="100"` | yes |
| `v_konus` | sight cone, degrees; tested at half that angle | `units.xml` `vKonus` | yes |
| `observ` | sight multiplier | `units.xml` `observ` | yes |
| `durak` | dull-unit reaim chance (0.5) | `enemy.gd` `DURAK_REAIM` | yes (UnitRaider.durak) |
| `vsos` | suction toward the thunderhead | `UnitThunderHead` `vsos` (`t_vsos`, `VSOS_POROG`) | yes |
| `vzdrzhne` | colour shift on the thunderhead wreck | `dieTransform` (`brain_thunderhead.gd`) | yes |
| `ugol` | orbit angle | thunderhead `ugol` | yes (UnitThunderHead.ugol) |
| `distanc` | orbit or pull distance | thunderhead `distanc` | yes (UnitThunderHead.distanc) |
| `otschet` | scans a light-stepping player gets before a mine notices | `Mine.otschet` | yes |
| `otlozh` | sideways offset on a delayed necro curse | `brain_boss_necr.gd` `cast_curse` | yes (UnitBossNecr.castCurse otlozh) |
| `kol_emit` | minions out, and the cap | boss drone `KOL_EMIT`; thunderhead `kol_emit` | yes (UnitBossDron.kol_emit) |
| `kolth` | shots left in the drone's alternate volley | `brain_boss_dron.gd` | yes (UnitBossDron.kolth) |

## World, items, UI

| Name | English | Where it comes from | Mirrors original field |
|---|---|---|---|
| `kol` | count: stack, spawn, particles, room weight (`kol²`) | `Item.kol`; land generation weight | yes |
| `kol_en` | enemies placed in a generated room | `Land.setLocDif` (`land_spawn.gd`) | yes |
| `kol_phoenix` | phoenix already placed in that location | `land_spawn.gd` `loc.kol_phoenix` | yes (Location.kol_phoenix) |
| `opac` | opacity; a door with none uses `Box.door_opac` (1) | `Tile.opacity`; `fog.gd` `DOOR_OPAC` | yes |
| `wopac` | opacity of tiles under the water line | `Location.lighting` `opacWater` | yes |
| `frec` | particles per tick: dens × width × height / 100 | `Area` emitter (`area_fx.gd`) | yes |
| `radtip` | radiation kind: 0 rads, 1 gas, 2 pink cloud | `objs.xml` `radtip` | yes |
| `locktip` | lock kind on a door or container | `objs.xml` `locktip` | yes |
| `entip` | enemy-type index for a generated room | editor `ENTIP`; `land_spawn` `tip_enemy` | yes (options.entip) |
| `wtip` | room water type in the editor; on a vendor row, the category (`drink` when `ftip` is 1) | editor `WTIP`; `vendors.gd` | yes (PipPageVend.wtip) |
| `ftip` | food subtype; 1 is a drink | item row `ftip` | yes |
| `uid` | authored object id | room `uid` | yes (Obj.uid) |
| `wid` | authored id kept as the entity id | `Entity.claim` (meta `wid`) | yes |
| `dopusk` | travel allowed: no organ at 1 or below | `Game.dopusk` (`game_state.gd`) | yes |
| `propusk` | new-game option that skips the training land | settings `game/propusk`; intro is `World.setLoadScreen` | yes |
| `nazv` | display name | `UnitNPC.nazv`; save-slot label | yes |
| `trol` | PipBuck category and row icons | `assets/ui/pip/trol`; visPip icon frames | yes |
| `kol_bou` | marked-up total the player pays for the marked buy rows | `PipPageVend.selBuy` (`vendors.gd` `sel_buy`) | yes |
| `kol_sell` | total the vendor pays out for marked sell rows; a buy also adds list price here, and `trade` clears it | `PipPageVend.sell` / `sel_sell` | yes |
| `expl_kol` | how many blasts a weapon card shows | weapon `expl_kol` (`pip_info.gd`) | yes (Weapon.explKol) |
| `antiprec` | range inside which a shot ignores spread | weapon `antiprec` (`sats.gd`) | yes (Weapon.antiprec) |
| `polz` | crawl clip | unit anim `polz` | yes |
| `derg` | flail clip while levitated | unit anim `derg` | yes |
| `shit` | shield | icon `shit`; `visualPlayer` `visShit` | yes |
