extends Node

## Location.recalcWater: a wall tile above the room's waterLevel that breaks
## is queued; once a tick each queued open tile fills when the tiles below,
## left and right are solid or water and one of left, right or above is water,
## else the water left, right and above it drains and is queued in turn.
## Rows from waterLevel down never change. The changed tiles are the land
## flag "water" ("x,y" world tile -> 0 / 1 against the built rooms), so the
## land memory keeps them; the room's water art and opacWater follow.
## Water and wall / door solids live on the room grid (room_grid.gd). An
## opened or broken door wakes the water like a broken wall (PORT_RULES "World").

const TILE := 40.0
const COLS := 48
const ROWS := 25
const FLAG := "water"
const _Flags := preload("res://scripts/map/room_flags.gd")
const _Look := preload("res://scripts/map/room_look.gd")
const _Grid := preload("res://scripts/map/room_grid.gd")

var props: Node
var land: Node2D
var _queue: Array[Vector2i] = []
var _delta: Dictionary = {}
## Physics frame of the last fill. Extra sim steps in that frame are dropped.
var _flow_frame := -1


static func of(owner_props: Node) -> Node:
	var host := owner_props.get_parent() as Node2D
	if host == null:
		return null
	var node := host.get_node_or_null("WaterFlow")
	if node == null:
		node = (load("res://scripts/map/water_flow.gd") as GDScript).new()
		node.name = "WaterFlow"
		node.set("props", owner_props)
		node.set("land", host)
		node.set("_delta", (owner_props.call("flag", FLAG, {}) as Dictionary).duplicate())
		host.add_child(node)
	return node


func enqueue(t: Vector2i) -> void:
	_queue.append(t)


## land_props.note_broken: the wall cell in rect is open now.
static func broke(owner_props: Node, rect: Rect2) -> void:
	var at := rect.get_center()
	var host := owner_props.get_parent()
	forget_solids(host)
	if not _Grid.has_water(_Flags.env_at(at, host)):
		return
	var flow := of(owner_props)
	if flow != null:
		flow.call("enqueue", Vector2i(floori(at.x / TILE), floori(at.y / TILE)))


## An opened or broken door: its tiles drain like a broken wall.
static func door_opened(owner_props: Node, body: Node2D) -> void:
	var host := owner_props.get_parent()
	forget_solids(host)
	var size := Vector2(float(body.get_meta("door_w", TILE)), float(body.get_meta("door_h", TILE * 2.0)))
	var rect := Rect2(body.global_position, size)
	var flow: Node = null
	var x := floori(rect.position.x / TILE)
	while float(x) * TILE < rect.end.x:
		var y := floori(rect.position.y / TILE)
		while float(y) * TILE < rect.end.y:
			var at := (Vector2(x, y) + Vector2(0.5, 0.5)) * TILE
			if _Grid.has_water(_Flags.env_at(at, host)):
				if flow == null:
					flow = of(owner_props)
				if flow != null:
					flow.call("enqueue", Vector2i(x, y))
			y += 1
		x += 1


## A wall or door changed: the grid solids of every room refill on next use.
static func forget_solids(host: Node) -> void:
	if host == null or not host.has_meta(_Flags.META):
		return
	var envs: Dictionary = host.get_meta(_Flags.META)
	for key in envs:
		_Grid.forget_solid(envs[key])


## A built or reloaded land: put the saved fills and drains back on its rooms.
static func restore(owner_props: Node) -> void:
	var host := owner_props.get_parent() as Node2D
	if host == null or not host.has_meta(_Flags.META):
		return
	var saved: Dictionary = owner_props.call("flag", FLAG, {})
	var envs: Dictionary = host.get_meta(_Flags.META)
	var rooms := {}
	for key in envs:
		var env: Dictionary = envs[key]
		_Grid.forget_solid(env)
		if _Grid.reset_water(env):
			rooms[key] = true
	var cells: Array = []
	for key in saved:
		var parts := str(key).split(",")
		if parts.size() < 2:
			continue
		var t := Vector2i(int(parts[0]), int(parts[1]))
		var room := Vector2i(floori(float(t.x) / COLS), floori(float(t.y) / ROWS))
		if not envs.has(room):
			continue
		_write(envs[room], t, int(saved[key]))
		rooms[room] = true
		cells.append(Vector3i(t.x, t.y, int(saved[key])))
	for room in rooms:
		_Look.redraw_water(host, room, envs[room])
	if not cells.is_empty() and host.is_inside_tree():
		var wopac := 0.0
		for room in rooms:
			wopac = maxf(wopac, float((envs[room] as Dictionary).get("wopac", 0.0)))
		host.get_tree().call_group("fog", "water_changed", host, cells, wopac)
	var flow := host.get_node_or_null("WaterFlow")
	if flow != null:
		flow.set("_delta", saved.duplicate())


