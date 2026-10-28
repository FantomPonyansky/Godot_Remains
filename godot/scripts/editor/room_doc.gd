extends RefCounted

## One rooms_*.json (or imported XML) in memory for the editor.
const Codec := preload("res://scripts/editor/room_codec.gd")
const Catalog := preload("res://scripts/map/tile_catalog.gd")
const RoomFile := preload("res://scripts/map/room_file.gd")
const Registry := preload("res://scripts/map/land_registry.gd")
const LandGen := preload("res://scripts/map/land_gen.gd")

var file := ""
var source := ""
var placed := false
var title := ""
var options: Dictionary = {}
## Port mod field. Not written back by to_dict (save_doc already records base).
var base := ""
## Editor-only. {file, name} of the room this document was copied from. Not saved.
var origin: Dictionary = {}
## Land-row options for the file (or a copy's base/origin). Not saved.
var land_defaults: Dictionary = {}
var rooms: Array = []
var dirty := false
var room_i := -1
var grid: Array = []
var _undo: Array = []
var _redo: Array = []


func load_dict(doc: Dictionary) -> void:
	file = str(doc.get("file", ""))
	source = str(doc.get("source", ""))
	placed = bool(doc.get("placed", false))
	title = str(doc.get("title", ""))
	var opt: Variant = doc.get("options", {})
	options = (opt as Dictionary).duplicate(true) if opt is Dictionary else {}
	base = str(doc.get("base", ""))
	var org: Variant = doc.get("origin", {})
	origin = (org as Dictionary).duplicate(true) if org is Dictionary else {}
	land_defaults = inherited_options(file, doc)
	rooms = (doc.get("rooms", []) as Array).duplicate(true)
	room_i = -1
	grid.clear()
	dirty = false
	_undo.clear()
	_redo.clear()


func to_dict() -> Dictionary:
	commit()
	var out := {"file": file, "source": source, "placed": placed, "rooms": rooms}
	if not options.is_empty():
		out["options"] = options
	if title != "":
		out["title"] = title
	if not origin.is_empty():
		out["origin"] = origin
	return out


## Dict passed to a test. base stays off the saved document.
func land_probe() -> Dictionary:
	var probe := to_dict()
	if base != "":
		probe["base"] = base
	return probe


## File whose land row supplies defaults. A shipped file matches itself.
## A mod copy with no land of its own uses origin, then base.
static func land_source(file_name: String, doc: Dictionary) -> String:
	var named := file_name if file_name != "" else str(doc.get("file", ""))
	if not _lands_for(named).is_empty():
		return named
	var origin_file := ""
	var org: Variant = doc.get("origin", {})
	if org is Dictionary:
		origin_file = str((org as Dictionary).get("file", ""))
	if origin_file != "" and not _lands_for(origin_file).is_empty():
		return origin_file
	var from_base := str(doc.get("base", ""))
	if from_base != "" and from_base != named and not _lands_for(from_base).is_empty():
		return from_base
	if origin_file != "":
		return origin_file
	if from_base != "":
		return from_base
	return named


## First land in registry order that uses the file. Later lands that share the
## file are not mixed in, so two rows cannot invent a hybrid default.
static func inherited_options(file_name: String, doc: Dictionary = {}) -> Dictionary:
	var ids := _lands_for(land_source(file_name, doc))
	if ids.is_empty():
		return {}
	var opt: Variant = Registry.land(str(ids[0])).get("options", {})
	if opt is Dictionary:
		return (opt as Dictionary).duplicate(true)
	return {}


static func _lands_for(file_name: String) -> Array:
	if file_name == "":
		return []
	var ids: Array = []
	var seen := {}
	for id_v in Registry.ids():
		var id := str(id_v)
		var row: Dictionary = Registry.land(id)
		if str(row.get("file", "")) != file_name:
			continue
		ids.append(id)
		seen[id] = true
	for id_v in LandGen.lands_using(file_name):
		var id := str(id_v)
		if seen.has(id):
			continue
		ids.append(id)
	return ids


func open_room(name: String, save_current := true) -> bool:
	if save_current:
		commit()
	for i in rooms.size():
		if str(rooms[i].get("name", "")) == name:
			room_i = i
			grid = Codec.grid_from_rows(rooms[i].get("rows", []))
			return true
	return false


func commit() -> void:
	if room_i < 0 or room_i >= rooms.size():
		return
	rooms[room_i]["rows"] = Codec.rows_from_grid(grid)
	if not placed:
		rooms[room_i]["doors"] = Codec.doors_from_rows(rooms[room_i]["rows"])


