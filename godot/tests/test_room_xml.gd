extends SceneTree

## JSON -> XML -> JSON for every rooms_*.json, plus a delta false-positive check.
## godot --headless --path godot -s res://tests/test_room_xml.gd

const DIR := "res://assets/data/maps/rooms"
const Codec := preload("res://scripts/editor/room_codec.gd")
const RoomFile := preload("res://scripts/map/room_file.gd")

var _shown := 0
var _counts := {"rows": 0, "xyz": 0, "options": 0, "doors": 0, "objs": 0, "name": 0}


func _init() -> void:
	_delta_check()
	_xml_all()
	var total := 0
	for k in _counts.keys():
		total += int(_counts[k])
	print("xml mismatches ", total, " ", _counts)
	quit()


func _delta_check() -> void:
	var stem := ""
	for f in DirAccess.get_files_at(DIR):
		if str(f).begins_with("rooms_") and str(f).ends_with(".json"):
			stem = str(f).get_basename()
			break
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("%s/%s.json" % [DIR, stem]))
	var doc: Dictionary = raw
	var drift := 0
	var with_doors := 0
	for room_v in doc.get("rooms", []):
		if not (room_v.get("doors") is Array):
			continue
		with_doors += 1
		if not _doors_eq(room_v["doors"], Codec.doors_from_rows(room_v.get("rows", []))):
			drift += 1
	var copy: Dictionary = _floats(doc)
	for room_v in copy.get("rooms", []):
		room_v["doors"] = Codec.doors_from_rows(room_v.get("rows", []))
	var untouched: Dictionary = RoomFile._delta(stem, copy)
	var edited: Dictionary = copy.duplicate(true)
	var rooms: Array = edited.get("rooms", [])
	if not rooms.is_empty():
		var room: Dictionary = rooms[0]
		var rows: Array = (room.get("rows", []) as Array).duplicate()
		if not rows.is_empty():
			rows[0] = "ZZZ" + str(rows[0])
			room["rows"] = rows
	var changed: Dictionary = RoomFile._delta(stem, edited)
	var u_rooms := (untouched.get("rooms", []) as Array).size()
	var c_rooms := (changed.get("rooms", []) as Array).size()
	print("delta file ", stem, " door_drift ", drift, "/", with_doors, " untouched_rooms ", u_rooms, " edited_rooms ", c_rooms, " untouched_keys ", untouched.keys())


func _xml_all() -> void:
	var files := 0
	var rooms_n := 0
	for f in DirAccess.get_files_at(DIR):
		var name := str(f)
		if not name.begins_with("rooms_") or not name.ends_with(".json"):
			continue
		files += 1
		var stem := name.get_basename()
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("%s/%s" % [DIR, name]))
		if typeof(raw) != TYPE_DICTIONARY:
			_bad("name", "%s bad json" % stem)
			continue
		var doc: Dictionary = raw
		var xml := Codec.xml_from_doc(doc)
		var back: Dictionary = Codec.doc_from_xml(xml, stem)
		var a: Array = doc.get("rooms", [])
		var b: Array = back.get("rooms", [])
		rooms_n += a.size()
		if a.size() != b.size():
			_bad("name", "%s room count %d -> %d" % [stem, a.size(), b.size()])
			if b.is_empty():
				var p := XMLParser.new()
				print("  open_buffer ", p.open_buffer(xml.to_utf8_buffer()))
		var n := mini(a.size(), b.size())
		for i in n:
			_cmp_room(stem, a[i], b[i])
	print("xml files ", files, " rooms ", rooms_n)


