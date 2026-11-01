extends RefCounted

## Drawn guns, throwables, magic weapons, reload and the shot.
## p is the player body. Tick order stays in player.gd; these names forward.

const _Body := preload("res://scripts/player.gd")

var p: _Body

func _init(host: _Body) -> void:
	p = host

var aim_dir: Vector2 = Vector2.RIGHT

## Sim ticks. Condition still writes seconds through the _fire_cd property.
var _fire_ticks: int = 0

var _fire_cd: float:
	set(value):
		_fire_ticks = p._hold_ticks(value)
	get:
		return float(_fire_ticks) / 30.0

var _voice_serial: int = 0

var _weapons: Array = []

var _weapon_i: int = -1

var _catalog: Dictionary = {}

var _mag_rounds: Dictionary = {}

## Sim ticks. Condition still writes seconds through the _reload_left property.
var _reload_ticks: int = 0

var _reload_left: float:
	set(value):
		_reload_ticks = p._hold_ticks(value)
	get:
		return float(_reload_ticks) / 30.0

var _reload_id: String = ""

# Leftover recharge wait per weapon, in seconds. ammo_recharg ticks at 30 Hz.
var _rech_left: Dictionary = {}

var _burst_left: int = 0

var _burst_wait: int = 0

var _prep: int = 0

var _semi_lock: bool = false

var _armed_id: String = ""

## UnitPlayer.magicWeapon fired by keyMagic: its own t_attack, t_prep and t_auto.
## Without a favourite it is the last magic weapon drawn.
var _magic_last_id: String = ""

## UnitPlayer.throwWeapon fired by keyGrenad: favourites cell 29, else the last explosive drawn.
var _throw_last_id: String = ""

var _throw_cd: int = 0

var _throw_armed := false

var _magic_cd: int = 0

var _magic_prep: int = 0

var _magic_semi: bool = false

var _said: Dictionary = {}

# Weapon presentation state (Weapon / WClub / UnitPlayer.changeWeapon), in 30 Hz ticks.
var _armed: Dictionary = {}

var _chw_left: int = 0

var _chw_ready := false

var _reload_hold: int = 0

var _reload_filled := false

var _reload_prev: int = 0

## pers.atkPoss (potion_shadow / potion_rat set it to 0). The rat never attacks.
func _attack_ok() -> bool:
	return not p.rat and GameState.attack_allowed()

## keyAttack or the vote's autoAttack.
func _shoot_held() -> bool:
	return LocalInput.held(&"shoot") or Effects.auto_attack()

## UnitPlayer.changeWeapon("not"): the weapon is put away until the next equip.
func holster() -> void:
	if Inventory != null:
		Inventory.holster()
	_weapon_i = -1
	_publish_weapon()

func _update_muzzle(cursor: Vector2) -> void:
	var origin := p.global_position + Vector2(0, -36)
	if p.puppet.has_method("get_muzzle_global"):
		origin = p.puppet.get_muzzle_global()
	var to_cursor := cursor - origin
	aim_dir = to_cursor.normalized() if to_cursor.length_squared() > 1.0 else Vector2(p.facing, 0)
	p.muzzle.global_position = origin

func _load_catalog() -> void:
	_catalog.clear()
	if not FileAccess.file_exists("res://assets/data/weapons.json"):
		push_error("weapons.json missing")
		return
	var parsed: Variant = DataLib.load("res://assets/data/weapons.json")
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("weapons.json did not parse")
		return
	for entry_v in (parsed as Dictionary).get("weapons", []):
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v
		var id := str(entry.get("id", ""))
		if id != "":
			_catalog[id] = entry

func _sync_owned() -> void:
	var bags := p.get_node_or_null("/root/Inventory")
	if bags == null or not bags.has_method("owned_weapon_ids"):
		return
	var keep := ""
	if str(bags.get("weapon_id")) != "":
		keep = str(bags.weapon_id)
	var rows: Array = []
	for id_v in bags.owned_weapon_ids():
		var made: Dictionary = bags.weapon_def(str(id_v))
		if made.is_empty():
			continue
		rows.append(made)
	_weapons = rows
	_weapon_i = -1
	if keep != "":
		for i in rows.size():
			if str((rows[i] as Dictionary).get("id", "")) == keep:
				_weapon_i = i
				break
	_publish_weapon()

func _weapon() -> Dictionary:
	if _weapon_i < 0 or _weapon_i >= _weapons.size():
		return {}
	return _weapons[_weapon_i]

## Port: the step skips hidden weapons, spells and magic weapons (those are
## magic_attack / cast_spell, picked on the wheels).
func _cycle_weapon(step: int) -> void:
	if _weapons.is_empty() or not GameState.attack_allowed():
		return
	var index := -1
	var at := _weapon_i
	if at < 0:
		at = -1 if step > 0 else _weapons.size()
	for _i in _weapons.size():
		at = posmod(at + step, _weapons.size())
		var row: Dictionary = _weapons[at]
		var kind := str(row.get("kind", ""))
		if kind == "magic" or kind == "spell" or bool(row.get("spell", false)) or Stash.is_hidden(str(row.get("id", ""))):
			continue
		index = at
		break
	if index < 0 or index == _weapon_i:
		return
	var id := str((_weapons[index] as Dictionary).get("id", ""))
	var bags := p.get_node_or_null("/root/Inventory")
	if bags and bags.has_method("equip") and bags.equip(id):
		return
	_weapon_i = index
	_publish_weapon()