func room() -> Dictionary:
	if room_i < 0 or room_i >= rooms.size():
		return {}
	return rooms[room_i]


func cell(x: int, y: int) -> Dictionary:
	if y < 0 or y >= grid.size() or x < 0 or x >= Codec.COLS:
		return Codec.empty_cell()
	return grid[y][x]


func set_cell(x: int, y: int, value: Dictionary) -> void:
	if y < 0 or y >= grid.size() or x < 0 or x >= Codec.COLS:
		return
	grid[y][x] = value
	dirty = true


func _capture() -> Dictionary:
	commit()
	return {
		"rooms": rooms.duplicate(true),
		"options": options.duplicate(true),
		"title": title,
		"placed": placed,
	}


func snapshot() -> void:
	_undo.append(_capture())
	if _undo.size() > 40:
		_undo.pop_front()
	_redo.clear()


func undo() -> bool:
	if _undo.is_empty():
		return false
	_redo.append(_capture())
	_use(_undo.pop_back())
	return true


func redo() -> bool:
	if _redo.is_empty():
		return false
	_undo.append(_capture())
	_use(_redo.pop_back())
	return true


func _use(snap: Dictionary) -> void:
	rooms = (snap.get("rooms", []) as Array).duplicate(true)
	var opt: Variant = snap.get("options", {})
	options = (opt as Dictionary).duplicate(true) if opt is Dictionary else {}
	title = str(snap.get("title", ""))
	placed = bool(snap.get("placed", false))
	_reopen()
	dirty = true


func apply_room(room: Dictionary) -> void:
	snapshot()
	var neu: Dictionary = room.duplicate(true)
	if room_i < 0 or room_i >= rooms.size():
		rooms.append(neu)
		room_i = rooms.size() - 1
	else:
		rooms[room_i] = neu
	dirty = true
	var name := str(neu.get("name", ""))
	if name == "" or not open_room(name, false):
		grid = Codec.grid_from_rows(neu.get("rows", []))


func apply_land(parsed: Dictionary) -> void:
	snapshot()
	rooms = (parsed.get("rooms", []) as Array).duplicate(true)
	var opt: Variant = parsed.get("options", {})
	options = (opt as Dictionary).duplicate(true) if opt is Dictionary else {}
	if parsed.has("title"):
		title = str(parsed.get("title", ""))
	placed = bool(parsed.get("placed", placed))
	dirty = true
	_reopen()


func _reopen() -> void:
	var name := str(room().get("name", ""))
	if name != "" and open_room(name, false):
		return
	room_i = -1
	grid.clear()


## a is the drag start, b the cell under the cursor.
## Erase clears only brush slots set to `_`. kind limits which diag tokens ("beam" / "slope").
## A beam token paints one horizontal row. A slope token paints one 45° line.
## A stair token paints one column. Else the rect.
func paint_drag(a: Vector2i, b: Vector2i, brush: Dictionary, outline: bool, erase: bool, kind := "") -> void:
	if erase:
		_erase_slots(a, b, brush, outline, kind)
		return
	var diag := _live(brush, "diag")
	if diag != "" and _piece_kind(diag) == "beam":
		paint_rect(Rect2i(mini(a.x, b.x), a.y, absi(b.x - a.x) + 1, 1), brush, false, false)
		return
	if diag != "":
		_paint_diag(a, b, brush, diag)
		return
	if _live(brush, "stair") != "":
		var y0 := mini(a.y, b.y)
		var y1 := maxi(a.y, b.y)
		paint_rect(Rect2i(a.x, y0, 1, y1 - y0 + 1), brush, false, false)
		return
	var x0 := mini(a.x, b.x)
	var y2 := mini(a.y, b.y)
	var x1 := maxi(a.x, b.x)
	var y3 := maxi(a.y, b.y)
	paint_rect(Rect2i(x0, y2, x1 - x0 + 1, y3 - y2 + 1), brush, outline, false)


## Inclusive corners. Objects are left for the editor (it knows the layer).
func _erase_slots(a: Vector2i, b: Vector2i, brush: Dictionary, outline: bool, kind: String) -> void:
	var clear := {}
	for key in ["front", "back", "stair", "diag", "water"]:
		if brush.has(key) and str(brush[key]) == "_":
			clear[key] = "_"
	if clear.is_empty():
		return
	snapshot()
	var x0 := mini(a.x, b.x)
	var y0 := mini(a.y, b.y)
	var x1 := maxi(a.x, b.x)
	var y1 := maxi(a.y, b.y)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if outline and x != x0 and x != x1 and y != y0 and y != y1:
				continue
			var cur := cell(x, y)
			if clear.has("diag") and kind != "" and _piece_kind(str(cur.get("diag", ""))) != kind:
				continue
			set_cell(x, y, _stamp(cur, clear))


