extends Node

## Location.sky rooms. Location.zoom > 1 makes the room zoom times wider and
## taller (play_land.gd gives it a block of its own rows). While the player is
## inside, Land.ativateLoc sets isFly and stay = false (player.gd sky_mode)
## and Camera.setZoom(2) fits the whole room on screen. UnitPlayer.canLeaveLoc
## refuses to leave a sky room, so the player is held inside it; only a
## script goto (megabossDie) takes them out.

const COLS := 48
const ROWS := 25
const TILE := 40.0
## A body further outside than this was moved by a script, not flown out.
const HOLD := 200.0

var rects: Array[Rect2] = []
var _inside := -1
var _limits: Array[int] = []


static func zoom_of(room: Dictionary) -> int:
	var o: Dictionary = room.get("options", {})
	if not o.has("sky") or int(room.get("z", 0)) != 0 or bool(room.get("sky_part", false)):
		return 0
	return maxi(1, int(str(o.get("zoom", "1")).to_float()))


static func attach(land: Node, rooms: Array) -> void:
	var found: Array[Rect2] = []
	for room_v in rooms:
		var room: Dictionary = room_v
		var zoom := zoom_of(room)
		if zoom <= 0:
			continue
		var cell := Vector2(COLS * TILE, ROWS * TILE)
		found.append(Rect2(Vector2(int(room.x), int(room.y)) * cell, cell * zoom))
	if found.is_empty():
		return
	var node: Node = (load("res://scripts/map/sky_arena.gd") as GDScript).new()
	node.name = "SkyArena"
	node.rects = found
	land.add_child(node)


func _physics_process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player == null or not "sky_mode" in player:
		return
	var at := player.global_position
	var now := -1
	for i in rects.size():
		if rects[i].grow(HOLD if i == _inside else 0.0).has_point(at):
			now = i
			break
	if now != _inside:
		_leave(player)
		if now >= 0:
			_enter(player, now)
	if _inside < 0:
		return
	var r := rects[_inside]
	var held := at.clamp(r.position + Vector2(25.0, 80.0), r.end - Vector2(25.0, 1.0))
	if held != at:
		player.global_position = held
		var v: Vector2 = player.velocity
		if held.x != at.x:
			v.x = 0.0
		if held.y != at.y:
			v.y = 0.0
		player.velocity = v


func _enter(player: CharacterBody2D, index: int) -> void:
	_inside = index
	player.set("sky_mode", true)
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	var r := rects[index]
	_limits = [cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom]
	cam.limit_left = int(r.position.x)
	cam.limit_top = int(r.position.y)
	cam.limit_right = int(r.end.x)
	cam.limit_bottom = int(r.end.y)
	var view := cam.get_viewport_rect().size
	CameraDistance.set_room_zoom(minf(view.x / r.size.x, view.y / r.size.y))
	cam.reset_smoothing()


func _leave(player: CharacterBody2D) -> void:
	if _inside < 0:
		return
	_inside = -1
	player.set("sky_mode", false)
	CameraDistance.set_room_zoom(0.0)
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam != null and _limits.size() == 4:
		cam.limit_left = _limits[0]
		cam.limit_top = _limits[1]
		cam.limit_right = _limits[2]
		cam.limit_bottom = _limits[3]
		cam.reset_smoothing()


func _exit_tree() -> void:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player != null:
		_leave(player)
