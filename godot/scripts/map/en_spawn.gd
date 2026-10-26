extends RefCounted

## Location.enemySpawn and the alarm spawn timer (t_alarmsp). Each room keeps its
## enspawn points and kolEnSpawn, the enemies it may still call in. Spawned units
## go on the current scene, where land_memory.gd adopts and saves them.

const TPS := 30.0
const _Spawn := preload("res://scripts/map/land_spawn.gd")
const _Enemy := preload("res://scenes/enemy.tscn")
const _EmergeGlow := preload("res://scripts/emerge_glow.gd")
const EMERG := 30

var props: Node
## Room key "x,y" -> {points, kol, tip, loc, ctx, t}.
var _rooms: Dictionary = {}
var _acc := 0.0


func _init(host: Node) -> void:
	props = host


## An enspawn row from LandSpawn: its feet and the room's spawn data.
func add_point(row: Dictionary) -> void:
	var room: Array = row.get("room", [0, 0])
	var key := "%d,%d" % [int(room[0]), int(room[1])]
	var info: Dictionary = row.get("spawn", {})
	if not _rooms.has(key):
		_rooms[key] = {
			"points": [],
			"kol": int(props.flag("enspawn|" + key, int(info.get("kol", 0)))),
			"tip": str(info.get("tip", "enl2")),
			"loc": info.get("loc", {}),
			"ctx": info.get("ctx", {}),
			"t": 0,
		}
	var feet: Array = row.get("feet", [0, 0])
	(_rooms[key].points as Array).append(Vector2(float(feet[0]), float(feet[1])))


func left(key: String) -> int:
	return int(_rooms[key].kol) if _rooms.has(key) else 0


## Location.signal(n): the first alarm spawn comes up to n / 4 ticks later.
func signal_room(key: String, n: int = 300) -> void:
	if _rooms.has(key):
		_rooms[key].t = int(float(n) * randf() * 0.25 + 0.25)


func tick(delta: float) -> void:
	_acc += delta * TPS
	var steps := 0
	while _acc >= 1.0 and steps < 4:
		_acc -= 1.0
		steps += 1
		for key in _rooms.keys():
			var rec: Dictionary = _rooms[key]
			if int(rec.t) <= 0:
				continue
			rec.t = int(rec.t) - 1
			if int(rec.t) == 0:
				spawn(str(key), false, false)


## enemySpawn(one, getGG): one enemy at a random enspawn point of the room. Off
## a single trigger (one) the alarm chain does not continue.
func spawn(key: String, one: bool, get_gg: bool) -> Node:
	var rec: Variant = _rooms.get(key)
	if not rec is Dictionary or int(rec.kol) <= 0 or (rec.points as Array).is_empty():
		return null
	rec.kol = int(rec.kol) - 1
	props.set_flag("enspawn|" + key, int(rec.kol))
	if not one:
		rec.t = floori(randf() * 30.0)
	var points: Array = rec.points
	var sp: Vector2 = points[randi() % points.size()]
	var loc: Dictionary = (rec.loc as Dictionary).duplicate()
	if loc.is_empty():
		return null
	# createUnit with abs: never in water.
	loc["water"] = 1 << 20
	var out := {"rows": []}
	_Spawn._create_unit(rec.ctx, loc, str(rec.tip), 0, 0, {}, [], "", out)
	if (out.rows as Array).is_empty():
		return null
	var row: Dictionary = out.rows.back()
	if str(row.get("cat", "")) != "unit" or not bool(row.get("supported", false)):
		return null
	return _make(row, sp, get_gg)


## Location.waveSpawn: a Probation wave obj {id, tr, hero, cid} at enspawn n of
## the room (a random one past the last); fraction 1, alerted, marked wave.
func wave_spawn(key: String, obj: Dictionary, n: int) -> Node:
	var rec: Variant = _rooms.get(key)
	if not rec is Dictionary or (rec.points as Array).is_empty():
		return null
	var points: Array = rec.points
	var sp: Vector2 = points[n] if n < points.size() else points[randi() % points.size()]
	var loc: Dictionary = (rec.loc as Dictionary).duplicate()
	if loc.is_empty():
		return null
	loc["water"] = 1 << 20
	var attrs := {}
	for k in ["tr", "hero"]:
		if str(obj.get(k, "")) != "":
			attrs[k] = str(obj[k])
	var out := {"rows": []}
	_Spawn._create_unit(rec.ctx, loc, str(obj.get("id", "")), 0, 0, attrs, [], str(obj.get("cid", "")), out)
	if (out.rows as Array).is_empty():
		return null
	var row: Dictionary = out.rows.back()
	if str(row.get("cat", "")) != "unit" or not bool(row.get("supported", false)):
		return null
	var unit := _make(row, sp, true)
	if unit != null:
		unit.set_meta("wave", true)
	return unit


func _make(row: Dictionary, at: Vector2, get_gg: bool) -> Node:
	var host := props.get_tree().current_scene
	if host == null:
		return null
	var unit := _Enemy.instantiate() as CharacterBody2D
	var unit_id := str(row.unit_id)
	unit.set_meta("unit_id", unit_id)
	unit.name = unit_id
	unit.add_to_group(unit_id)
	unit.set_meta("level", int(row.get("level", 0)))
	unit.set_meta("hero", int(row.get("hero", 0)))
	unit.set_meta("tr", int(row.get("tr", 0)))
	unit.position = at
	host.add_child(unit)
	unit.global_position = at
	props.call("_rank_unit", unit, int(row.get("level", 0)), int(row.get("hero", 0)), 1.0)
	var player := props.get_tree().get_first_node_in_group("player") as Node2D
	if unit.has_method("_become_alert"):
		unit.call("_become_alert", player.global_position if get_gg and player != null else at)
	_emerge(unit)
	return unit


## Unit.emergence(30): the unit fades in, frozen and glowing, over 30 ticks.
func _emerge(unit: CanvasItem) -> void:
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	var glow: Node = _EmergeGlow.attach_to(unit)
	var show := func(t: float) -> void:
		if not is_instance_valid(unit):
			return
		var tf := floorf(t) / float(EMERG + 1)
		unit.modulate.a = 1.0 - tf
		if is_instance_valid(glow):
			glow.set("tf", tf)
	show.call(float(EMERG))
	var tween := props.create_tween()
	tween.tween_method(show, float(EMERG), 0.0, float(EMERG) / TPS)
	tween.tween_callback(func() -> void:
		if is_instance_valid(glow):
			glow.queue_free()
		if is_instance_valid(unit):
			unit.modulate.a = 1.0
			unit.process_mode = Node.PROCESS_MODE_INHERIT)
