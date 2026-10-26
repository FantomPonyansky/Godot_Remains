extends RefCounted

## One file per Rooms/*.xml document.
## godot/assets/data/maps/rooms/<file>.json
##
## A room is {name, x?, y?, z?, options, doors?, rows[25], objs[]}.
## objs entries the builder edits: kind "loot" (a container) or kind "up"
## (enl1 / enl2 / enf1 / enc1 / lov). Other objects stay in objs so a save
## does not drop them. doors is 22 ints. Missing doors means the generator
## treats every slot as 2, matching Location.buildLoc.

const DIR := "res://assets/data/maps/rooms"
const COLS := 48
const ROWS := 25

static var _cache: Dictionary = {}


static func drop_cache() -> void:
	_cache.clear()


static func file_names() -> Array:
	var index: Dictionary = _read("%s/index.json" % DIR)
	var files: Array = index.get("files", [])
	return files


static func load_doc(file_name: String) -> Dictionary:
	if _cache.has(file_name):
		return _cache[file_name]
	var doc := _read("%s/%s.json" % [DIR, file_name])
	if doc.is_empty():
		return {}
	_cache[file_name] = doc
	return doc


static func save_room(file_name: String, room: Dictionary) -> String:
	var doc := load_doc(file_name)
	if doc.is_empty():
		return "missing %s" % file_name
	var rooms: Array = doc.get("rooms", [])
	var found := false
	var name := str(room.get("name", ""))
	for i in rooms.size():
		if str(rooms[i].get("name", "")) == name:
			rooms[i] = room
			found = true
			break
	if not found:
		rooms.append(room)
	doc["rooms"] = rooms
	var path := "%s/%s.json" % [DIR, file_name]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return "cannot write %s (%s)" % [path, error_string(FileAccess.get_open_error())]
	f.store_string(JSON.stringify(doc))
	f.close()
	_cache[file_name] = doc
	return ""


static func is_open_code(code: String) -> bool:
	if code.is_empty() or code.begins_with("_"):
		return true
	return code.unicode_at(0) <= 64


static func code_at(rows: Array, x: int, y: int) -> String:
	if y < 0 or y >= rows.size():
		return "A"
	var parts: PackedStringArray = str(rows[y]).split(".")
	if x < 0 or x >= parts.size():
		return "A"
	return parts[x]


static func generator_mask(room: Dictionary) -> Array:
	var raw = room.get("doors", null)
	var mask: Array = []
	if raw is Array and not raw.is_empty():
		for i in 22:
			mask.append(int(raw[i]) if i < raw.size() else 0)
		return mask
	mask.resize(22)
	mask.fill(2)
	return mask


static func editor_mask(room: Dictionary) -> Array:
	var raw = room.get("doors", null)
	if raw is Array and not raw.is_empty():
		return generator_mask(room)
	return doors_from_tiles(room.get("rows", []))


static func mirror_mask(mask: Array) -> Array:
	var swapped: Array = mask.duplicate()
	_swap(swapped, 6, 10)
	_swap(swapped, 7, 9)
	_swap(swapped, 17, 21)
	_swap(swapped, 18, 20)
	for i in 6:
		_swap(swapped, i, i + 11)
	return swapped


static func mirror_rows(rows: Array) -> Array:
	var out: Array = []
	for row_v in rows:
		var parts: PackedStringArray = str(row_v).split(".")
		var flipped: PackedStringArray = PackedStringArray()
		flipped.resize(COLS)
		for x in COLS:
			var src := COLS - 1 - x
			flipped[x] = _mirror_code(parts[src]) if src < parts.size() else ""
		out.append(".".join(flipped))
	return out


## Ladder sides and stair directions swap (AllData mat @m).
static func _mirror_code(code: String) -> String:
	var out := ""
	for i in code.length():
		out += TileCatalog.mirror_char(code.substr(i, 1))
	return out


static func mirror_objs(objs: Array) -> Array:
	var out: Array = []
	for obj_v in objs:
		var copy: Dictionary = (obj_v as Dictionary).duplicate(true)
		if str(copy.get("tag", "obj")) == "obj":
			var sz := int(copy.get("size", 1))
			if sz < 1:
				sz = 1
			copy["x"] = COLS - int(copy.get("x", 0)) - sz
		out.append(copy)
	return out


static func doors_from_tiles(rows: Array) -> Array:
	var mask: Array = []
	for n in 22:
		mask.append(_door_width(rows, n))
	return mask


static func _door_width(rows: Array, n: int) -> int:
	var q := 0
	if n >= 17:
		q = (n - 17) * 9 + 4
		if _solid(rows, q + 1, 0) or _solid(rows, q + 2, 0) or _solid(rows, q + 1, 1) or _solid(rows, q + 2, 1):
			return 0
		if not _solid(rows, q, 0) and not _solid(rows, q + 3, 0) and not _solid(rows, q, 1) and not _solid(rows, q + 3, 1):
			return 4
		return 2
	if n >= 11:
		q = (n - 11) * 4 + 3
		if _solid(rows, 0, q) or _solid(rows, 0, q - 1) or _solid(rows, 1, q) or _solid(rows, 1, q - 1):
			return 0
		if not _solid(rows, 0, q - 2) and not _solid(rows, 1, q - 2):
			return 3
		return 2
	if n >= 6:
		q = (n - 6) * 9 + 4
		var bottom := ROWS - 1
		if _solid(rows, q + 1, bottom) or _solid(rows, q + 2, bottom) or _solid(rows, q + 1, bottom - 1) or _solid(rows, q + 2, bottom - 1):
			return 0
		if not _solid(rows, q, bottom) and not _solid(rows, q + 3, bottom) and not _solid(rows, q, bottom - 1) and not _solid(rows, q + 3, bottom - 1):
			return 4
		return 2
	q = n * 4 + 3
	var right := COLS - 1
	if _solid(rows, right, q) or _solid(rows, right, q - 1) or _solid(rows, right - 1, q) or _solid(rows, right - 1, q - 1):
		return 0
	if not _solid(rows, right, q - 2) and not _solid(rows, right - 1, q - 2):
		return 3
	return 2


static func _solid(rows: Array, x: int, y: int) -> bool:
	return not is_open_code(code_at(rows, x, y))


static func _swap(mask: Array, a: int, b: int) -> void:
	var tmp = mask[a]
	mask[a] = mask[b]
	mask[b] = tmp


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed
