extends RefCounted

## One file per Rooms/*.xml document.
## godot/assets/data/maps/rooms/<file>.json
##
## A room is {name, x?, y?, z?, options, doors?, rows[25], objs[], pools?}.
## objs entries the builder edits: kind "loot" (a container) or kind "up"
## (enl1 / enl2 / enf1 / enc1 / lov). Other objects stay in objs so a save
## does not drop them. doors is 22 ints. Missing doors means the generator
## treats every slot as 2, matching Location.buildLoc.

const DIR := "res://assets/data/maps/rooms"
const COLS := 48
const ROWS := 25
const Codec := preload("res://scripts/editor/room_codec.gd")
## mods/rooms/_disabled.json is {"disabled": [stem, ...]}. load_doc skips those overlays.
const DISABLED := "_disabled.json"

static var _cache: Dictionary = {}
## Survives drop_cache so a play-test one-room doc is still there after enter_land.
static var _hold: Dictionary = {}
## land id -> [{file, name, room}] from enabled mod files. Dropped with the cache and on save.
static var _pool_by: Dictionary = {}
static var _pool_ready := false


static func drop_cache() -> void:
	_cache.clear()
	_drop_pools()
	for k in _hold:
		_cache[k] = _hold[k]


static func prime(file_name: String, doc: Dictionary) -> void:
	_cache[file_name] = doc
	_drop_pools()


static func hold(file_name: String, doc: Dictionary) -> void:
	_hold[file_name] = doc
	_cache[file_name] = doc
	_drop_pools()


static func release() -> void:
	_hold.clear()


static func mods_dir() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		var ud := tree.root.get_node_or_null("/root/UserDir")
		if ud != null and ud.has_method("mods_rooms"):
			return str(ud.call("mods_rooms"))
	return "user://mods/rooms/"


static func _mod_path(file_name: String) -> String:
	return mods_dir().path_join(file_name + ".json")


static func _disabled_path() -> String:
	return mods_dir().path_join(DISABLED)


static func mod_enabled(file_name: String) -> bool:
	for n in _read(_disabled_path()).get("disabled", []):
		if str(n) == file_name:
			return false
	return true


static func set_mod_enabled(file_name: String, on: bool) -> void:
	var names: Array = []
	for n in _read(_disabled_path()).get("disabled", []):
		var s := str(n)
		if s != "" and s != file_name:
			names.append(s)
	if not on and file_name != "":
		names.append(file_name)
	var path := _disabled_path()
	if names.is_empty():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	else:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			return
		f.store_string(JSON.stringify({"disabled": names}))
		f.close()
	_cache.erase(file_name)
	_drop_pools()


static func has_mod(file_name: String) -> bool:
	return FileAccess.file_exists(_mod_path(file_name))


static func delete_mod(file_name: String) -> String:
	return _remove_mod(file_name)


static func file_names() -> Array:
	var index: Dictionary = _read("%s/index.json" % DIR)
	var files: Array = index.get("files", [])
	var dir := mods_dir()
	var abs := ProjectSettings.globalize_path(dir)
	# Top-level files only. get_files_at skips subfolders, so mods/rooms/_autosave/ is not a mod.
	if DirAccess.dir_exists_absolute(abs):
		for f in DirAccess.get_files_at(dir):
			var stem := str(f).get_basename()
			if str(f).ends_with(".json") and stem != "index" and not stem.begins_with("_") and not files.has(stem):
				files.append(stem)
	return files


static func load_doc(file_name: String) -> Dictionary:
	if _cache.has(file_name):
		return _cache[file_name]
	var doc := _read("%s/%s.json" % [DIR, file_name])
	if mod_enabled(file_name):
		var mod := _read(_mod_path(file_name))
		if not mod.is_empty():
			doc = _overlay(doc, mod)
	if doc.is_empty():
		return {}
	_cache[file_name] = doc
	return doc


