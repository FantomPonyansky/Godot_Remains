extends RefCounted

const Palette := preload("res://scripts/editor/editor_palette.gd")

## Cell tokens and room XML, same rules as Editor.swf edTile.enc/dec.
## A token is front (or `_`) + optional zForm `,` `;` `:` + back + stair + diag + water.

const COLS := 48
const ROWS := 25
const ZFORM := {",": 1, ";": 2, ":": 3}
const ZCHAR := ["", ",", ";", ":"]
const STAIR := {"А": true, "Б": true}
const DIAG := {
	"-": true, "Д": true, "Е": true, "К": true, "Н": true, "Р": true,
	"В": true, "Г": true, "Ж": true, "З": true, "И": true, "Й": true,
	"Л": true, "М": true, "О": true, "П": true, "С": true, "Т": true,
}


static func empty_cell() -> Dictionary:
	return {"front": "", "back": "", "stair": "", "diag": "", "water": "", "zform": 0}


static func parse_token(s: String) -> Dictionary:
	var cell := empty_cell()
	if s.is_empty():
		return cell
	var head := s.substr(0, 1)
	if head != "_":
		cell.front = head
	for i in range(1, s.length()):
		var ch := s.substr(i, 1)
		if ZFORM.has(ch):
			cell.zform = int(ZFORM[ch])
		elif ch == "*":
			cell.water = "*"
		elif STAIR.has(ch):
			cell.stair = ch
		elif DIAG.has(ch):
			cell.diag = ch
		elif ch != "_":
			cell.back = ch
	return cell


