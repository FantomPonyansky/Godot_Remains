extends StaticBody2D

## UnitTrigger (laser, pressure plate, cans, tripwire), UnitDamager (wall gun,
## grenade bundle, charge) and UnitTrap (bear trap). Times are ticks at 30/s.
## Trigger and damager status: 0 armed, 1 activated, 2 disarmed.

const TPS := 30.0
const TILE := 40.0
const F_PLAYER := 100
const F_RAIDER := 2
const F_ROBOT := 4
const V_NOISE := 1200.0
const VISIBILITY := 300.0
const SHEETS := "res://assets/sprites/sheets/traps/"
const _Bullet := preload("res://scenes/bullet.tscn")
const _Enemy := preload("res://scenes/enemy.tscn")
const _Block := preload("res://scripts/block_destroy.gd")
const _Registry := preload("res://scripts/map/land_registry.gd")
const _Spawn := preload("res://scripts/map/land_spawn.gd")
const _WeaponVis := preload("res://scripts/weapon_vis.gd")
## vismtrap: frames 1-4 snap the jaws shut, 5-20 open them again (gotoAndPlay 1 / 5).
const SNAP_END := 3
const REARM_FROM := 4
const REARM_END := 19

## units.xml: phis sX/sY, comb hp, fraction, un skill/res/one/plate/tip, snd act.
const UNITS := {
	"triglaser": {"kind": "trig", "size": [20, 40], "hp": 100, "fr": 4, "skill": "science", "res": "hturret2", "snd": "mine_bip", "robot": true},
	"trigplate": {"kind": "trig", "size": [40, 10], "hp": 100, "fr": 2, "skill": "repair", "res": "damshot", "plate": true, "snd": "button"},
	"trigcans": {"kind": "trig", "size": [40, 70], "hp": 10, "fr": 2, "skill": "sneak", "res": "noise", "snd": "cans"},
	"trigridge": {"kind": "trig", "size": [20, 40], "hp": 10, "fr": 2, "skill": "repair", "res": "damgren", "one": true},
	"damshot": {"kind": "dam", "size": [40, 70], "hp": 30, "fr": 2, "skill": "repair", "tip": 1},
	"damgren": {"kind": "dam", "size": [20, 20], "hp": 20, "fr": 2, "skill": "explosives", "tip": 2},
	"damexpl1": {"kind": "dam", "size": [36, 36], "hp": 20, "fr": 2, "skill": "explosives", "tip": 3},
	"mtrap": {"kind": "trap", "size": [20, 20], "hp": 100, "fr": 0, "skill": "repair", "damage": 24},
}
const GUNS := ["", "lshot", "hunt", "assr", "dartgun", "flamer"]
## weapons.xml sats que: UnitDamager fires que * 2 rounds per activation.
const SATS_QUE := {"assr": 3, "flamer": 10}
const EXPL1 := {"damage": 250.0, "destroy": 1000, "radius": 200.0}

static var _weapons := {}
static var _manifest := {}

var id := "damshot"
var kind := "dam"
var props: Node = null
var status := 0
var hp := 10.0
var max_hp := 10.0
var fraction := 2
var level := 0
var need_skill := "repair"
var need_lvl := 1
var res := ""
var allid := ""
var allact := ""
var one := false
var plate := false
var size := Vector2(20, 20)
var facing := 1.0
var is_vis := false
var dead := false
var die_actions: Array = []

var _room: Array = [0, 0]
var _ai_n := 0
var _acc := 0.0
var _set_up := false
var _is_act := false
var _damager: Node = null

var _tip := 1
var _tr := "0"
var _weap: Dictionary = {}
var _kolammo := 100
var _och := 20
var _noch := 0
var _is_shoot := false
var _t_attack := 0
var _expl_damage := 0.0
var _cel := Vector2.ZERO

var _snapped := false
var _rearm := false
var _damage := 24.0

## Telekinesis (player.gd sets held). units.xml mtrap massa 15 / 50.
var held := false
var massa := 0.3
var _lifted := false
var _fall_v := 0.0

## Map memory of the damager this trigger made: land_memory.gd state.
var _dam_made := false
var _dam_state: Dictionary = {}

var _sheet: Dictionary = {}
var _vis: Sprite2D = null
var _gun: Sprite2D = null
var _frame := 0
var _play_to := -1
var _play_end := 0


