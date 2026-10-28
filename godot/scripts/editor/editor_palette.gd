extends RefCounted

## AllData mat @ed groups. Ids match TileCatalog BLOCK / OVERLAY. Water is editor-only.

const FRONT: Array = [
	"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T",
]
const BACK: Array = [
	"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
]
const STAIR: Array = ["А", "Б"]
const DIAG: Array = [
	"-", "Д", "Е", "К", "Н", "Р",
	"В", "Г", "Ж", "З", "И", "Й", "Л", "М", "О", "П", "С", "Т",
]
## Right (/) then left (\). Same pairs as TileCatalog.MIRROR. Beams have none.
const DIAG_PAIRS: Array = [
	["В", "Г"], ["Ж", "З"], ["И", "Й"], ["Л", "М"], ["О", "П"], ["С", "Т"],
]
const Catalog := preload("res://scripts/map/tile_catalog.gd")
const WATER: Array = ["*"]
## Room options backwall. Same ids play_land paints (TileCatalog.file_for), plus sky.
const WALLS: Array = [
	"", "sky", "tBackWall", "tBlocks", "tBrick", "tCave", "tConRough", "tConcrete",
	"tConcreteDirt", "tDarkMetal", "tDirt", "tDirt2", "tEncl3", "tKaf", "tLeaking",
	"tMarble", "tMbase", "tMeh", "tMetalPlates", "tMetalPlates2", "tMoss", "tMossy",
	"tRivets", "tRust", "tShtuk", "tStConcrete", "tStPlates", "tSteklo", "tTiles",
	"tWindows", "tWood", "tWoodPlanks", "tTower", "tRustPlates",
]


static func diag_pairs() -> Array:
	return DIAG_PAIRS


## TileCatalog piece kind: "beam", "slope", or "".
static func diag_kind(token: String) -> String:
	var piece: Array = Catalog.OVERLAY.get(token, [])
	if piece.is_empty():
		return ""
	return str(piece[0])


static func beam_ids() -> Array:
	var out: Array = []
	for id_v in DIAG:
		var id := str(id_v)
		if diag_kind(id) == "beam":
			out.append(id)
	return out


static func slope_ids() -> Array:
	var out: Array = []
	for id_v in DIAG:
		var id := str(id_v)
		if diag_kind(id) == "slope":
			out.append(id)
	return out


static func tile_name(slot: String, id: String) -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return id
	var locale := tree.root.get_node_or_null("Locale")
	if locale == null:
		return id
	return str(locale.call("t", "ed_tile_%s_%s" % [slot, id], id))


static var _raw: Dictionary = {}


static func brush_for(slot: String, id: String, zform: int = -1) -> Dictionary:
	var b := {"front": "", "back": "", "stair": "", "diag": "", "water": ""}
	if slot != "" and id != "":
		b[slot] = id
	if zform >= 0:
		b["zform"] = zform
	return b


static func _table() -> Dictionary:
	if not _raw.is_empty():
		return _raw
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/maps/objs.json"))
	if typeof(data) == TYPE_DICTIONARY:
		_raw = data
	return _raw


## size from objs.json. kind is "up" (tip) or "loot" (cont), same as the room import.
static func object_meta(id: String) -> Dictionary:
	var row: Dictionary = _table().get(id, {})
	var size := int(str(row.get("size", "1")))
	if size < 1:
		size = 1
	var kind := ""
	if str(row.get("tip", "")) == "up":
		kind = "up"
	elif str(row.get("cont", "")) != "":
		kind = "loot"
	var wid := int(str(row.get("wid", row.get("height", "1"))))
	if wid < 1:
		wid = 1
	return {"size": size, "wid": wid, "kind": kind, "allact": str(row.get("allact", ""))}


static func wall_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for id_v in WALLS:
		var id := str(id_v)
		if id != "" and id != "sky" and file_for_wall(id) == "":
			continue
		out.append(id)
	return out


static func file_for_wall(id: String) -> String:
	return Catalog.file_for(id)


static func wall_label(id: String) -> String:
	var key := "ed_wall_default" if id == "" else "ed_wall_%s" % id
	return _locale(key, id if id != "" else key)


static func music_ids() -> PackedStringArray:
	var names: Array = []
	for f in DirAccess.get_files_at("res://assets/music"):
		var s := str(f)
		if s.ends_with(".mp3"):
			names.append(s.get_basename())
	names.sort()
	return PackedStringArray(names)


static var _backs: PackedStringArray = PackedStringArray()


static func back_ids() -> PackedStringArray:
	if not _backs.is_empty():
		return _backs
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/backs.json"))
	if typeof(data) != TYPE_DICTIONARY:
		return _backs
	var kinds: Dictionary = (data as Dictionary).get("kinds", {})
	var ids: Array = kinds.keys()
	ids.sort()
	_backs = PackedStringArray(ids)
	return _backs


static func _locale(key: String, fallback: String) -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return fallback
	var locale := tree.root.get_node_or_null("Locale")
	if locale == null:
		return fallback
	return str(locale.call("t", key, fallback))


static func objs() -> Array:
	var data := _table()
	if data.is_empty():
		return []
	var out: Array = []
	for id in data.keys():
		var row: Dictionary = data[id]
		if str(id) == "area":
			continue
		var ed := int(str(row.get("ed", "0")))
		if ed <= 0:
			continue
		out.append({"id": str(id), "ed": ed, "ico": str(row.get("ico", "")), "size": int(str(row.get("size", "1"))), "wid": int(str(row.get("wid", "0"))), "n": str(row.get("n", id))})
	out.sort_custom(func(a, b): return int(a.ed) < int(b.ed) or (int(a.ed) == int(b.ed) and str(a.id) < str(b.id)))
	return out
