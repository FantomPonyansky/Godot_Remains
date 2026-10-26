extends RefCounted

## Lands.xml, objs.xml, Scripts.xml and Npcs.xml as extracted by
## tools/extract_lands.py. Values stay the raw XML strings.

const DIR := "res://assets/data/maps/"
## Dev-only stress land (tools/make_perf_arena.py; console 'arena'). Not in exports.
const PERF_ARENA := {
	"id": "perf_arena", "dif": "15", "biom": "3", "file": "rooms_perf_arena", "locx": "0", "locy": "0",
	"stage": "0", "tip": "story", "scr": [], "probs": [],
	"options": {"backwall": "tWindows", "fon": "fonRuins", "music": "music_mane_1", "darkness": "-20"},
}

static var _lands: Dictionary = {}
static var _order: Array = []
static var _objs: Dictionary = {}
static var _scripts: Dictionary = {}
static var _npcs: Dictionary = {}
static var _units: Dictionary = {}
static var _aliases: Dictionary = {}
static var _combat: Dictionary = {}
static var _loaded := false


static func ids() -> Array:
	_ensure()
	return _order.duplicate()


static func land(id: String) -> Dictionary:
	_ensure()
	return _lands.get(id, {})


static func obj(id: String) -> Dictionary:
	_ensure()
	return _objs.get(id, {})


static func script(id: String) -> Dictionary:
	_ensure()
	return _scripts.get(id, {})


static func npc(id: String) -> Dictionary:
	_ensure()
	return _npcs.get(id, {})


static func prob(land_id: String, prob_id: String) -> Dictionary:
	for row_v in land(land_id).get("probs", []):
		var row: Dictionary = row_v
		if str(row.get("id", "")) == prob_id:
			return row
	for row_v in land("prob").get("probs", []):
		var row: Dictionary = row_v
		if str(row.get("id", "")) == prob_id:
			return row
	return {}


## enemies.json: sprite sheet and port AI row.
static func unit_row(id: String) -> Dictionary:
	_ensure()
	if _units.has(id):
		return _units[id]
	var alt := str(_aliases.get(id, ""))
	return _units.get(alt, {})


## enemy_combat.json: units.xml stats only.
static func has_stats(id: String) -> bool:
	_ensure()
	return _combat.has(id) or _combat.has(str(_aliases.get(id, "")))


static func int_of(value, fallback: int = 0) -> int:
	if value == null:
		return fallback
	var text := str(value).strip_edges()
	if text.is_valid_int():
		return int(text)
	if text.is_valid_float():
		return int(float(text))
	return fallback


static func float_of(value, fallback: float = 0.0) -> float:
	if value == null:
		return fallback
	var text := str(value).strip_edges()
	if text.is_valid_float():
		return float(text)
	return fallback


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var lands := _read(DIR + "lands.json")
	_lands = lands.get("lands", {})
	_order = lands.get("order", [])
	if OS.is_debug_build() and FileAccess.file_exists("res://assets/data/maps/rooms/rooms_perf_arena.json"):
		_lands[PERF_ARENA.id] = PERF_ARENA
		_order.append(PERF_ARENA.id)
	_objs = _read(DIR + "objs.json")
	_scripts = _read(DIR + "scripts.json")
	_npcs = _read(DIR + "npcs.json")
	var units := _read("res://assets/data/enemies.json")
	_units = units.get("units", {})
	_aliases = units.get("aliases", {})
	_combat = _read("res://assets/data/enemy_combat.json").get("units", {})


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("missing %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("bad %s" % path)
		return {}
	return parsed
