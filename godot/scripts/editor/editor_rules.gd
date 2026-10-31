extends RefCounted

## Shared field checks for the property windows and the headless audit.
## Messages are keys until bind() points them at Locale.

const Palette := preload("res://scripts/editor/editor_palette.gd")
const Codec := preload("res://scripts/editor/room_codec.gd")
const Catalog := preload("res://scripts/map/tile_catalog.gd")
const Reg := preload("res://scripts/map/land_registry.gd")

const COLS := 48
const ROWS := 25
const TIPS: Array = [
	["", "ed_tip_any"], ["uniq", "ed_tip_uniq"], ["beg0", "ed_tip_beg0"], ["back", "ed_tip_back"],
	["roof", "ed_tip_roof"], ["pass", "ed_tip_pass"], ["passroof", "ed_tip_passroof"],
	["roofpass", "ed_tip_roofpass"], ["vert", "ed_tip_vert"], ["surf", "ed_tip_surf"],
	["beg1", "ed_tip_beg1"], ["beg2", "ed_tip_beg2"], ["beg3", "ed_tip_beg3"],
	["end", "ed_tip_end"], ["end1", "ed_tip_end1"],
]
const ENTIP: Array = [
	["", "ed_entip_biome"], ["0", "ed_entip_0"], ["1", "ed_entip_1"], ["2", "ed_entip_2"],
	["3", "ed_entip_3"], ["4", "ed_entip_4"], ["5", "ed_entip_5"], ["6", "ed_entip_6"],
	["7", "ed_entip_7"], ["8", "ed_entip_8"], ["9", "ed_entip_9"], ["10", "ed_entip_10"],
	["11", "ed_entip_11"],
]
const WTIP: Array = [["", "ed_wtip_land"], ["0", "ed_wtip_0"], ["1", "ed_wtip_1"], ["2", "ed_wtip_2"], ["3", "ed_wtip_3"]]
const LON: Array = [["", "ed_lon_own"], ["1", "ed_lon_on"], ["-1", "ed_lon_off"], ["0", "ed_lon_0"]]
const AREA_TIP: Array = [["", "ed_area_tip_gg"], ["en", "ed_area_tip_en"]]
const VIS_IDS: PackedStringArray = ["lift", "port", "necr", "jmp"]
const LOCKTIP: Array = [
	["", "ed_obj_default"], ["0", "ed_locktip_0"], ["1", "ed_locktip_1"], ["2", "ed_locktip_2"],
	["3", "ed_locktip_3"], ["4", "ed_locktip_4"], ["5", "ed_locktip_5"],
]
const KEYLOSS: Array = [["", "ed_obj_default"], ["1", "ed_keyloss_1"], ["2", "ed_keyloss_2"]]
const MINETIP: Array = [["", "ed_obj_default"], ["3", "ed_mine_3"], ["6", "ed_mine_6"]]
const INTER: Array = [
	["", "ed_obj_default"], ["0", "ed_inter_0"], ["1", "ed_inter_1"], ["2", "ed_inter_2"],
	["4", "ed_inter_4"], ["5", "ed_inter_5"], ["8", "ed_inter_8"], ["12", "ed_inter_12"],
]
const TURN: Array = [["", "ed_obj_default"], ["-1", "ed_turn_l"], ["1", "ed_turn_r"]]
const FRACTION: Array = [
	["", "ed_obj_default"], ["1", "ed_frac_1"], ["2", "ed_frac_2"],
	["4", "ed_frac_4"], ["100", "ed_frac_100"],
]
const FUN: Array = [["", "ed_obj_default"], ["generator", "ed_fun_gen"]]
const DOOR_KEYS: Array = [
	"lock", "locktip", "lockhp", "lockatt", "key", "keyloss", "hack", "mine", "minetip",
	"cont", "open", "autoclose", "inter", "time",
]
const UNIT_KEYS: Array = ["turn", "hpmult", "ai", "fraction", "weap", "qid", "unres", "tr", "emit"]
const USE_KEYS: Array = ["allact", "allid", "mess", "down", "fun"]
const OBJ_KEYS := {
	"id": 1, "uid": 1, "code": 1, "x": 1, "y": 1, "turn": 1, "hpmult": 1, "ai": 1,
	"unres": 1, "qid": 1, "fraction": 1, "tr": 1, "weap": 1, "emit": 1, "dig": 1,
	"vis": 1, "sr": 1, "st": 1, "lock": 1, "tele": 1, "open": 1, "cont": 1, "locktip": 1,
	"lockhp": 1, "lockatt": 1, "key": 1, "keyloss": 1, "mine": 1, "minetip": 1, "damage": 1,
	"hack": 1, "inter": 1, "time": 1, "autoclose": 1, "allid": 1, "allact": 1, "fun": 1,
	"fr": 1, "w": 1, "h": 1, "a": 1, "lon": 1, "off": 1, "mess": 1, "down": 1,
	"tilehp": 1, "tileop": 1, "grav": 1, "dens": 1, "port": 1, "kolammo": 1, "och": 1,
	"expl": 1, "multhp": 1, "trig": 1, "sign": 1, "noblock": 1, "observ": 1, "scr": 1,
	"prize": 1, "indestruct": 1, "npc": 1, "hero": 1, "light": 1, "name": 1,
	"phase": 1, "period": 1, "transm": 1, "rep": 1, "tipdam": 1, "ear": 1,
	"on": 1, "stay": 1, "noagro": 1, "f": 1, "fly": 1, "main": 1, "hide": 1,
	"red": 1, "nores": 1, "dx": 1, "cons": 1, "alarm": 1, "trigger": 1, "pole": 1,
	"dis": 1, "pokr": 1, "nobase": 1, "dammult": 1, "die": 1, "back": 1, "res": 1,
	"radrad": 1, "locklevel": 1, "noruna": 1, "sur": 1, "nodrop": 1, "fix": 1,
	"prob": 1, "invis": 1,
}
## k key, w which class shows it, r check|int|float|token|plain. Empty stays valid.
const OBJ_SPEC: Array = [
	{"k": "prize", "w": "boxcp", "r": "check"},
	{"k": "indestruct", "w": "box", "r": "check"},
	{"k": "light", "w": "light", "r": "check"},
	{"k": "name", "w": "name", "r": "token"},
	{"k": "phase", "w": "box", "r": "int", "lo": 0, "hi": 100000},
	{"k": "period", "w": "box", "r": "int", "lo": 0, "hi": 100000},
	{"k": "transm", "w": "box", "r": "check"},
	{"k": "tipdam", "w": "box", "r": "int", "lo": 0, "hi": 100},
	{"k": "pokr", "w": "box", "r": "check"},
	{"k": "radrad", "w": "box", "r": "int", "lo": 0, "hi": 100000},
	{"k": "sur", "w": "box", "r": "token"},
	{"k": "prob", "w": "box", "r": "token"},
	{"k": "cons", "w": "boxcp", "r": "token"},
	{"k": "nobase", "w": "boxcp", "r": "check"},
	{"k": "locklevel", "w": "boxcp", "r": "int", "lo": 0, "hi": 100},
	{"k": "noruna", "w": "boxcp", "r": "check"},
	{"k": "npc", "w": "npc", "r": "token"},
	{"k": "hero", "w": "unit", "r": "int", "lo": 0, "hi": 20},
	{"k": "ear", "w": "unit", "r": "float", "lo": 0.0, "hi": 100.0},
	{"k": "on", "w": "transm", "r": "check"},
	{"k": "stay", "w": "encl", "r": "check"},
	{"k": "noagro", "w": "unit", "r": "check"},
	{"k": "f", "w": "zavod", "r": "int", "lo": 0, "hi": 99},
	{"k": "fly", "w": "npc", "r": "check"},
	{"k": "main", "w": "cp", "r": "check"},
	{"k": "hide", "w": "cpnpc", "r": "check"},
	{"k": "red", "w": "zeb", "r": "check"},
	{"k": "nores", "w": "zeb", "r": "check"},
	{"k": "dx", "w": "hrail", "r": "int", "lo": -500, "hi": 500},
	{"k": "alarm", "w": "unit", "r": "token"},
	{"k": "trigger", "w": "unit", "r": "token"},
	{"k": "pole", "w": "ali", "r": "token"},
	{"k": "dis", "w": "unit", "r": "check"},
	{"k": "dammult", "w": "npc", "r": "float", "lo": 0.0, "hi": 100.0},
	{"k": "die", "w": "unit", "r": "check"},
	{"k": "back", "w": "indoor", "r": "plain"},
	{"k": "res", "w": "trig", "r": "plain"},
	{"k": "nodrop", "w": "raid", "r": "check"},
	{"k": "fix", "w": "train", "r": "check"},
	{"k": "invis", "w": "npc", "r": "check"},
	{"k": "rep", "w": "pon", "r": "token"},
	{"k": "tele", "w": "cp", "r": "check"},
	{"k": "multhp", "w": "unit", "r": "plain"},
	{"k": "trig", "w": "unit", "r": "plain"},
	{"k": "observ", "w": "unit", "r": "plain"},
	{"k": "sign", "w": "box", "r": "plain"},
	{"k": "off", "w": "box", "r": "check"},
	{"k": "scr", "w": "box", "r": "plain"},
	{"k": "sr", "w": "unit", "r": "plain"},
	{"k": "vis", "w": "unit", "r": "plain"},
	{"k": "dig", "w": "unit", "r": "check"},
	{"k": "fr", "w": "back", "r": "plain"},
	{"k": "w", "w": "back", "r": "plain"},
	{"k": "h", "w": "back", "r": "plain"},
	{"k": "a", "w": "back", "r": "plain"},
	{"k": "lon", "w": "back", "r": "plain"},
]
## Typed fields, in window order. A key is shown only when attr_on says this id reads it.
const FIELD_KEYS: PackedStringArray = [
	"lock", "locktip", "lockhp", "lockatt", "key", "keyloss", "hack", "mine", "minetip",
	"cont", "open", "autoclose", "inter", "time", "allact", "allid", "fun", "sign", "off", "scr",
	"turn", "tr", "hpmult", "multhp", "ai", "fraction", "weap", "qid", "unres",
	"hero", "ear", "name", "light", "npc", "fly", "hide", "dammult", "invis",
	"noagro", "dis", "die", "alarm", "trigger", "emit", "stay", "nodrop",
	"pole", "red", "nores", "rep", "res", "fix", "on", "sr", "vis", "dig", "trig", "observ",
	"prize", "indestruct", "phase", "period", "transm", "tipdam", "pokr", "radrad",
	"sur", "prob", "cons", "nobase", "locklevel", "noruna", "main", "tele", "back", "dx", "f",
	"fr", "w", "h", "a", "lon",
]
const _RAIDER: PackedStringArray = [
	"UnitRaider", "UnitSlaver", "UnitMerc", "UnitRanger", "UnitZebra", "UnitEncl",
]
const _TURRET: PackedStringArray = ["UnitTurret", "UnitThunderTurret"]
const _SKIP_UNIT: PackedStringArray = [
	"UnitTransmitter", "UnitTrigger", "UnitDamager", "UnitTrain", "UnitDestr",
]
## Placed ids whose catalog has no inter, but a shipped room sets inter and Interact is created.
const _INTER_EXTRA: PackedStringArray = ["box", "brspr", "camp", "couch", "mcrate2", "septum"]
const _ALLACT_EXTRA: PackedStringArray = ["wallsafe", "doorboss", "wires1"]
const _ALLID_EXTRA: PackedStringArray = ["alicorn", "hturret2", "potek", "pult", "wires1"]