## water is the saved 0 / 1 of a tile.
static func _write(env: Dictionary, t: Vector2i, water: int) -> void:
	_Grid.set_water(env, posmod(t.x, COLS), posmod(t.y, ROWS), _Grid.FULL if water != 0 else 0)


func _ready() -> void:
	Sim.register(Sim.Phase.WORLD, _sim_tick)


func _exit_tree() -> void:
	if is_instance_valid(Sim):
		Sim.unregister(_sim_tick)


## One fill per physics frame. A catch-up of several sim steps drops the rest,
## which is what the old accumulator did when it zeroed itself.
func _sim_tick() -> void:
	if _queue.is_empty():
		return
	var frame := Engine.get_physics_frames()
	if frame == _flow_frame:
		return
	_flow_frame = frame
	_recalc()


func _recalc() -> void:
	var rec := _queue
	_queue = []
	var changed := {}
	for t in rec:
		var env := _env(t)
		if env.is_empty() or posmod(t.y, ROWS) >= int(env.get("water", 100)) or _solid(t):
			continue
		var tl := t + Vector2i(-1, 0)
		var tr := t + Vector2i(1, 0)
		var tt := t + Vector2i(0, -1)
		var tb := t + Vector2i(0, 1)
		if (_solid(tb) or _wet(tb)) and (_solid(tr) or _wet(tr)) and (_solid(tl) or _wet(tl)) \
				and (_wet(tl) or _wet(tr) or _wet(tt)):
			if not _wet(t):
				_put(t, 1, changed)
		else:
			for n in [tl, tr, tt]:
				if _wet(n):
					_put(n, 0, changed)
					_queue.append(n)
	if changed.is_empty():
		return
	var cells: Array = []
	var wopac := 0.0
	for room in changed:
		var env: Dictionary = _Flags.envs(land).get(room, {})
		_Look.redraw_water(land, room, env)
		wopac = maxf(wopac, float(env.get("wopac", 0.0)))
		cells.append_array(changed[room])
	get_tree().call_group("fog", "water_changed", land, cells, wopac)
	props.call("set_flag", FLAG, _delta.duplicate())


func _put(t: Vector2i, water: int, changed: Dictionary) -> void:
	var env := _env(t)
	_write(env, t, water)
	var key := "%d,%d" % [t.x, t.y]
	if _Grid.is_built_water(env, posmod(t.x, COLS), posmod(t.y, ROWS), _Grid.FULL if water != 0 else 0):
		_delta.erase(key)
	else:
		_delta[key] = water
	var room := Vector2i(floori(float(t.x) / COLS), floori(float(t.y) / ROWS))
	if not changed.has(room):
		changed[room] = []
	(changed[room] as Array).append(Vector3i(t.x, t.y, water))


func _env(t: Vector2i) -> Dictionary:
	return _Flags.envs(land).get(Vector2i(floori(float(t.x) / COLS), floori(float(t.y) / ROWS)), {})


func _wet(t: Vector2i) -> bool:
	return _Grid.wet(_env(t), posmod(t.x, COLS), posmod(t.y, ROWS))


## Tile.collision 1: a live wall cell or closed door (the grid), else another
## static body asked live (crates and lifts move).
## Outside the rooms (Location.defaultTile) counts as solid.
func _solid(t: Vector2i) -> bool:
	var env := _env(t)
	if env.is_empty():
		return true
	var room := Vector2i(floori(float(t.x) / COLS), floori(float(t.y) / ROWS))
	var cell := _Grid.solid(env, land, props, room, posmod(t.x, COLS), posmod(t.y, ROWS))
	if cell != _Grid.FREE:
		return cell == _Grid.SOLID
	var at := (Vector2(t) + Vector2(0.5, 0.5)) * TILE
	var q := PhysicsPointQueryParameters2D.new()
	q.position = at
	q.collision_mask = 1
	for hit in land.get_world_2d().direct_space_state.intersect_point(q, 8):
		var body: Object = hit.get("collider")
		if (body is StaticBody2D or body is AnimatableBody2D) and not body.has_method("solid_at"):
			return true
	return false
