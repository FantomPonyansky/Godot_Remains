extends RefCounted

## Land.buildRandomLand / buildSpecifLand for the map builder.
## Room files: res://assets/data/maps/rooms/<file>.json
##
## Each build calls randomize() once, then randf(), matching Math.random()
## with no Math.seed. Rolls, in order: mirror, one bag pick, enemy type,
## then 3 right door picks and 1 down pick, then createXpBonuses.
## setdoor keeps every Location.setDoor pick for setNoObj. Enemy counts,
## trials, exits, checkpoints and clouds are LandSpawn's. A back room is
## recorded by name; PlayLand builds it as a second layer with the front
## cell's mirror, water and ramka (newLoc gets the same options object).
## landStage, act.visited and mbase_visited are read once per Land
## (WorldState.build_value), so a rebuild of the same Land matches.
## land_dif is Land.landDifLevel: max(player level - 1, act dif).

const RoomFile := preload("res://scripts/map/room_file.gd")

const COLS := 48
const ROWS := 25
const TILE := 40
const NORND := ["beg0", "back", "roof", "pass", "passroof", "roofpass", "vert", "surf"]

const GENERATED := {
	"random_plant": {"file": "rooms_plant", "conf": 0, "biom": 0, "mx": 4, "my": 6, "dif": 0, "sx": 0, "sy": 0},
	"random_sewer": {"file": "rooms_sewer", "conf": 2, "biom": 1, "mx": 8, "my": 3, "dif": 10, "sx": 0, "sy": 0},
	"random_stable": {"file": "rooms_stable", "conf": 1, "biom": 2, "mx": 4, "my": 6, "dif": 12, "sx": 0, "sy": 0},
	"random_mane": {"file": "rooms_mane", "conf": 3, "biom": 3, "mx": 5, "my": 5, "dif": 15, "sx": 0, "sy": 4},
	"random_canter": {"file": "rooms_canter", "conf": 5, "biom": 5, "mx": 8, "my": 3, "dif": 18, "sx": 0, "sy": 0},
	"random_mbase": {"file": "rooms_mbase", "conf": 4, "biom": 4, "mx": 5, "my": 3, "dif": 22, "sx": 0, "sy": 0},
	"bunker": {"file": "rooms_mbase", "conf": 7, "biom": 4, "mx": 6, "my": 3, "dif": 24, "sx": 0, "sy": 0},
	"random_encl": {"file": "rooms_encl", "conf": 6, "biom": 6, "mx": 3, "my": 8, "dif": 27, "sx": 0, "sy": 7},
	"stable_pi": {"file": "rooms_pi", "conf": 10, "biom": 10, "mx": 4, "my": 6, "dif": 0, "sx": 3, "sy": 5},
	"stable_pi_atk": {"file": "rooms_pi", "conf": 11, "biom": 11, "mx": 6, "my": 2, "dif": 0, "sx": 0, "sy": 0},
}

## WorldState.begin_build seeds the RNG so a land rebuilt from a save is the same land.
static var keep_seed := false


## Editor play-test of an unplaced file. Not a shipped land id.
## GENERATED is const, so temps live here.
static var _extra: Dictionary = {}


static func bind_temp(id: String, spec: Dictionary) -> void:
	_extra[id] = spec


static func unbind_temp(id: String) -> void:
	_extra.erase(id)


static func is_generated(id: String) -> bool:
	return _extra.has(id) or GENERATED.has(id)


static func generated(id: String) -> Dictionary:
	if _extra.has(id):
		return _extra[id]
	return GENERATED.get(id, {})


static func lands_using(file_name: String) -> Array:
	var ids: Array = []
	for land_id in GENERATED.keys():
		if str(GENERATED[land_id].file) == file_name:
			ids.append(land_id)
	return ids