func _piece_kind(token: String) -> String:
	var piece: Array = Catalog.OVERLAY.get(token, [])
	if piece.is_empty():
		return ""
	return str(piece[0])


func _live(brush: Dictionary, key: String) -> String:
	if not brush.has(key):
		return ""
	var v := str(brush[key])
	if v == "" or v == "_":
		return ""
	return v


func _slope_side(token: String) -> String:
	var piece: Array = Catalog.OVERLAY.get(token, [])
	if piece.size() < 3 or str(piece[0]) != "slope":
		return ""
	return str(piece[2])


## sx == sy is the \ slope (left). The other diagonal is / (right).
func _diag_token(token: String, sx: int, sy: int) -> String:
	var side := _slope_side(token)
	if side == "":
		return token
	var want := "left" if sx == sy else "right"
	if side == want:
		return token
	return Catalog.mirror_char(token)


func _paint_diag(a: Vector2i, b: Vector2i, brush: Dictionary, token: String) -> void:
	var dx := b.x - a.x
	var dy := b.y - a.y
	var sx := 0
	var sy := 0
	if dx != 0 and dy != 0:
		sx = 1 if dx > 0 else -1
		sy = 1 if dy > 0 else -1
		token = _diag_token(token, sx, sy)
	elif dx != 0 or dy != 0:
		var side := _slope_side(token)
		if dx != 0:
			sx = 1 if dx > 0 else -1
			sy = sx if side != "right" else -sx
		else:
			sy = 1 if dy > 0 else -1
			sx = sy if side != "right" else -sy
	var n := maxi(absi(dx), absi(dy))
	var stamped := brush.duplicate()
	stamped["diag"] = token
	snapshot()
	for i in n + 1:
		var at := Vector2i(a.x + sx * i, a.y + sy * i)
		set_cell(at.x, at.y, _stamp(cell(at.x, at.y), stamped))


func paint_rect(r: Rect2i, brush: Dictionary, outline: bool, erase: bool) -> void:
	if erase:
		var ex0 := mini(r.position.x, r.end.x - 1)
		var ey0 := mini(r.position.y, r.end.y - 1)
		var ex1 := maxi(r.position.x, r.end.x - 1)
		var ey1 := maxi(r.position.y, r.end.y - 1)
		_erase_slots(Vector2i(ex0, ey0), Vector2i(ex1, ey1), brush, outline, "")
		return
	snapshot()
	var x0 := mini(r.position.x, r.end.x - 1)
	var y0 := mini(r.position.y, r.end.y - 1)
	var x1 := maxi(r.position.x, r.end.x - 1)
	var y1 := maxi(r.position.y, r.end.y - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if outline and x != x0 and x != x1 and y != y0 and y != y1:
				continue
			set_cell(x, y, _stamp(cell(x, y), brush))


## `_` clears that slot. zform is applied only when the brush carries it.
func _stamp(dst: Dictionary, brush: Dictionary) -> Dictionary:
	var out := dst.duplicate()
	for key in ["front", "back", "stair", "diag", "water"]:
		if not brush.has(key):
			continue
		var v := str(brush[key])
		if v == "_":
			out[key] = ""
		elif v != "":
			out[key] = v
	if brush.has("zform"):
		out.zform = int(brush.zform)
	return out


func copy_room(from_name: String, to_name: String) -> bool:
	snapshot()
	var src: Dictionary = {}
	var dest_i := -1
	for i in rooms.size():
		var name := str(rooms[i].get("name", ""))
		if name == from_name:
			src = rooms[i]
		if name == to_name:
			dest_i = i
	if src.is_empty():
		return false
	var copy: Dictionary = src.duplicate(true)
	copy["name"] = to_name
	if dest_i >= 0:
		var old: Dictionary = rooms[dest_i]
		for axis in ["x", "y", "z"]:
			if old.has(axis):
				copy[axis] = old[axis]
			else:
				copy.erase(axis)
		rooms[dest_i] = copy
	else:
		rooms.append(copy)
	dirty = true
	return true


func delete_room(name: String) -> bool:
	snapshot()
	for i in rooms.size():
		if str(rooms[i].get("name", "")) == name:
			rooms.remove_at(i)
			if room_i == i:
				room_i = -1
				grid.clear()
			elif room_i > i:
				room_i -= 1
			dirty = true
			return true
	return false


func xml_text() -> String:
	return Codec.xml_from_doc(to_dict())
