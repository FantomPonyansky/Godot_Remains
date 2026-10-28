extends RefCounted

## Editor-only prefs in the Godot user dir. Never written into a room or map.

const Groups := preload("res://scripts/editor/editor_groups.gd")
const PATH := "user://editor_prefs.cfg"
const _EYE_KEYS: PackedStringArray = [
	"front", "back", "obj", "area", "water", "stair", "beam", "ladder", "backdrop",
	"stairs", "doors", "actors", "props",
]

static var _cfg: ConfigFile


static func _file() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.load(PATH)
	return _cfg


static func _save() -> void:
	_file().save(PATH)


static func fold_open(layer: String, group: String) -> bool:
	return bool(_file().get_value("fold", "%s/%s" % [layer, group], true))


static func set_fold(layer: String, group: String, open: bool) -> void:
	_file().set_value("fold", "%s/%s" % [layer, group], open)
	_save()


static func test_fon() -> String:
	return str(_file().get_value("test", "fon", ""))


static func set_test_fon(id: String) -> void:
	_file().set_value("test", "fon", id)
	_save()


static func layer_id(raw: String) -> String:
	if Groups.LAYERS.has(raw):
		return raw
	return str(Groups.LAYER_ALIAS.get(raw, "front"))


## New eye keys win. An older file maps water onto Fronts, stair/beam/ladder
## onto Stairs (shown if any of those eyes was on), and obj onto every object layer.
static func migrate_eyes(saved: Dictionary) -> Dictionary:
	var modern := saved.has("stairs") or saved.has("doors") or saved.has("actors") or saved.has("props")
	var eyes := {}
	for id_v in Groups.LAYERS:
		var id := str(id_v)
		if modern:
			eyes[id] = bool(saved.get(id, true))
			continue
		if id == "stairs":
			if saved.has("stair") or saved.has("beam") or saved.has("ladder"):
				eyes[id] = bool(saved.get("stair", true)) or bool(saved.get("beam", true)) or bool(saved.get("ladder", true))
			else:
				eyes[id] = true
		elif id == "doors" or id == "actors" or id == "props":
			eyes[id] = bool(saved.get("obj", true))
		else:
			eyes[id] = bool(saved.get(id, true))
	return eyes


static func view_get() -> Dictionary:
	var f := _file()
	var saved := {}
	for id in _EYE_KEYS:
		var key := "eye_%s" % id
		if f.has_section_key("view", key):
			saved[id] = bool(f.get_value("view", key))
	return {
		"tex": bool(f.get_value("view", "tex", false)),
		"ids": bool(f.get_value("view", "ids", false)),
		"layer": layer_id(str(f.get_value("view", "layer", "front"))),
		"zoom": float(f.get_value("view", "zoom", 1.0)),
		"pan_x": float(f.get_value("view", "pan_x", 0.0)),
		"pan_y": float(f.get_value("view", "pan_y", 0.0)),
		"pan_user": bool(f.get_value("view", "pan_user", false)),
		"eyes": migrate_eyes(saved),
	}


static func view_set(state: Dictionary) -> void:
	var f := _file()
	f.set_value("view", "tex", bool(state.get("tex", false)))
	f.set_value("view", "ids", bool(state.get("ids", false)))
	f.set_value("view", "layer", str(state.get("layer", "front")))
	f.set_value("view", "zoom", float(state.get("zoom", 1.0)))
	f.set_value("view", "pan_x", float(state.get("pan_x", 0.0)))
	f.set_value("view", "pan_y", float(state.get("pan_y", 0.0)))
	f.set_value("view", "pan_user", bool(state.get("pan_user", false)))
	var eyes: Variant = state.get("eyes", {})
	if eyes is Dictionary:
		for id in eyes.keys():
			f.set_value("view", "eye_%s" % str(id), bool(eyes[id]))
	_save()
