extends RefCounted

## One id, one layer. Tiles come from the palette lists. Objects come from
## objs.json `ed`, with the explicit id lists winning over `ed`.
## An ed>0 id that matches none of these rules is still placed (by ed) and
## printed once: EDITOR LAYER GAP. That line should stay absent.

const Palette := preload("res://scripts/editor/editor_palette.gd")

const LAYERS: PackedStringArray = [
	"front", "back", "stairs", "doors", "actors", "props", "area", "backdrop",
]
const LAYER_ALIAS := {
	"water": "front",
	"stair": "stairs",
	"beam": "stairs",
	"ladder": "stairs",
	"obj": "doors",
}
const SUBS := {
	"doors": ["doors", "windows", "barriers", "storey", "exits"],
	"actors": ["enemies", "npc", "traps"],
	"props": ["containers", "terminals", "work", "mech"],
	"stairs": ["stairs", "beams", "ladders"],
}
const WINDOWS: PackedStringArray = ["window1", "window2"]
const BARRIERS: PackedStringArray = [
	"septum", "grate", "hgrate", "enclpole", "alib1", "alib2", "platform1",
]
const STOREY: PackedStringArray = [
	"indoor1", "indoor2", "indoor3", "indoor4",
	"instdoor", "inbasedoor", "inencldoor", "door_st1", "door_st2",
]
const DOOR8: PackedStringArray = ["aaa", "tomb"]
const TERMINALS: PackedStringArray = ["term", "term1", "term2", "term3", "termh", "elpanel"]
const WORK: PackedStringArray = [
	"work", "himlab", "stove", "p_luna", "barst", "smotr", "camp", "brspr", "reactor",
]
const MECH: PackedStringArray = [
	"knop1", "knop2", "knop3", "knop4", "platform2", "platform3",
	"dsph", "detonator", "robocell", "alarm", "generat",
]
## ed -> [layer, subgroup]. ed 8 is not a blanket rule (only DOOR8 and STOREY).
const ED_GROUP := {
	1: ["props", "containers"],
	2: ["props", "containers"],
	3: ["props", "containers"],
	4: ["props", "mech"],
	5: ["props", "work"],
	6: ["doors", "doors"],
	7: ["doors", "doors"],
	8: ["doors", "doors"],
	9: ["doors", "exits"],
	11: ["doors", "exits"],
	12: ["actors", "npc"],
	13: ["actors", "enemies"],
	14: ["actors", "enemies"],
	15: ["actors", "enemies"],
	16: ["actors", "enemies"],
	17: ["actors", "enemies"],
	18: ["actors", "traps"],
	19: ["actors", "traps"],
}

static var _groups: Dictionary = {}
static var _explicit: Dictionary = {}
static var _by_id: Dictionary = {}
static var _gaps: Dictionary = {}


static func prepare() -> int:
	_ensure()
	return _gaps.size()


static func for_layer(layer: String) -> Array:
	_ensure()
	return _groups.get(layer, [])


static func obj_layer(obj: Dictionary) -> String:
	if str(obj.get("tag", "obj")) == "back":
		return "backdrop"
	var id := str(obj.get("id", ""))
	if id == "area":
		return "area"
	_ensure()
	var row: Dictionary = _by_id.get(id, {})
	var layer := str(row.get("layer", ""))
	if layer == "":
		return "props"
	return layer


static func natural_less(a: String, b: String) -> bool:
	var ia := 0
	var ib := 0
	while ia < a.length() and ib < b.length():
		var da := _digit(a, ia)
		var db := _digit(b, ib)
		if da and db:
			var na := 0
			while ia < a.length() and _digit(a, ia):
				na = na * 10 + int(a.substr(ia, 1))
				ia += 1
			var nb := 0
			while ib < b.length() and _digit(b, ib):
				nb = nb * 10 + int(b.substr(ib, 1))
				ib += 1
			if na != nb:
				return na < nb
			continue
		var ca := a.unicode_at(ia)
		var cb := b.unicode_at(ib)
		if ca != cb:
			return ca < cb
		ia += 1
		ib += 1
	return a.length() < b.length()


static func _digit(s: String, i: int) -> bool:
	var c := s.unicode_at(i)
	return c >= 48 and c <= 57


