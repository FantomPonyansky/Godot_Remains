extends Node2D

## Back rooms (Land.locs z = 1) and trial rooms (Land.probs) are a Location
## of their own in the original: Land.ativateLoc shows only that room and
## Camera.calc keeps the view inside it. play_land.gd lays them out in rows
## under the land grid; while the player is in one, the camera is clamped to
## that room (zoomed in just enough when the view is larger than the room)
## and everything outside it is blacked out.

const COLS := 48
const ROWS := 25
const TILE := 40.0
const ROOM := Vector2(COLS * TILE, ROWS * TILE)
## Hysteresis so the feet on the room's bottom edge do not flicker out.
const HOLD := 40.0
const FAR := 200000.0
const MASK_Z := 4000

var rects: Array[Rect2] = []
var _inside := -1
var _limits: Array[int] = []
var _mask: Array[Polygon2D] = []


static func attach(land: Node, rooms: Array) -> void:
	var found: Array[Rect2] = []
	for room_v in rooms:
		var room: Dictionary = room_v
		if bool(room.get("sky_part", false)):
			continue
		if int(room.get("z", 0)) == 0 and str(room.get("prob", "")) == "":
			continue
		found.append(Rect2(Vector2(int(room.x), int(room.y)) * ROOM, ROOM))
	if found.is_empty():
		return
	var node: Node2D = (load("res://scripts/map/back_room.gd") as GDScript).new()
	node.name = "BackRoom"
	node.rects = found
	land.add_child(node)


func _ready() -> void:
	for i in 4:
		var part := Polygon2D.new()
		part.color = Color.BLACK
		part.z_index = MASK_Z
		part.z_as_relative = false
		part.visible = false
		add_child(part)
		_mask.append(part)


func _physics_process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var at := to_local(player.global_position)
	var now := -1
	if _inside >= 0 and rects[_inside].grow(HOLD).has_point(at):
		now = _inside
	else:
		for i in rects.size():
			if rects[i].has_point(at):
				now = i
				break
	if now == _inside:
		return
	_leave(player)
	if now >= 0:
		_enter(player, now)


func _enter(player: Node2D, index: int) -> void:
	_inside = index
	var r := rects[index]
	_cover(r)
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	var g := Rect2(to_global(r.position), r.size)
	_limits = [cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom]
	cam.limit_left = int(g.position.x)
	cam.limit_top = int(g.position.y)
	cam.limit_right = int(g.end.x)
	cam.limit_bottom = int(g.end.y)
	var view := cam.get_viewport_rect().size / maxf(cam.zoom.y, 0.01)
	if view.x > g.size.x or view.y > g.size.y:
		var screen := cam.get_viewport_rect().size
		CameraDistance.set_room_zoom(maxf(screen.x / g.size.x, screen.y / g.size.y))
	if cam.has_method("snap"):
		cam.call("snap")
	cam.reset_smoothing()


func _leave(player: Node2D) -> void:
	if _inside < 0:
		return
	_inside = -1
	for part in _mask:
		part.visible = false
	if CameraDistance.room_zoom > 0.0:
		CameraDistance.set_room_zoom(0.0)
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam != null and _limits.size() == 4:
		cam.limit_left = _limits[0]
		cam.limit_top = _limits[1]
		cam.limit_right = _limits[2]
		cam.limit_bottom = _limits[3]
		cam.reset_smoothing()


func _cover(r: Rect2) -> void:
	var a := r.position
	var b := r.end
	var boxes := [
		Rect2(-FAR, -FAR, FAR * 2.0, a.y + FAR),
		Rect2(-FAR, b.y, FAR * 2.0, FAR),
		Rect2(-FAR, a.y, a.x + FAR, r.size.y),
		Rect2(b.x, a.y, FAR, r.size.y),
	]
	for i in 4:
		var box: Rect2 = boxes[i]
		_mask[i].polygon = PackedVector2Array([box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)])
		_mask[i].visible = true


func _exit_tree() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		_leave(player)