func _publish_weapon() -> void:
	var w := _weapon()
	var id := str(w.get("id", ""))
	if id != _armed_id:
		# Holstering cancels a reload that has not finished (setNull zeroes t_reload).
		# The rounds already in the magazine stay with that weapon.
		_reload_ticks = 0
		_reload_id = ""
		_armed_id = id
		_burst_left = 0
		_prep = 0
		_semi_lock = false
		if str(w.get("kind", "")) == "magic" and not bool(w.get("spell", false)):
			_magic_last_id = id
		if str(w.get("kind", "")) == "explosives":
			_throw_last_id = id
		_on_weapon_drawn(w)
		_begin_weapon_change()
	elif _chw_left <= 0.0:
		_armed = w
	if w.is_empty():
		GameState.set_weapon_name("")
		return
	var dtype := str(w.get("damage_type", ""))
	var label := str(w.get("name", w.get("id", "")))
	if p.TYPE_LABELS.has(dtype):
		label = "%s (%s)" % [label, p.TYPE_LABELS[dtype]]
	GameState.set_weapon_name(label)

func _begin_weapon_change() -> void:
	# UnitPlayer.changeWeapon: work "change", t_work 30. At 20 the old weapon is
	# put away, at 10 the new one is drawn. Loading a game swaps at once.
	if not _chw_ready or not p.is_inside_tree():
		_chw_left = 0
		_draw_armed(_weapon())
		return
	_chw_left = 30

func _tick_weapon_change(_delta: float) -> void:
	_chw_ready = true
	if _chw_left <= 0:
		return
	var before := _chw_left
	_chw_left = maxi(0, _chw_left - Sim.frame_steps)
	if before > 20.0 and _chw_left <= 20.0:
		_draw_armed({})
	if before > 10.0 and _chw_left <= 10.0:
		_draw_armed(_weapon())
	if p.puppet.has_method("set_weapon_lowered"):
		p.puppet.set_weapon_lowered(_chw_left > 10.0)

func _draw_armed(w: Dictionary) -> void:
	_armed = w
	if p.puppet.has_method("set_weapon"):
		p.puppet.set_weapon(w)
	if "recoil_mult" in p.puppet:
		p.puppet.recoil_mult = int(Progression.pers("recoilMult", 1.0))
		p.puppet.drot_mult = 1.0 if str(w.get("kind", "")) == "magic" else Progression.pers("drotMult", 1.0)

func _poll_quick_slots() -> void:
	# UnitPlayer: keyWeapon1..12 call useFav(i), with keyRun held useFav(i + 12).
	var focus := p.get_viewport().gui_get_focus_owner()
	if focus is Control and (focus as Control).is_visible_in_tree():
		return
	for n in Favorites.HOTKEYS:
		var action := Favorites.action_of(n + 1)
		if not InputMap.has_action(action) or not LocalInput.just_pressed(StringName(action)):
			continue
		if p._spells._action_taken_by_spell(action):
			continue
		var cell := n + 1 + (Favorites.HOTKEYS if LocalInput.held(&"sprint") else 0)
		Favorites.use_fav(cell)
		return

func _try_shoot() -> void:
	if p.bullet_scene == null:
		return
	var w := _weapon()
	if w.is_empty() or not _allowed(w):
		return
	var delivery := str(w.get("delivery", "projectile"))
	# changeWeapon hands spells to changeSpell. keyAttack never casts them.
	if delivery == "spell" or bool(w.get("spell", false)):
		return
	if not _pay(w):
		_burst_left = 0
		return
	var fired := false
	if delivery == "melee":
		fired = p._melee_c._melee(w)
	elif delivery == "mine":
		fired = _mine(w)
	elif delivery == "grenade":
		fired = _grenade(w)
	else:
		fired = _shoot_pellets(w)
	if not fired:
		_burst_left = 0
		return
	# Magazine drops only after a shot or swing actually starts.
	_commit_magazine(w)
	# Weapon.shoot: recoil, shell, and the vis "shoot" label. t_attack is rapid.
	if delivery != "melee" and p.puppet.has_method("weapon_fired"):
		p.puppet.weapon_fired(int(round(_shot_gap(w) * 30.0)))
	# magazineCapacity == 1 starts the reload in the same attack that fired.
	if int(w.get("mag", 0)) == 1 and not _self_charges(w):
		_begin_reload(w, false)
	_arm_cooldown(w)
	if p.sats.queued():
		p.sats.act()

func _throw_weapon() -> Dictionary:
	var id := ""
	if MagicBinds != null and MagicBinds.has_method("throw_weapon"):
		id = str(MagicBinds.throw_weapon())
	if id == "":
		id = _throw_last_id
	if id == "" or Inventory.count(id) <= 0:
		return {}
	for row in _weapons:
		if str((row as Dictionary).get("id", "")) == id:
			return row
	return {}