func setup(row: Dictionary, host: Node) -> void:
	props = host
	id = str(row.get("unit_id", row.get("id", "damshot")))
	if not UNITS.has(id):
		id = "damshot"
	var data: Dictionary = UNITS[id]
	kind = str(data.kind)
	var attrs: Dictionary = row.get("attrs", {})
	var feet: Array = row.get("feet", [0, 0])
	position = Vector2(float(feet[0]), float(feet[1]))
	_room = row.get("room", [0, 0])
	size = Vector2(float(data.size[0]), float(data.size[1]))
	max_hp = float(data.hp)
	fraction = int(data.fr)
	if kind == "trig" and int(row.get("tip_enemy", -1)) == 2 and fraction == F_RAIDER:
		fraction = F_ROBOT
	need_skill = str(data.skill)
	res = str(attrs.get("res", data.get("res", "")))
	allid = str(attrs.get("allid", ""))
	allact = str(attrs.get("allact", ""))
	one = bool(data.get("one", false))
	plate = bool(data.get("plate", false))
	_tip = int(data.get("tip", 1))
	_tr = str(attrs.get("tr", "0"))
	var turn := int(float(str(attrs.get("turn", "0"))))
	if turn != 0:
		facing = 1.0 if turn > 0 else -1.0
	level = int(row.get("level", 0))
	if kind == "dam":
		_set_weapon(attrs)
	elif kind == "trap":
		_damage = float(data.damage) * (1.0 + float(level) * 0.07)
		max_hp *= 1.0 + float(level) * 0.11
	if kind != "trap":
		need_lvl = clampi(int(round(float(level) * 0.25 * (randf() * 0.7 + 0.3))), 1, 5)
	hp = max_hp
	if allid != "":
		set_meta("allid", allid)
	set_meta("unit_id", id)
	set_meta("room_x", int(_room[0]))
	set_meta("room_y", int(_room[1]))


func _ready() -> void:
	name = id
	add_to_group("trap_units")
	collision_layer = 4
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector2(0.0, -size.y * 0.5)
	add_child(shape)
	if kind == "trap":
		collision_mask = 1
	_make_vis()
	_ai_n = randi() % 5
	_set_vis(false)
	refresh_use()


func user_action() -> String:
	return "rearm" if kind == "trap" and _snapped else "disarm"


## Interact.active: a trigger or damager only while armed, a trap always.
func refresh_use() -> void:
	set_meta("user_action", user_action())
	set_meta("hold_use", true)
	set_meta("act_time", 60 if kind == "trap" and _snapped else 30)
	set_meta("usable", is_vis and not dead and (kind == "trap" or status == 0))


func use_object(from_timer: bool) -> void:
	if not from_timer:
		var player := get_tree().get_first_node_in_group("player")
		if player != null and player.has_method("begin_use_timer"):
			player.begin_use_timer(self)
		return
	var need := 3 if kind == "trap" and _snapped else need_lvl
	if need_skill != "" and Progression.skill_level_of(need_skill) < need:
		_notice(OriginalLines.info("needSkill", OriginalLines.eff(need_skill), str(need)))
		return
	match kind:
		"trig":
			_trig_disarm()
		"dam":
			_dam_disarm()
		"trap":
			_trap_use()


## Unit.command from scripts and Location.allAct.
func command(com: String, _val: String = "") -> void:
	if com == "dam":
		if kind == "dam":
			activate()
		elif kind == "trig":
			_trig_activate()


func take_hit(amount: int = 1, _type: String = "") -> void:
	if dead or amount <= 0:
		return
	hp -= float(amount)
	if not is_vis:
		_set_vis(true)
	if hp <= 0.0:
		_die()


func _physics_process(delta: float) -> void:
	if dead:
		return
	_acc += delta * TPS
	var steps := 0
	while _acc >= 1.0 and steps < 4:
		_acc -= 1.0
		steps += 1
		_step()
		if dead:
			return


func _step() -> void:
	if not _set_up:
		_set_up = true
		_restore()
		if kind == "trig" and allid == "":
			if not _dam_state.is_empty():
				_relink_damager()
			elif status != 2:
				_set_damager()
	_ai_n += 1
	_tick_anim()
	match kind:
		"trig":
			_trig_control()
		"dam":
			_dam_control()
		"trap":
			_fall_step()
			_trap_control()
	if _ai_n % 10 == 0 and not is_vis and _look_invis():
		_set_vis(true)


