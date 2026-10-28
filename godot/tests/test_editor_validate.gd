extends SceneTree

## Same validators as the property windows, against every built-in rooms_*.json
## and land-row options. Warnings are printed and do not fail the run.
## godot --headless --path godot --user-dir %TEMP%\foe_editor_validate -s res://tests/test_editor_validate.gd

const DIR := "res://assets/data/maps/rooms"
const Rules := preload("res://scripts/editor/editor_rules.gd")
const Lands := preload("res://scripts/map/land_registry.gd")

var _err := {}
var _warn := {}
var _err_n := 0
var _warn_n := 0


func _init() -> void:
	var groups = load("res://scripts/editor/editor_groups.gd")
	if groups == null:
		_note("error", "load", "groups", "editor_groups failed to compile")
	elif int(groups.prepare()) != 0:
		_note("error", "layers", "gap", "uncovered objs.json id")
	for f in DirAccess.get_files_at(DIR):
		var name := str(f)
		if not name.begins_with("rooms_") or not name.ends_with(".json"):
			continue
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("%s/%s" % [DIR, name]))
		if not raw is Dictionary:
			_note("error", "file", name, "not a document")
			continue
		var doc: Dictionary = raw
		var opt: Variant = doc.get("options", {})
		if opt is Dictionary and not (opt as Dictionary).is_empty():
			_take("map:%s" % name.get_basename(), Rules.audit_map(opt))
		var rooms: Array = doc.get("rooms", [])
		for room_v in rooms:
			if not room_v is Dictionary:
				continue
			var room: Dictionary = room_v
			_take("%s/%s" % [name.get_basename(), room.get("name", "")], Rules.audit_room(room, rooms))
			for obj_v in room.get("objs", []):
				if not obj_v is Dictionary:
					continue
				var obj: Dictionary = obj_v
				if Rules.is_area(obj):
					_take("area", Rules.audit_area(obj, room))
				else:
					_take("obj", Rules.audit_object(obj, room))
	for id_v in Lands.ids():
		var row := Lands.land(str(id_v))
		var opt: Variant = row.get("options", {})
		if opt is Dictionary and not (opt as Dictionary).is_empty():
			_take("land:%s" % str(id_v), Rules.audit_map(opt))
	_storey_probe()
	_field_probe()
	_dump("errors", _err, _err_n)
	_dump("warnings", _warn, _warn_n)
	print("validate errors ", _err_n, " warnings ", _warn_n)
	quit(1 if _err_n > 0 else 0)


func _storey_probe() -> void:
	var Check = load("res://scripts/editor/editor_check.gd")
	var Files = load("res://scripts/map/room_file.gd")
	if Check == null or Files == null:
		_note("error", "load", "editor", "editor_check failed to compile")
		return
	var strings: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/port_strings.json"))
	if typeof(strings) != TYPE_DICTIONARY or not (strings as Dictionary).has("ed_restore_ask"):
		_note("error", "strings", "port", "autosave strings missing")
	var front := {"name": "front", "x": 1, "y": 2, "rows": _blank_rows(), "objs": []}
	var back := {"name": "back", "x": 1, "y": 2, "z": 1, "rows": _blank_rows(), "objs": []}
	if str(Check.partner(front, [front, back]).get("name", "")) != "back":
		_note("error", "storey", "pair", "z pair missing")
	var rnd := [
		{"name": "hall", "options": {"back": "hall_back"}, "rows": _blank_rows(), "objs": []},
		{"name": "hall_back", "options": {"tip": "back"}, "rows": _blank_rows(), "objs": []},
	]
	if str(Check.partner(rnd[0], rnd).get("name", "")) != "hall_back":
		_note("error", "storey", "back", "back link missing")
	var zbad: Array = Check.run({"rooms": [{"name": "zz", "z": 3, "rows": _blank_rows(), "objs": []}]})
	if zbad.is_empty() or str(zbad[0].get("text", "")) == "ok":
		_note("error", "storey", "z", "z check missing")
	var alone: Array = Check.run({"rooms": [{"name": "only", "rows": _blank_rows(), "objs": [
		{"tag": "obj", "id": "indoor1", "x": 2, "y": 3, "size": 2},
	]}]})
	if not _has_text(alone, "one-storey"):
		_note("error", "storey", "one", "one-storey door not flagged")
	var walled := _blank_rows()
	var parts: PackedStringArray = str(walled[2]).split(".")
	parts[2] = "C"
	walled[2] = ".".join(parts)
	var bad: Array = Check.run({"rooms": [
		{"name": "f", "x": 0, "y": 0, "rows": _blank_rows(), "objs": [
			{"tag": "obj", "id": "indoor1", "x": 2, "y": 3, "size": 2},
		]},
		{"name": "b", "x": 0, "y": 0, "z": 1, "rows": walled, "objs": [
			{"tag": "obj", "id": "indoor2", "x": 2, "y": 3, "size": 2},
		]},
	]})
	if not _has_text(bad, "another id") or not _has_text(bad, "blocked"):
		_note("error", "storey", "door", "twin or arrival check missing")
	var clean: Array = Check.run({"rooms": [{"name": "c", "rows": _blank_rows(), "objs": []}]})
	if not clean.is_empty():
		_note("error", "storey", "clean", "clean room reported %s" % str(clean.size()))
	var auto := "user://mods/rooms/_autosave"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(auto))
	var f := FileAccess.open(auto.path_join("probe_auto.json"), FileAccess.WRITE)
	if f == null:
		_note("error", "autosave", "write", "cannot write autosave")
		return
	f.store_string("{}")
	f.close()
	if Files.file_names().has("probe_auto"):
		_note("error", "autosave", "list", "autosave folder is listed as a mod")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(auto.path_join("probe_auto.json")))