static func token_ok(s: String) -> bool:
	if s.is_empty():
		return false
	if encode_token(parse_token(s)) == s:
		return true
	for i in s.length():
		var c := s.unicode_at(i)
		var ok := (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c > 127
		ok = ok or c == 95 or c == 42 or c == 44 or c == 59 or c == 58
		if not ok:
			return false
	return true


static func room_xml(room: Dictionary) -> String:
	return _room_xml(room)


static func land_xml(doc: Dictionary) -> String:
	var attrs := ""
	if bool(doc.get("placed", false)):
		attrs += " serial=\"1\""
	var title := str(doc.get("title", ""))
	if title != "":
		attrs += " title=\"%s\"" % _esc(title)
	var opt: Variant = doc.get("options", {})
	if opt is Dictionary:
		for k in (opt as Dictionary).keys():
			attrs += " %s=\"%s\"" % [str(k), _esc(str(opt[k]))]
	var out := PackedStringArray()
	out.append("<?xml version=\"1.0\" encoding=\"utf-8\"?>")
	out.append("<land%s>" % attrs)
	for room_v in doc.get("rooms", []):
		if typeof(room_v) == TYPE_DICTIONARY:
			out.append(_room_xml(room_v))
	out.append("</land>")
	return "\n".join(out) + "\n"


static func encode_token(cell: Dictionary) -> String:
	var front := str(cell.get("front", ""))
	var s := "_" if front == "" else front
	var z := clampi(int(cell.get("zform", 0)), 0, 3)
	s += ZCHAR[z]
	for key in ["back", "stair", "diag", "water"]:
		var v := str(cell.get(key, ""))
		if v != "":
			s += v
	return s


static func parse_row(row: String) -> Array:
	var cells: Array = []
	var parts := row.split(".")
	for i in COLS:
		cells.append(parse_token(parts[i] if i < parts.size() else ""))
	return cells


static func encode_row(cells: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.resize(COLS)
	for i in COLS:
		parts[i] = encode_token(cells[i] if i < cells.size() else empty_cell())
	return ".".join(parts)


static func grid_from_rows(rows: Array) -> Array:
	var grid: Array = []
	for y in ROWS:
		grid.append(parse_row(str(rows[y]) if y < rows.size() else ""))
	return grid


static func rows_from_grid(grid: Array) -> Array:
	var rows: Array = []
	for y in ROWS:
		rows.append(encode_row(grid[y] if y < grid.size() else []))
	return rows


## Editor.getDoors: solid is a nonempty front slot (not RoomFile.is_open_code, which
## also treats a first character ≤ 64 as open). Geometry is the same 22 slots.
static func doors_from_rows(rows: Array) -> Array:
	var mask: Array = []
	for n in 22:
		mask.append(_door_width(rows, n))
	return mask


static func _front(rows: Array, x: int, y: int) -> bool:
	if y < 0 or y >= rows.size() or x < 0:
		return false
	var parts: PackedStringArray = str(rows[y]).split(".")
	if x >= parts.size():
		return false
	return str(parse_token(parts[x]).get("front", "")) != ""


static func _door_width(rows: Array, n: int) -> int:
	var q := 0
	if n >= 17:
		q = (n - 17) * 9 + 4
		if _front(rows, q + 1, 0) or _front(rows, q + 2, 0) or _front(rows, q + 1, 1) or _front(rows, q + 2, 1):
			return 0
		if not _front(rows, q, 0) and not _front(rows, q + 3, 0) and not _front(rows, q, 1) and not _front(rows, q + 3, 1):
			return 4
		return 2
	if n >= 11:
		q = (n - 11) * 4 + 3
		if _front(rows, 0, q) or _front(rows, 0, q - 1) or _front(rows, 1, q) or _front(rows, 1, q - 1):
			return 0
		if not _front(rows, 0, q - 2) and not _front(rows, 1, q - 2):
			return 3
		return 2
	if n >= 6:
		q = (n - 6) * 9 + 4
		var bottom := ROWS - 1
		if _front(rows, q + 1, bottom) or _front(rows, q + 2, bottom) or _front(rows, q + 1, bottom - 1) or _front(rows, q + 2, bottom - 1):
			return 0
		if not _front(rows, q, bottom) and not _front(rows, q + 3, bottom) and not _front(rows, q, bottom - 1) and not _front(rows, q + 3, bottom - 1):
			return 4
		return 2
	q = n * 4 + 3
	var right := COLS - 1
	if _front(rows, right, q) or _front(rows, right, q - 1) or _front(rows, right - 1, q) or _front(rows, right - 1, q - 1):
		return 0
	if not _front(rows, right, q - 2) and not _front(rows, right - 1, q - 2):
		return 3
	return 2


## Editor.code: 16 chars from 0-9A-Za-z, first char a letter.
static func object_code() -> String:
	const CHARS := "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
	var s := CHARS[10 + randi() % 52]
	for _i in 15:
		s += CHARS[randi() % 62]
	return s


static func doc_from_xml(text: String, file_name: String = "") -> Dictionary:
	var root := XMLParser.new()
	if root.open_buffer(text.to_utf8_buffer()) != OK:
		return {}
	return _read_all(root, file_name)


static func xml_from_doc(doc: Dictionary) -> String:
	var out := PackedStringArray()
	out.append("<?xml version=\"1.0\" encoding=\"utf-8\"?>")
	out.append("<all>")
	if bool(doc.get("placed", false)):
		out.append("<land serial=\"1\"/>")
	for room_v in doc.get("rooms", []):
		out.append(_room_xml(room_v))
	out.append("</all>")
	return "\n".join(out) + "\n"


static func xml_one_room(room: Dictionary) -> String:
	return xml_rooms([room])


static func xml_rooms(rooms: Array) -> String:
	var out := PackedStringArray()
	out.append("<?xml version=\"1.0\" encoding=\"utf-8\"?>")
	out.append("<land>")
	for room_v in rooms:
		if typeof(room_v) == TYPE_DICTIONARY:
			out.append(_room_xml(room_v))
	out.append("</land>")
	return "\n".join(out) + "\n"


static func _room_xml(room: Dictionary) -> String:
	var attrs := " name=\"%s\"" % _esc(str(room.get("name", "")))
	for axis in ["x", "y", "z"]:
		if room.has(axis):
			var n := int(room[axis])
			if axis != "z" or n > 0:
				attrs += " %s=\"%d\"" % [axis, n]
	var parts: PackedStringArray = PackedStringArray()
	parts.append("<room%s>" % attrs)
	for row_v in room.get("rows", []):
		parts.append("<a>%s</a>" % str(row_v))
	for obj_v in room.get("objs", []):
		parts.append(node_xml(obj_v, true))
	if room.has("doors") and room.doors is Array:
		var bits: PackedStringArray = PackedStringArray()
		for n in room.doors:
			bits.append(str(int(n)))
		parts.append("<doors>%s</doors>" % ".".join(bits))
	var opt: Dictionary = room.get("options", {})
	if not opt.is_empty():
		var o := "<options"
		for k in opt.keys():
			o += " %s=\"%s\"" % [str(k), _esc(str(opt[k]))]
		parts.append(o + "/>")
	parts.append("</room>")
	return "\n".join(parts)


static func node_xml(obj: Dictionary, room_obj: bool) -> String:
	var tag := str(obj.get("tag", "obj"))
	var attrs := ""
	if room_obj:
		attrs += " id=\"%s\" x=\"%s\" y=\"%s\"" % [_esc(str(obj.get("id", ""))), str(int(obj.get("x", 0))), str(int(obj.get("y", 0)))]
		var extra: Dictionary = obj.get("attrs", {})
		for k in extra.keys():
			attrs += " %s=\"%s\"" % [str(k), _esc(str(extra[k]))]
	else:
		var extra2: Dictionary = obj.get("attrs", {})
		for k in extra2.keys():
			attrs += " %s=\"%s\"" % [str(k), _esc(str(extra2[k]))]
	var kids: Array = obj.get("kids", [])
	if kids.is_empty():
		return "<%s%s/>" % [tag, attrs]
	var parts: PackedStringArray = PackedStringArray()
	parts.append("<%s%s>" % [tag, attrs])
	for kid in kids:
		parts.append(node_xml(kid, false))
	parts.append("</%s>" % tag)
	return "".join(parts)


static func _esc(s: String) -> String:
	return s.replace("&", "&amp;").replace("\"", "&quot;").replace("<", "&lt;").replace(">", "&gt;")


static func _read_all(p: XMLParser, file_name: String) -> Dictionary:
	var rooms: Array = []
	var placed := false
	var opt := {}
	var title := ""
	while p.read() == OK:
		if p.get_node_type() != XMLParser.NODE_ELEMENT:
			continue
		var name := p.get_node_name()
		if name == "land":
			placed = p.get_named_attribute_value_safe("serial") == "1"
			for i in p.get_attribute_count():
				var k := p.get_attribute_name(i)
				if k == "serial":
					continue
				if k == "title":
					title = p.get_attribute_value(i)
				else:
					opt[k] = p.get_attribute_value(i)
		elif name == "room":
			rooms.append(_read_room(p))
	var doc := {"file": file_name, "source": "xml", "placed": placed, "rooms": rooms}
	if title != "":
		doc["title"] = title
	if not opt.is_empty():
		doc["options"] = opt
	return doc


static func _read_room(p: XMLParser) -> Dictionary:
	var room := {
		"name": p.get_named_attribute_value_safe("name"),
		"rows": [],
		"objs": [],
	}
	for axis in ["x", "y", "z"]:
		var v := p.get_named_attribute_value_safe(axis)
		if v != "":
			room[axis] = int(v)
	if p.is_empty():
		return room
	while p.read() == OK:
		var kind := p.get_node_type()
		if kind == XMLParser.NODE_ELEMENT_END and p.get_node_name() == "room":
			break
		if kind != XMLParser.NODE_ELEMENT:
			continue
		var tag := p.get_node_name()
		if tag == "a":
			room.rows.append(_text_until(p, "a"))
		elif tag == "doors":
			var bits: Array = []
			for part in _text_until(p, "doors").split("."):
				bits.append(int(part) if part.is_valid_int() else 0)
			room.doors = bits
		elif tag == "options":
			var opt := {}
			for i in p.get_attribute_count():
				opt[p.get_attribute_name(i)] = p.get_attribute_value(i)
			room.options = opt
			if not p.is_empty():
				_skip(p, "options")
		elif tag == "obj" or tag == "back":
			room.objs.append(_read_obj(p, tag))
	return room


static func _read_obj(p: XMLParser, tag: String) -> Dictionary:
	var obj := {"tag": tag, "id": p.get_named_attribute_value_safe("id"), "x": int(p.get_named_attribute_value_safe("x")), "y": int(p.get_named_attribute_value_safe("y")), "size": 1}
	var extra := {}
	for i in p.get_attribute_count():
		var k := p.get_attribute_name(i)
		if k != "id" and k != "x" and k != "y":
			extra[k] = p.get_attribute_value(i)
	if not extra.is_empty():
		obj.attrs = extra
	if p.is_empty():
		_fill_obj(obj)
		return obj
	var kids: Array = []
	while p.read() == OK:
		var kind := p.get_node_type()
		if kind == XMLParser.NODE_ELEMENT_END and p.get_node_name() == tag:
			break
		if kind == XMLParser.NODE_ELEMENT:
			kids.append(_read_kid(p))
	if not kids.is_empty():
		obj.kids = kids
	_fill_obj(obj)
	return obj


static func _fill_obj(obj: Dictionary) -> void:
	if str(obj.get("tag", "")) != "obj":
		return
	var meta: Dictionary = Palette.object_meta(str(obj.get("id", "")))
	obj["size"] = int(meta.get("size", 1))
	var kind := str(meta.get("kind", ""))
	if kind != "":
		obj["kind"] = kind


static func _read_kid(p: XMLParser) -> Dictionary:
	var node := {"tag": p.get_node_name()}
	if p.get_attribute_count() > 0:
		var attrs := {}
		for i in p.get_attribute_count():
			attrs[p.get_attribute_name(i)] = p.get_attribute_value(i)
		node.attrs = attrs
	if p.is_empty():
		return node
	var kids: Array = []
	var tag := p.get_node_name()
	while p.read() == OK:
		var kind := p.get_node_type()
		if kind == XMLParser.NODE_ELEMENT_END and p.get_node_name() == tag:
			break
		if kind == XMLParser.NODE_ELEMENT:
			kids.append(_read_kid(p))
	if not kids.is_empty():
		node.kids = kids
	return node


static func _text_until(p: XMLParser, tag: String) -> String:
	if p.is_empty():
		return ""
	var text := ""
	while p.read() == OK:
		var kind := p.get_node_type()
		if kind == XMLParser.NODE_ELEMENT_END and p.get_node_name() == tag:
			break
		if kind == XMLParser.NODE_TEXT:
			text += p.get_node_data()
	return text


static func _skip(p: XMLParser, tag: String) -> void:
	while p.read() == OK:
		if p.get_node_type() == XMLParser.NODE_ELEMENT_END and p.get_node_name() == tag:
			return
