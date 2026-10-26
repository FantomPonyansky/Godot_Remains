extends StaticBody2D

## Stepped stair (slope tile). The original ramp is not a solid volume:
## checkDiagon lands you on the walk line only while falling, and collisionTile
## ignores a platform once the feet are already below that line. Down+jump sets
## throu, so the same stair (and the next ones, while down is held) let you drop.
##
## The filled triangle stays, on the platform layer. Walking up it still stands.
## While a body's feet are below this tile's walk line it is excepted, so a
## jump from underneath passes through and can land once the feet clear it.
## That holds for every walking unit (Unit.checkDiagon), not only the player.
## The existing down+jump drop clears the platform layer, which is this body.
##
## One slope (the leader) runs the pass for all of them each physics frame.
## Slopes are indexed by tile column, so a body only tests the ramps under it.

const TILE := 40.0

var side := "right"
var lip := 0.0

static var _columns: Dictionary = {}
static var _leader: Node = null
## Body instance id -> {slope: true} for the slopes currently open to it.
static var _open: Dictionary = {}

var _column := 0


func _init() -> void:
	process_physics_priority = -20


func _ready() -> void:
	_column = int(floor(global_position.x / TILE))
	var list: Array = _columns.get(_column, [])
	list.append(self)
	_columns[_column] = list
	if _leader == null or not is_instance_valid(_leader) or not _leader.is_inside_tree():
		_leader = self
	set_physics_process(_leader == self)


func _exit_tree() -> void:
	var list: Array = _columns.get(_column, [])
	list.erase(self)
	if list.is_empty():
		_columns.erase(_column)
	for id in _open.keys():
		(_open[id] as Dictionary).erase(self)
	if _leader != self:
		return
	_leader = null
	for col in _columns.keys():
		for other in _columns[col]:
			if is_instance_valid(other) and other != self and (other as Node).is_inside_tree():
				_leader = other
				(other as Node).set_physics_process(true)
				return


func _physics_process(_delta: float) -> void:
	var tree := get_tree()
	var seen := {}
	for group_name in ["player", "enemies", "allies"]:
		for node in tree.get_nodes_in_group(group_name):
			var body := node as CharacterBody2D
			if body == null or not body.is_physics_processing():
				continue
			seen[body.get_instance_id()] = true
			_pass_body(body)
	for id in _open.keys():
		if seen.has(id):
			continue
		var gone := instance_from_id(id) as CharacterBody2D
		if gone == null or not is_instance_valid(gone):
			_open.erase(id)
		elif not gone.is_physics_processing():
			continue
		else:
			for slope in (_open[id] as Dictionary).keys():
				if is_instance_valid(slope):
					(slope as PhysicsBody2D).remove_collision_exception_with(gone)
			_open.erase(id)


func _pass_body(body: CharacterBody2D) -> void:
	var id := body.get_instance_id()
	var was: Dictionary = _open.get(id, {})
	var now := {}
	var col := int(floor(body.global_position.x / TILE))
	for c in [col - 1, col, col + 1]:
		for slope in _columns.get(c, []):
			if is_instance_valid(slope) and slope._feet_under(body):
				now[slope] = true
	for slope in was.keys():
		if not now.has(slope) and is_instance_valid(slope):
			(slope as PhysicsBody2D).remove_collision_exception_with(body)
	for slope in now.keys():
		if not was.has(slope):
			(slope as PhysicsBody2D).add_collision_exception_with(body)
	if now.is_empty():
		_open.erase(id)
	else:
		_open[id] = now


func _feet_under(body: CharacterBody2D) -> bool:
	var x := body.global_position.x
	# Open by the body's leading edge so walking in under the high side, or
	# jumping into it, does not bump the ramp's face. The low end still climbs:
	# there the feet are not below the walk line.
	# Wider than the 25 px half body plus one tick of running, so the edge never meets the face first.
	var reach := 40.0
	if x < global_position.x - reach or x > global_position.x + TILE + reach:
		return false
	var sample := clampf(x, global_position.x, global_position.x + TILE)
	var surface := _surface_y(sample)
	# Unit.run checkDiagon: on the floor a unit only steps onto a stair while it
	# already stands on one, or (player) holds up; otherwise it walks under it.
	if body.is_on_floor() and not _on_stair(body):
		var up := body.is_in_group("player") and Input.is_action_pressed("aim_up")
		if not up:
			return body.global_position.y > surface - 4.0
	return body.global_position.y > surface + 2.0


static func _on_stair(body: CharacterBody2D) -> bool:
	for i in body.get_slide_collision_count():
		var hit := body.get_slide_collision(i)
		if hit.get_normal().y < -0.5 and hit.get_collider() != null and hit.get_collider().has_method("_surface_y"):
			return true
	return false


func _surface_y(x: float) -> float:
	var t := clampf((x - global_position.x) / TILE, 0.0, 1.0)
	var high := global_position.y + lip
	var low := global_position.y + TILE
	if side == "left":
		return lerpf(high, low, t)
	return lerpf(low, high, t)
