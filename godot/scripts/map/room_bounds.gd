extends Node2D

## Seamless rooms (port deviation; the original simulates only the active
## Location). Bodies cross room edges freely and this node keeps the room
## bookkeeping in step:
## - room_x / room_y metas follow units, corpses, drops and boxes into the room
##   they are in now (room_changed fires), so room lookups, saves and AI agree;
## - the player's room and its 8 neighbours run, anything further away freezes
##   (drops, boxes, bodies; units sleep on their own in enemy.gd) and wakes when
##   the player comes near; shots that leave the running rooms are dropped;
## - the land has no room past a missing neighbour. Sides and tops facing one
##   get a wall (Land.gotoLoc returns null there). Falling through a bottom with
##   no room is Land.gotoLoc {die:true} for the player and Unit.outLoc for the
##   rest: outside @bezdna rooms a live unit that can jump springs back up,
##   anything else is removed. Flying or levitated units are held at the edge.

signal room_changed(node: Node, from: Vector2i, to: Vector2i)

const FogScript := preload("res://scripts/fog.gd")
const _Flags := preload("res://scripts/map/room_flags.gd")

const ROOM_W := 1920.0
const ROOM_H := 1000.0
const ACTIVE_REACH := 1
## enemy.gd CHASE_REACH: a chaser one room past the running set still shoots.
const SHOT_REACH := 2
const EDGE := 40.0
const TICK := 0.1

enum Kind { NONE, UNIT, LOOT, BOX, BODY }

var _rooms := {}
var _tracked := {}
var _fresh: Array[Node] = []
var _actors: Node
var _acc := 0.0
var _player: Node2D
var _player_room := Vector2i(-99999, -99999)
var _player_safe := Vector2.ZERO
var _fell := false


## actors is land_props. rooms is its bound room rows, empty for the stable.
func setup(actors: Node, rooms: Array) -> void:
	_actors = actors
	name = "RoomBounds"
	var rows := rooms
	if rows.is_empty():
		rows = FogScript.begin_rooms()
	for room_v in rows:
		var room: Dictionary = room_v
		_rooms[Vector2i(int(room.get("x", 0)), int(room.get("y", 0)))] = true
	_build_edges()
	actors.child_entered_tree.connect(_on_child)
	for child in actors.get_children():
		_fresh.append(child)


static func room_of(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x / ROOM_W), floori(at.y / ROOM_H))


## The player's room and the 8 around it simulate. A back room (same x,
## y + back_band) is treated as the front room's neighbour. Back rooms and
## trial rooms sit in rows under the map; they are separate locations, so
## they never wake their row neighbours and are not woken by them.
func is_active(key: Vector2i) -> bool:
	if key == _player_room:
		return true
	var band := int(get_parent().get_meta("back_band", 0)) if get_parent() != null else 0
	if band > 0 and key.x == _player_room.x and absi(key.y - _player_room.y) == band:
		return true
	if _apart(key) or _apart(_player_room):
		return false
	return absi(key.x - _player_room.x) <= ACTIVE_REACH and absi(key.y - _player_room.y) <= ACTIVE_REACH


func _apart(key: Vector2i) -> bool:
	var host := get_parent()
	if host == null:
		return false
	var band := int(host.get_meta("back_band", 0))
	if band > 0 and key.y >= band and key.y < band * 2:
		return true
	return host.has_meta("trial_row") and key.y == int(host.get_meta("trial_row"))


func _build_edges() -> void:
	var dirs := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]
	for key_v in _rooms:
		var key: Vector2i = key_v
		var origin := Vector2(key.x * ROOM_W, key.y * ROOM_H)
		for dir_v in dirs:
			var dir: Vector2i = dir_v
			if _rooms.has(key + dir):
				continue
			var rect: Rect2
			match dir:
				Vector2i.LEFT:
					rect = Rect2(origin + Vector2(-EDGE, 0.0), Vector2(EDGE, ROOM_H))
				Vector2i.RIGHT:
					rect = Rect2(origin + Vector2(ROOM_W, 0.0), Vector2(EDGE, ROOM_H))
				_:
					rect = Rect2(origin + Vector2(0.0, -EDGE), Vector2(ROOM_W, EDGE))
			_add_edge(rect)