## Player file wins per room name. `remove` drops rooms. A file with no built-in base is used as-is.
static func _overlay(base: Dictionary, mod: Dictionary) -> Dictionary:
	if base.is_empty():
		return mod
	var out: Dictionary = base.duplicate(true)
	for key in mod.keys():
		if key == "rooms" or key == "remove" or key == "file" or key == "source" or key == "base":
			continue
		out[key] = mod[key]
	var rooms: Array = out.get("rooms", [])
	var by := {}
	for i in rooms.size():
		by[str(rooms[i].get("name", ""))] = i
	for name in mod.get("remove", []):
		var key := str(name)
		if by.has(key):
			rooms.remove_at(int(by[key]))
			by.clear()
			for i in rooms.size():
				by[str(rooms[i].get("name", ""))] = i
	for room_v in mod.get("rooms", []):
		var key := str(room_v.get("name", ""))
		if by.has(key):
			rooms[int(by[key])] = room_v
		else:
			rooms.append(room_v)
	out["rooms"] = rooms
	out["base"] = str(mod.get("base", out.get("file", "")))
	return out


## Mods file is a delta against the built-in document: changed or new rooms,
## `remove` for built-in names the user deleted, and top-level fields that differ.
## Integral floats match ints. A doors row equal to doors_from_rows of the built-in
## rows is not a change. pools is a normal room field, so a pools edit is a changed room.
## An empty delta deletes the mod file, unless that file is
## disabled (the overlay stays on disk). `to_mods` false writes the whole document.
static func save_doc(file_name: String, doc: Dictionary, to_mods: bool = true) -> String:
	doc = doc.duplicate(true)
	doc.erase("origin")
	for room_v in doc.get("rooms", []):
		if room_v is Dictionary:
			(room_v as Dictionary).erase("origin")
			(room_v as Dictionary).erase("_origin_file")
			(room_v as Dictionary).erase("_pair")
	var path := _mod_path(file_name) if to_mods else "%s/%s.json" % [DIR, file_name]
	var body: Dictionary
	if to_mods:
		body = _delta(file_name, doc)
		if body.is_empty():
			if not mod_enabled(file_name):
				_cache.erase(file_name)
				_drop_pools()
				return ""
			return _remove_mod(file_name)
	else:
		body = doc.duplicate(true)
		body["file"] = file_name
	var abs := ProjectSettings.globalize_path(path.get_base_dir())
	DirAccess.make_dir_recursive_absolute(abs)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return "cannot write %s (%s)" % [path, error_string(FileAccess.get_open_error())]
	f.store_string(JSON.stringify(body))
	var err := f.get_error()
	f.close()
	if err != OK:
		return "cannot write %s (%s)" % [path, error_string(err)]
	_cache.erase(file_name)
	_drop_pools()
	return ""