## land_memory writes "dead" for a spent trap; the record comes back on re-entry.
func _restore() -> void:
	if not bool(get_meta("dead", false)):
		return
	if kind == "trap":
		_snapped = true
		_set_frame(SNAP_END)
		_set_vis(true)
	else:
		status = 2
		_show_status()
	refresh_use()


## UnitTrap.save keeps rearm (the player set it); a trigger keeps its damager.
func memory_state() -> Dictionary:
	if kind == "trap":
		return {"rearm": true} if _rearm else {}
	if kind != "trig" or not _dam_made:
		return {}
	if not _alive(_damager):
		return {"dam": {"gone": true}}
	if _damager.is_in_group("trap_units"):
		var at := (_damager as Node2D).position
		return {"dam": {
			"id": str(_damager.get("id")),
			"pos": [at.x, at.y],
			"turn": int(float(_damager.get("facing"))),
			"tr": str(_damager.get("_tr")),
			"kolammo": int(_damager.get("_kolammo")),
		}}
	return {"dam": {"turret": str(_damager.get_meta("wid", ""))}}


func load_memory(state: Dictionary) -> void:
	if kind == "trap" and bool(state.get("rearm", false)):
		_rearm = true
		fraction = F_PLAYER
	if kind == "trig" and state.get("dam") is Dictionary:
		_dam_state = state.dam


## The remembered damager: a wall gun or bundle made again as it was left, the
## turret found among the land's saved units, nothing once it was spent.
func _relink_damager() -> void:
	_dam_made = true
	if bool(_dam_state.get("gone", false)):
		return
	if _dam_state.has("turret"):
		var wid := str(_dam_state.turret)
		for node in get_tree().get_nodes_in_group("enemies"):
			if wid != "" and str(node.get_meta("wid", "")) == wid:
				_damager = node
				node.set("fraction", fraction)
				return
		return
	var pos: Array = _dam_state.get("pos", [])
	if pos.size() < 2 or props == null or not props.has_method("spawn_trap_unit"):
		return
	var attrs := {"tr": str(_dam_state.get("tr", "0")), "kolammo": str(int(_dam_state.get("kolammo", 1)))}
	var turn := int(_dam_state.get("turn", 0))
	if turn != 0:
		attrs["turn"] = str(turn)
	_damager = props.spawn_trap_unit({
		"unit_id": str(_dam_state.get("id", "damshot")),
		"feet": [float(pos[0]), float(pos[1])],
		"room": _room,
		"level": level,
		"attrs": attrs,
	})
	if _damager != null:
		_damager.set("fraction", fraction)


# --- UnitTrigger ---

func _trig_control() -> void:
	if status == 2 or (one and status == 1) or _player_busy():
		return
	if _ai_n % 5 != 0:
		return
	var act := _touched()
	if not _is_act and act:
		_trig_activate()
	if _is_act and not act and not one and status == 1:
		status = 0
		refresh_use()
		_show_status()
	_is_act = act


func _trig_activate() -> void:
	if status != 0:
		return
	_set_vis(true)
	status = 1
	var act := false
	# activate returns before setStatus: the clip and the prompt stay as they were.
	if allact == "spawn":
		if props != null and props.has_method("enemy_spawn"):
			props.enemy_spawn(global_position, true, true)
		return
	if allid != "":
		for node in get_tree().get_nodes_in_group("trap_units"):
			if node != self and str(node.get("kind")) == "dam" and str(node.get("allid")) == allid:
				node.call("activate")
				act = true
		if allact != "" and props != null and props.has_method("all_act"):
			props.all_act(allact, allid)
	if res == "noise" or res == "hturret2":
		_budilo(V_NOISE)
		act = true
		if res == "hturret2" and _alive(_damager):
			_brain_command(_damager, "alarma")
	if _alive(_damager):
		var st: Variant = _damager.get("status")
		if st == null or int(st) < 2:
			if _damager.is_in_group("trap_units"):
				_damager.call("command", "dam")
			else:
				_brain_command(_damager, "dam")
			act = true
	if UNITS[id].has("snd"):
		SfxBank.play(str(UNITS[id].snd))
	refresh_use()
	_show_status()
	if act:
		_notice(OriginalLines.info("trapActivate"))


