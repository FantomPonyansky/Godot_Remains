extends Node

## Room streaming for generated lands (PORT_RULES.md "World": fixed and story
## lands stay built in full). A room's actors (units, boxes, traps, runtime
## units, drops) are loaded within LOAD_REACH rooms of any player and go into
## land memory beyond UNLOAD_REACH (land_props.unload_room / reload_room).
## Collision, doors and dressing stay built: a generated land is bounded, and
## meshing walls again while walking would cost frames and move wall seams.
## play_land.remesh is there for chained chunks (ARCHITECTURE_PLAN.md R5.6).
## The back or front room behind a player's room counts as near. Rooms
## that run (room_bounds ACTIVE_REACH 1) are always inside LOAD_REACH.

const _Addr := preload("res://scripts/map/room_address.gd")

const LOAD_REACH := 2
const UNLOAD_REACH := 3
const TICK := 0.25
## Nodes freed per tick before the rest waits; rooms whose rows have not
## spawned yet cost nothing. Loads only queue rows, so they are not capped.
const UNLOAD_NODES_PER_TICK := 40

## Off: every room stays loaded (the cmdline user arg nostream turns it off).
static var enabled := true

var paused := false
var _land: Node2D
var _props: Node
var _out := {}
var _t := 0.0
var unloaded_total := 0


static func attach(land: Node2D, props: Node) -> Node:
	if not enabled or "nostream" in OS.get_cmdline_user_args():
		return null
	var node: Node = (load("res://scripts/map/room_stream.gd") as GDScript).new()
	node.name = "RoomStream"
	node._land = land
	node._props = props
	land.add_child(node)
	return node


func is_out(cell: Vector2i) -> bool:
	return _out.has(cell)


func _physics_process(delta: float) -> void:
	if paused or _land == null or not _land.is_inside_tree() or not _land.is_in_group("active_land"):
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = TICK
	tick()


## One streaming pass: load what is near a player, unload some of what is far.
func tick() -> void:
	var near: Array = []
	for p in Run.players():
		if p is Node2D and is_instance_valid(p):
			var at := (p as Node2D).global_position
			near.append(Vector2i(floori(at.x / 1920.0), floori(at.y / 1000.0)))
	if near.is_empty():
		return
	for cell_v in _out.keys():
		if _gap(cell_v, near) <= LOAD_REACH:
			_out.erase(cell_v)
			_props.reload_room(cell_v)
	var far: Array = []
	for cell_v in _land.get_meta(_Addr.META_AT, {}):
		if not _out.has(cell_v) and _gap(cell_v, near) > UNLOAD_REACH:
			far.append(cell_v)
	far.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _gap(a, near) > _gap(b, near))
	var freed := 0
	for cell_v in far:
		if freed >= UNLOAD_NODES_PER_TICK:
			break
		_out[cell_v] = true
		var n := int(_props.unload_room(cell_v))
		freed += n
		unloaded_total += n


func _gap(cell: Vector2i, near: Array) -> int:
	var best := 1 << 20
	for here_v in near:
		var here: Vector2i = here_v
		if _Addr.twin(_land, here) == cell:
			return 0
		best = mini(best, maxi(absi(cell.x - here.x), absi(cell.y - here.y)))
	return best