static func build(land_id: String, land_dif: float = -1.0) -> Dictionary:
	if not is_generated(land_id):
		return {"error": "unknown generated land %s" % land_id}
	var spec: Dictionary = generated(land_id).duplicate()
	spec["stage"] = int(_input(land_id, "stage", _fresh("stage", land_id)))
	spec["visited"] = bool(_input(land_id, "visited", _fresh("visited", land_id)))
	spec["mbase_visited"] = int(_input(land_id, "mbase_visited", _fresh("mbase_visited", land_id)))
	spec["land_dif"] = land_dif if land_dif >= 0.0 else float(spec.dif)
	var file_name := str(spec.file)
	var doc := RoomFile.load_doc(file_name)
	if doc.is_empty():
		return {"error": "missing room file %s" % file_name}
	if not keep_seed:
		randomize()
	var pool: Array = _prepare(doc)
	_mix_pool(pool, land_id, file_name)
	var conf := int(spec.conf)
	var width := int(spec.mx)
	var height := int(spec.my)
	var note := ""
	if conf == 0 and int(spec.stage) <= 0:
		height = 3
		note = "landStage 0 clamps height from %d to 3" % int(spec.my)
	var cells := {}
	for x in width:
		for y in height:
			var made: Dictionary = _place_cell(pool, cells, spec, x, y, width, height)
			if str(made.get("error", "")) != "":
				return made
			cells[Vector2i(x, y)] = made
	_pick_doors(cells, width, height)
	var xp_total := _place_xp(cells, spec, width, height)
	var passes := _passages(cells)
	var packed := _pack(land_id, file_name, true, false, cells, passes, width, height, int(spec.mx), int(spec.my), note)
	packed["xp_total"] = xp_total
	return packed


## Open cells of a back room behind cell: its own tiles under the front
## cell's mirror and ramka. Back rooms get no setDoor, so the frame stays shut.
static func back_open(src: Dictionary, cell: Dictionary) -> Array:
	var open: Array = _open_grid(src.get("rows", []), bool(cell.get("mirror", false)))
	_apply_ramka(open, int(cell.get("ramka", 1)))
	return open


static func _fresh(key: String, land_id: String):
	var tree := Engine.get_main_loop() as SceneTree
	var travel: Node = tree.root.get_node_or_null("/root/Travel") if tree else null
	if travel == null:
		return false if key == "visited" else 0
	if key == "stage":
		return travel.land_stage(land_id)
	if key == "visited":
		return bool(travel.land_act(land_id).get("visited", false))
	return int(travel.triggers.get("mbase_visited", 0))


static func _input(land_id: String, key: String, value: Variant) -> Variant:
	var tree := Engine.get_main_loop() as SceneTree
	var world: Node = tree.root.get_node_or_null("WorldState") if tree else null
	if world == null:
		return value
	return world.build_value(land_id, key, value)


static func present(file_name: String) -> Dictionary:
	var doc := RoomFile.load_doc(file_name)
	if doc.is_empty():
		return {"error": "missing room file %s" % file_name}
	if not bool(doc.get("placed", false)):
		return {
			"error": "",
			"land_id": file_name,
			"file": file_name,
			"rnd": false,
			"templates_only": true,
			"width": 0,
			"height": 0,
			"catalog_mx": 0,
			"catalog_my": 0,
			"min_x": 0,
			"min_y": 0,
			"max_x": 1,
			"max_y": 1,
			"cells": {},
			"passes": [],
			"note": "Template list only. Trials are not a land grid.",
			"xp_total": 0,
		}
	var cells := {}
	for room_v in doc.get("rooms", []):
		var room: Dictionary = room_v
		if int(room.get("z", 0)) != 0:
			continue
		if not room.has("x") or not room.has("y"):
			continue
		var x := int(room.x)
		var y := int(room.y)
		cells[Vector2i(x, y)] = {
			"x": x,
			"y": y,
			"name": str(room.get("name", "")),
			"mirror": false,
			"fixed": false,
			"doors": RoomFile.editor_mask(room),
			"open": _open_grid(room.get("rows", []), false),
			"water": 100,
			"enemy_type": -1,
			"ups": _count_kind(room, "up"),
			"xp": [],
			"back": str((room.get("options", {}) as Dictionary).get("back", "")),
		}
	return _pack(file_name, file_name, false, false, cells, _passages(cells), 0, 0, 0, 0, "")


