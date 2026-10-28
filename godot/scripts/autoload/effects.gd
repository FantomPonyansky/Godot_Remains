extends Node

## Effect.as and the effect half of Unit / UnitPlayer / Pers.
##
## Every effect counts down in ticks (30 a second). Effect.step runs secEffect
## on whole seconds, then stepEffect, then t--; a forever effect rolls back to
## 30, anything else ends (and turns into its post effect when it has one).
## Unit.addEffect stacks: one food effect at a time, a repeat (or the post of
## the new one) is replaced in place keeping the larger val, "add" effects sum
## their time (at most 30000 ticks).
##
## Player effects change Pers parameters through setSkillParam (effs.xml sk
## rows). stat() replays those rows over a base value in list order; the
## systems that read a parameter call it. Effects on other units go through
## the unit's own status fields where it has them (enemy.gd burning, freezing,
## blindness, acid, pink cloud) plus a record here for timing and resistances.
##
## Also kept here: the player's cut and poison pools (Unit.cut / poison),
## chem addictions (Pers.addictions) and the curse trigger.
##
##   Effects.add(target, id, ticks := -1, power := 1.0, val := 0.0)
##   Effects.remove(target, id) / Effects.has(target, id)
## target null (or the player node) is the player.

signal changed
signal effect_started(target: Node, id: String)
signal effect_ended(target: Node, id: String)

const DATA_PATH := "res://assets/data/effects.json"
const ITEMS_PATH := "res://assets/data/effect_items.json"
const TPS := 30
const MAX_T := 30000
## Pers.ad1 / ad2 / ad3 / admax.
const AD1 := 100
const AD2 := 250
const AD3 := 500
const ADMAX := 750
## Pers.critHeal per difficulty: cut and poison drop by this every second.
const CRIT_HEAL: Array[float] = [0.2, 0.2, 0.2, 0.1, 0.1]
## E_Resistances.LEGACY_DAMAGE_TYPES, the numeric ids of effs.xml tip="res".
const RES_IDS: PackedStringArray = [
	"DAM_PIERCE", "DAM_CUT", "DAM_BLUNT", "DAM_BURN", "DAM_EXPLOSION",
	"DAM_LASER", "DAM_PLASMA", "DAM_VENOM", "DAM_EMP", "DAM_ELECTRIC",
	"DAM_ACID", "DAM_COLD", "DAM_POISON", "DAM_BLEED", "DAM_BITE",
	"DAM_BALEFIRE", "DAM_DEATH", "DAM_PSYCHIC", "DAM_ASTRO", "DAM_PINKCLOUD",
]
## Unit statuses enemy.gd already runs: [time field, damage-per-second field or "", default dps].
const UNIT_NATIVE := {
	"burning": ["_burn_left", "_burn_dps", 2.0],
	"freezing": ["_ice_t", "", 0.0],
	"blindness": ["_blind_t", "", 0.0],
	"chemburn": ["_acid_left", "_acid_dps", 2.0],
	"pinkcloud": ["_pink_left", "_pink_dps", 20.0],
}
## Effect.visEff / UnitPlayer.setFilters tints for the player body.
const TINT_FREEZE := Color(0.86, 0.86, 1.0)
const TINT_INV := Color(1.0, 0.55, 0.55)
const TINT_SHADOW := Color(0.25, 0.25, 0.3)
const _StatusPart := preload("res://scripts/status_part.gd")
## land_props ROOM_W x ROOM_H tiles of TILE px: Location maxX / maxY.
const ROOM_PX := Vector2(48 * 40, 25 * 40)

var cut: float = 0.0
var poison: float = 0.0
## Unit.stun on the player. UnitPlayer.actions zeroes it every tick, so it never holds.
var stun: int = 0
## Pers.addictions, keyed by the post effect id.
var addictions: Dictionary = {}
## game.triggers["curse"].
var curse_trigger: int = 0

var _defs: Dictionary = {}
var _items: Dictionary = {}
var _list: Array = []
var _units: Dictionary = {}
var _ops: Dictionary = {}
var _res: Dictionary = {}
var _dirty := true
var _acc := 0.0
var _t_hp := 0
var _bleed_carry := 0.0
var _poison_carry := 0.0
var _fet := Vector2.ZERO
var _tinted := false
var _auto_attack := false
var _vote_aim := false
var _vote_cel := Vector2.ZERO


func _ready() -> void:
	_load()
	call_deferred("_bind")


func _bind() -> void:
	var world := get_node_or_null("/root/WorldState")
	if world == null:
		return
	world.register("effects", save_data, load_data)
	if world.has_signal("run_reset") and not world.run_reset.is_connected(reset_run):
		world.run_reset.connect(reset_run)


func _load() -> void:
	var parsed: Variant = _read_json(DATA_PATH)
	if parsed is Dictionary:
		for row_v in (parsed as Dictionary).get("effects", []):
			if row_v is Dictionary:
				_defs[str(row_v.get("id", ""))] = row_v
	var items: Variant = _read_json(ITEMS_PATH)
	if items is Dictionary:
		for row_v in (items as Dictionary).get("items", []):
			if row_v is Dictionary:
				_items[str(row_v.get("id", ""))] = row_v


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("Effects: missing %s" % path)
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


# --- public API ---------------------------------------------------------

