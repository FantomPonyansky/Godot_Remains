extends RefCounted

## Test a land or one room from the editor. Install before GameState.reset_run
## so Travel.lands includes editor_play. Leaving the test returns to the editor.

const ID := "editor_play"
const MENU := "res://scenes/main_menu.tscn"
const EDITOR := "res://scenes/room_editor.tscn"
const Codec := preload("res://scripts/editor/room_codec.gd")
const Catalog := preload("res://scripts/map/tile_catalog.gd")
const Reg := preload("res://scripts/map/land_registry.gd")
const Files := preload("res://scripts/map/room_file.gd")
const Doc := preload("res://scripts/editor/room_doc.gd")
static var pending: Dictionary = {}
static var _back: Dictionary = {}


static func start(file_name: String, room_name: String = "", one_room := false, doc: Dictionary = {}, dirty := false, kind := "", fon := "", view: Dictionary = {}) -> void:
	pending = {"file": file_name, "room": room_name, "one_room": one_room, "cell": Vector2i.ZERO, "dirty": dirty, "kind": kind}
	if fon != "":
		pending["fon"] = fon
	if not view.is_empty():
		pending["view"] = view.duplicate(true)
	if not doc.is_empty():
		pending["doc"] = doc.duplicate(true)


static func has_pending() -> bool:
	return str(pending.get("file", "")) != ""


static func install() -> Dictionary:
	var job: Dictionary = pending.duplicate()
	if job.is_empty():
		return {}
	_unpause()
	var RoomFile: GDScript = load("res://scripts/map/room_file.gd")
	var Registry: GDScript = load("res://scripts/map/land_registry.gd")
	var LandGen: GDScript = load("res://scripts/map/land_gen.gd")
	LandGen.unbind_temp(ID)
	var file := str(job.get("file", ""))
	var mem: Variant = job.get("doc", {})
	var doc: Dictionary = (mem as Dictionary).duplicate(true) if mem is Dictionary and not (mem as Dictionary).is_empty() else RoomFile.load_doc(file)
	var room_name := str(job.get("room", ""))
	var one := bool(job.get("one_room", false)) and room_name != ""
	var loc := Vector2i.ZERO
	if one:
		var only: Array = []
		for room_v in doc.get("rooms", []):
			if str(room_v.get("name", "")) != room_name:
				continue
			var copy: Dictionary = (room_v as Dictionary).duplicate(true)
			if not copy.has("x") or not copy.has("y"):
				copy["x"] = 0
				copy["y"] = 0
			copy.erase("z")
			only.append(copy)
			loc = Vector2i(int(copy.x), int(copy.y))
		doc = doc.duplicate(true)
		doc["rooms"] = only
		doc["placed"] = true
		RoomFile.hold(file, doc)
	elif mem is Dictionary and not (mem as Dictionary).is_empty():
		RoomFile.hold(file, doc)
	if not one and room_name != "":
		for room_v in doc.get("rooms", []):
			if str(room_v.get("name", "")) == room_name:
				loc = Vector2i(int(room_v.get("x", 0)), int(room_v.get("y", 0)))
	var row := {
		"id": ID, "file": file, "locx": str(loc.x), "locy": str(loc.y),
		"tip": "story", "dif": "0", "options": {},
	}
	if not one and not bool(doc.get("placed", false)):
		row = _rnd_row(LandGen, Registry, file)
		loc = Vector2i(Registry.int_of(row.get("locx"), 0), Registry.int_of(row.get("locy"), 0))
	# Room documents keep the Test backdrop only. Maps take the land row, then the file's own options.
	if str(job.get("kind", "")) != "room":
		row["options"] = Doc.inherited_options(file, doc)
	var land_opts: Variant = doc.get("options", {})
	if land_opts is Dictionary and not (land_opts as Dictionary).is_empty():
		var merged: Dictionary = (row.get("options", {}) as Dictionary).duplicate(true)
		for key in land_opts:
			merged[key] = land_opts[key]
		row["options"] = merged
	var test_fon := str(job.get("fon", ""))
	if one and test_fon != "":
		var opts: Dictionary = (row.get("options", {}) as Dictionary).duplicate(true)
		opts["fon"] = test_fon
		row["options"] = opts
	job["cell"] = loc
	Registry.register_temp(ID, row)
	return job


