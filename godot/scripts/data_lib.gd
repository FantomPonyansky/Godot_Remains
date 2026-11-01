class_name DataLib
extends RefCounted

## One loader for res:// JSON asset data. Not an autoload: -s checks can call it.
##
## load(path) parses each path once per process and returns the cached value.
## It is read-only (writes raise an engine error). copy(path) is a deep copy for code that writes
## into the table (loot pools stamp a running total on each row).
## rows(path) / by_id(path) are the normalised shape: an array of rows, or an
## id-keyed object. A scalar map's rows are {id, value}. Both are read-only.
## A missing file returns null and does not report. A bad JSON or a schema miss
## is reported once (push_error and a log line) and does not crash.
##
## Inside this script call DataLib.load: a bare load() is the engine's
## ResourceLoader and returns a JSON resource.
##
## load() merges enabled mods over the built-in file (_merge_overlays). The
## cached value stays deep read-only. Mod JSON and schema failures are log
## lines (ModLoader: skip …); they are not push_error. Mod files are parsed
## without the engine JSON parser, so a broken file does not print ERROR.
## Built-in schema misses still push_error. In a -s run nothing calls UserDir._init, so the first
## load boots mods itself when the user dir is visible from the command line.

const Schemas = preload("res://scripts/data_schemas.gd")

static var _lock := Mutex.new()
static var _cache: Dictionary = {}
static var _norm: Dictionary = {}
static var _reported: Dictionary = {}
static var _overlay_ready := false
static var _vetting := false
static var _collecting := false
static var _errs: Array = []
static var _overlaid: Dictionary = {}
static var _notes := PackedStringArray()


static func load(path: String) -> Variant:
	if path == "":
		return null
	_lock.lock()
	if _cache.has(path):
		var hit: Variant = _cache[path]
		_lock.unlock()
		return hit
	_lock.unlock()
	var base: Variant = _read(path)
	var merged: Variant = _merge_overlays(path, base)
	if _vetting:
		return merged
	if merged != null:
		_validate(path, merged)
		_freeze(merged)
	_lock.lock()
	if not _cache.has(path):
		_cache[path] = merged
	else:
		merged = _cache[path]
	_lock.unlock()
	return merged


static func copy(path: String) -> Variant:
	var value: Variant = DataLib.load(path)
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value


static func rows(path: String) -> Array:
	var built: Variant = _view(path, "rows")
	return built if built is Array else []


static func by_id(path: String) -> Dictionary:
	var built: Variant = _view(path, "by_id")
	return built if built is Dictionary else {}


## Read-only all the way down, so a caller that writes into a shared table gets
## an engine error instead of changing it for every other reader.
static func _freeze(value: Variant) -> void:
	if value is Dictionary:
		for v in (value as Dictionary).values():
			_freeze(v)
		(value as Dictionary).make_read_only()
	elif value is Array:
		for v in value as Array:
			_freeze(v)
		(value as Array).make_read_only()


## Mod data, merged in load order over a copy of the built-in value.
## `remove` deletes ids from that object and from direct id-rows. Id-keyed
## objects and id-rows deep-merge (mod fields win). An array whose rows have
## no ids is replaced. The cached built-in value is never written.
static func _merge_overlays(path: String, base: Variant) -> Variant:
	if not _overlay_ready and not _vetting:
		var mods = load("res://scripts/mod_loader.gd")
		if mods != null and not bool(mods.booted()):
			mods.boot()
	if not _overlaid.has(path):
		return base
	return _dup(_overlaid[path])


static func notes() -> PackedStringArray:
	return _notes.duplicate()


## Test hook. The menu does not call this; mod switches apply on the next boot.
static func drop_overlays() -> void:
	_overlay_ready = false
	_vetting = false
	_overlaid.clear()
	_notes = PackedStringArray()
	_lock.lock()
	_cache.clear()
	_norm.clear()
	_lock.unlock()