func _cmp_room(stem: String, a: Dictionary, b: Dictionary) -> void:
	var room := "%s %s" % [stem, str(a.get("name", ""))]
	if str(a.get("name", "")) != str(b.get("name", "")):
		_bad("name", "%s name %s -> %s" % [stem, a.get("name", ""), b.get("name", "")])
	var ar: Array = a.get("rows", [])
	var br: Array = b.get("rows", [])
	if ar != br:
		var at := ""
		for i in mini(ar.size(), br.size()):
			if str(ar[i]) != str(br[i]):
				at = "row %d %s -> %s" % [i, str(ar[i]).substr(0, 40), str(br[i]).substr(0, 40)]
				break
		if at == "":
			at = "row count %d -> %d" % [ar.size(), br.size()]
		_bad("rows", "%s %s" % [room, at])
	for axis in ["x", "y", "z"]:
		var ha := a.has(axis)
		var hb := b.has(axis)
		if ha != hb or (ha and int(a[axis]) != int(b[axis])):
			_bad("xyz", "%s %s %s -> %s" % [room, axis, a.get(axis, "-"), b.get(axis, "-")])
	var oa: Dictionary = a.get("options", {})
	var ob: Dictionary = b.get("options", {})
	if oa != ob:
		_bad("options", "%s options %s -> %s" % [room, oa, ob])
	var da := a.has("doors")
	var db := b.has("doors")
	if da != db or (da and not _doors_eq(a["doors"], b.get("doors", []))):
		_bad("doors", "%s doors %s -> %s" % [room, a.get("doors", "-"), b.get("doors", "-")])
	var ao: Array = a.get("objs", [])
	var bo: Array = b.get("objs", [])
	if ao.size() != bo.size():
		_bad("objs", "%s objs count %d -> %d" % [room, ao.size(), bo.size()])
	else:
		for i in ao.size():
			if not _obj_eq(ao[i], bo[i]):
				_bad("objs", "%s #%d %s" % [room, i, _obj_diff_one(ao[i], bo[i])])


func _obj_eq(a: Dictionary, b: Dictionary) -> bool:
	if str(a.get("tag", "")) != str(b.get("tag", "")):
		return false
	if str(a.get("id", "")) != str(b.get("id", "")):
		return false
	if int(a.get("x", 0)) != int(b.get("x", 0)) or int(a.get("y", 0)) != int(b.get("y", 0)):
		return false
	if int(a.get("size", 1)) != int(b.get("size", 1)):
		return false
	if str(a.get("kind", "")) != str(b.get("kind", "")):
		return false
	if (a.get("attrs", {}) as Dictionary) != (b.get("attrs", {}) as Dictionary):
		return false
	return _kids_eq(a.get("kids", []), b.get("kids", []))


func _kids_eq(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		var ka: Dictionary = a[i]
		var kb: Dictionary = b[i]
		if str(ka.get("tag", "")) != str(kb.get("tag", "")):
			return false
		if (ka.get("attrs", {}) as Dictionary) != (kb.get("attrs", {}) as Dictionary):
			return false
		if not _kids_eq(ka.get("kids", []), kb.get("kids", [])):
			return false
	return true


func _obj_diff_one(ao: Dictionary, bo: Dictionary) -> String:
	if str(ao.get("id", "")) != str(bo.get("id", "")) or str(ao.get("tag", "")) != str(bo.get("tag", "")):
		return "%s/%s -> %s/%s" % [ao.get("tag", ""), ao.get("id", ""), bo.get("tag", ""), bo.get("id", "")]
	if int(ao.get("x", 0)) != int(bo.get("x", 0)) or int(ao.get("y", 0)) != int(bo.get("y", 0)):
		return "%s xy %s,%s -> %s,%s" % [ao.get("id", ""), ao.get("x", ""), ao.get("y", ""), bo.get("x", ""), bo.get("y", "")]
	if int(ao.get("size", 1)) != int(bo.get("size", 1)) or str(ao.get("kind", "")) != str(bo.get("kind", "")):
		return "%s size/kind %s/%s -> %s/%s" % [ao.get("id", ""), ao.get("size", ""), ao.get("kind", ""), bo.get("size", ""), bo.get("kind", "")]
	if (ao.get("attrs", {}) as Dictionary) != (bo.get("attrs", {}) as Dictionary):
		return "%s attrs" % ao.get("id", "")
	return "%s kids" % ao.get("id", "")


func _doors_eq(a: Variant, b: Variant) -> bool:
	if not (a is Array) or not (b is Array):
		return false
	var aa: Array = a
	var bb: Array = b
	if aa.size() != bb.size():
		return false
	for i in aa.size():
		if int(aa[i]) != int(bb[i]):
			return false
	return true


func _floats(v: Variant) -> Variant:
	match typeof(v):
		TYPE_INT:
			return float(v)
		TYPE_ARRAY:
			var src: Array = v
			var out: Array = []
			for item in src:
				out.append(_floats(item))
			return out
		TYPE_DICTIONARY:
			var src_d: Dictionary = v
			var out_d := {}
			for k in src_d.keys():
				out_d[k] = _floats(src_d[k])
			return out_d
	return v


func _bad(kind: String, msg: String) -> void:
	_counts[kind] = int(_counts.get(kind, 0)) + 1
	if _shown < 20:
		print(msg)
		_shown += 1