## Same shape as a lands.json random row, and a LandGen spec so the land builds.
static func _rnd_row(LandGen: GDScript, Registry: GDScript, file: String) -> Dictionary:
	var ids: Array = LandGen.lands_using(file)
	var spec: Dictionary
	var options := {}
	var stage := "0"
	if not ids.is_empty():
		var src := str(ids[0])
		spec = (LandGen.GENERATED[src] as Dictionary).duplicate()
		var info: Dictionary = Registry.land(src)
		options = (info.get("options", {}) as Dictionary).duplicate(true)
		stage = str(info.get("stage", "0"))
	else:
		spec = {"file": file, "conf": 3, "biom": 3, "mx": 4, "my": 4, "dif": 0, "sx": 0, "sy": 0}
	spec["file"] = file
	LandGen.bind_temp(ID, spec)
	return {
		"id": ID, "tip": "rnd", "rnd": "1", "file": file,
		"dif": str(spec.get("dif", 0)), "biom": str(spec.get("biom", 0)),
		"conf": str(spec.get("conf", 0)), "stage": stage,
		"mx": str(spec.get("mx", 4)), "my": str(spec.get("my", 4)),
		"locx": str(spec.get("sx", 0)), "locy": str(spec.get("sy", 0)),
		"options": options,
	}


static func _finish() -> void:
	var LandGen: GDScript = load("res://scripts/map/land_gen.gd")
	var Registry: GDScript = load("res://scripts/map/land_registry.gd")
	var RoomFile: GDScript = load("res://scripts/map/room_file.gd")
	LandGen.unbind_temp(ID)
	Registry.unregister_temp(ID)
	RoomFile.release()
	RoomFile.drop_cache()
	_back = {
		"file": str(pending.get("file", "")), "room": str(pending.get("room", "")),
		"doc": pending.get("doc", {}), "dirty": bool(pending.get("dirty", false)),
		"kind": str(pending.get("kind", "")), "view": pending.get("view", {}),
	}
	pending.clear()
	_unpause()


static func _unpause() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var state := tree.root.get_node_or_null("GameState")
	if state != null and state.has_method("set_paused"):
		state.set_paused(false)
	tree.paused = false


static func consume_return() -> String:
	if has_pending():
		_finish()
	return EDITOR


static func menu_dest() -> String:
	if has_pending():
		return consume_return()
	return MENU


static func take_back() -> Dictionary:
	var job: Dictionary = _back
	_back = {}
	return job


## Editor play only. Player object, else a door or border entrance that the body
## fits, else the first open cell with a full floor under it and two free cells above.
## Feet sit on the cell's right edge (play_land._feet), so the next column must be open too.
static func spawn_cell(room: Dictionary) -> Vector2i:
	var rows: Array = room.get("rows", [])
	for obj_v in room.get("objs", []):
		if typeof(obj_v) != TYPE_DICTIONARY:
			continue
		var obj: Dictionary = obj_v
		if str(obj.get("id", "")) == "player":
			return Vector2i(int(obj.get("x", 3)), int(obj.get("y", 3)))
	var opened := _door_cells(room)
	var door := _door_stand(room, rows, opened, true)
	if door.x >= 0:
		return door
	var mouth := _entrance_stand(rows, opened)
	if mouth.x >= 0:
		return mouth
	var air := _scan_stand(rows, opened, true)
	if air.x >= 0:
		return air
	var loose := _scan_stand(rows, opened, false)
	if loose.x >= 0:
		return loose
	var buried := _door_stand(room, rows, opened, false)
	if buried.x >= 0:
		return buried
	return Vector2i(3, 3)


static func _door_cells(room: Dictionary) -> Dictionary:
	var open := {}
	for obj_v in room.get("objs", []):
		if typeof(obj_v) != TYPE_DICTIONARY:
			continue
		var obj: Dictionary = obj_v
		if str(obj.get("tag", "obj")) == "back":
			continue
		var info: Dictionary = Reg.obj(str(obj.get("id", "")))
		if str(info.get("tip", "")) != "door":
			continue
		var wh := _wh(obj, info)
		var ox := int(obj.get("x", 0))
		var oy := int(obj.get("y", 0))
		for dx in wh.x:
			for dy in wh.y:
				open[Vector2i(ox + dx, oy - (wh.y - 1) + dy)] = true
	return open