## Unit.addEffect. ticks <= 0 keeps the effs.xml duration. power scales val
## (the xml val unless val > 0 is given). Returns the effect record or {}.
func add(target: Variant, id: String, ticks: int = -1, power: float = 1.0, val: float = 0.0, se: bool = true) -> Dictionary:
	if id == "":
		return {}
	if _is_player(target):
		return _add_player(id, ticks, power, val, se)
	var unit := target as Node
	if unit == null or not is_instance_valid(unit):
		return {}
	return _add_unit(unit, id, ticks, power, val)


## Unit.remEffect: the effect ends now (with its post effect, if any).
func remove(target: Variant, id: String) -> void:
	if _is_player(target):
		for e in _list.duplicate():
			if not e.vse and e.id == id:
				_unset(e, null, true, true, true)
		return
	var unit := target as Node
	if unit == null:
		return
	for e in _unit_list(unit).duplicate():
		if not e.vse and e.id == id:
			_unset(e, unit, true, true, true)


func has(target: Variant, id: String) -> bool:
	return not _find(target, id).is_empty()


## Ticks left, -1 for a forever effect, 0 when absent.
func ticks_left(target: Variant, id: String) -> int:
	var e := _find(target, id)
	if e.is_empty():
		return 0
	return -1 if bool(e.forever) else int(e.t)


func level_of(target: Variant, id: String) -> int:
	var e := _find(target, id)
	return int(e.lvl) if not e.is_empty() else 0


## Live player effects (copies), in list order.
func player_effects() -> Array:
	var out: Array = []
	for e in _list:
		if not e.vse:
			out.append((e as Dictionary).duplicate())
	return out


## Pers parameter after the effect sk rows: base, then add / mult / set in list order.
func stat(name: String, base: float) -> float:
	_refresh()
	var v := base
	for op in _ops.get(name, []):
		match str(op[0]):
			"add":
				v += float(op[1])
			"mult":
				v *= float(op[1])
			_:
				v = float(op[1])
	return v


func has_stat(name: String) -> bool:
	_refresh()
	return _ops.has(name)


## changeResist from effs.xml tip="res": added to the player's vulnerability (1 = normal).
func vulner_delta(tip: String) -> float:
	_refresh()
	return float(_res.get(tip, 0.0))


func def_of(id: String) -> Dictionary:
	return _defs.get(id, {})


func item_row(id: String) -> Dictionary:
	return _items.get(id, {})


func ids() -> Array:
	return _defs.keys()


# --- player effects -----------------------------------------------------

func _add_player(id: String, ticks: int, power: float, val: float, se: bool) -> Dictionary:
	var eff := _make(id, val, power)
	if ticks > 0:
		eff.t = ticks
	for i in _list.size():
		var old: Dictionary = _list[i]
		if old.vse:
			continue
		if int(eff.tip) == 3 and int(old.tip) == 3:
			_list[i] = eff
			_set_eff(eff, null)
			return eff
		if old.id == id or (str(eff.post) != "" and old.id == eff.post):
			if float(old.val) > float(eff.val):
				eff.val = old.val
			if eff.add:
				eff.t = mini(int(eff.t) + int(old.t), MAX_T)
				_check_t(eff, null)
			_list[i] = eff
			_set_eff(eff, null)
			return eff
	eff.se = se
	_list.append(eff)
	if se:
		var mess := OriginalLines.mess("eff", id)
		if mess != "":
			_notice(mess)
	_set_eff(eff, null)
	effect_started.emit(null, id)
	return eff


## Effect.getXmlParam.
func _make(id: String, val: float, power: float = 1.0) -> Dictionary:
	var e := {
		"id": id, "tip": 0, "t": 1, "forever": false, "lvl": 1,
		"lvl1": 0, "lvl2": 0, "lvl3": 0, "val": val, "add": false, "se": true,
		"him": 0, "ad": false, "post": "", "post_bad": false, "del": [], "params": false,
		"vse": false, "native": false,
	}
	_load_def(e)
	if val <= 0.0:
		e.val = float(e.val) * power
	return e


func _load_def(e: Dictionary) -> void:
	e.t = 1
	e.post = ""
	e.post_bad = false
	e.del = []
	e.him = 0
	e.lvl = 1
	e.forever = false
	var d: Dictionary = _defs.get(str(e.id), {})
	if not d.is_empty():
		e.tip = int(d.get("tip", 0))
		e.t = int(round(float(d.get("t", 0)) * TPS))
		if float(e.val) == 0.0:
			e.val = float(d.get("val", 0))
		e.params = not (d.get("sk", []) as Array).is_empty()
		if str(d.get("post", "")) != "":
			e.post = str(d.post)
		if str(d.get("postbad", "")) != "":
			e.post = str(d.postbad)
			e.post_bad = true
		e.him = int(d.get("him", 0))
		e.lvl1 = int(d.get("lvl1", 0))
		e.lvl2 = int(d.get("lvl2", 0))
		e.lvl3 = int(d.get("lvl3", 0))
		e.add = int(d.get("add", 0)) != 0
		e.del = (d.get("del", []) as Array).duplicate()
	if int(e.t) == 0:
		e.t = TPS
		e.forever = true