func _trig_disarm() -> void:
	status = 2
	set_meta("dead", true)
	refresh_use()
	_show_status()
	_notice(OriginalLines.info("trapDisarm"))


## UnitTrigger.setArea.
func _area() -> Rect2:
	var at := global_position
	if id == "trigridge" or id == "triglaser":
		return Rect2(at.x - 5.0, at.y - 30.0, 10.0, 10.0)
	if plate:
		return Rect2(at.x - size.x * 0.5, at.y - 2.0, size.x, 2.0)
	return Rect2(at.x - size.x * 0.5, at.y - size.y, size.x, size.y)


func _touched() -> bool:
	var area := _area()
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and fraction != F_PLAYER and not GameState.is_dead():
		var act := GameState.activate_trap()
		if act > 0.0 and (not plate or (act > 1.0 and _stands(player))) and area.intersects(_rect_of(player)):
			return true
	for node in get_tree().get_nodes_in_group("enemies"):
		var unit := node as Node2D
		if unit == null or not _unit_meets(unit):
			continue
		var act2 := _act_trap(unit)
		if act2 <= 0 or (plate and (act2 <= 1 or not _stands(unit))):
			continue
		if area.intersects(_rect_of(unit)):
			return true
	return false


## setDamager: a grenade bundle on the ceiling above, a turret there for a laser,
## a gun on the nearest wall for a plate. Without a spot it falls back to a gun.
func _set_damager() -> void:
	if res == "noise" or res == "" or props == null:
		return
	_dam_made = true
	var at := global_position
	var nx := at.x
	var ny := at.y
	var turn := 0
	var ok := false
	if res == "damgren" and randf() < 0.25 and not _solid(Vector2(at.x, at.y + 60.0)):
		ny = at.y + 2.0 * TILE
		res = "expl1"
		ok = true
	else:
		for i in range(1, 11):
			if res == "damgren" or res == "hturret2":
				if _solid(Vector2(at.x, at.y - 10.0 - i * TILE)):
					if i == 1:
						break
					ny = at.y - (i - 1) * TILE
					ok = true
					break
				if res == "hturret2":
					var side_hit := false
					for dx in [-TILE, TILE]:
						if _solid(Vector2(at.x + dx, at.y - 10.0 - i * TILE)):
							ny = at.y - (i - 1) * TILE
							nx = at.x + dx
							side_hit = true
							break
					if side_hit:
						ok = true
						break
			if res == "damshot" and i > 1:
				if _solid(Vector2(at.x - i * TILE, at.y - 10.0)):
					nx = at.x - (i - 1) * TILE
					turn = 1
					ok = true
					break
				if _solid(Vector2(at.x + i * TILE, at.y - 10.0)):
					nx = at.x + (i - 1) * TILE
					turn = -1
					ok = true
					break
	if ok:
		_damager = _create(res, Vector2(nx, ny), turn)
	elif res == "damgren" or res == "hturret2":
		res = "damshot"
		_set_damager()
	else:
		res = "damshot"
		if randf() < 0.5:
			nx = at.x + (3 + randi() % 8) * TILE
			turn = -1
		else:
			nx = at.x - (3 + randi() % 8) * TILE
			turn = 1
		_damager = _create(res, Vector2(nx, ny), turn)


func _create(what: String, at: Vector2, turn: int) -> Node:
	if what == "hturret2":
		return _create_turret(at)
	var unit_id := "damexpl1" if what == "expl1" else what
	var row := {
		"unit_id": unit_id,
		"feet": [at.x, at.y],
		"room": _room,
		"level": level,
		"attrs": {"turn": str(turn)} if turn != 0 else {},
	}
	if not props.has_method("spawn_trap_unit"):
		return null
	var node: Node = props.spawn_trap_unit(row)
	if node != null:
		node.set("fraction", fraction)
	return node


