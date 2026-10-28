extends RefCounted

## Warnings only. Known keys from Editor.txt.
## run() returns {room, obj_index?, text}. An empty list is a clean check.

const Rules := preload("res://scripts/editor/editor_rules.gd")
const Codec := preload("res://scripts/editor/room_codec.gd")
const RoomFile := preload("res://scripts/map/room_file.gd")
const ROOM_KEYS := {
	"test": 1, "tip": 1, "uniq": 1, "entip": 1, "back": 1, "level": 1, "base": 1,
	"bezdna": 1, "nomap": 1, "retdark": 1, "levitoff": 1, "portoff": 1, "desoff": 1,
	"petoff": 1, "noblack": 1, "vis": 1, "rad": 1, "wrad": 1, "wopac": 1, "wlevel": 1,
	"wtip": 1, "color": 1, "dark": 1, "backform": 1, "backwall": 1, "lon": 1, "music": 1,
	"transpfon": 1, "colorfon": 1,
	"items": 1, "spawn": 1, "kolspawn": 1, "nornd": 1, "stage": 1, "wdam": 1,
	"wtipdam": 1, "fon": 1, "maxdy": 1, "tilespawn": 1, "train": 1, "trus": 1,
	"sky": 1, "zoom": 1,
}
const OBJ_KEYS := Rules.OBJ_KEYS
## objs.json allact comein. doorboss counts only when the placed object sets allact=comein.
const STOREY_IDS := {
	"indoor1": 1, "indoor2": 1, "indoor3": 1, "indoor4": 1,
	"instdoor": 1, "inbasedoor": 1, "inencldoor": 1,
	"door_st1": 1, "door_st2": 1,
}
## Land.enterLoc passes the standing box minus 4 px of width. littlepip is 50×78, tiles are 40.
const TILE := 40.0
const BODY_W := 46.0
const BODY_H := 78.0

static var _acts := {}


static func run(doc: Dictionary) -> Array:
	var out: Array = []
	var rooms: Array = doc.get("rooms", [])
	var names := {}
	var uids := {}
	var codes := {}
	var backs := {}
	for room_v in rooms:
		var n := str(room_v.get("name", ""))
		names[n] = true
		if str(room_v.get("options", {}).get("tip", "")) == "back":
			backs[n] = true
		for obj_v in room_v.get("objs", []):
			var attrs: Dictionary = obj_v.get("attrs", {})
			var uid := str(attrs.get("uid", ""))
			if uid != "":
				uids[uid] = true
			var code := str(attrs.get("code", ""))
			if code != "":
				if codes.has(code):
					out.append(_item(n, "duplicate code %s (%s and %s)" % [code, codes[code], n]))
				else:
					codes[code] = n
	for room_v in rooms:
		if typeof(room_v) != TYPE_DICTIONARY:
			continue
		var room: Dictionary = room_v
		var n := str(room.get("name", ""))
		_storey_z(out, room, n)
		var opt: Dictionary = room.get("options", {})
		for k in opt.keys():
			if not ROOM_KEYS.has(str(k)):
				out.append(_item(n, "%s: unknown room attr %s" % [n, k]))
		var back := str(opt.get("back", ""))
		if back != "" and not backs.has(back) and not names.has(back):
			out.append(_item(n, "%s: back=%s missing" % [n, back]))
		elif back != "" and not backs.has(back):
			out.append(_item(n, "%s: back=%s has no tip=back" % [n, back]))
		if room.has("doors") and room.doors is Array:
			var computed: Array = Codec.doors_from_rows(room.get("rows", []))
			var doors: Array = room.doors
			var differ := doors.size() != computed.size()
			if not differ:
				for i in doors.size():
					if int(doors[i]) != int(computed[i]):
						differ = true
						break
			if differ:
				out.append(_item(n, "%s: doors row differs from walls" % n))
		var objs: Array = room.get("objs", [])
		for i in objs.size():
			var obj_v: Dictionary = objs[i]
			var attrs: Dictionary = obj_v.get("attrs", {})
			for k in attrs.keys():
				if not OBJ_KEYS.has(str(k)):
					out.append(_item(n, "%s/%s: unknown attr %s" % [n, obj_v.get("id"), k], i))
			_targets(out, n, str(attrs.get("allact", "")), uids, i)
			_kids(out, n, obj_v.get("kids", []), uids, i)
			_storey_door(out, room, rooms, obj_v, i)
			if Rules.is_area(obj_v) and _area_inert(obj_v):
				out.append(_item(n, "%s: area at %s,%s does nothing" % [n, obj_v.get("x", 0), obj_v.get("y", 0)], i))
	return out


