extends Node

## Location.recalcWater: a wall tile above the room's waterLevel that breaks
## is queued; once a tick each queued open tile fills when the tiles below,
## left and right are solid or water and one of left, right or above is water,
## else the water left, right and above it drains and is queued in turn.
## Rows from waterLevel down never change. The changed tiles are the land
## flag "water" ("x,y" world tile -> 0 / 1 against the built rooms), so the
## land memory keeps them; the room's water art and opacWater follow.

const TILE := 40.0
const COLS := 48
const ROWS := 25
const TPS := 30.0
const FLAG := "water"
const _Flags := preload("res://scripts/map/room_flags.gd")
const _Look := preload("res://scripts/map/room_look.gd")

var props: Node
var land: Node2D
var _queue: Array[Vector2i] = []
var _delta: Dictionary = {}
var _walls: Array = []
var _acc := 0.0


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
	var mask: PackedByteArray = _Flags.env_at(at, host).get("wmask", PackedByteArray())
	if mask.is_empty():
		return
	var flow := of(owner_props)
	if flow != null:
		flow.call("enqueue", Vector2i(floori(at.x / TILE), floori(at.y / TILE)))


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
		if env.has("wmask0"):
			env["wmask"] = (env.wmask0 as PackedByteArray).duplicate()
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


static func _write(env: Dictionary, t: Vector2i, water: int) -> void:
	var mask: PackedByteArray = env.get("wmask", PackedByteArray())
	if mask.is_empty():
		return
	if not env.has("wmask0"):
		env["wmask0"] = mask.duplicate()
	var i := posmod(t.x, COLS)
	var j := posmod(t.y, ROWS)
	mask[j * COLS + i] = water
	env["wmask"] = mask


func _ready() -> void:
	var solids := land.get_node_or_null("Solids")
	if solids:
		for child in solids.get_children():
			if child.has_method("solid_at"):
				_walls.append(child)


func _physics_process(delta: float) -> void:
	if _queue.is_empty():
		_acc = 0.0
		return
	_acc += delta * TPS
	if _acc < 1.0:
		return
	_acc = 0.0
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
	var base: PackedByteArray = env.get("wmask0", PackedByteArray())
	var i := posmod(t.y, ROWS) * COLS + posmod(t.x, COLS)
	if not base.is_empty() and base[i] == water:
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
	var mask: PackedByteArray = _env(t).get("wmask", PackedByteArray())
	return not mask.is_empty() and mask[posmod(t.y, ROWS) * COLS + posmod(t.x, COLS)] == 1


## Tile.collision 1: a live wall cell, else a closed door or other static body.
## Outside the rooms (Location.defaultTile) counts as solid.
func _solid(t: Vector2i) -> bool:
	if _env(t).is_empty():
		return true
	var at := (Vector2(t) + Vector2(0.5, 0.5)) * TILE
	for wall in _walls:
		if is_instance_valid(wall) and wall.covers(at):
			return wall.solid_at(at)
	var q := PhysicsPointQueryParameters2D.new()
	q.position = at
	q.collision_mask = 1
	for hit in land.get_world_2d().direct_space_state.intersect_point(q, 8):
		var body: Object = hit.get("collider")
		if (body is StaticBody2D or body is AnimatableBody2D) and not body.has_method("solid_at"):
			return true
	return false