static func _ensure() -> void:
	if not _groups.is_empty():
		return
	_bind_lists()
	var bag := {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/maps/objs.json"))
	var rows: Dictionary = data if data is Dictionary else {}
	for id_v in rows.keys():
		var id := str(id_v)
		var row: Dictionary = rows[id_v]
		var ed := int(str(row.get("ed", "0")))
		if ed <= 0:
			continue
		var place := _classify(id, ed)
		_by_id[id] = place
		var layer := str(place.get("layer", ""))
		var sub := str(place.get("sub", ""))
		if layer == "" or layer == "area" or sub == "":
			continue
		var key := "%s/%s" % [layer, sub]
		if not bag.has(key):
			bag[key] = []
		(bag[key] as Array).append(id)
	for layer_v in ["doors", "actors", "props"]:
		_groups[str(layer_v)] = _pack_subs(str(layer_v), bag)
	var fronts: Array = []
	for id_v in Palette.FRONT:
		fronts.append(str(id_v))
	fronts.append("*")
	_groups["front"] = [{"name": "", "items": _sorted(fronts), "flat": true}]
	var backs: Array = []
	for id_v in Palette.BACK:
		backs.append(str(id_v))
	_groups["back"] = [{"name": "", "items": _sorted(backs), "flat": true}]
	_groups["stairs"] = [
		{"name": "stairs", "items": _sorted(Palette.slope_ids())},
		{"name": "beams", "items": _sorted(Palette.beam_ids())},
		{"name": "ladders", "items": _sorted(_as_array(Palette.STAIR))},
	]
	var arts: Array = []
	for id_v in Palette.back_ids():
		arts.append(str(id_v))
	_groups["backdrop"] = [{"name": "", "items": _sorted(arts), "flat": true}]
	_groups["area"] = []


static func _as_array(ids: Array) -> Array:
	var out: Array = []
	for id_v in ids:
		out.append(str(id_v))
	return out


static func _pack_subs(layer: String, bag: Dictionary) -> Array:
	var order: Array = SUBS.get(layer, [])
	var seen := {}
	var out: Array = []
	for sub_v in order:
		var sub := str(sub_v)
		seen[sub] = true
		var items: Array = bag.get("%s/%s" % [layer, sub], [])
		if items.is_empty():
			continue
		out.append({"name": sub, "items": _sorted(items)})
	var extra: Array = []
	var prefix := layer + "/"
	for key_v in bag.keys():
		var key := str(key_v)
		if not key.begins_with(prefix):
			continue
		var sub := key.substr(prefix.length())
		if seen.has(sub):
			continue
		extra.append(sub)
	extra.sort_custom(func(a, b): return natural_less(str(a), str(b)))
	for sub_v in extra:
		var sub := str(sub_v)
		out.append({"name": sub, "items": _sorted(bag["%s/%s" % [layer, sub]])})
	return out


static func _sorted(ids: Array) -> Array:
	var out: Array = ids.duplicate()
	out.sort_custom(func(a, b): return natural_less(str(a), str(b)))
	return out


static func _bind_lists() -> void:
	if not _explicit.is_empty():
		return
	_bind(WINDOWS, "doors", "windows")
	_bind(BARRIERS, "doors", "barriers")
	_bind(STOREY, "doors", "storey")
	_bind(DOOR8, "doors", "doors")
	_bind(TERMINALS, "props", "terminals")
	_bind(WORK, "props", "work")
	_bind(MECH, "props", "mech")


static func _bind(ids: PackedStringArray, layer: String, sub: String) -> void:
	for id_v in ids:
		var id := str(id_v)
		if _explicit.has(id):
			_gap(id, -1)
			continue
		_explicit[id] = {"layer": layer, "sub": sub}


static func _ed_covered(ed: int) -> bool:
	return ed >= 1 and ed <= 19 and ed != 8 and ed != 10


static func _classify(id: String, ed: int) -> Dictionary:
	if _explicit.has(id):
		return _explicit[id]
	if id == "area":
		return {"layer": "area", "sub": ""}
	if _ed_covered(ed):
		var pair: Array = ED_GROUP[ed]
		return {"layer": str(pair[0]), "sub": str(pair[1])}
	var layer := "props"
	var sub := "ed%d" % ed
	if ed == 8:
		layer = "doors"
		sub = "doors"
	_gap(id, ed)
	return {"layer": layer, "sub": sub}


static func _gap(id: String, ed: int) -> void:
	if _gaps.has(id):
		return
	_gaps[id] = true
	print("EDITOR LAYER GAP: %s ed=%s" % [id, ed])