static func _door_stand(room: Dictionary, rows: Array, opened: Dictionary, need_fit: bool) -> Vector2i:
	for obj_v in room.get("objs", []):
		if typeof(obj_v) != TYPE_DICTIONARY:
			continue
		var obj: Dictionary = obj_v
		if str(obj.get("tag", "obj")) == "back":
			continue
		var info: Dictionary = Reg.obj(str(obj.get("id", "")))
		if str(info.get("tip", "")) != "door":
			continue
		var wh := _wh(obj, info)
		var x := int(obj.get("x", 0)) + int((wh.x - 1) / 2)
		var y := int(obj.get("y", 0))
		if not need_fit or _body_fit(rows, opened, x, y):
			return Vector2i(x, y)
	return Vector2i(-1, -1)


static func _entrance_stand(rows: Array, opened: Dictionary) -> Vector2i:
	var mask: Array = Codec.doors_from_rows(rows)
	for n in mask.size():
		if int(mask[n]) <= 0:
			continue
		for at in _mouth_cells(n, int(mask[n])):
			if _body_fit(rows, opened, at.x, at.y):
				return at
	return Vector2i(-1, -1)


static func _mouth_cells(n: int, width: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if n >= 17:
		var q := (n - 17) * 9 + 4
		var y := 1 if width < 3 else 2
		out.append(Vector2i(q + 1, y))
	elif n >= 11:
		var q := (n - 11) * 4 + 3
		out.append(Vector2i(1, q))
		out.append(Vector2i(2, q))
	elif n >= 6:
		var q := (n - 6) * 9 + 4
		out.append(Vector2i(q + 1, Codec.ROWS - 2))
	else:
		var q := n * 4 + 3
		out.append(Vector2i(Codec.COLS - 2, q))
		out.append(Vector2i(Codec.COLS - 3, q))
	return out


static func _scan_stand(rows: Array, opened: Dictionary, two_above: bool) -> Vector2i:
	var y_from := 2 if two_above else 1
	for y in range(y_from, Codec.ROWS - 1):
		for x in Codec.COLS - 1:
			if two_above:
				if _blocked(rows, opened, x, y) or _blocked(rows, opened, x, y - 1) or _blocked(rows, opened, x, y - 2):
					continue
				if _blocked(rows, opened, x + 1, y) or _blocked(rows, opened, x + 1, y - 1):
					continue
				if not _full_floor(rows, opened, x, y + 1):
					continue
				return Vector2i(x, y)
			elif _body_fit(rows, opened, x, y):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


static func _body_fit(rows: Array, opened: Dictionary, x: int, y: int) -> bool:
	if x < 0 or x >= Codec.COLS - 1 or y < 1 or y >= Codec.ROWS - 1:
		return false
	if _blocked(rows, opened, x, y) or _blocked(rows, opened, x, y - 1):
		return false
	if _blocked(rows, opened, x + 1, y) or _blocked(rows, opened, x + 1, y - 1):
		return false
	return _full_floor(rows, opened, x, y + 1)


static func _token(rows: Array, x: int, y: int) -> Dictionary:
	if x < 0 or x >= Codec.COLS or y < 0 or y >= Codec.ROWS:
		return {"front": "A", "diag": "", "zform": 0}
	return Codec.parse_token(Files.code_at(rows, x, y))


static func _kind(diag: String) -> String:
	var piece: Array = Catalog.OVERLAY.get(diag, [])
	if piece.is_empty():
		return ""
	return str(piece[0])


static func _blocked(rows: Array, opened: Dictionary, x: int, y: int) -> bool:
	var at := Vector2i(x, y)
	if opened.has(at):
		return false
	var cell := _token(rows, x, y)
	var kind := _kind(str(cell.get("diag", "")))
	if kind == "slope" or kind == "beam":
		return true
	return str(cell.get("front", "")) != ""


static func _full_floor(rows: Array, opened: Dictionary, x: int, y: int) -> bool:
	var at := Vector2i(x, y)
	if opened.has(at):
		return false
	var cell := _token(rows, x, y)
	if _kind(str(cell.get("diag", ""))) == "slope":
		return false
	return str(cell.get("front", "")) != "" and int(cell.get("zform", 0)) == 0


static func _wh(obj: Dictionary, info: Dictionary) -> Vector2i:
	var w := int(str(obj.get("size", info.get("size", 1))))
	var h := int(str(obj.get("wid", obj.get("height", info.get("wid", info.get("height", 1))))))
	return Vector2i(maxi(w, 1), maxi(h, 1))