static var locale_on := false
static var _tr: Callable = Callable()
static var _trf: Callable = Callable()
static var _script_ids: PackedStringArray = PackedStringArray()
static var _emits: PackedStringArray = PackedStringArray()
static var _weaps: PackedStringArray = PackedStringArray()


static func bind(tr: Callable, trf: Callable) -> void:
	_tr = tr
	_trf = trf
	locale_on = true


static func _loc(key: String) -> String:
	if locale_on:
		return str(_tr.call(key))
	return key


static func _locf(key: String, args: Array) -> String:
	if locale_on:
		return str(_trf.call(key, args))
	return key


static func is_area(obj: Dictionary) -> bool:
	return str(obj.get("id", "")) == "area" and str(obj.get("tag", "obj")) != "back"


static func _attrs(obj: Dictionary) -> Dictionary:
	var attrs: Variant = obj.get("attrs", {})
	return (attrs as Dictionary).duplicate(true) if attrs is Dictionary else {}


static func show_text(v) -> String:
	match typeof(v):
		TYPE_NIL:
			return ""
		TYPE_BOOL:
			return "1" if v else ""
		TYPE_INT:
			return str(v)
		TYPE_FLOAT:
			if is_nan(v) or not is_finite(v):
				return str(v)
			if is_equal_approx(v, round(v)) and absf(v) < 1.0e15:
				return str(int(round(v)))
			return str(v)
		_:
			var s := str(v)
			var whole := _parse_whole(s)
			if bool(whole.get("ok", false)) and s.find(".") >= 0:
				return str(int(whole.n))
			return s