## Effect.setEff.
func _set_eff(e: Dictionary, unit: Node) -> void:
	for nid in e.del:
		var list := _list if unit == null else _unit_list(unit)
		for other in list:
			if not other.vse and other.id == str(nid):
				_unset(other, unit, false, false, false)
				break
	if unit != null:
		_unit_params(unit)
		return
	if e.params:
		_dirty = true
	var p := _player()
	match str(e.id):
		"stupor":
			GameState.stam = 0.0
		"fetter":
			if p is Node2D:
				_fet = (p as Node2D).global_position
		"curse":
			curse_trigger = 1
		"potion_fly":
			_part(p, "black", 15)
		"potion_shadow":
			_part(p, "black", 15)
			Pets.uncall_pet(true)
		"potion_rat":
			Pets.uncall_pet(true)
			_part(p, "black", 30)
			if p != null and p.has_method("rat_on"):
				p.call("rat_on")
	_visuals()
	changed.emit()
	_params_moved()


## Effect.checkT: drunk-style levels from the time left.
func _check_t(e: Dictionary, unit: Node) -> void:
	if int(e.lvl1) <= 0:
		return
	var prev := int(e.lvl)
	var secs := float(e.t) / float(TPS)
	var lvl := 1
	if secs > float(e.lvl1):
		lvl = 2
	if secs > float(e.lvl2):
		lvl = 3
	if secs > float(e.lvl3):
		lvl = 4
	e.lvl = lvl
	if prev != lvl and e.params:
		if unit == null:
			_dirty = true
			_params_moved()
		else:
			_unit_params(unit)


## Effect.unsetEff.
func _unset(e: Dictionary, unit: Node, on_post: bool = true, inf: bool = true, set_param: bool = true) -> void:
	var was := str(e.id)
	if unit == null and was == "potion_rat":
		var p := _player()
		if p != null and p.has_method("rat_off") and not bool(p.call("rat_off")):
			if int(e.t) < 20:
				e.t = 29
			return
		if Pets.ret_pet != "":
			Pets.call_pet(Pets.ret_pet, true)
	e.vse = true
	if unit == null and inf and e.se:
		var name := OriginalLines.eff(was)
		_notice(OriginalLines.info("endFoodEffect" if int(e.tip) == 3 else "endEffect", name))
	if str(e.post) != "" and on_post:
		e.id = e.post
		var bad := bool(e.post_bad)
		_load_def(e)
		if bad:
			var proc := int(addictions.get(str(e.id), 0))
			if proc >= AD1:
				e.forever = true
				e.ad = true
			if proc >= AD2:
				e.lvl = 2
			if proc >= AD3:
				e.lvl = 3
		e.vse = false
	if unit != null:
		if UNIT_NATIVE.has(was) and e.vse:
			_native_clear(unit, was)
		if set_param:
			_unit_params(unit)
		effect_ended.emit(unit, was)
		return
	if e.params and set_param:
		_dirty = true
	match was:
		"potion_fly":
			_part(_player(), "black", 15)
		"potion_shadow":
			if Pets.ret_pet != "":
				Pets.call_pet(Pets.ret_pet, true)
	_visuals()
	changed.emit()
	if set_param:
		_params_moved()
	effect_ended.emit(null, was)


# --- ticking ------------------------------------------------------------

func _process(delta: float) -> void:
	if GameState.paused:
		return
	_acc += delta * TPS
	var n := mini(int(_acc), 10)
	if n <= 0:
		return
	_acc -= float(n)
	for _i in n:
		_tick()


func _tick() -> void:
	var p := _player()
	if p != null and not GameState.is_dead():
		_tick_player(p)
	if not _units.is_empty():
		_tick_units()
	if _dirty:
		_refresh()


func _tick_player(p: Node) -> void:
	var i := 0
	var moved := false
	while i < _list.size():
		var e: Dictionary = _list[i]
		if e.vse:
			_list.remove_at(i)
			moved = true
			continue
		_step(e, null, p)
		i += 1
	if moved:
		changed.emit()
	stun = 0
	_tick_pools()
	if has(null, "fetter"):
		_fetter(p)
	_tick_vote(p)


## UnitPlayer: attackForever aims at a random room point (5% a tick) and flips autoAttack (10%).
func _tick_vote(p: Node) -> void:
	if stat("attackForever", 0.0) <= 0.0:
		_auto_attack = false
		_vote_aim = false
		return
	if randf() < 0.05 and p is Node2D:
		var room := ((p as Node2D).global_position / ROOM_PX).floor() * ROOM_PX
		_vote_cel = room + Vector2(randf() * ROOM_PX.x, randf() * ROOM_PX.y)
		_vote_aim = true
	if randf() < 0.1:
		_auto_attack = not _auto_attack


## The aim point under attackForever (vote); the cursor otherwise.
func forced_aim(cursor: Vector2) -> Vector2:
	if stat("attackForever", 0.0) <= 0.0:
		return cursor
	if not _vote_aim:
		_vote_cel = cursor
		_vote_aim = true
	return _vote_cel


## UnitPlayer.autoAttack: attacks as if the attack key were held.
func auto_attack() -> bool:
	return _auto_attack


## attackForever blocks grenades, spells, reload, punches and weapon changes.
func attack_forever() -> bool:
	return stat("attackForever", 0.0) > 0.0