## UnitPlayer keyGrenad: throwWeapon.attack() without changing the weapon in hand,
## while keyAttack is up and that weapon is not mid-attack. A press waits until
## it can go; an explosive then throws once, a magic weapon repeats while held.
func _tick_throw_key(delta: float) -> void:
	_throw_cd = p._spend(_throw_cd)
	var grenade := LocalInput.held(&"grenade") or LocalInput.just_pressed(&"grenade")
	if not InputMap.has_action("grenade") or not grenade:
		_throw_armed = false
		return
	if LocalInput.just_pressed(&"grenade"):
		_throw_armed = true
	if not _throw_armed or not p._Flags.allows("weapons") or not _attack_ok() or Effects.attack_forever():
		return
	if LocalInput.held(&"shoot") or _chw_left > 0.0 or p._melee_c._hoof_work > 0.0:
		return
	if _fire_cd > 0.0 or _magic_cd > 0.0 or _reload_left > 0.0 or _burst_left > 0:
		return
	var w := _throw_weapon()
	if w.is_empty():
		_throw_armed = false
		return
	if p.sats.queued():
		p.sats.clear_all()
	if str(w.get("kind", "")) == "explosives":
		_throw_armed = false
	if _throw_cd > 0.0:
		return
	if not _allowed(w) or not _pay(w):
		_throw_cd = maxi(_throw_cd, _fire_ticks)
		_fire_ticks = 0
		return
	var fired := false
	match str(w.get("delivery", "projectile")):
		"grenade":
			fired = _grenade(w)
		"mine":
			fired = _mine(w)
		_:
			fired = _shoot_pellets(w)
	if not fired:
		return
	_commit_magazine(w)
	_throw_cd = p._hold_ticks(_shot_gap(w))
	if str(w.get("id", "")) == _armed_id:
		_fire_ticks = _throw_cd

## favorites cell 30 holds a magic weapon or explosive. Empty, it is the last magic weapon drawn.
func _magic_weapon() -> Dictionary:
	var id := ""
	if MagicBinds != null and MagicBinds.has_method("magic_weapon"):
		id = str(MagicBinds.magic_weapon())
	if id == "":
		id = _magic_last_id
	if id == "":
		return {}
	for row in _weapons:
		if str((row as Dictionary).get("id", "")) == id:
			return row
	return {}

## UnitPlayer keyMagic: magicWeapon.attack() while keyAttack is up, outside the work
## animation, and only when the weapon in hand is not mid-attack (atkWeapon 0 or 3).
func _tick_magic_key(delta: float) -> void:
	_magic_cd = p._spend(_magic_cd)
	var held := InputMap.has_action("magic_attack") and (LocalInput.held(&"magic_attack") or LocalInput.just_pressed(&"magic_attack")) and p._Flags.allows("weapons")
	held = held and _attack_ok() and not Effects.attack_forever()
	var w := _magic_weapon() if held else {}
	if w.is_empty():
		_magic_semi = false
		_magic_prep = p._spend(_magic_prep)
		return
	if LocalInput.held(&"shoot") or _chw_left > 0.0 or p._melee_c._hoof_work > 0.0:
		return
	if _fire_cd > 0.0 or _reload_left > 0.0 or _burst_left > 0:
		return
	# Weapon.attack: a held key on a non-auto weapon only refreshes t_auto.
	if _magic_semi and not bool(w.get("auto", false)):
		return
	var prep_need := int(w.get("prep", 0))
	if prep_need > 0:
		if _magic_prep < prep_need + 10:
			_magic_prep += Sim.frame_steps
		if _magic_prep < prep_need:
			return
	if _magic_cd > 0.0:
		return
	_magic_semi = true
	if not _allowed(w) or not _pay(w):
		_magic_cd = maxi(_magic_cd, _fire_ticks)
		_fire_ticks = 0
		return
	var fired := false
	match str(w.get("delivery", "projectile")):
		"grenade":
			fired = _grenade(w)
		"mine":
			fired = _mine(w)
		_:
			fired = _shoot_pellets(w)
	if not fired:
		return
	_commit_magazine(w)
	_magic_cd = p._hold_ticks(_shot_gap(w))
	if str(w.get("id", "")) == _armed_id:
		_fire_ticks = _magic_cd

func _dry_fire() -> void:
	# Weapon.attack on an empty magazine only calls initReload. No click plays.
	var w := _weapon()
	_fire_ticks = p._hold_ticks(_shot_gap(w) if not w.is_empty() else 0.22)

func _tick_weapon(delta: float) -> void:
	# Condition's jam writes the _reload_left property (seconds).
	if _reload_ticks > _reload_prev:
		_reload_filled = false
	if _reload_ticks > 0:
		_reload_ticks = p._spend(_reload_ticks)
		# reloadWeapon runs when t_reload reaches 10. Firing waits for 0.
		var gate := int(round(10.0 * Effects.stat("reloadMult", Progression.pers("reloadMult", 1.0))))
		if not _reload_filled and _reload_ticks <= gate:
			_reload_filled = true
			_finish_reload()
		if _reload_ticks <= 0 and not _reload_filled:
			_finish_reload()
	_reload_prev = _reload_ticks
	var w := _weapon()
	if w.is_empty() or not _self_charges(w):
		return
	var mag := int(w.get("mag", 0))
	var id := str(w.get("id", ""))
	if mag <= 0 or id == "":
		return
	if not _mag_rounds.has(id):
		_mag_rounds[id] = mag
	# Weapon.step only counts t_rech while t_attack == 0 and the cell is not full.
	var period := int(w.get("recharg", 0))
	if period <= 0:
		return
	var left := int(_rech_left.get(id, p._hold_ticks(float(period) / 30.0)))
	if int(_mag_rounds[id]) >= mag:
		return
	if _fire_ticks > 0 or _burst_left > 0 or _reload_ticks > 0:
		_rech_left[id] = left
		return
	left -= Sim.frame_steps
	var step := p._hold_ticks(float(period) / 30.0)
	while left <= 0 and int(_mag_rounds[id]) < mag:
		_mag_rounds[id] = int(_mag_rounds[id]) + 1
		left += step
	_rech_left[id] = left

func _finish_reload() -> void:
	var w: Dictionary = _catalog.get(_reload_id, {})
	if w.is_empty():
		w = _weapon()
	_transfer_into_mag(w)

