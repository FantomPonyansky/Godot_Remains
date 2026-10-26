extends Node2D

## Tile slices of one room, layer and z drawn by a single canvas item instead
## of one Sprite2D each. Rooms hold hundreds of patch and lip slices.

const ROOM_PX := Vector2(48 * 40, 25 * 40)

var _cmds: Array = []


## The canvas under parent for the room holding at, created on first use.
static func at(parent: Node, at_px: Vector2, z: int) -> Node2D:
	var room := Vector2i((at_px / ROOM_PX).floor())
	var key := "Tiles_%d_%d_%d" % [room.x, room.y, z]
	var node := parent.get_node_or_null(key) as Node2D
	if node == null:
		node = (load("res://scripts/map/tile_canvas.gd") as GDScript).new()
		node.name = key
		node.z_index = z
		node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		node.set_meta("room_x", room.x)
		node.set_meta("room_y", room.y)
		node.add_to_group("room_hide")
		parent.add_child(node)
	return node


func add(texture: Texture2D, dest: Rect2, src: Rect2) -> void:
	_cmds.append([texture, dest, src])
	queue_redraw()


func _draw() -> void:
	for c in _cmds:
		draw_texture_rect_region(c[0], c[1], c[2])