## Effect.step.
func _step(e: Dictionary, unit: Node, p: Node) -> void:
	if int(e.t) % TPS == 0:
		_sec(e, unit, p)
	if e.vse:
		return
	if str(e.id) == "sacrifice" and int(e.t) == 5:
		if unit == null:
			GameState.apply_damage(int(round(float(GameState._max_health()) * 0.5)), "DAM_INTERNAL", true)
		else:
			_unit_hit(unit, _unit_max_hp(unit) * 0.5, "DAM_INTERNAL")
	e.t = int(e.t) - 1
	if int(e.t) <= 0:
		if e.forever:
			e.t = TPS
		else:
			_unset(e, unit)


## Effect.secEffect. Effects the unit runs itself (native) only keep time here.
func _sec(e: Dictionary, unit: Node, p: Node) -> void:
	_check_t(e, unit)
	if e.native:
		return
	var v := float(e.val)
	match str(e.id):
		"burning":
			_hit(unit, v, "DAM_BURN")
		"pinkcloud":
			_hit(unit, v, "DAM_PINKCLOUD")
		"chemburn":
			_hit(unit, v, "DAM_ACID")
		"blindness":
			if unit == null and p is Node2D:
				var at := (p as Node2D).global_position + Vector2(randf() * 600.0 - 300.0, randf() * 400.0 - 200.0)
				_StatusPart.emit(get_tree(), "blind", at)
		"drunk":
			if int(e.lvl) > 3:
				_hit(unit, v, "DAM_POISON")
		"hydra":
			if unit == null:
				GameState.heal_raw(v)
				heal_cut(v / 2.0)
				GameState.heal_organs(v)
				GameState.heal_blood(v)
		"inhibitor":
			var from: Node2D = (p if unit == null else unit) as Node2D
			if from != null and v > 0.0:
				for en in get_tree().get_nodes_in_group("enemies"):
					if en is Node2D and en.has_method("apply_slow") and (en as Node2D).global_position.distance_squared_to(from.global_position) < v * v:
						en.apply_slow(40.0 / TPS)


func _hit(unit: Node, amount: float, tip: String) -> void:
	if unit == null:
		GameState.apply_damage_f(amount, tip, true)
	else:
		_unit_hit(unit, amount, tip)


func _unit_hit(unit: Node, amount: float, tip: String) -> void:
	if unit.has_method("_receive"):
		unit.call("_receive", amount, tip, null, true)
	elif unit.has_method("take_hit"):
		unit.take_hit(int(round(amount)), tip)


## Unit.actions periodic block: every 30 ticks sqrt(cut) as BLEED and sqrt(poison) as POISON.
func _tick_pools() -> void:
	if cut <= 0.0 and poison <= 0.0:
		return
	if _t_hp > 0:
		_t_hp -= 1
		return
	_t_hp = TPS
	var heal := CRIT_HEAL[clampi(GameState.difficulty(), 0, CRIT_HEAL.size() - 1)]
	if cut > 0.0:
		_bleed_carry += sqrt(cut)
		var n := int(_bleed_carry)
		_bleed_carry -= float(n)
		if n > 0:
			GameState.apply_damage(n, "DAM_BLEED", true)
		cut = maxf(0.0, cut - heal)
	if poison > 0.0:
		_poison_carry += sqrt(poison)
		var m := int(_poison_carry)
		_poison_carry -= float(m)
		if m > 0:
			GameState.apply_damage(m, "DAM_POISON", true)
		poison = maxf(0.0, poison - heal)
	if cut <= 0.0 and poison <= 0.0:
		changed.emit()


## UnitPlayer.actions isFetter: past isFetter px the chain pulls back toward the anchor.
func _fetter(p: Node) -> void:
	var body := p as CharacterBody2D
	var reach := stat("isFetter", 0.0)
	if body == null or reach <= 0.0:
		return
	var d := _fet - body.global_position + Vector2(0.0, -30.0)
	var r := d.length()
	if r > reach * 2.0:
		_fet = body.global_position
		return
	if r > reach * 0.95:
		var k := 1.0 if r > reach else (r / reach * 20.0 - 19.0)
		body.velocity += d / 20.0 * k * float(TPS)


# --- parameters ---------------------------------------------------------

func _refresh() -> void:
	if not _dirty:
		return
	_dirty = false
	_ops.clear()
	_res.clear()
	for e in _list:
		if e.vse or not e.params:
			continue
		var d: Dictionary = _defs.get(str(e.id), {})
		for sk_v in d.get("sk", []):
			var sk: Dictionary = sk_v
			var v := _sk_value(sk, int(e.lvl))
			if str(sk.get("tip", "")) == "res":
				var tip := _res_id(str(sk.get("id", "")))
				_res[tip] = float(_res.get(tip, 0.0)) - v
				continue
			var key := str(sk.get("id", ""))
			if not _ops.has(key):
				_ops[key] = []
			(_ops[key] as Array).append([str(sk.get("ref", "")), v])
	_apply_player_meta()


## Pers.setSkillParam value for one sk row.
static func _sk_value(sk: Dictionary, lvl: int) -> float:
	var v0 := 0.0
	if sk.has("v0"):
		v0 = float(sk.v0)
	elif str(sk.get("ref", "")) == "mult":
		v0 = 1.0
	if lvl <= 0:
		return v0
	if sk.has("vd"):
		return v0 + float(lvl) * float(sk.vd)
	if sk.has("v%d" % lvl):
		return float(sk["v%d" % lvl])
	return float(sk.get("v1", 0.0))