static func to_preview(built: Dictionary) -> Dictionary:
	if str(built.get("error", "")) != "":
		return {"error": built.error}
	var cells_out: Array = []
	var counts := {"fixed": 0, "random": 0, "quest": 0}
	for key in built.cells.keys():
		var cell: Dictionary = built.cells[key]
		var kind := "fixed" if bool(cell.get("fixed", false)) else "random"
		counts[kind] = int(counts[kind]) + 1
		cells_out.append({
			"x": int(cell.x),
			"y": int(cell.y),
			"kind": kind,
			"tiles": _preview_rows(cell),
		})
	return {
		"land_id": str(built.get("land_id", "")),
		"width": int(built.width),
		"height": int(built.height),
		"min_x": int(built.min_x),
		"min_y": int(built.min_y),
		"room_tiles_x": COLS,
		"room_tiles_y": ROWS,
		"link_count": (built.get("passes", []) as Array).size(),
		"counts": counts,
		"cells": cells_out,
		"quest_symbols": {},
		"seed": "fresh",
	}


static func _place_cell(pool: Array, cells: Dictionary, spec: Dictionary, x: int, y: int, width: int, height: int) -> Dictionary:
	var conf := int(spec.conf)
	var stage := int(spec.get("stage", 0))
	var visited := bool(spec.get("visited", false))
	var mirror := randf() < 0.5
	var ramka := 1
	var maxlevel := stage
	var ntip = null
	var use_tip := false
	var fixed := false
	var entrance := (conf == 0 and y == 0 and not visited) or ((conf == 1 or conf == 2 or conf == 5) and y == 0 and x == 0 and not visited)
	if entrance:
		mirror = false
		use_tip = true
		fixed = true
		ntip = "beg%d" % x if conf == 0 else "beg0"
		if conf == 5:
			ramka = 3
	else:
		match conf:
			3:
				if x == 2 and y == 0:
					ramka = 7
					use_tip = true
					fixed = true
					ntip = "passroof"
				elif x == 2:
					ramka = 5
					fixed = true
					ntip = "pass"
				elif y == 0:
					ramka = 6
					fixed = true
					ntip = "roof"
			4:
				maxlevel = 0
				if x == 0:
					if y == 0:
						if int(spec.get("mbase_visited", 0)) <= 0:
							mirror = false
							ramka = 8
							use_tip = true
							fixed = true
							ntip = "beg0"
					else:
						fixed = true
						ntip = "vert"
				elif x == width - 1:
					if y == height - 1:
						mirror = false
						use_tip = true
						fixed = true
						ntip = "end"
					else:
						fixed = true
						ntip = "vert"
			5:
				if y == 0:
					ramka = 3
					fixed = true
					ntip = "surf"
			7:
				maxlevel = 1
				if x == 0:
					if y == 0:
						mirror = false
						use_tip = true
						fixed = true
						ntip = "beg1"
					else:
						fixed = true
						ntip = "vert"
				elif x == width - 1:
					if y == height - 1:
						mirror = false
						use_tip = true
						fixed = true
						ntip = "end1"
					else:
						fixed = true
						ntip = "vert"
			10:
				maxlevel = 10
				if x == int(spec.sx) and y == int(spec.sy):
					mirror = false
					use_tip = true
					fixed = true
					ntip = "beg0"
				elif x == 1 and y == 1:
					mirror = false
					use_tip = true
					fixed = true
					ntip = "roof"
			11:
				if x == 5 and y == 0:
					mirror = false
					use_tip = true
					fixed = true
					ntip = "pass"
	var chosen = null
	if use_tip:
		chosen = _pick_tip(pool, str(ntip))
	else:
		var left = cells[Vector2i(x - 1, y)].get("template") if x > 0 else null
		var above = cells[Vector2i(x, y - 1)].get("template") if y > 0 else null
		chosen = _pick_random(pool, maxlevel, left, above, ntip, conf)
	if chosen == null:
		return {"error": "no template for %s at %d,%d" % [str(spec.file), x, y]}
	var options: Dictionary = chosen.src.get("options", {})
	var water := _water(conf, y)
	var base_water := water
	if options.has("wlevel"):
		water = _to_int(options.wlevel, water)
	var deep := 0.0
	if conf == 0:
		deep = float(y) / 2.0
	elif conf == 1:
		deep = float(y)
	elif conf == 2:
		deep = float(y) * 2.5
	var preset := -1
	if options.has("entip"):
		preset = _to_int(options.entip, -1)
	var enemy := _enemy_type(int(spec.biom), float(spec.get("land_dif", spec.dif)) + deep, preset)
	var rows: Array = chosen.src.get("rows", [])
	var open: Array = _open_grid(rows, mirror)
	_apply_ramka(open, ramka)
	var carved := _blank_grid()
	var mask: Array = RoomFile.generator_mask(chosen.src)
	if mirror:
		mask = RoomFile.mirror_mask(mask)
	return {
		"x": x,
		"y": y,
		"name": chosen.name,
		"mirror": mirror,
		"fixed": fixed,
		"doors": mask,
		"open": open,
		"carved": carved,
		"water": water,
		"base_water": base_water,
		"ramka": ramka,
		"enemy_type": enemy,
		"ups": _count_kind(chosen.src, "up"),
		"xp": [],
		"back": chosen.back,
		"template": chosen,
		"pass_r": [],
		"pass_d": [],
		"setdoor": [],
	}


