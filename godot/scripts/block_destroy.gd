extends RefCounted

## weapons.json char_destroy. Weapon.destroy defaults to 10 when the field is absent.
## EMP ammo zeros it later, in the bullet.

const PATH := "res://assets/data/block_destroy.json"

static var _map: Dictionary = {}
static var _loaded := false


static func of(id: String) -> int:
	if id == "":
		return 0
	_load()
	if _map.has(id):
		return int(_map[id])
	return 10


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) == TYPE_DICTIONARY:
		_map = parsed