static func show_port(v) -> String:
	var s := str(v)
	var parts := s.split(":")
	if parts.size() != 2:
		return s
	return "%s:%s" % [show_text(parts[0]), show_text(parts[1])]


static func _parse_whole(text: String) -> Dictionary:
	var s := text.strip_edges()
	if s.is_valid_int():
		return {"ok": true, "n": int(s)}
	if s.is_valid_float():
		var f := s.to_float()
		if is_finite(f) and is_equal_approx(f, round(f)):
			return {"ok": true, "n": int(round(f))}
	return {"ok": false, "n": 0}


static func _int_text(text: String, lo: int, hi: int, extra: PackedStringArray) -> String:
	if text == "":
		return ""
	if extra.has(text):
		return ""
	var whole := _parse_whole(text)
	if not bool(whole.get("ok", false)):
		return _loc("ed_bad_int")
	var n := int(whole.n)
	if n < lo or n > hi:
		return _locf("ed_bad_range", [lo, hi])
	return ""


static func _float_text(text: String, lo: float, hi: float) -> String:
	if text == "":
		return ""
	if not text.is_valid_float():
		return _loc("ed_bad_num")
	var n := float(text)
	if n < lo or n > hi:
		return _locf("ed_bad_range", [lo, hi])
	return ""


static func _in_ids(id: String, ids: PackedStringArray) -> bool:
	if ids.has(id):
		return true
	var fold := id.to_lower()
	for known in ids:
		if str(known).to_lower() == fold:
			return true
	return false


static func _ids_reason(id: String, ids: PackedStringArray, key := "") -> String:
	if id == "":
		return ""
	if _in_ids(id, ids):
		return ""
	if key == "weap":
		var base := id.split("^")[0]
		if base != id and _in_ids(base, ids):
			return ""
	return "~" + _loc("ed_bad_name")


static func _code_reason(text: String) -> String:
	if text == "":
		return ""
	if text.length() == 16 and _letter(text.substr(0, 1)):
		return ""
	return "~" + _loc("ed_bad_code")


static func _letter(ch: String) -> bool:
	if ch == "":
		return false
	var c := ch.unicode_at(0)
	return (c >= 65 and c <= 90) or (c >= 97 and c <= 122)