func _wants_shot(delta: float) -> bool:
	var w := _weapon()
	if w.is_empty() or not p._Flags.allows("weapons") or not _attack_ok():
		return false
	if _burst_left > 0:
		_burst_wait = p._spend(_burst_wait)
		return _burst_wait <= 0
	if p._spells._port_shot_cut:
		p._spells._port_shot_cut = LocalInput.held(&"shoot")
		if p._spells._port_shot_cut:
			return false
	# UnitPlayer: currentWeapon.attack(true) at que[0], once the weapon has turned onto it.
	if p.sats != null and p.sats.firing():
		var to_cel: Vector2 = p.sats.cel_point() - p.muzzle.global_position
		return to_cel.length_squared() < 1.0 or absf(aim_dir.angle_to(to_cel)) < 0.15
	var held := _shoot_held()
	if not held:
		_semi_lock = false
		_prep = p._spend(_prep)
		# Already up: a latched tap still fires. A charge needs the key held.
		if not LocalInput.just_pressed(&"shoot") or int(w.get("prep", 0)) > 0:
			return false
		return true
	var prep_need := int(w.get("prep", 0))
	if prep_need > 0:
		# attack() adds 2 to t_prep while t_prep < prep + 10. actions() takes 1 back.
		if _prep < prep_need + 10:
			_prep += Sim.frame_steps
		if _prep < prep_need:
			return false
	if bool(w.get("auto", false)):
		return true
	if _semi_lock:
		return false
	if prep_need > 0:
		return true
	return LocalInput.just_pressed(&"shoot") or Effects.auto_attack()

func _shot_gap(w: Dictionary) -> float:
	# WClub sets rapidMult = 1 / meleeSpdMult. Head trauma lowers meleeSpdMult.
	var gap := maxf(float(w.get("rapid", 5)), 1.0) / 30.0
	if str(w.get("kind", "")) == "melee":
		gap /= p._melee_c._melee_spd()
	return gap

func _arm_cooldown(w: Dictionary) -> void:
	var rapid := _shot_gap(w)
	var burst := int(w.get("burst", 0))
	var auto := bool(w.get("auto", false))
	if _burst_left > 0:
		_burst_left -= 1
		if _burst_left > 0:
			_burst_wait = p._hold_ticks(rapid)
			_fire_ticks = 0
		else:
			_fire_ticks = p._hold_ticks(rapid * 2.0)
			if not auto:
				_semi_lock = true
		return
	if burst > 1:
		_burst_left = burst - 1
		_burst_wait = p._hold_ticks(rapid)
		_fire_ticks = 0
		return
	_fire_ticks = p._hold_ticks(rapid * (2.0 if burst == 1 else 1.0))
	if not auto:
		_semi_lock = true

func _allowed(w: Dictionary) -> bool:
	# Spell.cast has no character level gate. Magic weapons (WMagic) keep perslvl.
	var need := 0 if bool(w.get("spell", false)) else int(w.get("pers_lvl", 0))
	var lvl := int(Progression.level) if Progression else 1
	if need > lvl:
		p._notice(OriginalLines.info("persLevel"))
		_fire_cd = 0.35
		return false
	if str(w.get("kind", "")) != "explosives" and _razn(w) > 2:
		p._notice(OriginalLines.info("weaponSkillLevel"))
		_fire_cd = 0.35
		return false
	return true

func _razn(w: Dictionary) -> int:
	if str(w.get("skill_id", "")) == "":
		return 0
	return int(w.get("lvl", 0)) - _skill_level(w)

func _skill_level(w: Dictionary) -> int:
	var sid := str(w.get("skill_id", ""))
	if sid == "" or Progression == null:
		return 100
	return int(Progression.skill_level_of(sid))

func _skill_mult(w: Dictionary) -> float:
	var sid := str(w.get("skill_id", ""))
	if sid == "" or Progression == null:
		return 1.0
	return 1.0 + 0.05 * float(Progression.rank(sid))

func _skill_conf(w: Dictionary) -> float:
	var razn := _razn(w)
	var explosives := str(w.get("kind", "")) == "explosives"
	if razn <= 0:
		return 1.0
	if razn == 1:
		return 0.75 if explosives else 0.8
	return 0.5 if explosives else 0.6

func _skill_plus(w: Dictionary) -> float:
	if str(w.get("kind", "")) == "magic":
		return 1.0
	var razn := _razn(w)
	if razn < 0:
		return 1.0 - float(razn) * 0.1
	return 1.0

func _amount(w: Dictionary, expl: bool) -> float:
	var base := float(w.get("damage_expl" if expl else "damage", 0.0))
	var kind := str(w.get("kind", ""))
	# resultDamage: (dam0 + damAdd) * damMult. Both come from the weapon's perk.
	if Progression and kind != "magic":
		base = (base + Progression.weapon_perk(w, "Det", 0.0)) * Progression.weapon_perk(w, "Dam", 1.0)
	var sk := _skill_mult(w)
	var amount := base
	if kind == "explosives":
		amount = base * (1.0 + (sk - 1.0) * 0.5) * _skill_conf(w)
	elif kind == "magic":
		amount = base * sk
	else:
		# resultDamage: (1 - breaking * 0.3), WClub (1 - breaking * 0.6).
		amount = base * sk * _skill_plus(w) * (1.0 - _breaking(w) * (0.6 if kind == "melee" else 0.3))
	if Progression:
		amount *= 1.0 + float(Progression.skill_level_of("attack")) * 0.05
		if kind == "melee":
			amount *= Progression.pers("meleeDamMult", 1.0)
		var chance := Progression.get_crit_chance() + Progression.weapon_perk(w, "Critch", 0.0)
		if chance > 0.0 and Rng.randf(&"combat") < chance:
			amount *= Progression.get_crit_damage_multiplier()
	amount *= GameState.damage_dealt_mult(kind)
	if kind == "magic" or bool(w.get("spell", false)):
		amount *= GameState.spell_damage_mult()
		if Progression:
			amount *= Progression.pers("spellsDamMult", 1.0)
	amount *= _worn_dam_mult(w)
	return amount