## mods: enabled records from ModLoader, each with a `files` array of
## {rel, abs, res}. A mod that fails JSON or schema on any file is omitted
## entirely. Returns {good, skip, applied}.
static func vet_mods(mods: Array) -> Dictionary:
	_vetting = true
	_overlay_ready = false
	var running := {}
	var owners := {}
	var good: Array = []
	var skip := {}
	var applied: Array = []
	for mod_v in mods:
		var mod: Dictionary = mod_v
		var id := str(mod.get("id", ""))
		var files: Array = mod.get("files", [])
		var staged := {}
		var parsed := {}
		var reason := ""
		for file_v in files:
			var file: Dictionary = file_v
			var res := str(file.get("res", ""))
			var text := FileAccess.get_file_as_string(str(file.get("abs", "")))
			var body: Variant = _parse_mod_json(text)
			if body == null:
				reason = "%s JSON did not parse" % str(file.get("rel", res))
				break
			var base: Variant = running[res] if running.has(res) else _read(res)
			var spec: Dictionary = Schemas.for_path(res)
			var merged: Variant = _merge_value(base, body, spec)
			var problems := _problems_of(res, merged)
			if not problems.is_empty():
				var err: Array = problems[0]
				var at := str(err[0])
				var where := res if at == "" else "%s id=%s" % [res, at]
				reason = "%s: %s" % [where, str(err[1])]
				break
			staged[res] = merged
			parsed[res] = body
		if reason != "":
			skip[id] = reason
			_note("ModLoader: skip %s: %s" % [id, reason])
			continue
		for res in staged.keys():
			var spec_ok: Dictionary = Schemas.for_path(str(res))
			var who: Dictionary = owners.get(res, {})
			for claim in _claims(parsed[res], spec_ok):
				if who.has(claim) and str(who[claim]) != id:
					_note("DataLib: duplicate id %s in %s: %s then %s, last wins" % [claim, res, who[claim], id])
				who[claim] = id
			owners[res] = who
			running[res] = staged[res]
		good.append(mod)
		applied.append({"id": id, "version": str(mod.get("version", ""))})
	for path in running.keys():
		var ids := _id_list(str(path), running[path])
		_note("DataLib: merged %s ids: %s" % [path, ", ".join(ids)])
	_overlaid = running
	_overlay_ready = true
	_vetting = false
	return {"good": good, "skip": skip, "applied": applied}


static func _note(line: String) -> void:
	_notes.append(line)
	print(line)


static func _problems_of(path: String, data: Variant) -> Array:
	_errs = []
	_collecting = true
	_validate(path, data)
	_collecting = false
	var out := _errs.duplicate()
	_errs = []
	return out


static func _merge_value(base: Variant, modv: Variant, spec: Dictionary) -> Variant:
	if modv is Dictionary and (base is Dictionary or base == null):
		var src: Dictionary = base if base is Dictionary else {}
		return _merge_dict(src, modv, spec)
	if modv is Array and base is Array:
		var field := str(spec.get("id_field", "id"))
		return _merge_array(base, modv, field, true)
	return _dup(modv)