## objs.xml hturret2: a UnitTurret with cid hidden2, asleep until the alarm.
## Made on the current scene like any run-time unit, so land_memory saves it.
func _create_turret(at: Vector2) -> Node:
	var made: Dictionary = _Spawn._make_unit("hturret2", "", {}, float(level))
	var host := get_tree().current_scene
	if made.is_empty() or _Registry.unit_row(str(made.id)).is_empty() or host == null or not props.has_method("_rank_unit"):
		res = "damshot"
		_set_damager()
		return _damager
	var unit := _Enemy.instantiate() as CharacterBody2D
	var unit_id := str(made.id)
	unit.set_meta("unit_id", unit_id)
	unit.name = unit_id
	unit.add_to_group(unit_id)
	unit.set_meta("level", level)
	unit.set_meta("hero", 0)
	unit.set_meta("tr", int(made.get("tr", 0)))
	unit.set_meta("hidden", str(made.get("hidden", 2)))
	unit.position = at
	host.add_child(unit)
	unit.global_position = at
	props.call("_rank_unit", unit, level, 0, 1.0)
	unit.set("fraction", fraction)
	return unit


# --- UnitDamager ---

func _set_weapon(attrs: Dictionary) -> void:
	if _tip == 1:
		if _tr == "0":
			_tr = str(randi_range(1, 5))
		var wid: String = GUNS[int(_tr)] if _tr.is_valid_int() and int(_tr) >= 1 and int(_tr) <= 5 else _tr
		_weap = _weapon(wid)
		if _weap.is_empty():
			_weap = _weapon("lshot")
		_kolammo = int(_weap.get("mag", 1))
		_och = int(SATS_QUE.get(str(_weap.get("id", "")), 1))
		if _och > 1:
			_och *= 2
		if _kolammo == 1:
			_kolammo = 3
	elif _tip == 2:
		_weap = _weapon("hgren" if _tr == "0" else _tr)
		if _weap.is_empty():
			_weap = _weapon("hgren")
		_kolammo = 3
		_och = 3
	else:
		_expl_damage = EXPL1.damage
		_kolammo = 1
	if attrs.has("kolammo"):
		_kolammo = int(float(str(attrs.kolammo)))
	if attrs.has("och"):
		_och = int(float(str(attrs.och)))
	if attrs.has("expl"):
		_expl_damage = float(str(attrs.expl))
	if not _weap.is_empty():
		var k := 1.0 + float(level) * 0.05
		_weap["damage"] = float(_weap.get("damage", 0.0)) * k
		_weap["damage_expl"] = float(_weap.get("damage_expl", 0.0)) * k
		if str(_weap.get("kind", "")) == "explosives":
			_weap["rapid"] = 1


func activate() -> void:
	if status != 0 or dead:
		return
	if _tip == 3:
		_i_expl()
		_kolammo = 0
		_dam_disarm()
		return
	status = 1
	_noch = 0
	_t_attack = 0
	_set_vis(true)
	refresh_use()


func _dam_control() -> void:
	if status == 2 or _kolammo <= 0:
		return
	if _is_shoot:
		_noch += 1
		_kolammo -= 1
		if _noch >= _och:
			status = 0
			refresh_use()
		_is_shoot = false
		if _kolammo <= 0:
			_dam_disarm()
			return
	if status == 1:
		if _tip == 2:
			_cel = global_position + Vector2(randf() * 80.0 - 40.0, 0.0)
		else:
			_cel = global_position + Vector2(200.0 * facing, -size.y * 0.5)
		_attack()


func _attack() -> void:
	if _t_attack > 0:
		_t_attack -= 1
		return
	_t_attack = maxi(1, int(_weap.get("rapid", 1))) - 1
	_is_shoot = true
	var muzzle := _muzzle()
	var pellets := maxi(1, int(_weap.get("pellets", 1)))
	for i in pellets:
		_shoot(muzzle)


## Unit.weaponY is half the height up; the gun's clip gives the muzzle (emit).
func _muzzle() -> Vector2:
	var grip := global_position + Vector2(0.0, -size.y * 0.5)
	if _tip == 2:
		return grip
	if _gun != null:
		var emit := _WeaponVis.emit(str(_weap.get("id", "")))
		return grip + Vector2(emit.x * facing, emit.y)
	return grip + Vector2(facing * size.x * 0.5, 0.0)