## Pers.armorParameters: each worn piece (suit, then amulet) multiplies one
## damage channel. Weapon.setPers applies gunsDamMult for skill 2, 3, or 4
## (smallguns, repair, energy). WClub applies meleeDamMult. WMagic applies
## spellsDamMult. magicMult also scales throwForce in Progression.throw_force.
func _worn_dam_mult(w: Dictionary) -> float:
	if Inventory == null or Condition == null:
		return 1.0
	var kind := str(w.get("kind", ""))
	var sid := str(w.get("skill_id", ""))
	var key := ""
	if kind == "melee":
		key = "melee"
	elif kind == "magic":
		key = "magic"
	elif sid == "smallguns" or sid == "repair" or sid == "energy":
		key = "guns"
	if key == "":
		return 1.0
	var mult := 1.0
	for worn_id in Inventory.worn_ids():
		var row: Dictionary = Condition.armor_row(worn_id)
		mult *= float(row.get(key, 1.0))
	return mult

func _pay(w: Dictionary) -> bool:
	var kind := str(w.get("kind", ""))
	if kind == "magic" or bool(w.get("spell", false)):
		if not GameState.spells_allowed():
			p._notice(OriginalLines.info("noSpells"))
			Fx.sound("nomagic", p.global_position, {"source": p})
			_fire_cd = 0.25
			return false
		# WMagic: magic and mana times allDManaMult and warlockDManaMult. A bar at
		# 99% may fire anything. Both pools fail with noMana.
		var cost := p._spells._spell_costs(w, true)
		if GameState.spell_block(cost.x, cost.y, true) != "":
			p._notice(OriginalLines.info("noMana"))
			Fx.sound("nomagic", p.global_position, {"source": p})
			_fire_cd = 0.25
			return false
		GameState.pay_spell(cost.x, cost.y)
		return true
	if kind == "melee" or (kind == "internal" and str(w.get("ammo", "")) == ""):
		if not _uses_mag(w):
			return true
	if kind == "explosives":
		var toss := maxi(1, int(w.get("ammo_per_shot", 1)))
		if GameState.try_spend_ammo(toss):
			return true
		_dry_fire()
		return false
	return _pay_gun(w)

func _pay_gun(w: Dictionary) -> bool:
	var per := maxi(1, int(w.get("ammo_per_shot", 1)))
	var mag := int(w.get("mag", 0))
	var id := str(w.get("id", ""))
	if not _uses_mag(w):
		return true
	if _self_charges(w) and not _mag_rounds.has(id):
		_mag_rounds[id] = mag
	if not _mag_rounds.has(id):
		_mag_rounds[id] = 0
	if int(_mag_rounds[id]) >= per:
		return true
	# A recharge cell does not manual-reload. An empty inventory mag reloads instead of firing.
	if _self_charges(w):
		_dry_fire()
		return false
	_begin_reload(w, true)
	return false

## Weapon.status: 5 broken, 4 no ammo, 2 empty magazine, 6 no mana, 1 attacking, 3 reloading, 0 ready.
func weapon_status() -> int:
	var w := _weapon()
	if w.is_empty():
		return 0
	var id := str(w.get("id", ""))
	if Condition != null and id != "" and float(Condition.weapon_max(id)) > 0.0 and float(Condition.weapon_hp(id)) <= 0.0:
		return 5
	var per := maxi(1, int(w.get("ammo_per_shot", 1)))
	if _inventory_ammo(w) and int(w.get("mag", 0)) > 0 and int(_mag_rounds.get(id, 0)) < per:
		return 4 if _ammo_reserve(str(w.get("ammo", ""))) < per else 2
	if str(w.get("kind", "")) == "magic":
		var cost := p._spells._spell_costs(w, true)
		if GameState.spell_block(cost.x, cost.y, true) != "":
			return 6
	if _fire_cd > 0.0 or _burst_left > 0:
		return 1
	if _reload_left > 0.0:
		return 3
	return 0

func _breaking(w: Dictionary) -> float:
	# Weapon.setBreaking: 0 above half condition, rising to 1 at zero.
	var id := str(w.get("id", ""))
	if Condition == null or id == "":
		return 0.0
	var top := float(Condition.weapon_max(id))
	if top <= 0.0:
		return 0.0
	var hp := Condition.weapon_hp(id)
	if hp >= top / 2.0:
		return 0.0
	return (top - hp) / top * 2.0 - 1.0

func _spread_angle(w: Dictionary, index: int, pellets: int) -> float:
	var dev := float(w.get("spread", 0.0))
	var sk := _skill_mult(w)
	var wobble_deg := dev / (sk + 0.01)
	if str(w.get("kind", "")) != "explosives":
		# Weapon.shoot: deviation * (1 + breaking * 2).
		wobble_deg = dev * (1.0 + _breaking(w) * 2.0) / _skill_conf(w) / (sk + 0.01)
	# allPrecMult scales Weapon.resultPrec. This slice has no bullet precision,
	# so the same factor widens the deviation. mazilAdd is added in degrees.
	wobble_deg = wobble_deg / maxf(GameState.aim_prec_mult(), 0.05) + GameState.aim_mazil()
	if Progression:
		wobble_deg *= Progression.weapon_perk(w, "Dev", 1.0)
	var wobble := (Rng.randf(&"combat") - 0.5) * wobble_deg * PI / 180.0
	var fan := (float(index) - (pellets - 1) * 0.5) * dev * PI / 360.0
	return wobble + fan