static func _pick_doors(cells: Dictionary, width: int, height: int) -> void:
	for x in width:
		for y in height:
			var cell: Dictionary = cells[Vector2i(x, y)]
			var right: Array = []
			if x < width - 1:
				var neighbor: Dictionary = cells[Vector2i(x + 1, y)]
				for slot in 6:
					var hole := mini(int(cell.doors[slot]), int(neighbor.doors[slot + 11]))
					if hole >= 2:
						right.append({"n": slot, "fak": hole})
			var down: Array = []
			if y < height - 1:
				var below: Dictionary = cells[Vector2i(x, y + 1)]
				for slot in range(6, 11):
					var hole := mini(int(cell.doors[slot]), int(below.doors[slot + 11]))
					if hole >= 2:
						down.append({"n": slot, "fak": hole})
			cell["pass_r"] = right
			cell["pass_d"] = down
	for x in width:
		for y in height:
			var cell: Dictionary = cells[Vector2i(x, y)]
			var right: Array = cell.pass_r
			if x < width - 1 and not right.is_empty():
				var neighbor: Dictionary = cells[Vector2i(x + 1, y)]
				for _draw in 3:
					var pick: Dictionary = right[int(randf() * float(right.size()))]
					_carve(cell.open, cell.carved, int(pick.n), int(pick.fak))
					_carve(neighbor.open, neighbor.carved, int(pick.n) + 11, int(pick.fak))
					cell.setdoor.append([int(pick.n), int(pick.fak)])
					neighbor.setdoor.append([int(pick.n) + 11, int(pick.fak)])
			var down: Array = cell.pass_d
			if y < height - 1 and not down.is_empty():
				var below: Dictionary = cells[Vector2i(x, y + 1)]
				var pick: Dictionary = down[int(randf() * float(down.size()))]
				_carve(cell.open, cell.carved, int(pick.n), int(pick.fak))
				_carve(below.open, below.carved, int(pick.n) + 11, int(pick.fak))
				cell.setdoor.append([int(pick.n), int(pick.fak)])
				below.setdoor.append([int(pick.n) + 11, int(pick.fak)])


static func _place_xp(cells: Dictionary, spec: Dictionary, width: int, height: int) -> int:
	var conf := int(spec.conf)
	var total := 0
	if conf == 10 or conf == 11:
		return 0
	for y in range(height - 1, -1, -1):
		for x in width:
			var skip := (conf == 4 or conf == 7) and x == int(spec.sx) and y == int(spec.sy)
			if skip:
				continue
			var cell: Dictionary = cells[Vector2i(x, y)]
			var spots: Array = _xp_spots(cell.open)
			cell["xp"] = spots
			total += spots.size()
	return total


