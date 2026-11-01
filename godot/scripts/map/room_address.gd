extends RefCounted

## Where a room is in its land, apart from where it is drawn: chunk, the
## map position (lx, ly: Land.locs x, y) and the layer. The pixel grid folds
## back rooms, sky blocks and trial rooms into rows below the map (play_land
## _layout); the address does not move when that layout changes.
## A land keeps both directions as meta: cell (pixel room) -> key and back.
## key is "chunk:lx:ly:layer". Fixed lands are chunk 0.

const MAIN := "main"
const BACK := "back"
const SKY := "sky"
const TRIAL := "trial"
const META_AT := "room_addr"
const META_CELL := "room_cell"
const NONE := Vector2i(-1073741824, -1073741824)


## Rooms that simulate together: the main map, one sky block, or a back or
## trial room alone (its own Location in the original).
static func group_at(land: Node, cell: Vector2i) -> String:
	var addr := at(land, cell)
	var a := parse(addr)
	if a.is_empty():
		return ""
	match str(a.layer):
		MAIN:
			return "%d:main" % int(a.chunk)
		SKY:
			return "%d:sky:%d:%d" % [int(a.chunk), int(a.lx) / 1000, int(a.ly) / 1000]
	return addr


static func key(chunk: int, lx: int, ly: int, layer: String) -> String:
	return "%d:%d:%d:%s" % [chunk, lx, ly, layer]


## {chunk, lx, ly, layer} of a key; empty for a bad key.
static func parse(addr: String) -> Dictionary:
	var parts := addr.split(":")
	if parts.size() != 4:
		return {}
	return {"chunk": int(parts[0]), "lx": int(parts[1]), "ly": int(parts[2]), "layer": parts[3]}


## The layer a built room row belongs to.
static func layer_of(room: Dictionary) -> String:
	if str(room.get("prob", "")) != "":
		return TRIAL
	if bool(room.get("sky_part", false)) or bool(room.get("sky_block", false)):
		return SKY
	if int(room.get("z", 0)) != 0:
		return BACK
	return MAIN


## Stamps chunk, layer and addr on every room and indexes them on land.
## Sky block parts keep the block room's map position with their offset in
## the block; trial rooms use their column in the trial row.
static func stamp(land: Node, rooms: Array, chunk := 0) -> void:
	var at := {}
	var cells := {}
	for room_v in rooms:
		var room: Dictionary = room_v
		var layer := layer_of(room)
		var lx := int(room.get("lx", 0))
		var ly := int(room.get("ly", 0))
		if layer == TRIAL:
			lx = int(room.get("x", 0))
			ly = 0
		elif layer == SKY and room.has("sky_of"):
			var of: Vector2i = room.sky_of
			lx = of.x * 1000 + int(room.get("sky_i", 0))
			ly = of.y * 1000 + int(room.get("sky_j", 0))
		var addr := key(chunk, lx, ly, layer)
		room["chunk"] = chunk
		room["layer"] = layer
		room["addr"] = addr
		var cell := Vector2i(int(room.get("x", 0)), int(room.get("y", 0)))
		at[cell] = addr
		cells[addr] = cell
	land.set_meta(META_AT, at)
	land.set_meta(META_CELL, cells)


## The address of a pixel room cell of land; "" when no room is there.
static func at(land: Node, cell: Vector2i) -> String:
	if land == null or not land.has_meta(META_AT):
		return ""
	return str((land.get_meta(META_AT) as Dictionary).get(cell, ""))


## The pixel room cell of an address; NONE when it is not built.
static func cell_of(land: Node, addr: String) -> Vector2i:
	if land == null or not land.has_meta(META_CELL):
		return NONE
	return (land.get_meta(META_CELL) as Dictionary).get(addr, NONE)


static func layer_at(land: Node, cell: Vector2i) -> String:
	var addr := at(land, cell)
	return "" if addr == "" else str(parse(addr).get("layer", ""))


## The main room a back room stands behind, or the back room behind a main
## room; NONE when there is none.
static func twin(land: Node, cell: Vector2i) -> Vector2i:
	var a := parse(at(land, cell))
	if a.is_empty() or not (a.layer == MAIN or a.layer == BACK):
		return NONE
	var other := BACK if a.layer == MAIN else MAIN
	return cell_of(land, key(int(a.chunk), int(a.lx), int(a.ly), other))