func _shoot_pellets(w: Dictionary) -> bool:
	var pellets := maxi(1, int(w.get("pellets", 1)))
	var origin := p.muzzle.global_position
	if str(w.get("kind", "")) == "magic" and p.puppet.has_method("spell_origin"):
		origin = p.puppet.spell_origin()
	var voice := _next_voice()
	var fired := false
	for i in pellets:
		var dir := aim_dir.rotated(_spread_angle(w, i, pellets))
		if _spawn_catalog(w, dir, origin, false, i, voice):
			fired = true
	return fired

func _grenade(w: Dictionary) -> bool:
	var origin := p.muzzle.global_position
	var cursor := p._cursor_world()
	var rx := cursor.x - origin.x
	var ry := cursor.y - origin.y
	var sk := _skill_mult(w) * _skill_conf(w)
	var speed_tick := float(w.get("speed", 10.0))
	var dist := sqrt(rx * rx + ry * ry)
	var vel := minf(speed_tick * sk, dist / 10.0 * sk - ry / 10.0 * sk)
	vel = maxf(vel, 1.0)
	var ang := aim_dir.angle() + (-rx / (vel + 0.0001) / 100.0) + _spread_angle(w, 0, 1)
	var dir := Vector2.from_angle(ang)
	var bullet := _make_bullet(w, dir, origin, true)
	bullet.velocity = dir * vel * 30.0
	bullet.use_velocity = true
	bullet.fall_accel = 900.0
	# PhisBullet blows at liv == 3 of detTime.
	bullet.lifetime = maxf(float(w.get("det_time", w.get("fuse", 75))) - 3.0, 1.0) / 30.0
	bullet.explode_on_timeout = true
	bullet.phis = true
	bullet.bumc = bool(w.get("bumc", false))
	bullet.lip = int(w.get("throw_tip", 0)) == 2
	bullet.sensor = Progression.pers("grenader", 0.0) > 0.0 and not LocalInput.held(&"sprint")
	var host := p.get_tree().current_scene
	if host == null:
		return false
	host.add_child(bullet)
	return true

func _mine(w: Dictionary) -> bool:
	var bullet := _make_bullet(w, Vector2.DOWN, p.global_position, true)
	# WThrow: sapper multiplies a player mine's damage.
	var sapper := Progression.pers("sapper", 1.0)
	if sapper > 1.0:
		bullet.damage = int(round(float(bullet.damage) * sapper))
	bullet.speed = 0.0
	bullet.velocity = Vector2.ZERO
	bullet.use_velocity = true
	bullet.lifetime = maxf(float(w.get("fuse", 75)), 1.0) / 30.0
	bullet.explode_on_timeout = true
	if int(w.get("radio", 0)) > 0:
		# WThrow char_radio (x37): sens 0 and no fuse. It waits for detonator().
		bullet.explode_on_timeout = false
		bullet.lifetime = 1.0e6
		bullet.set_meta("radio", str(w.get("id", "")))
		bullet.add_to_group("radio_mines")
	var host := p.get_tree().current_scene
	if host == null:
		return false
	host.add_child(bullet)
	return true

## WThrow.detonator: every radio mine of this id in play runs Mine.activate,
## then explodes after explTime (det_time) ticks.
func _detonator(w: Dictionary) -> bool:
	if int(w.get("radio", 0)) <= 0:
		return false
	var id := str(w.get("id", ""))
	for mine in p.get_tree().get_nodes_in_group("radio_mines"):
		if not is_instance_valid(mine) or str(mine.get_meta("radio", "")) != id:
			continue
		mine.remove_from_group("radio_mines")
		mine.set("explode_on_timeout", true)
		if mine.has_method("arm_fuse"):
			mine.arm_fuse(maxi(int(w.get("det_time", 15)), 1))
	return true

func _next_voice() -> int:
	_voice_serial += 1
	return _voice_serial

func _spawn_catalog(w: Dictionary, dir: Vector2, origin: Vector2, expl: bool, pellet: int = 0, voice: int = -1) -> bool:
	var bullet := _make_bullet(w, dir, origin, expl or float(w.get("radius", 0.0)) > 0.0)
	bullet.pellet_index = pellet
	bullet.voice_key = voice
	var flame := int(w.get("flame", 0))
	var grav := float(w.get("grav", 0.0))
	var exact := bool(w.get("volna", false)) or grav > 0.0
	var px := float(w.get("speed", 100.0)) * 30.0
	if Progression:
		px *= Progression.weapon_perk(w, "Speed", 1.0)
	if not exact:
		px *= Rng.randf(&"combat") * 0.4 + 0.8
	bullet.speed = px
	bullet.velocity = dir * px
	if flame > 0 or grav > 0.0:
		bullet.use_velocity = true
		bullet.fall_accel = grav * 900.0
		if flame == 1:
			bullet.fall_accel += -720.0
			bullet.lifetime = 200.0 / 7.0 / 30.0
		elif flame == 2:
			bullet.fall_accel += -180.0
			bullet.lifetime = 120.0 / 7.0 / 30.0
	else:
		bullet.lifetime = 100.0 / 30.0
	var host := p.get_tree().current_scene
	if host == null:
		return false
	host.add_child(bullet)
	return true