static func _xp_spots(open: Array) -> Array:
	var spots: Array = []
	var mesto := 4
	var misses := 5
	var half_x := int(float(COLS) * 0.5)
	var half_y := int(float(ROWS) * 0.5)
	for _try in 100:
		var x1 := 2
		var y1 := 2
		var x2 := COLS - 2
		var y2 := ROWS - 2
		match mesto:
			4:
				x2 = half_x
				y2 = half_y
			3:
				x1 = half_x
				y2 = half_y
			2:
				x2 = half_x
				y1 = half_y
			1:
				x1 = half_x
				y1 = half_y
		var nx := int(float(x1) + randf() * float(x2 - x1))
		var ny := int(float(y1) + randf() * float(y2 - y1))
		if _is_open(open, nx, ny) and (_is_open(open, nx - 1, ny) or _is_open(open, nx + 1, ny)):
			spots.append(Vector2i(nx, ny))
			if mesto > 0:
				mesto -= 1
			if spots.size() >= 5:
				return spots
		else:
			misses -= 1
			if misses <= 0:
				misses = 5
				if mesto > 0:
					mesto -= 1
	return spots


static func _enemy_type(biom: int, ml: float, preset: int) -> int:
	var tip := preset
	if biom == 0 and randf() < 0.25:
		tip = 1
	if tip < 0:
		tip = int(randf() * 3.0)
	if biom == 1:
		tip = 0
	if biom == 2 and tip == 1 and randf() < ml / 20.0:
		tip = 3
	if biom == 3:
		tip = int(randf() * 3.0) + 3
	if ml > 12.0 and (biom == 0 or biom == 2 or biom == 3) and randf() < 0.1:
		tip = 6
	if biom == 4:
		tip = 7
	if biom == 5:
		if randf() < 0.3:
			tip = 5
		else:
			tip = 8
	if biom == 6:
		if randf() > 0.3:
			tip = 9
		else:
			tip = 10
	if biom == 11:
		tip = 11
	return tip


static func _water(conf: int, y: int) -> int:
	if conf == 2:
		if y == 1:
			return 17
		if y > 1:
			return 0
	elif conf == 5:
		if y == 2:
			return 21
		if y > 2:
			return 0
	return 100


static func _prepare(doc: Dictionary) -> Array:
	var pool: Array = []
	for room_v in doc.get("rooms", []):
		var room: Dictionary = room_v
		var state := _Room.new()
		var options: Dictionary = room.get("options", {})
		state.name = str(room.get("name", ""))
		state.src = room
		state.has_tip = options.has("tip")
		state.tip = str(options.get("tip", ""))
		state.lvl = _to_int(options.get("level", 0), 0)
		state.kol = 2
		state.rnd = true
		state.back = str(options.get("back", "")) if options.has("back") else ""
		if state.has_tip and state.tip == "uniq":
			state.kol = 1
		if options.has("uniq"):
			state.kol = 1
		if state.has_tip and state.tip in NORND:
			state.rnd = false
		if options.has("nornd"):
			state.rnd = false
		if options.has("test"):
			state.kol = 4
			state.lvl = 0
		pool.append(state)
	return pool


## User rooms whose pools name this land, beside the land file's own rooms.
static func _mix_pool(pool: Array, land_id: String, home: String) -> void:
	for row_v in RoomFile._pool_entries(land_id):
		var row: Dictionary = row_v
		var file := str(row.get("file", ""))
		var room_name := str(row.get("name", ""))
		if file == home and _pool_has(pool, room_name):
			continue
		var room: Dictionary = row.get("room", {})
		var problems: Array = RoomFile.check_pool_room(room, land_id)
		if not problems.is_empty():
			var bits := PackedStringArray()
			for p in problems:
				bits.append(str(p))
			push_warning("pool room %s/%s: %s" % [file, room_name, "; ".join(bits)])
			continue
		for made_v in _prepare({"rooms": [room]}):
			pool.append(made_v)


static func _pool_has(pool: Array, room_name: String) -> bool:
	for room_v in pool:
		if (room_v as _Room).name == room_name:
			return true
	return false