static func _res_id(raw: String) -> String:
	if raw.is_valid_int():
		var i := int(raw)
		if i >= 0 and i < RES_IDS.size():
			return RES_IDS[i]
	return raw


func _params_moved() -> void:
	_refresh()
	if GameState.has_method("refresh_params"):
		GameState.refresh_params()


func _apply_player_meta() -> void:
	var p := _player()
	if p == null:
		return
	var mult := stat("stealthMult", 1.0) * stat("visiMult", 1.0)
	if mult < 1.0:
		p.set_meta("stealth_mult", mult)
	elif p.has_meta("stealth_mult"):
		p.remove_meta("stealth_mult")
	_visuals()


## Effect.visEff / UnitPlayer.setFilters on the player's own modulate.
func _visuals() -> void:
	var p := _player() as CanvasItem
	if p == null:
		return
	var c := Color.WHITE
	if _has_live("freezing"):
		c = c * TINT_FREEZE
	if _has_live("bloodinv"):
		c = c * TINT_INV
	if _has_live("potion_shadow"):
		c = c * TINT_SHADOW
	if _has_live("stealth") or _has_live("stealth_armor") or _has_live("potion_shadow"):
		c.a = 0.5
	if c == Color.WHITE and not _tinted:
		return
	_tinted = c != Color.WHITE
	p.modulate = c


func _has_live(id: String) -> bool:
	for e in _list:
		if not e.vse and e.id == id:
			return true
	return false


# --- units --------------------------------------------------------------

func _add_unit(unit: Node, id: String, ticks: int, power: float, val: float) -> Dictionary:
	var eff := _make(id, val, power)
	if ticks > 0:
		eff.t = ticks
	var list := _unit_list(unit, true)
	eff.native = UNIT_NATIVE.has(id) and str(UNIT_NATIVE[id][0]) in unit
	var placed := false
	for i in list.size():
		var old: Dictionary = list[i]
		if old.vse:
			continue
		if int(eff.tip) == 3 and int(old.tip) == 3 or old.id == id or (str(eff.post) != "" and old.id == eff.post):
			if float(old.val) > float(eff.val):
				eff.val = old.val
			if eff.add:
				eff.t = mini(int(eff.t) + int(old.t), MAX_T)
				_check_t(eff, unit)
			list[i] = eff
			placed = true
			break
	if not placed:
		list.append(eff)
	if eff.native:
		_native_set(unit, eff)
	match id:
		"contusion", "stupor":
			if unit.has_method("apply_slow"):
				unit.apply_slow(float(eff.t) / TPS)
	_set_eff(eff, unit)
	effect_started.emit(unit, id)
	return eff


func _unit_list(unit: Node, make: bool = false) -> Array:
	var key := unit.get_instance_id()
	if not _units.has(key):
		if not make:
			return []
		_units[key] = {"node": weakref(unit), "list": [], "res": {}}
	return _units[key].list


func _native_set(unit: Node, e: Dictionary) -> void:
	var spec: Array = UNIT_NATIVE[str(e.id)]
	unit.set(str(spec[0]), float(e.t) / TPS)
	if str(spec[1]) != "":
		unit.set(str(spec[1]), float(e.val) if float(e.val) > 0.0 else float(spec[2]))
	match str(e.id):
		"burning":
			if "_ice_t" in unit:
				unit.set("_ice_t", 0.0)
		"freezing":
			if "_burn_left" in unit:
				unit.set("_burn_left", 0.0)


func _native_clear(unit: Node, id: String) -> void:
	if UNIT_NATIVE.has(id) and is_instance_valid(unit):
		unit.set(str(UNIT_NATIVE[id][0]), 0.0)


## Unit.setEffParams: the unit's vulnerabilities are its base plus every live effect's res rows.
func _unit_params(unit: Node) -> void:
	var key := unit.get_instance_id()
	if not _units.has(key):
		return
	var rec: Dictionary = _units[key]
	var want := {}
	for e in rec.list:
		if e.vse:
			continue
		var d: Dictionary = _defs.get(str(e.id), {})
		for sk_v in d.get("sk", []):
			var sk: Dictionary = sk_v
			if str(sk.get("tip", "")) == "res":
				var tip := _res_id(str(sk.get("id", "")))
				want[tip] = float(want.get(tip, 0.0)) - _sk_value(sk, 1)
	var comp := Resistances.of(unit)
	if comp == null:
		return
	var had: Dictionary = rec.res
	var mult: Dictionary = comp.multipliers
	for tip in had.keys():
		mult[tip] = float(mult.get(tip, 1.0)) - float(had[tip])
	for tip in want.keys():
		mult[tip] = float(mult.get(tip, 1.0)) + float(want[tip])
	rec.res = want


func _tick_units() -> void:
	for key in _units.keys():
		var rec: Dictionary = _units[key]
		var unit := (rec.node as WeakRef).get_ref() as Node
		if unit == null or not is_instance_valid(unit) or unit.get("_dead") == true:
			_units.erase(key)
			continue
		var list: Array = rec.list
		var i := 0
		while i < list.size():
			var e: Dictionary = list[i]
			if e.vse:
				list.remove_at(i)
				continue
			if e.native and float(unit.get(str(UNIT_NATIVE[str(e.id)][0]))) <= 0.0:
				_unset(e, unit, false, false, true)
				list.remove_at(i)
				continue
			_step(e, unit, null)
			i += 1
		if list.is_empty() and (rec.res as Dictionary).is_empty():
			_units.erase(key)