func _make_bullet(w: Dictionary, dir: Vector2, origin: Vector2, expl: bool) -> Area2D:
	var bullet := p.bullet_scene.instantiate() as Area2D
	bullet.global_position = origin
	bullet.direction = dir
	bullet.from_player = true
	bullet.damage = maxi(0, int(round(_amount(w, expl))))
	bullet.damage_type = str(w.get("damage_type", "DAM_PIERCE"))
	bullet.block_damage = p._Block.of(str(w.get("id", "")))
	bullet.hitscan = false
	bullet.weapon_id = str(w.get("id", ""))
	bullet.blast_radius = float(w.get("radius", 0.0)) if expl or float(w.get("radius", 0.0)) > 0.0 else 0.0
	bullet.blast_radius *= Progression.pers("explRadMult", 1.0)
	bullet.explode_on_timeout = bullet.blast_radius > 0.0
	bullet.style = _style_of(w)
	bullet.range_px = float(w.get("range", 0.0)) * _prec_mult(w, dir)
	bullet.anti_px = float(w.get("antiprec", 0.0))
	bullet.miss_chance = maxf(0.0, 1.0 - _skill_conf(w))
	bullet.set_meta("prog_scaled", true)
	bullet.pier = float(w.get("pier", 0.0)) + Progression.weapon_perk(w, "Pier", 0.0)
	bullet.knock_mult = Progression.weapon_perk(w, "Knock", 1.0)
	if str(w.get("damage_type", "")) in ["DAM_LASER", "DAM_PLASMA"]:
		bullet.desintegr = Progression.pers("desintegr", 0.0)
	bullet.dop_effect = str(w.get("dop_effect", ""))
	bullet.dop_damage = float(w.get("dop_damage", 0.0))
	bullet.dop_chance = float(w.get("dop_chance", 1.0))
	var stun := Progression.weapon_perk(w, "Stun", 0.0)
	if stun > 0.0:
		# Weapon.setPers: <perk>Stun replaces the dop effect with a sure stun.
		bullet.dop_effect = "stun"
		bullet.dop_damage = stun
		bullet.dop_chance = 1.0
	if bullet.dop_effect != "":
		bullet.set_meta("dop_effect", bullet.dop_effect)
	return bullet

## Weapon.resultPrec: weapon precMult (allPrecMult, <perk>Prec) times the owner's
## precMult (allPrecMult and UnitPlayer's stance penalties from rungun / composure).
func _prec_mult(w: Dictionary, dir: Vector2) -> float:
	var all := Progression.pers("allPrecMult", 1.0)
	var stance := all
	# A running Sats queue skips the stance terms.
	if p.sats != null and p.sats.queued():
		return all * Progression.weapon_perk(w, "Prec", 1.0) * stance
	var stay := p.is_on_floor()
	var run_pen := Progression.pers("runPenalty", 0.5)
	if run_pen > 0.0 and (absf(p.velocity.x) > 300.0 or absf(p.velocity.y) > 300.0):
		stance *= 1.0 - run_pen
	if not stay:
		stance *= 1.0 - Progression.pers("jumpPenalty", 0.3)
	elif absf(p.velocity.x) < 30.0:
		stance *= 1.0 + Progression.pers("stayBonus", 0.3)
	if dir.x != 0.0 and signf(dir.x) != signf(p.facing):
		stance *= 1.0 - Progression.pers("backPenalty", 0.4)
	return all * Progression.weapon_perk(w, "Prec", 1.0) * stance

func _style_of(w: Dictionary) -> String:
	if int(w.get("flame", 0)) > 0:
		return "flame"
	var dtype := str(w.get("damage_type", ""))
	if float(w.get("radius", 0.0)) > 0.0 and dtype == "DAM_BURN":
		return "fireball"
	if int(w.get("pellets", 1)) > 1:
		return "pellet"
	match dtype:
		"DAM_LASER":
			return "laser"
		"DAM_PLASMA":
			return "plasma"
		"DAM_BURN":
			return "flame"
		_:
			return "bullet"

func _self_charges(w: Dictionary) -> bool:
	return int(w.get("recharg", 0)) > 0 or str(w.get("ammo", "")) == "recharg"

func _inventory_ammo(w: Dictionary) -> bool:
	var ammo := str(w.get("ammo", ""))
	return ammo != "" and ammo != "not" and not _self_charges(w)

func _uses_mag(w: Dictionary) -> bool:
	if int(w.get("mag", 0)) <= 0:
		return false
	var ammo := str(w.get("ammo", ""))
	return _inventory_ammo(w) or _self_charges(w) or ammo == "not"

func _on_weapon_drawn(w: Dictionary) -> void:
	if w.is_empty():
		return
	var id := str(w.get("id", ""))
	var cap := int(w.get("mag", 0))
	if _self_charges(w):
		# Recharge cells are born full. They do not take rounds from the bag.
		if cap > 0 and id != "" and not _mag_rounds.has(id):
			_mag_rounds[id] = cap
		return
	# Inventory-fed magazines start at 0 and keep their rounds across switches.
	# The first trigger pull on an empty one starts initReload.