func _add_edge(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.name = "Edge"
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = rect.position
	body.set_meta("blocks_sight", true)
	body.set_meta("land_edge", true)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.size * 0.5
	body.add_child(shape)
	add_child(body)


func _on_child(node: Node) -> void:
	_fresh.append(node)


func _physics_process(delta: float) -> void:
	if GameState.paused:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return
	_check_player()
	_acc += delta
	if _acc < TICK:
		return
	_acc = 0.0
	_classify()
	_sweep()
	_check_shots()


func _check_player() -> void:
	var at := _player.global_position
	var key := room_of(at)
	if _rooms.has(key):
		_player_safe = at
		_fell = false
		_player_room = key
		return
	if _fell or _player_safe == Vector2.ZERO:
		return
	if key.y > room_of(_player_safe).y:
		_fell = true
		GameState.apply_damage(1000000, "DAM_INTERNAL")
		return
	_player.global_position = _player_safe
	if "velocity" in _player:
		_player.set("velocity", Vector2.ZERO)


func _classify() -> void:
	if _fresh.is_empty():
		return
	for node in _fresh:
		if not is_instance_valid(node) or node == self:
			continue
		var kind := _kind_of(node)
		if kind != Kind.NONE:
			_tracked[node] = kind
	_fresh.clear()


func _kind_of(node: Node) -> int:
	if not node is Node2D:
		return Kind.NONE
	if node.is_in_group("ground_loot"):
		return Kind.LOOT
	if node.is_in_group("floor_box"):
		return Kind.BOX
	if node is CharacterBody2D and node.has_method("is_alert"):
		return Kind.UNIT
	if node.is_in_group("levitatable"):
		return Kind.BODY
	return Kind.NONE


func _sweep() -> void:
	var gone: Array = []
	for node_v in _tracked:
		if not is_instance_valid(node_v):
			gone.append(node_v)
			continue
		var node := node_v as Node2D
		if node.is_queued_for_deletion():
			gone.append(node_v)
			continue
		var at := node.global_position
		var key := room_of(at)
		if not _rooms.has(key):
			if _out_of_land(node, int(_tracked[node_v])):
				gone.append(node_v)
			continue
		node.set_meta("room_safe", at)
		var was := Vector2i(int(node.get_meta("room_x", key.x)), int(node.get_meta("room_y", key.y)))
		if was != key:
			node.set_meta("room_x", key.x)
			node.set_meta("room_y", key.y)
			room_changed.emit(node, was, key)
		_freeze(node, int(_tracked[node_v]), not is_active(key))
	for node in gone:
		_tracked.erase(node)


## True when the body was removed.
func _out_of_land(node: Node2D, kind: int) -> bool:
	if kind == Kind.UNIT and not bool(node.get("_dead")):
		if bool(node.get("_flying")) or bool(node.get("levitated")):
			_hold_back(node)
			return false
		if _bounce(node):
			return false
	elif _is_held(node):
		_hold_back(node)
		return false
	node.set_meta("fell_out", true)
	node.queue_free()
	return true


## Unit.outLoc DOWN outside @bezdna rooms: a unit that can jump springs back
## up (velocity.Y = -jumpdy, velocity.X = storona * maxSpeed).
func _bounce(node: Node2D) -> bool:
	var safe: Variant = node.get_meta("room_safe", null)
	if not safe is Vector2 or room_of(node.global_position).y <= room_of(safe).y:
		return false
	if bool(_Flags.env_at(safe).get("bezdna", false)):
		return false
	var brain: Variant = node.get("_brain")
	var jumpdy := float(brain.get("jumpdy")) if brain != null else float(node.get("_jump_tick"))
	if jumpdy <= 0.0:
		return false
	var speed := float(brain.get("max_speed")) * 30.0 if brain != null else float(node.get("move_speed"))
	node.global_position = safe
	node.set("velocity", Vector2(float(node.get("facing")) * speed, -jumpdy * 30.0))
	return true


func _hold_back(node: Node2D) -> void:
	var safe: Variant = node.get_meta("room_safe", null)
	if safe is Vector2:
		node.global_position = safe
	if "velocity" in node:
		node.set("velocity", Vector2.ZERO)


func _is_held(node: Node) -> bool:
	return bool(node.get("held")) if "held" in node else false


func _freeze(node: Node2D, kind: int, frozen: bool) -> void:
	if frozen and _is_held(node):
		frozen = false
	var was := bool(node.get_meta("frozen", false))
	if was == frozen:
		return
	match kind:
		Kind.UNIT:
			# Live units sleep and wake in enemy.gd. Corpses still fall and slide.
			if not bool(node.get("_dead")):
				return
			node.set_physics_process(not frozen)
		Kind.LOOT, Kind.BODY:
			node.set_physics_process(not frozen)
		Kind.BOX:
			# Out of the physics space too: a land holds hundreds of crates.
			node.process_mode = Node.PROCESS_MODE_DISABLED if frozen else Node.PROCESS_MODE_INHERIT
	node.set_meta("frozen", frozen)


## Bullet.as / PhisBullet.as die outside the Location. Here a shot dies once it
## is outside the land or past the rooms that run (chasers included).
func _check_shots() -> void:
	for group in ["player_bullets", "enemy_bullets"]:
		for shot in get_tree().get_nodes_in_group(group):
			if not shot is Node2D or shot.is_queued_for_deletion():
				continue
			var key := room_of((shot as Node2D).global_position)
			if _rooms.has(key) and absi(key.x - _player_room.x) <= SHOT_REACH and absi(key.y - _player_room.y) <= SHOT_REACH:
				continue
			shot.set("_dead", true)
			shot.queue_free()