func _shoot(muzzle: Vector2) -> void:
	var host := get_tree().current_scene
	if host == null:
		return
	var b := _Bullet.instantiate() as Area2D
	var thrown := str(_weap.get("kind", "")) == "explosives" or str(_weap.get("delivery", "")) == "grenade"
	var speed := maxf(float(_weap.get("speed", 12.0)) * TPS, 40.0)
	var blast := float(_weap.get("radius", 0.0))
	var dam := float(_weap.get("damage", 1.0))
	if thrown:
		dam = float(_weap.get("damage_expl", dam))
	var dir := (_cel - muzzle).normalized() if _cel.distance_squared_to(muzzle) > 1.0 else Vector2(facing, 0.0)
	var spread := float(_weap.get("spread", 0.0))
	if spread > 0.0:
		dir = dir.rotated(deg_to_rad((randf() - 0.5) * spread))
	b.global_position = muzzle
	b.from_player = false
	b.fraction = fraction
	b.speed = speed
	b.damage = maxi(1, int(round(dam)))
	b.damage_type = str(_weap.get("damage_type", "DAM_PIERCE"))
	b.block_damage = _Block.of(str(_weap.get("id", "")))
	b.dop_effect = str(_weap.get("dop_effect", ""))
	b.dop_damage = float(_weap.get("dop_damage", 0.0))
	b.dop_chance = float(_weap.get("dop_chance", 1.0))
	if thrown:
		# The bundle points down (rot HALF_PI) and lets its grenades fall, detTime 45.
		b.use_velocity = true
		b.fall_accel = 900.0
		b.velocity = Vector2(_cel.x - muzzle.x, 60.0) if _tip == 2 else dir * speed
		b.direction = b.velocity.normalized()
		b.lifetime = 45.0 / TPS
		b.blast_radius = blast
		b.explode_on_timeout = blast > 0.0
	else:
		b.direction = dir
		if blast > 0.0:
			b.blast_radius = blast
	b.weapon_id = str(_weap.get("id", ""))
	host.add_child(b)


func _dam_disarm() -> void:
	var at := _muzzle()
	if _tip == 1:
		_spill("frag", 1, at)
		var ammo := str(_weap.get("ammo", ""))
		if _kolammo > 0 and ammo != "":
			_spill(ammo, _kolammo, at)
	elif _tip == 2 and _kolammo > 0:
		for i in 3:
			_spill(str(_weap.get("id", "hgren")), 1, at)
	elif _tip == 3 and _kolammo > 0 and props != null and props.has_method("_spill"):
		for drop_v in preload("res://scripts/loot_roll.gd").roll("bomb"):
			if drop_v is Dictionary:
				_spill(str(drop_v.get("id", "")), int(drop_v.get("n", 1)), global_position + Vector2(0.0, -20.0))
	_remove()


## Bullet.iExpl: the bundle goes off with all its grenades; a charge at 250.
func _i_expl() -> void:
	var damage := _expl_damage
	var destroy: int = EXPL1.destroy
	var radius: float = EXPL1.radius
	if _tip == 2:
		damage = float(_weap.get("damage_expl", 110.0)) * float(_kolammo)
		destroy = _Block.of(str(_weap.get("id", "hgren")))
		radius = float(_weap.get("radius", 250.0))
	var host := get_tree().current_scene
	if host == null or damage <= 0.0:
		return
	var b := _Bullet.instantiate() as Area2D
	b.from_player = false
	b.fraction = fraction
	b.damage = maxi(1, int(round(damage)))
	b.damage_type = "DAM_EXPLOSION"
	b.block_damage = destroy
	b.blast_radius = radius
	b.explode_on_timeout = true
	b.use_velocity = true
	b.velocity = Vector2.ZERO
	b.speed = 0.0
	b.lifetime = 0.02
	b.style = "grenade"
	b.weapon_id = str(_weap.get("id", "")) if _tip == 2 else ""
	host.add_child(b)
	b.global_position = global_position + Vector2(0.0, -size.y * 0.5)


# --- UnitTrap ---

func _trap_control() -> void:
	if _snapped or held or _player_busy() or _ai_n % 5 != 0:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var me := _rect_of(self)
	if player != null and fraction != F_PLAYER and not GameState.is_dead() and GameState.activate_trap() > 1.0:
		if me.intersects(_rect_of(player)):
			player.call("take_hit", int(round(_damage)), "DAM_BITE")
			_klac(true)
			return
	for node in get_tree().get_nodes_in_group("enemies"):
		var unit := node as Node2D
		if unit == null or not _unit_meets(unit) or int(unit.get("fraction")) == 0 or _act_trap(unit) <= 1:
			continue
		if me.intersects(_rect_of(unit)) and unit.has_method("take_hit"):
			unit.call("take_hit", int(round(_damage)), "DAM_BITE")
			_klac(true)
			return