## enemy.gd _receive, after resistances and armor: contusion from explosions
## and Unit.damage's relat return to the bullet's owner.
func unit_damaged(unit: Node, dealt: float, tip: String, tt: bool, bullet: Node) -> void:
	if unit == null or dealt <= 0.0:
		return
	if tip == "DAM_EXPLOSION" and not tt and not bool(unit.get_meta("mech", false)) and not bool(unit.get_meta("robot", false)):
		if randf() < dealt / maxf(1.0, _unit_max_hp(unit)):
			add(unit, "contusion")
	if bullet != null and bool(bullet.get("from_player")):
		var relat := stat("relat", 0.0)
		if relat > 0.0:
			GameState.apply_damage_f(dealt * relat, "DAM_INTERNAL", false)


# --- player hits --------------------------------------------------------

## Unit.damage dop effects and UnitPlayer.damage psy, for a bullet that hit the player.
func player_hit(effect: String, dop: float, dealt: float) -> void:
	match effect:
		"psy":
			if randf() < 0.33:
				add(null, "horror")
			elif randf() < 0.5:
				add(null, "vote")
			else:
				add(null, "disorient")
		"igni":
			if player_vulner("DAM_BURN") > 0.1:
				add(null, "burning", -1, 1.0, dop)
		"ice":
			if player_vulner("DAM_COLD") > 0.1:
				add(null, "freezing")
		"blind":
			if player_vulner("DAM_LASER") > 0.1:
				add(null, "blindness")
		"acid":
			if player_vulner("DAM_ACID") > 0.1:
				add(null, "chemburn", -1, 1.0, dop)
		"pink":
			if player_vulner("DAM_PINKCLOUD") > 0.1:
				add(null, "pinkcloud", -1, 1.0, dop)
		"poison":
			if player_vulner("DAM_POISON") > 0.1:
				add_poison(dop)
		"cut":
			if player_vulner("DAM_BLEED") > 0.1:
				add_cut(dop)
		"stun":
			if randf() < dealt / maxf(1.0, float(GameState._max_health())):
				_stun_hit(int(dop))


## Player vulnerability to tip: 1 plus the effect res rows (armor is Condition's).
func player_vulner(tip: String) -> float:
	return 1.0 + vulner_delta(tip)


## Unit.damage on the player: explosions can stun (contusion).
func player_damaged(dealt: float, tip: String, tt: bool) -> void:
	if tip == "DAM_EXPLOSION" and not tt and dealt > 0.0:
		if randf() < dealt / maxf(1.0, float(GameState._max_health())):
			add(null, "contusion")


func add_cut(v: float) -> void:
	if v <= 0.0:
		return
	if cut <= 0.0:
		_notice(OriginalLines.info("cut"))
	cut += v
	changed.emit()


func add_poison(v: float) -> void:
	if v <= 0.0:
		return
	if poison <= 0.0:
		_notice(OriginalLines.info("poison"))
	poison += v
	changed.emit()


## UnitPlayer.heal tip 3.
func heal_cut(v: float) -> void:
	if v == 0.0 or cut <= 0.0:
		return
	cut = maxf(0.0, cut - v)
	changed.emit()


## UnitPlayer.heal tip 4: a negative amount poisons.
func heal_poison(v: float) -> void:
	if v == 0.0:
		return
	if v > 0.0:
		poison = maxf(0.0, poison - v)
	else:
		poison -= v
	changed.emit()


# --- items, addictions, death -------------------------------------------

## Pers.himLevel / himTimeMult / himBadMult (perks fightstim, longtime).
func him_level() -> int:
	return 2 if Progression.perk_rank("fightstim") > 0 else 1


func him_time_mult() -> float:
	return 2.0 if Progression.perk_rank("longtime") > 0 else 1.0


func him_bad_mult() -> float:
	return 0.5 if Progression.perk_rank("fightstim") > 0 else 1.0


## ItemInteraction.usePotion tail: detox, purification, effect, alcohol, chem
## radiation and addiction, then the use message. Heals are GameState's.
func use_item(id: String, pot: Dictionary) -> void:
	if str(pot.get("heal", "")) == "detoxin":
		_detox(int(pot.get("detox", 0)))
	if int(pot.get("hpurif", 0)) > 0:
		for e in _list.duplicate():
			if not e.vse and int(e.tip) == 4:
				_unset(e, null, false, true, false)
		remove(null, "curse")
		curse_trigger = 0
		_dirty = true
		_params_moved()
	if str(pot.get("perk", "")) != "":
		Progression.grant_perk(str(pot.perk))
	if str(pot.get("effect", "")) != "":
		var e := add(null, str(pot.effect))
		if not e.is_empty() and str(pot.get("tip", "")) == "him":
			if him_level() > 0:
				e.lvl = him_level()
				_dirty = true
				_params_moved()
			e.t = int(round(float(e.t) * him_time_mult()))
	if float(pot.get("alc", 0.0)) > 0.0:
		add(null, "drunk", int(round(float(pot.alc) * 10.0)) * TPS)
	if str(pot.get("ad", "")) != "":
		_addict(id, str(pot.ad), int(pot.get("admin", 0)), int(pot.get("admax", 0)))
	var name := OriginalLines.name_of(id)
	if str(pot.get("tip", "")) == "food":
		_notice(OriginalLines.info("usedfood2" if int(pot.get("ftip", 0)) == 1 else "usedfood", name))
	elif str(pot.get("heal", "")) == "organ":
		_notice(OriginalLines.info("usedheal", name))
	else:
		_notice(OriginalLines.info("heal", name))
	changed.emit()