static func _pick_tip(pool: Array, ntip: String):
	var bag: Array = []
	for room_v in pool:
		var room: _Room = room_v
		if room.has_tip and room.tip == ntip:
			bag.append(room)
	var chosen: _Room = null
	if bag.is_empty():
		if pool.is_empty():
			return null
		chosen = pool[int(randf() * float(pool.size()))]
	else:
		chosen = bag[int(randf() * float(bag.size()))]
	chosen.kol -= 1
	return chosen


static func _pick_random(pool: Array, maxlevel: int, left, above, ntip, conf: int):
	var bag: Array = []
	for room_v in pool:
		var room: _Room = room_v
		if room.lvl > maxlevel or room.kol <= 0:
			continue
		if left != null and room == left:
			continue
		if above != null and room == above:
			continue
		var ok := false
		if ntip == null:
			ok = room.rnd or not room.has_tip
		else:
			ok = room.has_tip and room.tip == str(ntip)
		if not ok:
			continue
		var weight := room.kol * room.kol
		if weight == 4 and room.lvl == 0 and maxlevel > 1:
			weight = 2
		for _i in weight:
			bag.append(room)
	var chosen: _Room = null
	if bag.is_empty():
		var fallback: Array = []
		for room_v in pool:
			var room: _Room = room_v
			if room.rnd:
				fallback.append(room)
		if fallback.is_empty():
			return null
		chosen = fallback[int(randf() * float(fallback.size()))]
	else:
		chosen = bag[int(randf() * float(bag.size()))]
	chosen.kol -= 1
	if conf == 4:
		chosen.kol = 0
	return chosen


static func _open_grid(rows: Array, mirror: bool) -> Array:
	var grid: Array = []
	for y in ROWS:
		var parts := PackedStringArray()
		if y < rows.size():
			parts = str(rows[y]).split(".")
		var line: Array = []
		line.resize(COLS)
		for x in COLS:
			var src := COLS - 1 - x if mirror else x
			var code := parts[src] if src >= 0 and src < parts.size() else ""
			line[x] = RoomFile.is_open_code(code)
		grid.append(line)
	return grid


static func _apply_ramka(open: Array, ramka: int) -> void:
	if ramka <= 0:
		return
	var right := COLS - 1
	var bottom := ROWS - 1
	for y in ROWS:
		for x in COLS:
			if x != 0 and x != right and y != 0 and y != bottom:
				continue
			var seal := false
			if ramka == 1:
				seal = true
			if (ramka == 2 or ramka == 4) and (x == 0 or x == right):
				seal = true
			if (ramka == 3 or ramka == 4) and y == bottom:
				seal = true
			if ramka == 5 and (x <= 10 or x >= 37):
				seal = true
			if ramka == 6 and y >= 16:
				seal = true
			if ramka == 7 and (x <= 10 or x >= 37) and y >= 16:
				seal = true
			if ramka == 8 and x == right:
				seal = true
			if seal:
				open[y][x] = false


static func _carve(open: Array, carved: Array, n: int, fak: int) -> void:
	if fak < 2 or n > 21 or n < 0:
		return
	var q := 0
	if n >= 17:
		q = (n - 17) * 9 + 4
		_hole(open, carved, q + 1, 0)
		_hole(open, carved, q + 2, 0)
		_hole(open, carved, q + 1, 1)
		_hole(open, carved, q + 2, 1)
		if fak > 2:
			_hole(open, carved, q, 0)
			_hole(open, carved, q + 3, 0)
			_hole(open, carved, q, 1)
			_hole(open, carved, q + 3, 1)
	elif n >= 11:
		q = (n - 11) * 4 + 3
		_hole(open, carved, 0, q)
		_hole(open, carved, 0, q - 1)
		_hole(open, carved, 1, q)
		_hole(open, carved, 1, q - 1)
		if fak > 2:
			_hole(open, carved, 0, q - 2)
			_hole(open, carved, 1, q - 2)
	elif n >= 6:
		q = (n - 6) * 9 + 4
		var bottom := ROWS - 1
		_hole(open, carved, q + 1, bottom)
		_hole(open, carved, q + 2, bottom)
		_hole(open, carved, q + 1, bottom - 1)
		_hole(open, carved, q + 2, bottom - 1)
		if fak > 2:
			_hole(open, carved, q, bottom)
			_hole(open, carved, q + 3, bottom)
			_hole(open, carved, q, bottom - 1)
			_hole(open, carved, q + 3, bottom - 1)
	else:
		q = n * 4 + 3
		var right := COLS - 1
		_hole(open, carved, right, q)
		_hole(open, carved, right, q - 1)
		_hole(open, carved, right - 1, q)
		_hole(open, carved, right - 1, q - 1)
		if fak > 2:
			_hole(open, carved, right, q - 2)
			_hole(open, carved, right - 1, q - 2)


