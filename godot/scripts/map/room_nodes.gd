extends RefCounted

## Which rooms own a land node: collision bodies, doors and room dressing.
## The node roots stay flat (Solids, Platforms, Ladders, Slopes, Doors,
## RoomDressing) because colliders are told apart by their parent's name;
## this index groups them per room instead. A merged wall that crosses a room
## border is owned by every room it covers (the joint between them).
## Actors are not listed here: they move, and land_props follows them with
## room_x / room_y (room_bounds.gd).

const META := "room_nodes"
const ROOM_W := 1920.0
const ROOM_H := 1000.0


## Pixel room cells a world rect covers.
static func cells_of(rect: Rect2) -> Array:
	var out: Array = []
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return out
	var x0 := floori(rect.position.x / ROOM_W)
	var y0 := floori(rect.position.y / ROOM_H)
	var x1 := floori((rect.end.x - 0.01) / ROOM_W)
	var y1 := floori((rect.end.y - 0.01) / ROOM_H)
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			out.append(Vector2i(x, y))
	return out


static func own(land: Node, node: Node, rooms: Array) -> void:
	node.set_meta("rooms", rooms)
	var index := _index(land)
	for cell_v in rooms:
		if not index.has(cell_v):
			index[cell_v] = []
		(index[cell_v] as Array).append(weakref(node))


## A body by its world rect (collision shapes start at the body's origin).
static func own_rect(land: Node, node: Node, rect: Rect2) -> void:
	own(land, node, cells_of(rect))


## Live nodes room cell owns, in the order they were added.
static func nodes_of(land: Node, cell: Vector2i) -> Array:
	var out: Array = []
	var index := _index(land)
	var kept: Array = []
	for ref_v in index.get(cell, []):
		var node := (ref_v as WeakRef).get_ref() as Node
		if node == null or node.is_queued_for_deletion():
			continue
		kept.append(ref_v)
		out.append(node)
	if index.has(cell):
		index[cell] = kept
	return out


## Draw-only nodes of a room under the land's RoomDressing: tile canvases,
## back walls and dim layers tagged room_x / room_y.
static func dressing_of(land: Node, cell: Vector2i) -> Array:
	var out: Array = []
	var root := land.get_node_or_null("RoomDressing")
	if root != null:
		_tagged(root, cell, out)
	return out


static func _tagged(node: Node, cell: Vector2i, out: Array) -> void:
	for child in node.get_children():
		if child.has_meta("room_x") and child.has_meta("room_y"):
			if int(child.get_meta("room_x")) == cell.x and int(child.get_meta("room_y")) == cell.y:
				out.append(child)
			continue
		_tagged(child, cell, out)


static func rooms_of(node: Node) -> Array:
	return node.get_meta("rooms", []) if node != null else []


static func _index(land: Node) -> Dictionary:
	if not land.has_meta(META):
		land.set_meta(META, {})
	return land.get_meta(META)