static func _merge_dict(base: Dictionary, modv: Dictionary, spec: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	var list_key := str(spec.get("list", ""))
	var id_field := str(spec.get("id_field", "id"))
	if modv.get("remove", null) is Array:
		var remove: Array = modv["remove"]
		out.erase("remove")
		for id in remove:
			out.erase(str(id))
		for key in out.keys():
			if out[key] is Array:
				out[key] = _strip_ids(out[key], remove, id_field)
	for key in modv.keys():
		if str(key) == "remove":
			continue
		var mv: Variant = modv[key]
		if out.has(key) and out[key] is Dictionary and mv is Dictionary:
			out[key] = _merge_dict(out[key], mv, {})
		elif mv is Array and (not out.has(key) or out[key] is Array):
			var cur: Array = out[key] if out.has(key) else []
			var field := id_field if str(key) == list_key else "id"
			out[key] = _merge_array(cur, mv, field, true)
		elif not out.has(key) and mv is Dictionary:
			out[key] = _merge_dict({}, mv, {})
		else:
			out[key] = _dup(mv)
	return out


static func _merge_array(base: Array, modv: Array, field: String, by_id: bool) -> Array:
	if not by_id or not _all_ids(modv, field):
		return _dup(modv)
	var out := base.duplicate(true)
	var index := {}
	for i in out.size():
		if out[i] is Dictionary:
			var id := str((out[i] as Dictionary).get(field, ""))
			if id != "":
				index[id] = i
	for item in modv:
		var row: Dictionary = item
		var id := str(row.get(field, ""))
		if index.has(id) and out[int(index[id])] is Dictionary:
			var at := int(index[id])
			out[at] = _merge_dict(out[at], row, {})
		else:
			out.append(_dup(row))
			index[id] = out.size() - 1
	return out


static func _all_ids(rows: Array, field: String) -> bool:
	if rows.is_empty():
		return false
	for item in rows:
		if item is not Dictionary or str((item as Dictionary).get(field, "")) == "":
			return false
	return true


static func _strip_ids(rows: Array, ids: Array, field: String) -> Array:
	var drop := {}
	for id in ids:
		drop[str(id)] = true
	var kept: Array = []
	for item in rows:
		if item is Dictionary:
			var id := str((item as Dictionary).get(field, ""))
			if id != "" and drop.has(id):
				continue
		kept.append(item)
	return kept


static func _claims(modv: Variant, spec: Dictionary) -> PackedStringArray:
	var ids := PackedStringArray()
	if modv is not Dictionary:
		return ids
	var body: Dictionary = modv
	if body.get("remove", null) is Array:
		for id in body["remove"]:
			ids.append(str(id))
	var list_key := str(spec.get("list", ""))
	var field := str(spec.get("id_field", "id"))
	if list_key != "" and body.get(list_key, null) is Array:
		for row in body[list_key]:
			if row is Dictionary:
				var id := str((row as Dictionary).get(field, ""))
				if id != "":
					ids.append(id)
	var map_key := str(spec.get("map", ""))
	if map_key != "" and body.get(map_key, null) is Dictionary:
		var bag: Dictionary = body[map_key]
		if bag.get("remove", null) is Array:
			for id in bag["remove"]:
				ids.append(str(id))
		for k in bag.keys():
			if str(k) != "remove":
				ids.append(str(k))
	elif (spec.get("of", {}) as Dictionary).has("."):
		for k in body.keys():
			if str(k) != "remove":
				ids.append(str(k))
	return ids


static func _id_list(path: String, data: Variant) -> PackedStringArray:
	var spec: Dictionary = Schemas.for_path(path)
	var ids := PackedStringArray()
	var listed: Variant = _listed(data, spec)
	if listed is Array:
		var field := str(spec.get("id_field", "id"))
		for row in listed as Array:
			if row is Dictionary:
				var id := str((row as Dictionary).get(field, ""))
				if id != "":
					ids.append(id)
		return ids
	for k in _mapped(data, spec).keys():
		ids.append(str(k))
	return ids


static func _dup(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value


static func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		_fail(path, "", "JSON did not parse")
		return null
	return parsed


static func _view(path: String, which: String) -> Variant:
	_lock.lock()
	var slot: Dictionary = _norm.get(path, {}) as Dictionary
	if slot.has(which):
		var hit: Variant = slot[which]
		_lock.unlock()
		return hit
	_lock.unlock()
	var data: Variant = DataLib.load(path)
	var spec: Dictionary = Schemas.for_path(path) as Dictionary
	var made := {"rows": _make_rows(data, spec), "by_id": _make_ids(data, spec)}
	_freeze(made["rows"])
	_freeze(made["by_id"])
	_lock.lock()
	slot = _norm.get(path, {}) as Dictionary
	if not slot.has(which):
		slot = made
		_norm[path] = slot
	var out: Variant = slot[which]
	_lock.unlock()
	return out


static func _make_rows(data: Variant, spec: Dictionary) -> Array:
	var listed: Variant = _listed(data, spec)
	if listed is Array:
		return listed as Array
	var src := _mapped(data, spec)
	if src.is_empty():
		return []
	var all_dict := true
	for id in src:
		if src[id] is not Dictionary:
			all_dict = false
			break
	var out: Array = []
	if all_dict:
		for id in src:
			out.append(src[id])
		return out
	for id in src:
		out.append({"id": str(id), "value": src[id]})
	return out


static func _make_ids(data: Variant, spec: Dictionary) -> Dictionary:
	var listed: Variant = _listed(data, spec)
	if listed is Array:
		var field := str(spec.get("id_field", "id"))
		var out := {}
		for row in (listed as Array):
			if row is Dictionary:
				var id := str((row as Dictionary).get(field, ""))
				if id != "":
					out[id] = row
		return out
	return _mapped(data, spec)


static func _listed(data: Variant, spec: Dictionary) -> Variant:
	var key := str(spec.get("list", ""))
	if key != "" and data is Dictionary:
		var arr: Variant = (data as Dictionary).get(key, [])
		return arr if arr is Array else []
	if str(spec.get("root", "")) == "array" and data is Array:
		return data
	return null


static func _mapped(data: Variant, spec: Dictionary) -> Dictionary:
	if data is not Dictionary:
		return {}
	var key := str(spec.get("map", ""))
	var of: Dictionary = spec.get("of", {}) as Dictionary
	if key == "":
		if of.has("."):
			return data as Dictionary
		if of.size() == 1:
			key = str(of.keys()[0])
	if key == "":
		return {}
	var sub: Variant = (data as Dictionary).get(key, {})
	if sub is Dictionary:
		return sub as Dictionary
	return {}


static func _validate(path: String, data: Variant) -> void:
	var spec: Dictionary = Schemas.for_path(path) as Dictionary
	if spec.is_empty():
		_fail(path, "", "no schema")
		return
	var root := str(spec.get("root", ""))
	if root == "dict" and data is not Dictionary:
		_fail(path, "", "root is not an object")
		return
	if root == "array" and data is not Array:
		_fail(path, "", "root is not an array")
		return
	if data is Dictionary:
		var req: Dictionary = spec.get("req", {}) as Dictionary
		for key in req:
			if not (data as Dictionary).has(key):
				_fail(path, "", "missing %s" % key)
			elif not _is_type((data as Dictionary)[key], str(req[key])):
				_fail(path, "", "%s is not %s" % [key, str(req[key])])
		var of: Dictionary = spec.get("of", {}) as Dictionary
		for key in of:
			var bag: Variant = data if str(key) == "." else (data as Dictionary).get(key, null)
			if bag is Dictionary:
				_check_map(path, bag as Dictionary, str(of[key]), spec)
	var listed: Variant = _listed(data, spec)
	if listed is Array:
		_check_rows(path, listed as Array, spec)


static func _check_map(path: String, bag: Dictionary, kind: String, spec: Dictionary) -> void:
	var fields: Dictionary = spec.get("fields", {}) as Dictionary
	var array_of := str(spec.get("array_of", ""))
	var array_min := int(spec.get("array_min", 0))
	for id in bag:
		var value: Variant = bag[id]
		if not _is_type(value, kind):
			_fail(path, str(id), "value is not %s" % kind)
			continue
		if value is Dictionary and not fields.is_empty():
			_check_fields(path, str(id), value as Dictionary, fields)
		if value is Array and array_of != "":
			if (value as Array).size() < array_min:
				_fail(path, str(id), "array shorter than %d" % array_min)
			for item in (value as Array):
				if not _is_type(item, array_of):
					_fail(path, str(id), "array element is not %s" % array_of)
					break


static func _check_rows(path: String, rows: Array, spec: Dictionary) -> void:
	var fields: Dictionary = spec.get("row", {}) as Dictionary
	var field := str(spec.get("id_field", "id"))
	var unique := bool(spec.get("unique", false))
	var seen := {}
	for i in rows.size():
		var row: Variant = rows[i]
		var at := str(i)
		if row is not Dictionary:
			_fail(path, at, "row is not an object")
			continue
		var id := str((row as Dictionary).get(field, ""))
		if unique:
			if id == "":
				_fail(path, at, "missing %s" % field)
			elif seen.has(id):
				_fail(path, id, "duplicate %s" % field)
			else:
				seen[id] = true
		if id != "":
			at = id
		if not fields.is_empty():
			_check_fields(path, at, row as Dictionary, fields)


static func _check_fields(path: String, id: String, row: Dictionary, fields: Dictionary) -> void:
	for key in fields:
		if not row.has(key):
			_fail(path, id, "missing %s" % key)
		elif not _is_type(row[key], str(fields[key])):
			_fail(path, id, "%s is not %s" % [key, str(fields[key])])


static func _is_type(value: Variant, kind: String) -> bool:
	match kind:
		"dict":
			return value is Dictionary
		"array":
			return value is Array
		"string":
			return value is String
		"number":
			return value is float or value is int
		"bool":
			return value is bool
		_:
			return false


static func _fail(path: String, id: String, message: String) -> void:
	if _collecting:
		_errs.append([id, message])
		return
	var token := "%s|%s|%s" % [path, id, message]
	_lock.lock()
	if _reported.has(token):
		_lock.unlock()
		return
	_reported[token] = true
	_lock.unlock()
	var where := path if id == "" else "%s id=%s" % [path, id]
	var line := "DataLib: %s: %s" % [where, message]
	push_error(line)
	print(line)


## Mod JSON only. A broken file returns null and does not print ERROR
## (JSON.parse_string does, and the check runner treats that as a failure).
static func _parse_mod_json(text: String) -> Variant:
	var parser := _QuietJson.new(text)
	var out: Variant = parser.value()
	if parser.bad:
		return null
	return out


class _QuietJson:
	var _s: String
	var _i := 0
	var _n := 0
	var bad := false

	func _init(text: String) -> void:
		_s = text
		_n = text.length()
		if _n > 0 and _s.unicode_at(0) == 0xFEFF:
			_i = 1

	func value() -> Variant:
		_skip()
		var out: Variant = _value()
		_skip()
		if bad or _i < _n:
			bad = true
			return null
		return out

	func _value() -> Variant:
		_skip()
		if bad or _i >= _n:
			bad = true
			return null
		var c := _s.unicode_at(_i)
		if c == 123:
			return _object()
		if c == 91:
			return _array()
		if c == 34:
			return _string()
		if c == 116:
			return _lit("true", true)
		if c == 102:
			return _lit("false", false)
		if c == 110:
			return _lit("null", null)
		if c == 45 or (c >= 48 and c <= 57):
			return _number()
		bad = true
		return null

	func _object() -> Dictionary:
		_i += 1
		var out := {}
		_skip()
		if _i < _n and _s.unicode_at(_i) == 125:
			_i += 1
			return out
		while not bad and _i < _n:
			if _s.unicode_at(_i) != 34:
				bad = true
				return {}
			var key := _string()
			_skip()
			if bad or _i >= _n or _s.unicode_at(_i) != 58:
				bad = true
				return {}
			_i += 1
			var val: Variant = _value()
			if bad:
				return {}
			out[key] = val
			_skip()
			if _i >= _n:
				bad = true
				return {}
			var c := _s.unicode_at(_i)
			_i += 1
			if c == 125:
				return out
			if c != 44:
				bad = true
				return {}
			_skip()
		bad = true
		return {}

	func _array() -> Array:
		_i += 1
		var out: Array = []
		_skip()
		if _i < _n and _s.unicode_at(_i) == 93:
			_i += 1
			return out
		while not bad and _i < _n:
			out.append(_value())
			if bad:
				return []
			_skip()
			if _i >= _n:
				bad = true
				return []
			var c := _s.unicode_at(_i)
			_i += 1
			if c == 93:
				return out
			if c != 44:
				bad = true
				return []
			_skip()
		bad = true
		return []

	func _string() -> String:
		_i += 1
		var out := ""
		while _i < _n:
			var c := _s.unicode_at(_i)
			_i += 1
			if c == 34:
				return out
			if c == 92:
				if _i >= _n:
					bad = true
					return ""
				var e := _s.unicode_at(_i)
				_i += 1
				if e == 34 or e == 92 or e == 47:
					out += char(e)
				elif e == 98:
					out += "\b"
				elif e == 102:
					out += "\f"
				elif e == 110:
					out += "\n"
				elif e == 114:
					out += "\r"
				elif e == 116:
					out += "\t"
				elif e == 117:
					var hex := _hex4()
					if bad:
						return ""
					out += char(hex)
				else:
					bad = true
					return ""
				continue
			if c < 32:
				bad = true
				return ""
			out += char(c)
		bad = true
		return ""

	func _hex4() -> int:
		if _i + 4 > _n:
			bad = true
			return 0
		var n := 0
		for _k in 4:
			var c := _s.unicode_at(_i)
			_i += 1
			var d := -1
			if c >= 48 and c <= 57:
				d = c - 48
			elif c >= 97 and c <= 102:
				d = c - 87
			elif c >= 65 and c <= 70:
				d = c - 55
			if d < 0:
				bad = true
				return 0
			n = (n << 4) + d
		return n

	func _number() -> Variant:
		var start := _i
		if _s.unicode_at(_i) == 45:
			_i += 1
		if _i >= _n or not _digit(_i):
			bad = true
			return null
		if _s.unicode_at(_i) == 48:
			_i += 1
		else:
			while _i < _n and _digit(_i):
				_i += 1
		if _i < _n and _s.unicode_at(_i) == 46:
			_i += 1
			if _i >= _n or not _digit(_i):
				bad = true
				return null
			while _i < _n and _digit(_i):
				_i += 1
		if _i < _n and (_s.unicode_at(_i) == 101 or _s.unicode_at(_i) == 69):
			_i += 1
			if _i < _n and (_s.unicode_at(_i) == 43 or _s.unicode_at(_i) == 45):
				_i += 1
			if _i >= _n or not _digit(_i):
				bad = true
				return null
			while _i < _n and _digit(_i):
				_i += 1
		# Engine JSON gives every number as a float; mods must match built-in data.
		return _s.substr(start, _i - start).to_float()

	func _digit(at: int) -> bool:
		var c := _s.unicode_at(at)
		return c >= 48 and c <= 57

	func _lit(word: String, result: Variant) -> Variant:
		if _s.substr(_i, word.length()) != word:
			bad = true
			return null
		_i += word.length()
		return result

	func _skip() -> void:
		while _i < _n:
			var c := _s.unicode_at(_i)
			if c == 32 or c == 9 or c == 10 or c == 13:
				_i += 1
			else:
				return