## klac: the jaws shut. Caught on something, they also take 35 internal damage.
func _klac(caught: bool) -> void:
	_snapped = true
	set_meta("dead", true)
	SfxBank.play("trap_a")
	_play(0, SNAP_END, SNAP_END)
	refresh_use()
	if caught:
		_set_vis(true)
		take_hit(35, "DAM_INTERNAL")


## disarm: an armed trap is sprung; a sprung one is set again for the player.
func _trap_use() -> void:
	if not _snapped:
		_klac(false)
		return
	_snapped = false
	_rearm = true
	fraction = F_PLAYER
	set_meta("dead", false)
	SfxBank.play("trap_reload")
	_play(REARM_FROM, REARM_END, 0)
	refresh_use()


## Unit gravity once telekinesis has moved the trap; it rests where it was set.
func _fall_step() -> void:
	if held:
		_lifted = true
		_fall_v = 0.0
		return
	if not _lifted:
		return
	if test_move(global_transform, Vector2(0.0, 1.0)):
		_fall_v = 0.0
		return
	_fall_v = minf(_fall_v + 1.0, 20.0)
	move_and_collide(Vector2(0.0, _fall_v))


# --- shared ---

func _die() -> void:
	if dead:
		return
	dead = true
	match kind:
		"trig":
			if status == 0:
				_trig_activate()
		"dam":
			if (_tip == 2 or _tip == 3) and _kolammo > 0:
				_i_expl()
			if _tip == 1:
				_spill("frag", 1, _muzzle())
	if not die_actions.is_empty() and props != null and props.has_method("run_actions"):
		props.run_actions(die_actions, "", self)
	_remove()


func _remove() -> void:
	dead = true
	status = 2
	set_meta("usable", false)
	set_physics_process(false)
	queue_free()


## setVis: alpha 0.1 while unseen. A bear trap can be lifted only once seen.
func _set_vis(v: bool) -> void:
	is_vis = v
	modulate.a = 1.0 if v else 0.1
	if kind == "trap":
		set_meta("levit_poss", v)
		if v:
			add_to_group("levitatable")
		else:
			remove_from_group("levitatable")
	refresh_use()