static func lines(items: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for item_v in items:
		if typeof(item_v) != TYPE_DICTIONARY:
			continue
		out.append(str((item_v as Dictionary).get("text", "")))
	return out


## The other storey: same x,y with the other of z 0/1, or the random back= / tip=back pair.
static func partner(room: Dictionary, rooms: Array) -> Dictionary:
	if room.is_empty():
		return {}
	var name := str(room.get("name", ""))
	if room.has("x") and room.has("y"):
		var x := int(room.x)
		var y := int(room.y)
		var z := int(room.get("z", 0))
		for other_v in rooms:
			if typeof(other_v) != TYPE_DICTIONARY:
				continue
			var other: Dictionary = other_v
			if str(other.get("name", "")) == name:
				continue
			if not other.has("x") or not other.has("y"):
				continue
			if int(other.x) != x or int(other.y) != y:
				continue
			var oz := int(other.get("z", 0))
			if oz != z and (oz == 0 or oz == 1) and (z == 0 or z == 1):
				return other
	var opt: Dictionary = room.get("options", {})
	var back := str(opt.get("back", ""))
	if back != "":
		for other_v in rooms:
			if typeof(other_v) == TYPE_DICTIONARY and str((other_v as Dictionary).get("name", "")) == back:
				return other_v
	if str(opt.get("tip", "")) == "back":
		for other_v in rooms:
			if typeof(other_v) != TYPE_DICTIONARY:
				continue
			if str((other_v as Dictionary).get("options", {}).get("back", "")) == name:
				return other_v
	return {}


static func is_storey_door(obj: Dictionary) -> bool:
	if str(obj.get("tag", "obj")) == "back" or Rules.is_area(obj):
		return false
	if act_of(obj) != "comein":
		return false
	var id := str(obj.get("id", ""))
	return STOREY_IDS.has(id) or id == "doorboss"


static func act_of(obj: Dictionary) -> String:
	var attrs: Dictionary = obj.get("attrs", {})
	var act := str(attrs.get("allact", ""))
	if act != "":
		return act
	return _default_act(str(obj.get("id", "")))


## Cells the standing box covers when a comein door drops the player on its anchor.
static func arrival_cells(ax: int, ay: int, size: int) -> Array:
	var wide := size if size > 0 else 1
	var x := (float(ax) + 0.5 * float(wide)) * TILE
	var y := (float(ay) + 1.0) * TILE - 1.0
	var half := BODY_W * 0.5
	var left := int(floor((x - half) / TILE))
	var right := int(floor((x + half) / TILE))
	var top := int(floor((y - BODY_H) / TILE))
	var bottom := int(floor(y / TILE))
	var cells: Array = []
	for cx in range(left, right + 1):
		for cy in range(top, bottom + 1):
			cells.append(Vector2i(cx, cy))
	return cells


## Tile.collision > 0. A lowered front (zForm) stays solid in the original.
static func tile_blocks(cell: Dictionary) -> bool:
	var front := str(cell.get("front", ""))
	if front == "":
		return false
	return not RoomFile.is_open_code(front)


static func _item(room: String, text: String, obj_index := -1) -> Dictionary:
	var item := {"room": room, "text": text}
	if obj_index >= 0:
		item["obj_index"] = obj_index
	return item


static func _storey_z(out: Array, room: Dictionary, n: String) -> void:
	if not room.has("z"):
		return
	var z := int(room.get("z", 0))
	if z == 0 or z == 1:
		return
	out.append(_item(n, _t("ed_check_z", "%s: z %s is not a storey (only 0 and 1)", [n, str(z)])))


static func _storey_door(out: Array, room: Dictionary, rooms: Array, obj: Dictionary, index: int) -> void:
	if not is_storey_door(obj):
		return
	var n := str(room.get("name", ""))
	var ax := int(obj.get("x", 0))
	var ay := int(obj.get("y", 0))
	var other := partner(room, rooms)
	if other.is_empty():
		out.append(_item(n, _t("ed_check_one", "%s: storey door at %s,%s in a one-storey room", [n, str(ax), str(ay)]), index))
		return
	var id := str(obj.get("id", ""))
	var same := false
	var other_id := false
	for obj_v in other.get("objs", []):
		if typeof(obj_v) != TYPE_DICTIONARY:
			continue
		var twin: Dictionary = obj_v
		if not is_storey_door(twin):
			continue
		if int(twin.get("x", 0)) != ax or int(twin.get("y", 0)) != ay:
			continue
		if str(twin.get("id", "")) == id:
			same = true
		else:
			other_id = true
	if not same and other_id:
		out.append(_item(n, _t("ed_check_id", "%s: storey door at %s,%s twin has another id", [n, str(ax), str(ay)]), index))
	elif not same:
		out.append(_item(n, _t("ed_check_twin", "%s: storey door at %s,%s has no twin", [n, str(ax), str(ay)]), index))
	if _arrival_blocked(other, ax, ay, _obj_size(obj)):
		out.append(_item(n, _t("ed_check_block", "%s: storey door at %s,%s arrival is blocked", [n, str(ax), str(ay)]), index))


static func _arrival_blocked(room: Dictionary, ax: int, ay: int, size: int) -> bool:
	var rows: Array = room.get("rows", [])
	for cell_v in arrival_cells(ax, ay, size):
		var at: Vector2i = cell_v
		if at.x < 0 or at.y < 0 or at.x >= Codec.COLS or at.y >= Codec.ROWS:
			continue
		if at.y >= rows.size():
			continue
		var parts: PackedStringArray = str(rows[at.y]).split(".")
		if at.x >= parts.size():
			continue
		if tile_blocks(Codec.parse_token(parts[at.x])):
			return true
	return false


static func _kids(out: Array, room: String, kids: Array, uids: Dictionary, obj_index: int) -> void:
	for kid in kids:
		var attrs: Dictionary = kid.get("attrs", {})
		var targ := str(attrs.get("targ", ""))
		if targ != "" and targ != "this" and not uids.has(targ):
			out.append(_item(room, "%s: script targ %s missing" % [room, targ], obj_index))
		_kids(out, room, kid.get("kids", []), uids, obj_index)


static func _targets(out: Array, room: String, act: String, _uids: Dictionary, _obj_index: int) -> void:
	if act == "":
		return
	# allact names are commands, not uids.
	if act != "":
		pass


static func _default_act(id: String) -> String:
	_ensure_acts()
	return str(_acts.get(id, ""))


static func _obj_size(obj: Dictionary) -> int:
	var n := int(obj.get("size", 0))
	if n > 0:
		return n
	_ensure_acts()
	n = int(_acts.get(str(obj.get("id", "")) + ".size", 1))
	return n if n > 0 else 1


static func _ensure_acts() -> void:
	if not _acts.is_empty():
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/maps/objs.json"))
	if typeof(data) != TYPE_DICTIONARY:
		_acts["_"] = 1
		return
	for id_v in (data as Dictionary).keys():
		var row: Dictionary = (data as Dictionary)[id_v]
		_acts[str(id_v)] = str(row.get("allact", ""))
		_acts[str(id_v) + ".size"] = int(str(row.get("size", "1")))
	_acts["_"] = 1


static func _area_inert(obj: Dictionary) -> bool:
	var forms = load("res://scripts/editor/editor_forms.gd")
	if forms == null:
		return false
	return bool(forms.area_inert(obj))


static func _t(key: String, fallback: String, args: Array) -> String:
	var text := fallback
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		var locale := tree.root.get_node_or_null("Locale")
		if locale != null and locale.has_method("t"):
			text = str(locale.call("t", key, fallback))
	return text % args