static func _hole(open: Array, carved: Array, x: int, y: int) -> void:
	_force_open(open, x, y)
	_force_open(carved, x, y)


static func _force_open(open: Array, x: int, y: int) -> void:
	if y < 0 or x < 0 or y >= open.size():
		return
	var line: Array = open[y]
	if x >= line.size():
		return
	line[x] = true


static func _is_open(open: Array, x: int, y: int) -> bool:
	if y < 0 or x < 0 or y >= open.size():
		return false
	var line: Array = open[y]
	if x >= line.size():
		return false
	return bool(line[x])


static func _passages(cells: Dictionary) -> Array:
	var rooms: Array[Vector2i] = []
	for key in cells.keys():
		rooms.append(key)
	var out: Array = []
	for at in rooms:
		var right := Vector2i(at.x + 1, at.y)
		if cells.has(right):
			_link_side(out, cells[at].open, cells[right].open, at)
		var below := Vector2i(at.x, at.y + 1)
		if cells.has(below):
			_link_down(out, cells[at].open, cells[below].open, at)
	return out


static func _link_side(out: Array, a: Array, b: Array, left: Vector2i) -> void:
	var spans: Array = []
	var open_rows: Array[int] = []
	for row in ROWS:
		if _is_open(a, COLS - 1, row) and _is_open(b, 0, row):
			open_rows.append(row)
	for slot in 6:
		var q := slot * 4 + 3
		var hole := mini(_h_hole(a, COLS - 1, q), _h_hole(b, 0, q))
		if hole < 2:
			continue
		var rows: Array[int] = []
		for row in [q - 2, q - 1, q]:
			if _is_open(a, COLS - 1, row) and _is_open(b, 0, row):
				rows.append(row)
		_add_runs(spans, rows)
	_add_runs(spans, open_rows)
	for span in _merge_spans(spans):
		out.append({
			"vertical": true,
			"edge": (left.x + 1) * COLS,
			"start": left.y * ROWS + int(span[0]),
			"end": left.y * ROWS + int(span[1]) + 1,
		})


static func _link_down(out: Array, a: Array, b: Array, above: Vector2i) -> void:
	var spans: Array = []
	var open_cols: Array[int] = []
	for col in COLS:
		if _is_open(a, col, ROWS - 1) and _is_open(b, col, 0):
			open_cols.append(col)
	for slot in range(6, 11):
		var q := (slot - 6) * 9 + 4
		var hole := mini(_v_hole(a, ROWS - 1, q), _v_hole(b, 0, q))
		if hole < 2:
			continue
		var cols: Array[int] = []
		for col in [q, q + 1, q + 2, q + 3]:
			if _is_open(a, col, ROWS - 1) and _is_open(b, col, 0):
				cols.append(col)
		_add_runs(spans, cols)
	_add_runs(spans, open_cols)
	for span in _merge_spans(spans):
		out.append({
			"vertical": false,
			"edge": (above.y + 1) * ROWS,
			"start": above.x * COLS + int(span[0]),
			"end": above.x * COLS + int(span[1]) + 1,
		})


static func _h_hole(grid: Array, col: int, q: int) -> int:
	var primary := 0
	if _is_open(grid, col, q):
		primary += 1
	if _is_open(grid, col, q - 1):
		primary += 1
	if primary < 2:
		return primary
	return primary + (1 if _is_open(grid, col, q - 2) else 0)