func _addict(item: String, ad: String, n1: int, n2: int) -> void:
	var n := int(round(randf() * float(n2 - n1) + float(n1)) * him_bad_mult() * GameState.dif_value("him_bad_dif"))
	var prev := int(addictions.get(ad, 0))
	addictions[ad] = mini(prev + n, ADMAX)
	var name := OriginalLines.name_of(item)
	if prev < AD3 and prev + n >= AD3:
		_notice(OriginalLines.info("addiction3", name))
	elif prev < AD2 and prev + n >= AD2:
		_notice(OriginalLines.info("addiction2", name))
	elif prev < AD1 and prev + n >= AD1:
		_notice(OriginalLines.info("addiction1", name))


## ItemInteraction.usePotion detoxin: five passes of 25..75 off each addiction
## until the budget is spent, then every chem effect ends and addictions reapply.
func _detox(budget: int) -> void:
	var lim := budget
	for _j in 5:
		for ad in addictions.keys():
			if int(addictions[ad]) > 0:
				var red := int(round(randf() * 50.0 + 25.0))
				if red > int(addictions[ad]):
					lim -= int(addictions[ad])
					addictions[ad] = 0
				else:
					lim -= red
					addictions[ad] = int(addictions[ad]) - red
			if lim <= 0:
				break
		if lim <= 0:
			break
	for e in _list.duplicate():
		if not e.vse and (int(e.him) == 1 or int(e.him) == 2):
			_unset(e, null, false, true, false)
	set_addictions()
	_dirty = true
	_params_moved()


## UnitPlayer.setAddictions.
func set_addictions() -> void:
	for ad in addictions.keys():
		var proc := int(addictions[ad])
		if proc < AD1:
			continue
		var e := add(null, str(ad))
		if e.is_empty():
			continue
		if proc >= AD2:
			e.lvl = 2
		if proc >= AD3:
			e.lvl = 3
		e.forever = true
		_dirty = true
	if curse_trigger > 0:
		add(null, "curse")
	_params_moved()


func addiction_level(ad: String) -> int:
	var proc := int(addictions.get(ad, 0))
	if proc >= AD3:
		return 3
	if proc >= AD2:
		return 2
	if proc >= AD1:
		return 1
	return 0


## UnitPlayer.die lastCh: Second chance keeps the player at 1 hp and heals 300.
func death_cheat() -> bool:
	var last := stat("lastCh", 0.0)
	if last <= 0.0:
		return false
	GameState.health = 1
	GameState.heal_raw(last * 0.1)
	GameState.heal_long(last * 0.9)
	remove(null, "potion_chance")
	add(null, "post_chance")
	return true


## Every player effect ends (no post effects survive), then addictions return.
func on_revive() -> void:
	for e in _list:
		if not e.vse:
			_unset(e, null, true, false, false)
	_list.clear()
	cut = 0.0
	poison = 0.0
	stun = 0
	_dirty = true
	set_addictions()
	changed.emit()


func reset_run() -> void:
	_list.clear()
	_units.clear()
	addictions.clear()
	curse_trigger = 0
	cut = 0.0
	poison = 0.0
	stun = 0
	_t_hp = 0
	_bleed_carry = 0.0
	_poison_carry = 0.0
	_dirty = true
	_refresh()
	_visuals()
	changed.emit()
	if GameState.has_method("refresh_params"):
		GameState.refresh_params()


# --- save ---------------------------------------------------------------

func save_data() -> Dictionary:
	var rows: Array = []
	for e in _list:
		if e.vse:
			continue
		rows.append({"id": e.id, "t": e.t, "forever": e.forever, "lvl": e.lvl, "val": e.val, "ad": e.ad, "se": e.se})
	return {"list": rows, "cut": cut, "poison": poison, "addictions": addictions.duplicate(), "curse": curse_trigger}


func load_data(data: Variant) -> void:
	if not data is Dictionary:
		return
	var d: Dictionary = data
	_list.clear()
	for row_v in d.get("list", []):
		if not row_v is Dictionary:
			continue
		var row: Dictionary = row_v
		var e := _make(str(row.get("id", "")), float(row.get("val", 0.0)))
		e.t = int(row.get("t", e.t))
		e.forever = bool(row.get("forever", e.forever))
		e.lvl = int(row.get("lvl", e.lvl))
		e.ad = bool(row.get("ad", false))
		e.se = bool(row.get("se", true))
		_list.append(e)
	cut = float(d.get("cut", 0.0))
	poison = float(d.get("poison", 0.0))
	addictions.clear()
	var ads: Dictionary = d.get("addictions", {})
	for k in ads.keys():
		addictions[str(k)] = int(ads[k])
	curse_trigger = int(d.get("curse", 0))
	_dirty = true
	_params_moved()
	changed.emit()


