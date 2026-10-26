extends Node

## Room-tagged draw-only nodes (meta room_x / room_y) hide unless their room is
## on camera or one room around it. Units and objects sleep in room_bounds.gd.

const ROOM_PX := Vector2(48 * 40, 25 * 40)
const TICK := 0.2
const HIDE := "room_hide"

## near(): nodes this far off camera still count (wide objects, movement
## between refreshes).
const NEAR_MARGIN := 600.0
const NEAR_MS := 200

var _land: Node2D
var _t := 0.0
var _live := Rect2i()

static var _near := {}
static var _near_at := {}


## Nodes of group whose origin is on camera or within NEAR_MARGIN of it, for
## per-frame cursor and prompt picks that would otherwise walk the whole land.
static func near(tree: SceneTree, group: String) -> Array:
	var now := Time.get_ticks_msec()
	var out: Array = []
	if now - int(_near_at.get(group, -NEAR_MS)) < NEAR_MS:
		for node in _near[group]:
			if is_instance_valid(node) and (node as Node).is_inside_tree():
				out.append(node)
		return out
	var vp := tree.root.get_viewport()
	var view := (vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()).grow(NEAR_MARGIN)
	var cam := vp.get_camera_2d()
	if cam != null:
		var size := vp.get_visible_rect().size / cam.zoom
		view = Rect2(cam.get_screen_center_position() - size * 0.5, size).grow(NEAR_MARGIN)
	for node in tree.get_nodes_in_group(group):
		if node is Node2D and view.has_point((node as Node2D).global_position):
			out.append(node)
	_near[group] = out
	_near_at[group] = now
	return out.duplicate()


static func attach(land: Node2D) -> Node:
	var node: Node = (load("res://scripts/map/room_activity.gd") as GDScript).new()
	node.name = "RoomActivity"
	node._land = land
	land.add_child(node)
	return node


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = TICK
	if _land == null or not _land.is_inside_tree():
		return
	var vp := get_viewport()
	var view := vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()
	var local := _land.get_global_transform().affine_inverse() * view
	var a := Vector2i((local.position / ROOM_PX).floor()) - Vector2i.ONE
	var b := Vector2i((local.end / ROOM_PX).floor()) + Vector2i.ONE
	_live = Rect2i(a, b - a + Vector2i.ONE)
	for node in get_tree().get_nodes_in_group(HIDE):
		if _land.is_ancestor_of(node):
			var on := _live.has_point(Vector2i(int(node.get_meta("room_x", 0)), int(node.get_meta("room_y", 0))))
			if (node as CanvasItem).visible != on:
				(node as CanvasItem).visible = on