## UnitPlayer.lookInvis: in sight within visibility * visiTrap.
func _look_invis() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return false
	var eye := player.global_position + Vector2(0.0, -30.0)
	var spot := global_position + Vector2(0.0, -size.y * 0.5)
	var reach := VISIBILITY * GameState.visi_trap()
	if eye.distance_squared_to(spot) > reach * reach:
		return false
	var query := PhysicsRayQueryParameters2D.create(eye, spot, 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## Unit.budilo: units of the trap's fraction inside rad * their ear come to look.
func _budilo(rad: float) -> void:
	var robot := bool(UNITS[id].get("robot", false))
	for node in get_tree().get_nodes_in_group("enemies"):
		if not node.has_method("_alarm_from") or int(node.get("fraction")) != fraction:
			continue
		if node.get("_dead") == true or node.get("_downed") == true:
			continue
		var reach := rad
		if not (robot and node.has_method("_is_machine") and bool(node.call("_is_machine"))):
			var ear: Variant = node.get("_ear")
			reach = rad * (float(ear) if ear != null else 1.0)
		if (node as Node2D).global_position.distance_squared_to(global_position) < reach * reach:
			node.call("_alarm_from", global_position)


func _brain_command(unit: Node, com: String) -> void:
	var brain: Variant = unit.get("_brain")
	if brain != null and brain.has_method("command"):
		brain.command(com, "")


func _unit_meets(unit: Node2D) -> bool:
	if unit.get("_dead") == true or unit.get("_downed") == true:
		return false
	return int(unit.get("fraction")) != fraction


## Unit acttrap: 0 never, 1 only traps the player set, 2 any.
func _act_trap(unit: Node) -> int:
	var row := _Registry.unit_row(str(unit.get_meta("unit_id", "")))
	var param: Variant = row.get("param", {})
	if param is Dictionary and (param as Dictionary).has("acttrap"):
		return int(float(str(param.acttrap)))
	return 2


func _stands(unit: Node) -> bool:
	return unit is CharacterBody2D and (unit as CharacterBody2D).is_on_floor()


func _rect_of(node: Node2D) -> Rect2:
	if node == self:
		return Rect2(global_position.x - size.x * 0.5, global_position.y - size.y, size.x, size.y)
	var body: Variant = node.get("body_size")
	if body is Vector2:
		var b := body as Vector2
		return Rect2(node.global_position.x - b.x * 0.5, node.global_position.y - b.y, b.x, b.y)
	for child in node.get_children():
		var cs := child as CollisionShape2D
		if cs == null or cs.disabled or cs.shape == null:
			continue
		var r := cs.shape.get_rect()
		r.position += cs.global_position
		return r
	return Rect2(node.global_position - Vector2(15.0, 40.0), Vector2(30.0, 40.0))


func _solid(at: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = at
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return not get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()


func _player_busy() -> bool:
	var player := get_tree().get_first_node_in_group("player")
	return player != null and player.get("_use_node") == self


func _alive(node: Variant) -> bool:
	return is_instance_valid(node) and not (node as Node).is_queued_for_deletion() and node.get("_dead") != true and node.get("dead") != true


func _spill(item: String, n: int, at: Vector2) -> void:
	if props != null and props.has_method("_spill"):
		props.call("_spill", item, n, at)


func _notice(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notice"):
		hud.show_notice(text)


static func _weapon(wid: String) -> Dictionary:
	if _weapons.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/weapons.json"))
		if parsed is Dictionary:
			for w_v in (parsed as Dictionary).get("weapons", []):
				if w_v is Dictionary:
					_weapons[str(w_v.get("id", ""))] = w_v
	var w: Variant = _weapons.get(wid)
	return (w as Dictionary).duplicate() if w is Dictionary else {}


# --- vis: pfe.swf vis<id> sheets, origin at the unit's feet ---

## A wall gun also shows its weapon's clip at weaponY (UnitDamager setVis).
func _make_vis() -> void:
	_sheet = _sheet_rec(id)
	if _sheet.is_empty():
		return
	var tex := load(SHEETS + str(_sheet.sheet)) as Texture2D
	if tex == null:
		_sheet = {}
		return
	var anchor: Array = _sheet.anchor
	_vis = Sprite2D.new()
	_vis.name = "Vis"
	_vis.texture = tex
	_vis.centered = false
	_vis.region_enabled = true
	_vis.offset = -Vector2(float(anchor[0]), float(anchor[1]))
	_vis.scale.x = facing
	add_child(_vis)
	if kind == "dam" and _tip == 1:
		_gun = Sprite2D.new()
		_gun.name = "Gun"
		if _WeaponVis.dress(_gun, str(_weap.get("id", ""))):
			_gun.position = Vector2(0.0, -size.y * 0.5)
			_gun.scale.x = facing
			add_child(_gun)
		else:
			_gun.free()
			_gun = null
	_show_status()
	_show_frame()


## setStatus: the trigger clip shows frame status + 1.
func _show_status() -> void:
	if kind == "trig":
		_set_frame(status)


func _set_frame(at: int) -> void:
	_frame = at
	_play_to = -1
	_show_frame()


func _play(from: int, to: int, end: int) -> void:
	_frame = from
	_play_to = to
	_play_end = end
	_show_frame()


func _tick_anim() -> void:
	if _play_to < 0:
		return
	_frame += 1
	if _frame >= _play_to:
		_frame = _play_end
		_play_to = -1
	_show_frame()


func _show_frame() -> void:
	if _vis == null:
		return
	var frames: Array = _sheet.clips.all.frames
	var cell: Array = _sheet.cell
	var cols := maxi(1, int(_sheet.cols))
	var idx := int(frames[clampi(_frame, 0, frames.size() - 1)])
	var w := float(cell[0])
	var h := float(cell[1])
	_vis.region_rect = Rect2(float(idx % cols) * w, float(idx / cols) * h, w, h)


static func _sheet_rec(unit_id: String) -> Dictionary:
	if _manifest.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SHEETS + "manifest.json"))
		if parsed is Dictionary:
			_manifest = parsed
	var rec: Variant = _manifest.get(unit_id)
	return rec if rec is Dictionary else {}