# --- HUD and PipBuck ----------------------------------------------------

## GUI.setEffects slots: cut, poison, shield, then each effect.
## Each row is {"icon": icon id, "text": counter}.
func hud_rows(shield: float = 0.0) -> Array:
	var out: Array = []
	if cut > 0.0:
		out.append({"icon": "cut", "text": _num(round(cut * 10.0) / 10.0)})
	if poison > 0.0:
		out.append({"icon": "poison", "text": _num(round(poison * 10.0) / 10.0)})
	if shield > 0.0:
		out.append({"icon": "shit", "text": str(int(ceil(shield)))})
	for e in _list:
		if e.vse:
			continue
		var icon := "food" if int(e.tip) == 3 else str(e.id)
		out.append({"icon": icon, "id": e.id, "text": "∞" if e.forever else str(floori(float(e.t) / TPS))})
	return out


## PipPageStat effects page rows: {"id", "name", "value", "info"}.
func pip_rows() -> Array:
	var out: Array = []
	for e in _list:
		if e.vse:
			continue
		var id := str(e.id)
		var name := OriginalLines.eff(id)
		var info := ""
		if e.ad:
			var ad_name := OriginalLines.eff(id + "_ad")
			if ad_name != "" and ad_name != id + "_ad":
				name = "%s (%s)" % [ad_name, OriginalLines.pip("ad%d" % int(e.lvl))]
				info = describe(id + "_ad", addiction_level(id))
		if id == "drunk":
			name = OriginalLines.pip("drunk%d" % int(e.lvl))
			info = describe(id, int(e.lvl))
		if info == "":
			info = describe(id, _info_level(id))
		if int(e.tip) == 3:
			name = OriginalLines.eff("food")
			info = OriginalLines.desc("eff", "food") + "\n\n" + info
		var value := "∞" if e.forever else str(int(round(float(e.t) / TPS)))
		out.append({"id": id, "name": name, "value": value, "info": info})
	return out


func _info_level(id: String) -> int:
	var d: Dictionary = _defs.get(id, {})
	match int(d.get("him", 0)):
		2:
			return maxi(1, addiction_level(id))
		1:
			return him_level()
	return 1


## PipPage.effStr: the info text with #1..#5 from textvar, plus the eff rows of that level.
func describe(id: String, lvl: int) -> String:
	var s := OriginalLines.desc("eff", id)
	var base := id.substr(0, id.length() - 3) if id.ends_with("_ad") else id
	var d: Dictionary = _defs.get(base, {})
	if d.is_empty():
		return s
	var tv: Array = d.get("textvar", [])
	if not tv.is_empty():
		var row: Dictionary = tv[lvl - 1] if lvl > 1 and lvl - 1 < tv.size() else tv[0]
		for k in 5:
			var key := "s%d" % (k + 1)
			if row.has(key):
				s = s.replace("#%d" % (k + 1), "[%s]" % str(row[key]))
	var rows: Array = d.get("eff", [])
	if not rows.is_empty() and lvl > 0:
		s += "\n"
		for r_v in rows:
			var r: Dictionary = r_v
			var label := OriginalLines.pip(str(r.id)) if str(r.get("id", "")) != "" else OriginalLines.pip("refeff")
			s += "\n%s: [%s]" % [label, str(r.get("n%d" % lvl, ""))]
	return s


static func _num(v: float) -> String:
	if is_equal_approx(v, round(v)):
		return str(int(round(v)))
	return str(v)


# --- helpers ------------------------------------------------------------

func _is_player(target: Variant) -> bool:
	if target == null:
		return true
	if target is String:
		return str(target) == "player" or str(target) == "gg"
	if target is Node and is_instance_valid(target):
		return (target as Node).is_in_group("player")
	return false


func _find(target: Variant, id: String) -> Dictionary:
	var list: Array = _list
	if not _is_player(target):
		var unit := target as Node
		if unit == null or not is_instance_valid(unit):
			return {}
		list = _unit_list(unit)
	for e in list:
		if not e.vse and e.id == id:
			return e
	return {}


static func _unit_max_hp(unit: Node) -> float:
	var v: Variant = unit.get("max_hp")
	return float(v) if v != null else 1.0


func _player() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group("player")


func _notice(text: String) -> void:
	if text == "" or not is_inside_tree():
		return
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notice"):
		hud.show_notice(text)


## Unit.newPart: kol particles at the middle of the player's 78 px body.
func _part(p: Node, id: String, kol: int) -> void:
	if p is Node2D and is_inside_tree():
		UnitFx.emit(get_tree(), id, (p as Node2D).global_position + Vector2(0, -39), {"kol": kol})


## Unit.damage dop stun on the player: the message and the floating mess, then the
## stun-- of Unit.actions (a star when it lands on a multiple of 10) before UnitPlayer zeroes it.
func _stun_hit(st: int) -> void:
	var p := _player()
	if st <= 0 and OriginalLines.has("info", "stun"):
		_notice(OriginalLines.info("stun"))
	if not (p is Node2D):
		return
	var at := (p as Node2D).global_position
	if st > 1:
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("float_number"):
			hud.float_number(at, OriginalLines.gui("stun"), "status")
	if st > 0 and (st - 1) % 10 == 0:
		_StatusPart.emit(get_tree(), "stun", at + Vector2(0, -58))
