extends RefCounted

## units.xml massa (massafix first, /50), levit (0 = telekinesis cannot lift it)
## and levit_max (ticks a lifted unit takes to break free; 0 = never).

const PATH := "res://assets/data/unit_massa.json"

static var _units: Dictionary = {}
static var _loaded := false


static func row(node: Node) -> Dictionary:
	if not _loaded:
		_load()
	var id := ""
	if node.has_meta("unit_id"):
		id = str(node.get_meta("unit_id"))
	if id == "" and "_species_id" in node:
		id = str(node.get("_species_id"))
	var found: Variant = _units.get(id.to_lower(), {})
	return found if found is Dictionary else {}


static func massa(node: Node) -> float:
	return float(row(node).get("massa", 1.0))


static func massa_of(id: String) -> float:
	if not _loaded:
		_load()
	var found: Variant = _units.get(id.to_lower(), {})
	return float((found as Dictionary).get("massa", 1.0)) if found is Dictionary else 1.0


static func _load() -> void:
	_loaded = true
	if not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		var units: Variant = (parsed as Dictionary).get("units", {})
		if units is Dictionary:
			_units = units