const _AREA_FIELDS: PackedStringArray = [
	"w", "h", "vis", "tip", "mess", "down", "off", "allact", "allid", "trig", "scr", "scrout",
	"tilehp", "tileop", "tilethre", "grav", "norad", "emit", "dens", "port", "code", "uid",
]
const _SAMPLES: PackedStringArray = [
	"raider", "turret", "npc", "mine", "woodbox", "safe", "door1", "window1", "term",
	"knop1", "table1", "checkpoint", "moln1", "spikes",
]


func _field_probe() -> void:
	var demoted := {}
	var raw := {}
	for f in DirAccess.get_files_at(DIR):
		var name := str(f)
		if not name.begins_with("rooms_") or not name.ends_with(".json"):
			continue
		var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string("%s/%s" % [DIR, name]))
		if not doc is Dictionary:
			continue
		for room_v in (doc as Dictionary).get("rooms", []):
			if not room_v is Dictionary:
				continue
			for obj_v in (room_v as Dictionary).get("objs", []):
				if not obj_v is Dictionary:
					continue
				var obj: Dictionary = obj_v
				var id := str(obj.get("id", ""))
				var attrs: Variant = obj.get("attrs", {})
				if not attrs is Dictionary:
					continue
				var area := Rules.is_area(obj)
				for key_v in (attrs as Dictionary).keys():
					var key := str(key_v)
					if key in ["uid", "code"]:
						continue
					var shown := _AREA_FIELDS.has(key) if area else Rules.attr_on(id, key)
					if shown:
						continue
					var bag: Dictionary = demoted if (not area and Rules.is_field(key)) else raw
					if not bag.has(id):
						bag[id] = {}
					(bag[id] as Dictionary)[key] = true
	print("other-field")
	var ids: Array = demoted.keys()
	ids.sort()
	if ids.is_empty():
		print("  none")
	for id_v in ids:
		var keys: Array = (demoted[id_v] as Dictionary).keys()
		keys.sort()
		print("  ", id_v, " ", keys.size(), " ", " ".join(keys))
	var raw_ids: Array = raw.keys()
	raw_ids.sort()
	var raw_n := 0
	for id_v in raw_ids:
		raw_n += (raw[id_v] as Dictionary).size()
	print("other-raw ", raw_ids.size(), " ids ", raw_n, " keys")
	for id_v in raw_ids:
		var keys: Array = (raw[id_v] as Dictionary).keys()
		keys.sort()
		print("  ", id_v, " ", " ".join(keys))
	print("fields")
	for id_v in _SAMPLES:
		print("  ", id_v, ": ", ", ".join(Rules.field_list(str(id_v))))


func _has_text(items: Array, bit: String) -> bool:
	for item_v in items:
		if typeof(item_v) == TYPE_DICTIONARY and str((item_v as Dictionary).get("text", "")).findn(bit) >= 0:
			return true
	return false


func _blank_rows() -> Array:
	var parts := PackedStringArray()
	parts.resize(48)
	parts.fill("_")
	var row := ".".join(parts)
	var rows: Array = []
	for _i in 25:
		rows.append(row)
	return rows


func _take(where: String, rows: Array) -> void:
	for row_v in rows:
		if not row_v is Dictionary:
			continue
		var row: Dictionary = row_v
		var bag: Dictionary = _err if str(row.get("level", "")) == "error" else _warn
		if str(row.get("level", "")) == "error":
			_err_n += 1
		else:
			_warn_n += 1
		var field := str(row.get("field", ""))
		if not bag.has(field):
			bag[field] = {"n": 0, "ex": []}
		var slot: Dictionary = bag[field]
		slot.n = int(slot.n) + 1
		var ex: Array = slot.ex
		if ex.size() < 3:
			ex.append("%s %s = %s" % [where, row.get("msg", ""), row.get("value", "")])


func _note(level: String, field: String, where: String, msg: String) -> void:
	_take(where, [{"field": field, "level": level, "msg": msg, "value": ""}])


func _dump(title: String, bag: Dictionary, total: int) -> void:
	print(title, " ", total)
	var keys: Array = bag.keys()
	keys.sort()
	for field in keys:
		var slot: Dictionary = bag[field]
		print("  ", field, " ", int(slot.n))
		for line in slot.ex:
			print("    ", line)