static func _token(text: String) -> bool:
	if text == "":
		return false
	for i in text.length():
		var c := text.unicode_at(i)
		var ok := (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 95
		if not ok:
			return false
	return true


static func _token_reason(text: String) -> String:
	if text == "" or text == "*" or _token(text):
		return ""
	return _loc("ed_bad_name")


static func _need_int(text: String, lo: int, hi: int, extra: PackedStringArray) -> String:
	if text == "":
		return _loc("ed_bad_int")
	return _int_text(text, lo, hi, extra)


static func bad_rect(x: int, y: int, w: int, h: int) -> bool:
	return x < 0 or y < 0 or w < 1 or h < 1 or x + w - 1 >= COLS or y - h + 1 < 0 or y >= ROWS


static func _port_reason(text: String, room: Dictionary) -> String:
	if text == "":
		return ""
	var parts := text.split(":")
	if parts.size() != 2:
		return _loc("ed_bad_port")
	var ax := _parse_whole(parts[0])
	var ay := _parse_whole(parts[1])
	if not bool(ax.get("ok", false)) or not bool(ay.get("ok", false)):
		return _loc("ed_bad_port")
	var x := int(ax.n)
	var y := int(ay.n)
	if x < 0 or y < 0 or x >= COLS or y >= ROWS:
		return _loc("ed_bad_port")
	if _wall(room, x, y):
		return _loc("ed_bad_port")
	return ""


static func _wall(room: Dictionary, x: int, y: int) -> bool:
	var rows: Array = room.get("rows", [])
	if y < 0 or y >= rows.size():
		return true
	var parts := str(rows[y]).split(".")
	if x < 0 or x >= parts.size():
		return true
	var info: Dictionary = Catalog.decode(parts[x])
	return str(info.get("block", "")) != ""


static func _script_reason(text: String, room: Dictionary) -> String:
	if text == "":
		return ""
	if _game_scripts().has(text):
		return ""
	for id_v in _room_script_ids(room):
		if str(id_v) == text:
			return ""
	return _loc("ed_bad_script")


static func _uid_reason(text: String, room: Dictionary) -> String:
	if text == "" or _token(text):
		return ""
	for id_v in _room_uids(room):
		if str(id_v) == text:
			return ""
	return _loc("ed_bad_uid")


static func _kids_reason(text: String) -> String:
	if text.strip_edges() == "":
		return ""
	var parsed: Variant = _parse_kids(text)
	return "" if parsed is Array else _loc("ed_bad_kids")


static func _parse_kids(text: String) -> Variant:
	var wrapped := "<all><room name=\"a\"><obj id=\"area\" x=\"0\" y=\"1\">%s</obj></room></all>" % text
	var doc := Codec.doc_from_xml(wrapped, "kids")
	var rooms: Array = doc.get("rooms", [])
	if rooms.is_empty():
		return null
	var objs: Array = (rooms[0] as Dictionary).get("objs", [])
	if objs.is_empty():
		return null
	var kids: Variant = (objs[0] as Dictionary).get("kids", [])
	if text.strip_edges() != "" and (not kids is Array or (kids as Array).is_empty()):
		return null
	return kids


static func _kids_text(obj: Dictionary) -> String:
	var parts := PackedStringArray()
	for kid_v in obj.get("kids", []):
		if typeof(kid_v) != TYPE_DICTIONARY:
			continue
		parts.append(Codec.node_xml(kid_v, false))
	return "\n".join(parts)


static func _room_chars(s: String) -> bool:
	if s == "":
		return false
	for i in s.length():
		var c := s.unicode_at(i)
		var ok := (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c > 127
		ok = ok or c == 95 or c == 46 or c == 32 or c == 45 or c == 33 or c == 91 or c == 93
		if not ok:
			return false
	return true


static func _color_ids() -> PackedStringArray:
	var colors := PackedStringArray([""])
	for c in RoomFlags.COLORS.keys():
		colors.append(str(c))
	return colors


static func _fon_ids() -> PackedStringArray:
	var names: Array = []
	var dir := DirAccess.open("res://assets/sprites/fon")
	if dir != null:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".png.import"):
				names.append(file_name.trim_suffix(".png.import"))
			elif file_name.ends_with(".png"):
				names.append(file_name.get_basename())
			file_name = dir.get_next()
		dir.list_dir_end()
	if names.is_empty():
		names = ["fonCanter", "fonClear", "fonDarkClouds", "fonDefault", "fonEnclave", "fonFinalb", "fonFire", "fonRuins", "fonWay"]
	names.sort()
	var out := PackedStringArray([""])
	var seen := {"": true}
	for name_v in names:
		var name := str(name_v)
		if seen.has(name):
			continue
		seen[name] = true
		out.append(name)
	return out


static func _emit_ids() -> PackedStringArray:
	if not _emits.is_empty():
		return _emits
	var names: Array = [""]
	var seen := {"": true}
	var text := FileAccess.get_file_as_string("res://scripts/units/unit_fx.gd")
	var start := text.find("const PARTS")
	var end := text.find("const FLARES")
	if start >= 0 and end > start:
		var body := text.substr(start, end - start)
		var i := 0
		while true:
			var q := body.find("\"", i)
			if q < 0:
				break
			var q2 := body.find("\"", q + 1)
			if q2 < 0:
				break
			var line := body.rfind("\n", q)
			if body.substr(line + 1, q - line - 1) == "\t" and body.substr(q2 + 1, 1) == ":":
				var id := body.substr(q + 1, q2 - q - 1)
				if not seen.has(id):
					seen[id] = true
					names.append(id)
			i = q2 + 1
	var line_end := text.find("\n", end)
	var flare := text.substr(end, line_end - end) if line_end > end else ""
	var j := 0
	while true:
		var q := flare.find("\"", j)
		if q < 0:
			break
		var q2 := flare.find("\"", q + 1)
		if q2 < 0:
			break
		var id := flare.substr(q + 1, q2 - q - 1)
		if not seen.has(id):
			seen[id] = true
			names.append(id)
		j = q2 + 1
	for id in ["purple_spark", "flame", "poison", "die_spark"]:
		if not seen.has(id):
			seen[id] = true
			names.append(id)
	names.sort()
	_emits = PackedStringArray(names)
	return _emits


static func _game_scripts() -> PackedStringArray:
	if not _script_ids.is_empty():
		return _script_ids
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/maps/scripts.json"))
	var names: Array = []
	if parsed is Dictionary:
		for key in (parsed as Dictionary).keys():
			names.append(str(key))
	names.sort()
	_script_ids = PackedStringArray(names)
	return _script_ids


static func _room_script_ids(room: Dictionary) -> Array:
	var out: Array = []
	for obj_v in room.get("objs", []):
		if typeof(obj_v) != TYPE_DICTIONARY:
			continue
		for kid_v in (obj_v as Dictionary).get("kids", []):
			if typeof(kid_v) != TYPE_DICTIONARY:
				continue
			var kid: Dictionary = kid_v
			if str(kid.get("tag", "")) != "scr":
				continue
			var id := str((kid.get("attrs", {}) as Dictionary).get("id", ""))
			if id != "" and not out.has(id):
				out.append(id)
	return out


static func _room_uids(room: Dictionary) -> Array:
	var out: Array = []
	for obj_v in room.get("objs", []):
		if typeof(obj_v) != TYPE_DICTIONARY:
			continue
		var uid := str(((obj_v as Dictionary).get("attrs", {}) as Dictionary).get("uid", ""))
		if uid != "" and not out.has(uid):
			out.append(uid)
	return out


static func _weap_ids() -> PackedStringArray:
	if not _weaps.is_empty():
		return _weaps
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/weapons.json"))
	var ids: Array = [""]
	if parsed is Dictionary:
		for row_v in (parsed as Dictionary).get("weapons", []):
			if row_v is Dictionary:
				ids.append(str((row_v as Dictionary).get("id", "")))
	_weaps = PackedStringArray(ids)
	return _weaps


static func _music_ids() -> PackedStringArray:
	var music := PackedStringArray([""])
	music.append_array(Palette.music_ids())
	return music


static func _enum_ids(pairs: Array) -> PackedStringArray:
	var ids := PackedStringArray()
	for pair_v in pairs:
		ids.append(str((pair_v as Array)[0]))
	return ids


static func _tip_of(id: String) -> String:
	return str(Reg.obj(id).get("tip", ""))


## True when this object's class reads the attribute. Presence alone does not show the field.
static func spec_on(id: String, _attrs: Dictionary, spec: Dictionary) -> bool:
	return attr_on(id, str(spec.get("k", "")))


## Lock suite: Interact reads these once it exists. Interact exists for a catalog
## inter of 1, 2, 4, 5 or 8 (containers, terminals, buttons, machines, storey
## doors), a catalog lock, a checkpoint, or a captive. inter 0 (grate, force
## field) opens and links, and does not take a lock. Furniture with no inter
## (woodbox, table1, bed) and a window with no inter do not.
## cont: objs.json cont, plus couch (a shipped container with an empty catalog cont).
## open: a door that already interacts, plus elpanel. autoclose: those, plus buttons (inter 4).
## phase/period: catalog moln or period (moln1). tipdam: catalog actdam (knop2).
## weap/emit/fraction/stay/nodrop: UnitRaider and its subclasses. fraction also UnitTurret.
## qid/npc/fly/dammult/invis: Unit reads qid on every actor; npc/fly/dammult/invis are UnitNPC.
## tr: subclasses that read @tr, not UnitNPC. Mines read tr; a tip=trap (spikes) does not.
static func attr_on(id: String, key: String) -> bool:
	var row := Reg.obj(id)
	var tip := str(row.get("tip", ""))
	var cl := str(row.get("cl", ""))
	var act := str(row.get("inter", ""))
	var cont := str(row.get("cont", ""))
	var lock := str(row.get("lock", ""))
	var door := tip == "door"
	var box := tip == "box" or door
	var unit := tip == "unit"
	var npc := cl == "UnitNPC"
	var turret := _TURRET.has(cl)
	var mine := cl == "Mine" or cl == "UnitTrap"
	var raider := _RAIDER.has(cl)
	var dummy := cl == "UnitTrain" or cl == "UnitDestr"
	var linker := cl == "UnitTrigger" or cl == "UnitDamager"
	var enemy := unit and not npc and not turret and not mine and not _SKIP_UNIT.has(cl)
	var actor := enemy or npc or turret or dummy or linker
	var lockable := lock != "" or tip == "checkpoint" or cl == "UnitCaptive" or act in ["1", "2", "4", "5", "8"]
	var linked := act != "" or _INTER_EXTRA.has(id)
	var back := tip == ""
	match key:
		"lock", "lockhp", "lockatt", "key", "keyloss", "mine", "minetip", "locklevel", "noruna":
			return lockable
		"locktip":
			return lockable or id == "platform1"
		"hack":
			return lockable or cl == "UnitMsp"
		"cont":
			return cont != "" or id == "couch"
		"open":
			return (door and (act != "" or lock != "")) or id == "elpanel"
		"autoclose":
			return (door and (act != "" or lock != "")) or act == "4" or id == "elpanel"
		"inter":
			return linked
		"time":
			return (door and act != "") or act in ["2", "4", "8"] or id in ["brspr", "camp"]
		"allact":
			return str(row.get("allact", "")) != "" or act in ["2", "4"] or cl == "UnitTrigger" or _ALLACT_EXTRA.has(id)
		"allid":
			return act != "" or str(row.get("allact", "")) != "" or linker or cl == "UnitCaptive" or tip == "up" or _ALLID_EXTRA.has(id) or _ALLACT_EXTRA.has(id)
		"fun":
			return id == "generat"
		"mess", "down":
			return false
		"sign", "off":
			return linked
		"scr":
			return box or actor
		"turn", "hpmult", "multhp", "unres", "light", "trigger", "trig":
			return actor or (key == "light" and box)
		"tr":
			return (enemy or turret or mine or dummy or linker) and tip != "trap"
		"ai", "qid":
			return enemy or npc
		"fraction":
			return turret or raider
		"weap", "emit", "stay", "nodrop":
			return raider
		"hero", "ear", "noagro", "dis", "die", "alarm", "observ":
			return enemy or (key == "observ" and turret)
		"name":
			return box or actor
		"npc", "fly", "dammult", "invis":
			return npc
		"hide":
			return npc or tip == "checkpoint"
		"pole":
			return cl == "UnitAlicorn"
		"red", "nores":
			return cl == "UnitZebra"
		"rep":
			return cl == "UnitPonPon"
		"res":
			return cl == "UnitTrigger"
		"fix":
			return dummy
		"on":
			return cl == "UnitTransmitter" or id == "transm"
		"sr":
			return cl == "UnitCaptive"
		"vis":
			return turret
		"dig":
			return cl == "UnitZombie"
		"main", "tele":
			return tip == "checkpoint"
		"prize":
			return cont != "" or (door and lock != "")
		"indestruct", "pokr":
			return box
		"phase", "period":
			return str(row.get("moln", "")) != "" or str(row.get("period", "")) != ""
		"transm":
			return tip == "box"
		"tipdam":
			return str(row.get("actdam", "")) != ""
		"radrad":
			return str(row.get("rad", "")) != "" or str(row.get("radrad", "")) != ""
		"sur":
			return cont != "" or str(row.get("sur", "")) != ""
		"prob":
			return id == "doorboss" or (act == "9" and id != "exit")
		"cons":
			return act in ["2", "5"] or cont != ""
		"nobase":
			return cont != ""
		"back":
			return id.begins_with("indoor")
		"dx":
			return id == "hrail"
		"f":
			return id == "zavod1"
		"fr", "w", "h", "a", "lon":
			return back
		_:
			return false


static func field_list(id: String) -> PackedStringArray:
	var out := PackedStringArray(["x", "y", "uid", "code"])
	for key_v in FIELD_KEYS:
		var key := str(key_v)
		if attr_on(id, key):
			out.append(key)
	return out


static func is_field(key: String) -> bool:
	return FIELD_KEYS.has(key)


static func kid_kinds(id: String, obj: Dictionary) -> PackedStringArray:
	var tip := _tip_of(id)
	var has := {}
	for kid_v in obj.get("kids", []):
		if typeof(kid_v) == TYPE_DICTIONARY:
			has[str((kid_v as Dictionary).get("tag", ""))] = true
	var out := PackedStringArray()
	var cont := str(Reg.obj(id).get("cont", "")) != ""
	if tip in ["box", "door", "checkpoint"] or cont or has.has("item"):
		out.append("item")
	if tip in ["box", "door", "unit", "checkpoint"] or id == "area" or has.has("scr"):
		out.append("scr")
	if tip in ["box", "door"] or has.has("move"):
		out.append("move")
	return out


static func _push(out: Array, field: String, value, msg: String) -> void:
	if msg == "":
		return
	var warn := msg.begins_with("~")
	out.append({
		"field": field,
		"level": "warn" if warn else "error",
		"msg": msg.substr(1) if warn else msg,
		"value": str(value),
	})


static func _audit_room_name(name: String, rooms: Array) -> String:
	if name == "":
		return _loc("ed_need_name")
	if not _room_chars(name):
		return _loc("ed_name_chars")
	var n := 0
	for room_v in rooms:
		if str(room_v.get("name", "")) == name:
			n += 1
	if n > 1:
		return _loc("ed_name_used")
	return ""


static func _own_uid_text(text: String, room: Dictionary, mine: String) -> String:
	if text == "":
		return ""
	if not _token(text):
		return _loc("ed_bad_name")
	var n := 0
	for obj_v in room.get("objs", []):
		if typeof(obj_v) != TYPE_DICTIONARY:
			continue
		if str((obj_v as Dictionary).get("attrs", {}).get("uid", "")) == text:
			n += 1
	if n > 1 or (n == 1 and mine != text):
		return "~" + _loc("ed_name_used")
	return ""


static func audit_room(room: Dictionary, rooms: Array) -> Array:
	var out: Array = []
	var opt: Dictionary = room.get("options", {})
	var name := str(room.get("name", ""))
	_push(out, "name", name, _audit_room_name(name, rooms))
	var tip := show_text(opt.get("tip", ""))
	_push(out, "tip", tip, _ids_reason(tip, _enum_ids(TIPS)))
	var entip := show_text(opt.get("entip", ""))
	if entip == "-1":
		entip = ""
	_push(out, "entip", entip, _ids_reason(entip, _enum_ids(ENTIP)))
	var level := show_text(opt.get("level", ""))
	_push(out, "level", level, _int_text(level, 0, 999, PackedStringArray(["uniq"])))
	var forms := PackedStringArray(["", "0", "1", "2", "3"])
	_push(out, "color", show_text(opt.get("color", "")), _ids_reason(show_text(opt.get("color", "")), _color_ids()))
	_push(out, "dark", show_text(opt.get("dark", "")), _float_text(show_text(opt.get("dark", "")), -400, 400))
	_push(out, "vis", show_text(opt.get("vis", "")), _float_text(show_text(opt.get("vis", "")), 0, 100))
	_push(out, "backwall", show_text(opt.get("backwall", "")), _ids_reason(show_text(opt.get("backwall", "")), Palette.wall_ids()))
	_push(out, "backform", show_text(opt.get("backform", "")), _ids_reason(show_text(opt.get("backform", "")), forms))
	_push(out, "lon", show_text(opt.get("lon", "")), _ids_reason(show_text(opt.get("lon", "")), _enum_ids(LON)))
	_push(out, "colorfon", show_text(opt.get("colorfon", "")), _ids_reason(show_text(opt.get("colorfon", "")), _color_ids()))
	_push(out, "rad", show_text(opt.get("rad", "")), _float_text(show_text(opt.get("rad", "")), 0, 1000))
	_push(out, "wlevel", show_text(opt.get("wlevel", "")), _int_text(show_text(opt.get("wlevel", "")), 0, 100, PackedStringArray()))
	_push(out, "wtip", show_text(opt.get("wtip", "")), _ids_reason(show_text(opt.get("wtip", "")), _enum_ids(WTIP)))
	_push(out, "wopac", show_text(opt.get("wopac", "")), _float_text(show_text(opt.get("wopac", "")), 0, 1))
	_push(out, "wrad", show_text(opt.get("wrad", "")), _float_text(show_text(opt.get("wrad", "")), 0, 1000))
	## Empty music is the land default (Location only copies the attribute when it has length).
	_push(out, "music", show_text(opt.get("music", "")), _ids_reason(show_text(opt.get("music", "")), _music_ids()))
	_push(out, "items", show_text(opt.get("items", "")), _token_reason(show_text(opt.get("items", ""))))
	_push(out, "spawn", show_text(opt.get("spawn", "")), _token_reason(show_text(opt.get("spawn", ""))))
	_push(out, "kolspawn", show_text(opt.get("kolspawn", "")), _int_text(show_text(opt.get("kolspawn", "")), 0, 100, PackedStringArray()))
	_push(out, "stage", show_text(opt.get("stage", "")), _int_text(show_text(opt.get("stage", "")), 0, 99, PackedStringArray()))
	_push(out, "wdam", show_text(opt.get("wdam", "")), _float_text(show_text(opt.get("wdam", "")), 0, 10000))
	_push(out, "wtipdam", show_text(opt.get("wtipdam", "")), _token_reason(show_text(opt.get("wtipdam", ""))))
	_push(out, "fon", show_text(opt.get("fon", "")), _ids_reason(show_text(opt.get("fon", "")), _fon_ids()))
	_push(out, "maxdy", show_text(opt.get("maxdy", "")), _float_text(show_text(opt.get("maxdy", "")), 0, 500))
	_push(out, "tilespawn", show_text(opt.get("tilespawn", "")), _float_text(show_text(opt.get("tilespawn", "")), 0, 1))
	_push(out, "trus", show_text(opt.get("trus", "")), _float_text(show_text(opt.get("trus", "")), 0, 100))
	_push(out, "zoom", show_text(opt.get("zoom", "")), _float_text(show_text(opt.get("zoom", "")), 0, 20))
	return out


static func audit_map(opt: Dictionary) -> Array:
	var out: Array = []
	var src: Dictionary = opt if opt != null else {}
	_push(out, "color", show_text(src.get("color", "")), _ids_reason(show_text(src.get("color", "")), _color_ids()))
	_push(out, "darkness", show_text(src.get("darkness", "")), _float_text(show_text(src.get("darkness", "")), -400, 400))
	_push(out, "vis", show_text(src.get("vis", "")), _float_text(show_text(src.get("vis", "")), 0, 100))
	_push(out, "rad", show_text(src.get("rad", "")), _float_text(show_text(src.get("rad", "")), 0, 1000))
	_push(out, "wrad", show_text(src.get("wrad", "")), _float_text(show_text(src.get("wrad", "")), 0, 1000))
	_push(out, "wdam", show_text(src.get("wdam", "")), _float_text(show_text(src.get("wdam", "")), 0, 1000))
	_push(out, "wtipdam", show_text(src.get("wtipdam", "")), _token_reason(show_text(src.get("wtipdam", ""))))
	_push(out, "wtip", show_text(src.get("wtip", "")), _ids_reason(show_text(src.get("wtip", "")), _enum_ids(WTIP)))
	_push(out, "wopac", show_text(src.get("wopac", "")), _float_text(show_text(src.get("wopac", "")), 0, 1))
	_push(out, "backwall", show_text(src.get("backwall", "")), _ids_reason(show_text(src.get("backwall", "")), Palette.wall_ids()))
	_push(out, "music", show_text(src.get("music", "")), _ids_reason(show_text(src.get("music", "")), _music_ids()))
	_push(out, "fon", show_text(src.get("fon", "")), _ids_reason(show_text(src.get("fon", "")), _fon_ids()))
	_push(out, "art", show_text(src.get("art", "")), _token_reason(show_text(src.get("art", ""))))
	_push(out, "xp", show_text(src.get("xp", "")), _int_text(show_text(src.get("xp", "")), 0, 100000, PackedStringArray()))
	return out


static func audit_object(obj: Dictionary, room: Dictionary) -> Array:
	if is_area(obj):
		return []
	var out: Array = []
	var attrs: Dictionary = _attrs(obj)
	var id := str(obj.get("id", ""))
	var x := show_text(obj.get("x", ""))
	var y := show_text(obj.get("y", ""))
	_push(out, "x", x, _need_int(x, 0, COLS - 1, PackedStringArray()))
	_push(out, "y", y, _need_int(y, 0, ROWS - 1, PackedStringArray()))
	## Validate a typed field when this object shows it, or when the value is present
	## (including a value kept in Other). Empty stays valid, so warnings do not grow.
	var see := func(key: String) -> bool: return attr_on(id, key) or attrs.has(key)
	if see.call("lock"):
		_push(out, "lock", show_text(attrs.get("lock", "")), _float_text(show_text(attrs.get("lock", "")), 0, 100))
	if see.call("locktip"):
		_push(out, "locktip", show_text(attrs.get("locktip", "")), _ids_reason(show_text(attrs.get("locktip", "")), _enum_ids(LOCKTIP)))
	if see.call("lockhp"):
		_push(out, "lockhp", show_text(attrs.get("lockhp", "")), _int_text(show_text(attrs.get("lockhp", "")), 0, 100000, PackedStringArray()))
	if see.call("lockatt"):
		_push(out, "lockatt", show_text(attrs.get("lockatt", "")), _int_text(show_text(attrs.get("lockatt", "")), -1000, 1000, PackedStringArray()))
	if see.call("key"):
		_push(out, "key", show_text(attrs.get("key", "")), _token_reason(show_text(attrs.get("key", ""))))
	if see.call("keyloss"):
		_push(out, "keyloss", show_text(attrs.get("keyloss", "")), _ids_reason(show_text(attrs.get("keyloss", "")), _enum_ids(KEYLOSS)))
	if see.call("mine"):
		_push(out, "mine", show_text(attrs.get("mine", "")), _int_text(show_text(attrs.get("mine", "")), 0, 20, PackedStringArray()))
	if see.call("minetip"):
		_push(out, "minetip", show_text(attrs.get("minetip", "")), _ids_reason(show_text(attrs.get("minetip", "")), _enum_ids(MINETIP)))
	if see.call("cont"):
		_push(out, "cont", show_text(attrs.get("cont", "")), _token_reason(show_text(attrs.get("cont", ""))))
	if see.call("autoclose"):
		_push(out, "autoclose", show_text(attrs.get("autoclose", "")), _int_text(show_text(attrs.get("autoclose", "")), 0, 100000, PackedStringArray()))
	if see.call("inter"):
		_push(out, "inter", show_text(attrs.get("inter", "")), _ids_reason(show_text(attrs.get("inter", "")), _enum_ids(INTER)))
	if see.call("time"):
		_push(out, "time", show_text(attrs.get("time", "")), _int_text(show_text(attrs.get("time", "")), 0, 100000, PackedStringArray()))
	if see.call("turn"):
		_push(out, "turn", show_text(attrs.get("turn", "")), _ids_reason(show_text(attrs.get("turn", "")), _enum_ids(TURN)))
	if see.call("hpmult"):
		_push(out, "hpmult", show_text(attrs.get("hpmult", "")), _float_text(show_text(attrs.get("hpmult", "")), 0.01, 100))
	if see.call("ai"):
		_push(out, "ai", show_text(attrs.get("ai", "")), _token_reason(show_text(attrs.get("ai", ""))))
	if see.call("fraction"):
		_push(out, "fraction", show_text(attrs.get("fraction", "")), _ids_reason(show_text(attrs.get("fraction", "")), _enum_ids(FRACTION)))
	if see.call("weap"):
		_push(out, "weap", show_text(attrs.get("weap", "")), _ids_reason(show_text(attrs.get("weap", "")), _weap_ids(), "weap"))
	if see.call("qid"):
		_push(out, "qid", show_text(attrs.get("qid", "")), _token_reason(show_text(attrs.get("qid", ""))))
	if see.call("tr"):
		var tr := show_text(attrs.get("tr", ""))
		var tr_why := _int_text(tr, 0, 100, PackedStringArray())
		if tr_why != "" and _token(tr):
			tr_why = "~" + tr_why
		_push(out, "tr", tr, tr_why)
	if see.call("emit"):
		_push(out, "emit", show_text(attrs.get("emit", "")), _ids_reason(show_text(attrs.get("emit", "")), _emit_ids()))
	if see.call("allact"):
		_push(out, "allact", show_text(attrs.get("allact", "")), _token_reason(show_text(attrs.get("allact", ""))))
	if see.call("allid"):
		_push(out, "allid", show_text(attrs.get("allid", "")), _uid_reason(show_text(attrs.get("allid", "")), room))
	if see.call("fun"):
		_push(out, "fun", show_text(attrs.get("fun", "")), _ids_reason(show_text(attrs.get("fun", "")), _enum_ids(FUN)))
	var uid := show_text(attrs.get("uid", ""))
	_push(out, "uid", uid, _own_uid_text(uid, room, str(attrs.get("uid", ""))))
	_push(out, "code", show_text(attrs.get("code", "")), _code_reason(show_text(attrs.get("code", ""))))
	var known := {"x": true, "y": true, "uid": true, "code": true}
	for key in DOOR_KEYS + UNIT_KEYS + USE_KEYS:
		known[key] = true
	for spec_v in OBJ_SPEC:
		var spec: Dictionary = spec_v
		var skey := str(spec.get("k", ""))
		known[skey] = true
		if not attrs.has(skey):
			continue
		var text := show_text(attrs.get(skey, ""))
		match str(spec.get("r", "")):
			"int":
				_push(out, skey, text, _int_text(text, int(spec.get("lo", 0)), int(spec.get("hi", 0)), PackedStringArray()))
			"float":
				_push(out, skey, text, _float_text(text, float(spec.get("lo", 0.0)), float(spec.get("hi", 0.0))))
			"token":
				_push(out, skey, text, _token_reason(text))
			_:
				pass
	for key_v in attrs.keys():
		var key := str(key_v)
		if known.has(key):
			continue
		if not OBJ_KEYS.has(key):
			_push(out, "other", key, "~" + _locf("ed_xml_warn", [key]))
	return out


static func audit_area(obj: Dictionary, room: Dictionary) -> Array:
	var out: Array = []
	var attrs: Dictionary = _attrs(obj)
	var x := show_text(obj.get("x", ""))
	var y := show_text(obj.get("y", ""))
	var w := show_text(attrs.get("w", "2"))
	var h := show_text(attrs.get("h", "2"))
	_push(out, "x", x, _need_int(x, 0, COLS - 1, PackedStringArray()))
	_push(out, "y", y, _need_int(y, 0, ROWS - 1, PackedStringArray()))
	_push(out, "w", w, _need_int(w, 1, COLS, PackedStringArray()))
	_push(out, "h", h, _need_int(h, 1, ROWS, PackedStringArray()))
	var zx := _parse_whole(x)
	var zy := _parse_whole(y)
	var zw := _parse_whole(w)
	var zh := _parse_whole(h)
	if bool(zx.ok) and bool(zy.ok) and bool(zw.ok) and bool(zh.ok):
		var xi := int(zx.n)
		var yi := int(zy.n)
		var wi := int(zw.n)
		var hi := int(zh.n)
		if bad_rect(xi, yi, wi, hi):
			_push(out, "rect", "%s,%s %sx%s" % [xi, yi, wi, hi], _loc("ed_bad_rect"))
	var vis := show_text(attrs.get("vis", ""))
	var vis_ids := PackedStringArray([""])
	vis_ids.append_array(VIS_IDS)
	_push(out, "vis", vis, _ids_reason(vis, vis_ids))
	var tip := show_text(attrs.get("tip", ""))
	if tip == "gg":
		tip = ""
	_push(out, "tip", tip, _ids_reason(tip, _enum_ids(AREA_TIP)))
	_push(out, "allid", show_text(attrs.get("allid", "")), _uid_reason(show_text(attrs.get("allid", "")), room))
	_push(out, "scr", show_text(attrs.get("scr", "")), _script_reason(show_text(attrs.get("scr", "")), room))
	_push(out, "scrout", show_text(attrs.get("scrout", "")), _script_reason(show_text(attrs.get("scrout", "")), room))
	_push(out, "kids", "", _kids_reason(_kids_text(obj)))
	_push(out, "tilehp", show_text(attrs.get("tilehp", "")), _int_text(show_text(attrs.get("tilehp", "")), 0, 1000000, PackedStringArray()))
	_push(out, "tileop", show_text(attrs.get("tileop", "")), _float_text(show_text(attrs.get("tileop", "")), 0, 1))
	_push(out, "tilethre", show_text(attrs.get("tilethre", "")), _int_text(show_text(attrs.get("tilethre", "")), 0, 1000000, PackedStringArray()))
	_push(out, "grav", show_text(attrs.get("grav", "")), _float_text(show_text(attrs.get("grav", "")), -100, 100))
	_push(out, "emit", show_text(attrs.get("emit", "")), _ids_reason(show_text(attrs.get("emit", "")), _emit_ids()))
	_push(out, "dens", show_text(attrs.get("dens", "")), _float_text(show_text(attrs.get("dens", "")), 0, 100))
	var port := show_port(attrs.get("port", ""))
	_push(out, "port", port, _port_reason(port, room))
	_push(out, "code", show_text(attrs.get("code", "")), _code_reason(show_text(attrs.get("code", ""))))
	return out
