extends Node

## The current run: registered players, the active land, and the local camera.
## Loaded after WorldState. The spawn counter is the run provider "eids"
## so summon, drop and bullet ids stay unique after a load.
## torso_hp_mult, player_dead and alicorn are written by the autoload that
## owns them (GameState, GameState, ScriptsEngine) and read by the character
## autoloads, which do not call back into those owners.
## sost, cur_land_id and exit_state are written by Travel. exit_state 0 is
## Exit.NONE. travel_on stays false until Travel is ready, so a boot without
## that autoload keeps WorldState's scene fallback.

const _Character := preload("res://scripts/character/character.gd")

var _character: _Character
var _others: Dictionary = {}
var _order: Array[Node2D] = []
var _ids: Array[int] = []
var _next_id := 1
var _spawn_n := 0
var _land: Node2D
var torso_hp_mult := 1.0
var player_dead := false
var alicorn := false
var sost := 1
var cur_land_id := ""
var exit_state := 0
var travel_on := false


func _ready() -> void:
	WorldState.register_run("eids", _eid_state, _set_eid_state)
	if not WorldState.run_reset.is_connected(_on_run_reset):
		WorldState.run_reset.connect(_on_run_reset)


## Adds p and assigns the next id, starting at 1. The eid is "p<id>".
## Registering the same node again does nothing.
func register_player(p: Node2D) -> void:
	if p == null or not is_instance_valid(p):
		return
	if _order.has(p):
		return
	var id := _next_id
	_order.append(p)
	_ids.append(id)
	_next_id += 1
	var eid := "p%d" % id
	p.set_meta("eid", eid)
	if "eid" in p:
		p.set("eid", eid)
	if "pid" in p:
		p.set("pid", id)
	Entity.note(p, eid)


## Player pid's character; 0 or the local id is the local one. The local one
## exists before the player body spawns (menus, slot loads) and outlives it.
## The autoload facades and character.json always use the local one; another
## player's is made on first use and dropped when that player leaves.
func character(pid := 0) -> _Character:
	if pid != 0 and pid != local_id():
		if not _others.has(pid):
			_others[pid] = _Character.new()
		return _others[pid]
	if _character == null:
		_character = _Character.new()
	return _character


## Next "<owner_eid>/s<counter>". An empty owner is "run".
func alloc_eid(owner_eid: String) -> String:
	_spawn_n += 1
	var owner := owner_eid if owner_eid != "" else "run"
	return "%s/s%d" % [owner, _spawn_n]


func _eid_state() -> Dictionary:
	return {"version": 1, "next": _spawn_n}


func _set_eid_state(data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	var n := int((data as Dictionary).get("next", 0))
	if n > _spawn_n:
		_spawn_n = n


func _on_run_reset() -> void:
	_spawn_n = 0


## Drops p. Freed entries are dropped with it.
func unregister_player(p: Node) -> void:
	if p == null:
		return
	var i := _order.size() - 1
	while i >= 0:
		if _order[i] == p or not is_instance_valid(_order[i]):
			_drop(i)
		i -= 1


## Registered players still in the tree, in registration order.
func players() -> Array:
	var out: Array = []
	var i := 0
	while i < _order.size():
		if is_instance_valid(_order[i]):
			out.append(_order[i])
			i += 1
		else:
			_drop(i)
	return out


## The first player still in the tree, or null.
func local_player() -> Node2D:
	var i := 0
	while i < _order.size():
		if is_instance_valid(_order[i]):
			return _order[i]
		_drop(i)
	return null


## The local player's id, or 0 when none is in the tree.
func local_id() -> int:
	var p := local_player()
	if p == null:
		return 0
	return _ids[_order.find(p)]


## The player assigned id at register, or null.
func by_id(id: int) -> Node2D:
	var i := 0
	while i < _order.size():
		if not is_instance_valid(_order[i]):
			_drop(i)
			continue
		if _ids[i] == id:
			return _order[i]
		i += 1
	return null


## The registered player closest to at, or null. A tie keeps the earlier registration.
func nearest_player(at: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	var i := 0
	while i < _order.size():
		if not is_instance_valid(_order[i]):
			_drop(i)
			continue
		var d := at.distance_squared_to(_order[i].global_position)
		if d < best_d:
			best_d = d
			best = _order[i]
		i += 1
	return best


## The active land. A node that left the group is looked up again (the stable stays alive).
func land() -> Node2D:
	if is_instance_valid(_land) and _land.is_in_group("active_land"):
		return _land
	_land = null
	var tree := get_tree()
	if tree == null:
		return null
	_land = tree.get_first_node_in_group("active_land") as Node2D
	return _land


## The local player's Camera2D, or the viewport camera when that child is missing.
func camera() -> Camera2D:
	var p := local_player()
	if p != null:
		var cam := p.get_node_or_null("Camera2D") as Camera2D
		if cam != null:
			return cam
	var vp := get_viewport()
	if vp == null:
		return null
	return vp.get_camera_2d()


func _drop(i: int) -> void:
	_others.erase(_ids[i])
	_order.remove_at(i)
	_ids.remove_at(i)