static func _v_hole(grid: Array, row: int, q: int) -> int:
	var primary := 0
	if _is_open(grid, q + 1, row):
		primary += 1
	if _is_open(grid, q + 2, row):
		primary += 1
	if primary < 2:
		return primary
	return primary + (1 if _is_open(grid, q, row) else 0) + (1 if _is_open(grid, q + 3, row) else 0)


static func _add_runs(spans: Array, indexes: Array) -> void:
	var run_from := -1
	var prev := -2
	for index in indexes:
		var i := int(index)
		if run_from < 0:
			run_from = i
			prev = i
			continue
		if i == prev + 1:
			prev = i
			continue
		if prev - run_from + 1 >= 2:
			spans.append([run_from, prev])
		run_from = i
		prev = i
	if run_from >= 0 and prev - run_from + 1 >= 2:
		spans.append([run_from, prev])


static func _merge_spans(spans: Array) -> Array:
	if spans.is_empty():
		return []
	spans.sort_custom(func(u: Array, v: Array) -> bool: return int(u[0]) < int(v[0]))
	var merged: Array = [[int(spans[0][0]), int(spans[0][1])]]
	for i in range(1, spans.size()):
		var a := int(spans[i][0])
		var b := int(spans[i][1])
		var last: Array = merged[merged.size() - 1]
		if a <= int(last[1]) + 1:
			last[1] = maxi(int(last[1]), b)
		else:
			merged.append([a, b])
	return merged


static func _preview_rows(cell: Dictionary) -> Array:
	var open: Array = cell.open
	var carved: Array = cell.get("carved", [])
	var rows: Array = []
	for y in ROWS:
		var line := ""
		var grid: Array = open[y]
		var marks: Array = carved[y] if y < carved.size() else []
		for x in COLS:
			if x < marks.size() and bool(marks[x]):
				line += "2"
			elif bool(grid[x]):
				line += "0"
			else:
				line += "1"
		rows.append(line)
	return rows


static func _blank_grid() -> Array:
	var grid: Array = []
	for _y in ROWS:
		var line: Array = []
		line.resize(COLS)
		line.fill(false)
		grid.append(line)
	return grid


static func _pack(land_id: String, file_name: String, rnd: bool, templates_only: bool, cells: Dictionary, passes: Array, width: int, height: int, catalog_mx: int, catalog_my: int, note: String) -> Dictionary:
	var min_x := 0
	var min_y := 0
	var max_x := maxi(width, 1)
	var max_y := maxi(height, 1)
	if not cells.is_empty():
		min_x = 1 << 30
		min_y = 1 << 30
		max_x = -(1 << 30)
		max_y = -(1 << 30)
		for cell_v in cells.values():
			var cell: Dictionary = cell_v
			min_x = mini(min_x, int(cell.x))
			min_y = mini(min_y, int(cell.y))
			max_x = maxi(max_x, int(cell.x) + 1)
			max_y = maxi(max_y, int(cell.y) + 1)
	return {
		"error": "",
		"land_id": land_id,
		"file": file_name,
		"rnd": rnd,
		"templates_only": templates_only,
		"width": width if width > 0 else max_x - min_x,
		"height": height if height > 0 else max_y - min_y,
		"catalog_mx": catalog_mx,
		"catalog_my": catalog_my,
		"min_x": min_x,
		"min_y": min_y,
		"max_x": max_x,
		"max_y": max_y,
		"cells": cells,
		"passes": passes,
		"note": note,
		"xp_total": 0,
	}


static func _count_kind(room: Dictionary, kind: String) -> int:
	var n := 0
	for obj_v in room.get("objs", []):
		if str((obj_v as Dictionary).get("kind", "")) == kind:
			n += 1
	return n


static func _to_int(value, fallback: int) -> int:
	if value == null:
		return fallback
	var kind := typeof(value)
	if kind == TYPE_INT or kind == TYPE_FLOAT:
		return int(value)
	var text := str(value).strip_edges()
	if text.is_valid_int():
		return int(text)
	return fallback


class _Room:
	var name := ""
	var src: Dictionary = {}
	var has_tip := false
	var tip := ""
	var lvl := 0
	var kol := 2
	var rnd := true
	var back := ""