static func _norm_value(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			var n := int(v)
			if is_equal_approx(float(v), float(n)):
				return n
			return v
		TYPE_ARRAY:
			var src: Array = v
			var out: Array = []
			for item in src:
				out.append(_norm_value(item))
			return out
		TYPE_DICTIONARY:
			var src_d: Dictionary = v
			var out_d := {}
			for k in src_d.keys():
				out_d[k] = _norm_value(src_d[k])
			return out_d
	return v


## Doors that are only the editor's recomputation of the built-in walls are not an edit.
static func _same_room(edited: Dictionary, base: Dictionary) -> bool:
	var a: Dictionary = _norm_value(edited)
	var b: Dictionary = _norm_value(base)
	if a.get("doors") is Array:
		var derived: Array = _norm_value(Codec.doors_from_rows(base.get("rows", [])))
		if a["doors"] == derived:
			a.erase("doors")
			b.erase("doors")
	return a == b


static func _delta(file_name: String, doc: Dictionary) -> Dictionary:
	var base := _read("%s/%s.json" % [DIR, file_name])
	if base.is_empty():
		var whole: Dictionary = doc.duplicate(true)
		whole["file"] = file_name
		whole["base"] = file_name
		whole["source"] = "mod"
		return whole
	var out := {}
	for key in doc.keys():
		if key == "rooms" or key == "file" or key == "source" or key == "base" or key == "remove" or key == "origin":
			continue
		if not base.has(key) or _norm_value(doc[key]) != _norm_value(base[key]):
			out[key] = doc[key]
	var by := {}
	for room_v in base.get("rooms", []):
		by[str(room_v.get("name", ""))] = room_v
	var seen := {}
	var rooms: Array = []
	for room_v in doc.get("rooms", []):
		var name := str(room_v.get("name", ""))
		seen[name] = true
		if not by.has(name) or not _same_room(room_v, by[name]):
			rooms.append(room_v)
	var remove: Array = []
	for room_v in base.get("rooms", []):
		var name := str(room_v.get("name", ""))
		if name != "" and not seen.has(name):
			remove.append(name)
	if not rooms.is_empty():
		out["rooms"] = rooms
	if not remove.is_empty():
		out["remove"] = remove
	if out.is_empty():
		return {}
	out = out.duplicate(true)
	out["file"] = file_name
	out["base"] = file_name
	out["source"] = "mod"
	return out


static func _remove_mod(file_name: String) -> String:
	var path := _mod_path(file_name)
	if not FileAccess.file_exists(path):
		_cache.erase(file_name)
		_drop_pools()
		return ""
	var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if err != OK:
		return "cannot delete %s (%s)" % [path, error_string(err)]
	_cache.erase(file_name)
	_drop_pools()
	return ""


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
	_drop_pools()
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


static func _drop_pools() -> void:
	_pool_ready = false
	_pool_by.clear()


static func _mods_live() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	return tree != null and tree.root.get_node_or_null("/root/UserDir") != null


## [{id, name, file}] for every generated land a room can join.
static func random_lands() -> Array:
	var gen = load("res://scripts/map/land_gen.gd")
	var lines = load("res://scripts/original_lines.gd")
	var out: Array = []
	for land_id in gen.GENERATED:
		var spec: Dictionary = gen.GENERATED[land_id]
		var id := str(land_id)
		var name := str(lines.text("map", id))
		if name == "":
			name = id
		out.append({"id": id, "name": name, "file": str(spec.get("file", ""))})
	return out


## Extra user rooms whose pools name this land. Each entry is {file, name}.
static func pool_rooms(land_id: String) -> Array:
	var out: Array = []
	for row_v in _pool_entries(land_id):
		var row: Dictionary = row_v
		out.append({"file": str(row.get("file", "")), "name": str(row.get("name", ""))})
	return out


static func _pool_entries(land_id: String) -> Array:
	_ensure_pools()
	var list = _pool_by.get(land_id, [])
	return list if list is Array else []


static func _ensure_pools() -> void:
	if _pool_ready:
		return
	_pool_ready = true
	var names := {}
	var live := _mods_live()
	if live:
		for f in file_names():
			var stem := str(f)
			if has_mod(stem):
				names[stem] = true
	for k in _cache.keys():
		names[str(k)] = true
	for k in _hold.keys():
		names[str(k)] = true
	var seen := {}
	for stem_v in names.keys():
		var stem := str(stem_v)
		if live and not mod_enabled(stem):
			continue
		var doc := load_doc(stem)
		for room_v in doc.get("rooms", []):
			if typeof(room_v) != TYPE_DICTIONARY:
				continue
			var pools_v = room_v.get("pools", null)
			if not (pools_v is Array):
				continue
			var room_name := str(room_v.get("name", ""))
			for land_v in pools_v:
				var land_id := str(land_v).strip_edges()
				if land_id == "":
					continue
				var key := "%s\n%s\n%s" % [stem, room_name, land_id]
				if seen.has(key):
					continue
				seen[key] = true
				if not _pool_by.has(land_id):
					_pool_by[land_id] = []
				(_pool_by[land_id] as Array).append({"file": stem, "name": room_name, "room": room_v})


## Empty means the generator may draw this room. Anything else skips it.
static func check_pool_room(room: Dictionary, land_id: String) -> Array:
	var problems: Array = []
	var gen = load("res://scripts/map/land_gen.gd")
	if not gen.GENERATED.has(land_id):
		problems.append("unknown random land %s" % land_id)
	if str(room.get("name", "")).strip_edges() == "":
		problems.append("room has no name")
	var options := {}
	var options_ok := true
	if room.has("options") and typeof(room.get("options")) != TYPE_DICTIONARY:
		problems.append("options must be an object")
		options_ok = false
	else:
		options = room.get("options", {})
	var rows_ok := _row_problems(room, problems)
	_obj_problems(room, problems)
	if room.has("doors"):
		_door_problems(room, problems, rows_ok)
	if options_ok and gen.GENERATED.has(land_id):
		_fit_problems(gen, gen.GENERATED[land_id], options, problems)
	return problems


static func _row_problems(room: Dictionary, problems: Array) -> bool:
	var rows = room.get("rows", [])
	if not (rows is Array) or rows.size() != ROWS:
		problems.append("room needs 25 rows of 48 cells")
		return false
	for i in rows.size():
		if str(rows[i]).split(".").size() != COLS:
			problems.append("row %d is not 48 cells" % i)
			return false
	return true


static func _obj_problems(room: Dictionary, problems: Array) -> void:
	if not room.has("objs"):
		return
	var objs = room.get("objs")
	if not (objs is Array):
		problems.append("objs must be a list")
		return
	for obj_v in objs:
		if typeof(obj_v) != TYPE_DICTIONARY:
			problems.append("objs entries must be objects")
			return


static func _door_problems(room: Dictionary, problems: Array, rows_ok: bool) -> void:
	var doors = room.get("doors")
	if not (doors is Array) or doors.size() != 22:
		problems.append("doors must be 22 numbers")
		return
	for i in 22:
		if not _num(doors[i]):
			problems.append("doors must be 22 numbers")
			return
	if not rows_ok:
		return
	var got: Array = doors_from_tiles(room.get("rows", []))
	for i in 22:
		if int(doors[i]) != int(got[i]):
			problems.append("doors do not match the walls")
			return


static func _num(v) -> bool:
	var kind := typeof(v)
	if kind == TYPE_INT or kind == TYPE_FLOAT:
		return true
	if kind == TYPE_STRING:
		var text := str(v)
		return text.is_valid_int() or text.is_valid_float()
	return false


static func _fit_problems(gen, spec: Dictionary, options: Dictionary, problems: Array) -> void:
	var tip := str(options.get("tip", "")) if options.has("tip") else ""
	if tip != "" and gen.NORND.has(tip) and not _land_wants(spec, tip):
		problems.append("tip %s is not placed on this land" % tip)
	var caps := {4: 0, 7: 1, 10: 10}
	var conf := int(spec.get("conf", -1))
	if not caps.has(conf) or options.has("test"):
		return
	if tip != "" and _land_wants(spec, tip):
		return
	var lvl: int = int(gen._to_int(options.get("level", 0), 0))
	var cap := int(caps[conf])
	if lvl > cap:
		problems.append("level %d is above this land's cap of %d" % [lvl, cap])


static func _land_wants(spec: Dictionary, tip: String) -> bool:
	var conf := int(spec.get("conf", -1))
	var mx := int(spec.get("mx", 0))
	if conf == 0:
		if not tip.begins_with("beg"):
			return false
		var n := tip.trim_prefix("beg")
		return n.is_valid_int() and int(n) >= 0 and int(n) < mx
	var wanted := {
		1: ["beg0"],
		2: ["beg0"],
		3: ["passroof", "pass", "roof"],
		4: ["beg0", "vert", "end"],
		5: ["beg0", "surf"],
		7: ["beg1", "vert", "end1"],
		10: ["beg0", "roof"],
		11: ["pass"],
	}
	return tip in wanted.get(conf, [])