func _poll_reload() -> void:
	# UnitPlayer: keyReload counts t_reload while held. Released before 10 ticks
	# it calls initReload. Held to 30 ticks it calls unloadWeapon.
	if not InputMap.has_action("reload") or Effects.attack_forever():
		return
	if LocalInput.held(&"reload") or LocalInput.just_pressed(&"reload"):
		# A radio weapon spends the press on detonator() (ctr.keyReload = false).
		if _reload_hold <= 0 and _detonator(_weapon()):
			_reload_hold = 31
		var before := _reload_hold
		_reload_hold += Sim.frame_steps
		if before < 30 and _reload_hold >= 30:
			_unload_weapon(_weapon())
		return
	var tapped := _reload_hold > 0 and _reload_hold < 10
	_reload_hold = 0
	if not tapped or _chw_left > 0.0:
		return
	var w := _weapon()
	if w.is_empty() or _self_charges(w) or int(w.get("mag", 0)) <= 0:
		return
	_begin_reload(w, false)

func _unload_weapon(w: Dictionary) -> void:
	# Weapon.unloadWeapon: the magazine goes back to the bag with sndReload.
	if w.is_empty() or not _inventory_ammo(w) or Inventory == null:
		return
	var id := str(w.get("id", ""))
	var have := int(_mag_rounds.get(id, 0))
	if have <= 0:
		return
	Inventory.add(str(w.get("ammo", "")), have)
	_mag_rounds[id] = 0
	p._notice(OriginalLines.info("unloadWeapon", OriginalLines.name_of(id)))
	p._play_if_present(str(p._WeaponVis.fx(id).get("snd_reload", "")))

func _begin_reload(w: Dictionary, from_trigger: bool) -> bool:
	if _self_charges(w):
		return false
	var cap := int(w.get("mag", 0))
	var id := str(w.get("id", ""))
	if cap <= 0 or id == "":
		return false
	var have := int(_mag_rounds.get(id, 0))
	if have >= cap:
		return false
	if _reload_left > 0.0 and _reload_id == id:
		return true
	var per := maxi(1, int(w.get("ammo_per_shot", 1)))
	var ammo := str(w.get("ammo", ""))
	if _inventory_ammo(w) and _ammo_reserve(ammo) < per:
		if from_trigger:
			_dry_fire()
		p._notice(OriginalLines.info("noAmmo", OriginalLines.name_of(ammo)))
		return false
	# ammo_reload is frames at 30 Hz. The magazine fills when that wait ends.
	var dur := maxf(float(w.get("reload", 0.0)), 0.0) * Effects.stat("reloadMult", Progression.pers("reloadMult", 1.0)) / 30.0
	_reload_id = id
	if dur <= 0.0:
		_transfer_into_mag(w)
		return true
	_reload_ticks = p._hold_ticks(dur)
	_fire_ticks = maxi(_fire_ticks, _reload_ticks)
	_present_reload(w)
	return true

func _push_gun_state() -> void:
	var w := _weapon()
	var held := _shoot_held() and _chw_left <= 0.0 and p._melee_c._hoof_work <= 0.0 and not w.is_empty()
	_tick_prep_sound(w, held)
	if p.puppet.has_method("weapon_prep"):
		p.puppet.weapon_prep(float(_prep), _reload_ticks > 0)
	if p.puppet.has_method("set_weapon_hidden"):
		var thrown := str(w.get("kind", "")) == "explosives" and (_fire_cd > 0.0 or GameState.ammo < 1)
		p.puppet.set_weapon_hidden(thrown)

func _tick_prep_sound(w: Dictionary, attacking: bool) -> void:
	# Weapon.actions sndPrep: start at t_prep * 30 ms on press, jump back to
	# snd_t1 + 200 while held past snd_t2 - 300, and to snd_t2 + 100 on release.
	var fx := p._WeaponVis.fx(str(w.get("id", "")))
	Fx.prep(str(fx.get("snd_prep", "")), {
		"attacking": attacking,
		"prep": _prep,
		"t1": float(fx.get("snd_t1", 0)),
		"t2": float(fx.get("snd_t2", 0)),
		"source": p,
	})

func _present_reload(w: Dictionary) -> void:
	# Weapon.initReload: gotoAndPlay("reload") on an animated vis, then sndReload.
	_reload_filled = false
	if p.puppet != null and p.puppet.has_method("play_reload"):
		p.puppet.call("play_reload", w)
	p._play_if_present(str(p._WeaponVis.fx(str(w.get("id", ""))).get("snd_reload", "")))

func _transfer_into_mag(w: Dictionary) -> void:
	if w.is_empty() or _self_charges(w):
		return
	var cap := int(w.get("mag", 0))
	var id := str(w.get("id", ""))
	if cap <= 0 or id == "":
		return
	var have := int(_mag_rounds.get(id, 0))
	var room := cap - have
	if room <= 0:
		return
	var ammo := str(w.get("ammo", ""))
	if ammo == "" or ammo == "not":
		_mag_rounds[id] = cap
		return
	if not _inventory_ammo(w):
		return
	var reserve := _ammo_reserve(ammo)
	var take := mini(room, reserve)
	if take <= 0:
		return
	if Inventory and Inventory.spend(ammo, take):
		_mag_rounds[id] = have + take

func _commit_magazine(w: Dictionary) -> void:
	if not _uses_mag(w):
		return
	var per := maxi(1, int(w.get("ammo_per_shot", 1)))
	var id := str(w.get("id", ""))
	var have := int(_mag_rounds.get(id, 0))
	if have < per:
		return
	# recyc: energy cells sometimes are not spent.
	var recyc := Progression.pers("recyc", 0.0)
	if recyc > 0.0 and str(w.get("ammo", "")) in ["batt", "energ", "crystal"] and Rng.randf(&"combat") < recyc:
		return
	_mag_rounds[id] = have - per

func _ammo_reserve(ammo: String) -> int:
	if ammo == "" or Inventory == null:
		return 0
	return Inventory.count(ammo)

