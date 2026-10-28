extends Node2D

## Stamps a land the player can walk. Hand-authored lands use the extracted
## room file (Lands.xml file, locx/locy). Generated lands run LandGen.build
## for that land's conf. Tiles are drawn through TileCatalog. The entrance is
## the start room's player spawn, else cell 3,3. Lands have no invisible exit
## strip: the original leaves a land only by script, door, checkpoint or the
## PipBuck map in a base room.
##
## The original keeps z=1 rooms (Land.locs[x][y][1]) and trial rooms
## (Land.probs) as separate layers. Here they are extra grid rows below the
## main grid, one empty row apart, so no room touches another layer.

const Catalog := preload("res://scripts/map/tile_catalog.gd")
const _Wall := preload("res://scripts/wall_span.gd")
const _DoorArt := preload("res://scripts/door_art.gd")
const Decor := preload("res://scripts/map/back_decor.gd")
const RoomFile := preload("res://scripts/map/room_file.gd")
const LandGen := preload("res://scripts/map/land_gen.gd")
const Registry := preload("res://scripts/map/land_registry.gd")
const LandSpawn := preload("res://scripts/map/land_spawn.gd")
const _Stair := preload("res://scripts/stair_slope.gd")
const _Flags := preload("res://scripts/map/room_flags.gd")
const _Look := preload("res://scripts/map/room_look.gd")
const _Fon := preload("res://scripts/map/land_fon.gd")
const _Outline := preload("res://scripts/map/tile_outline.gd")
const SkyArena := preload("res://scripts/map/sky_arena.gd")
const BackRoom := preload("res://scripts/map/back_room.gd")
const _TileCanvas := preload("res://scripts/map/tile_canvas.gd")
const _RoomActivity := preload("res://scripts/map/room_activity.gd")

const TILE := 40.0
const COLS := 48
const ROWS := 25
const SKY := Color(0.53, 0.68, 0.86)
const PROB_FILE := "rooms_prob"
## Port rule: the end of the Surf arrival tunnel leads back to begin, which
## the original never allows.
const SURF_TO_BEGIN := {
	"tag": "obj", "id": "area", "x": 0, "y": 9, "size": 2,
	"attrs": {"code": "portSurfToBegin", "w": "1", "h": "7"},
	"kids": [{"tag": "scr", "kids": [{"tag": "s", "attrs": {"act": "gotoland", "val": "begin"}}]}],
}

var land_id := ""
var spawn_px := Vector2.ZERO
var map_px := Vector2.ZERO
var plan: Dictionary = {}
var _tex: Dictionary = {}

static func make(next_id: String) -> Node2D:
	var node = (load("res://scripts/map/play_land.gd") as GDScript).new()
	var world := _world()
	if world:
		world.begin_build(next_id)
	var built: bool = node._build(next_id)
	if world:
		world.end_build(next_id)
	if not built:
		node.free()
		return null
	return node


static func _world() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("WorldState") if tree else null


func _build(next_id: String) -> bool:
	land_id = next_id
	name = "Land_%s" % next_id
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var spec: Dictionary = _spec(next_id)
	if spec.is_empty():
		push_error("no land %s" % next_id)
		return false
	var packed: Dictionary = _rooms(next_id, spec)
	if str(packed.get("error", "")) != "":
		push_error(str(packed.error))
		return false
	var rooms: Array = packed.rooms
	if rooms.is_empty():
		push_error("%s has no rooms" % next_id)
		return false
	plan = _plan(next_id, spec, packed, rooms)
	var ctx: Dictionary = plan.get("ctx", {})
	var prob_rooms := {}
	for room_v in rooms:
		if str((room_v as Dictionary).get("prob", "")) != "":
			prob_rooms[Vector2i(int(room_v.x), int(room_v.y))] = true
	# LootGen reads the room's Location (locDifLevel, weaponLevel, biom, prob)
	# and the Land (gameStage, lootLimit = level + 3, rnd).
	set_meta("loot_ctx", {
		"rooms": plan.get("room_dif", {}),
		"prob_rooms": prob_rooms,
		"land_dif": float(ctx.get("land_dif", 0)),
		"biom": int(ctx.get("biom", 0)),
		"rnd": bool(ctx.get("rnd", false)),
		"stage": Registry.int_of((spec.get("info", {}) as Dictionary).get("stage"), 0),
		"limit": float(_world().build_level(next_id, 1) + 3) if _world() else 4.0,
	})
	var max_x := 0
	var max_y := 0
	for room_v in rooms:
		var room: Dictionary = room_v
		max_x = maxi(max_x, int(room.x))
		max_y = maxi(max_y, int(room.y))
	map_px = Vector2((max_x + 1) * COLS * TILE, (max_y + 1) * ROWS * TILE)
	var sky: Color = spec.get("sky", Color(0, 0, 0, 1))
	var fon_name := str(((spec.get("info", {}) as Dictionary).get("options", {}) as Dictionary).get("fon", ""))
	var fon := _Fon.attach(self, fon_name)
	var start: Vector2i = packed.start
	var spawn_cell := Vector2i(3, 3)
	var solids := {}
	var platforms := {}
	var ladders := {}
	var slopes: Array = []
	var door_cells := {}
	var doors: Array = []
	var dressing := Node2D.new()
	dressing.name = "RoomDressing"
	dressing.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(dressing)
	var layers := Decor.layers(dressing, sky)
	(layers.holes as Node).set_meta("hole_mat", fon.hole_mat)
	var dim := layers.dim as Node2D
	# Pi stable and the attacked stable force lights on (Location homeStable / homeAtk).
	var lights := 1 if next_id == "stable_pi" or next_id == "stable_pi_atk" else 0
	var act: Dictionary = (spec.get("info", {}) as Dictionary).get("options", {})
	var envs := {}
	for room_v in rooms:
		var room: Dictionary = room_v
		var rx := int(room.x)
		var ry := int(room.y)
		var rows: Array = room.rows
		var options: Dictionary = room.get("options", {})
		var env := _Flags.row_of(room, act, next_id)
		envs[Vector2i(rx, ry)] = env
		var room_dim := _Look.dim_for(dim, env, rx, ry)
		var wall_name := str(options.get("backwall", spec.get("back", "")))
		_paint_backwall(room_dim, rx, ry, wall_name, int(env.backform))
		if rx == start.x and ry == start.y:
			spawn_cell = _spawn_cell(room.get("objs", []), spawn_cell)
		_take_room(room, solids, platforms, ladders, slopes, door_cells, doors, dressing, room_dim)
		Decor.paint({"dim": room_dim, "holes": layers.holes}, room, Vector2(rx * COLS * TILE, ry * ROWS * TILE), lights)
	set_meta(_Flags.META, envs)
	for pos in door_cells:
		solids.erase(pos)
		platforms.erase(pos)
		# Port rule: a ladder runs on through an open hatch above or below it.
		if str(door_cells[pos]) == "hatch":
			var below: Vector2i = pos + Vector2i.DOWN
			var above: Vector2i = pos + Vector2i.UP
			if not ladders.has(pos) and (ladders.has(below) or ladders.has(above)):
				ladders[pos] = ladders[below] if ladders.has(below) else ladders[above]
			continue
		ladders.erase(pos)
	var kept_slopes: Array = []
	for slope_v in slopes:
		var slope: Dictionary = slope_v
		if door_cells.has(Vector2i(int(slope.x), int(slope.y))):
			continue
		kept_slopes.append(slope)
	slopes = kept_slopes
	_lift_ladders(platforms, _grids(rooms), ladders)
	spawn_px = _feet(start, spawn_cell)
	_Outline.begin(self, solids, door_cells, rooms, COLS, ROWS)
	_spawn_collision(solids, platforms, ladders, slopes)
	_spawn_doors(doors)
	SkyArena.attach(self, rooms)
	BackRoom.attach(self, rooms)
	_spawn_actors(rooms)
	_Look.build(self, rooms, envs)
	fon.set_cells(rooms, envs, get_meta("room_mults", {}), str(spec.get("back", "")))
	_RoomActivity.attach(self)
	return true


func _spawn_actors(rooms: Array) -> void:
	if get_node_or_null("Actors") != null:
		return
	var actors: Node = load("res://scripts/land_props.gd").new()
	actors.name = "Actors"
	actors.bind_rooms(rooms)
	actors.bind_plan(plan.get("rows", []), spawn_px)
	add_child(actors)


func _spec(next_id: String) -> Dictionary:
	var info := Registry.land(next_id)
	if LandGen.is_generated(next_id):
		var row: Dictionary = LandGen.generated(next_id).duplicate()
		row["back"] = str((info.get("options", {}) as Dictionary).get("backwall", "tBackWall"))
		row["sky"] = Color(0, 0, 0, 1)
		row["rnd"] = true
		row["info"] = info
		return row
	if info.is_empty() or str(info.get("file", "")) == "" or str(info.get("tip", "")) == "prob":
		return {}
	var options: Dictionary = info.get("options", {})
	var back := str(options.get("backwall", ""))
	return {
		"file": str(info.file),
		"sx": Registry.int_of(info.get("locx"), 0),
		"sy": Registry.int_of(info.get("locy"), 0),
		"back": back,
		"sky": SKY if back == "sky" else Color(0, 0, 0, 1),
		"rnd": false,
		"info": info,
	}


func _rooms(next_id: String, spec: Dictionary) -> Dictionary:
	if LandGen.is_generated(next_id):
		return _generated(next_id)
	var doc := RoomFile.load_doc(str(spec.file))
	if doc.is_empty():
		return {"error": "missing %s" % str(spec.file)}
	var rooms: Array = []
	for room_v in doc.get("rooms", []):
		var room: Dictionary = room_v
		if not room.has("x") or not room.has("y"):
			continue
		var copy := room.duplicate()
		copy["lx"] = int(room.x)
		copy["ly"] = int(room.y)
		copy["z"] = int(room.get("z", 0))
		if next_id == "surf" and int(room.x) == 0 and int(room.y) == 1:
			copy["objs"] = (room.get("objs", []) as Array).duplicate(true)
			(copy["objs"] as Array).append(SURF_TO_BEGIN)
		rooms.append(copy)
	return _layout(rooms, Vector2i(int(spec.sx), int(spec.sy)), 0, 0)


func _generated(next_id: String) -> Dictionary:
	var built := LandGen.build(next_id, float(_land_dif(next_id, _spec(next_id))))
	if str(built.get("error", "")) != "":
		return built
	var doc := RoomFile.load_doc(str(built.file))
	var rooms: Array = []
	for key in built.cells:
		var cell: Dictionary = built.cells[key]
		var template = cell.get("template")
		var src: Dictionary = template.src if template != null else {}
		var copy := _cell_room(src, bool(cell.get("mirror", false)))
		_match_open(copy.rows, cell.get("open", []))
		copy["lx"] = int(cell.x)
		copy["ly"] = int(cell.y)
		copy["z"] = 0
		copy["enemy_type"] = int(cell.get("enemy_type", -1))
		copy["water"] = int(cell.get("water", 100))
		copy["setdoor"] = cell.get("setdoor", [])
		copy["xp"] = cell.get("xp", [])
		rooms.append(copy)
		var back_name := str(cell.get("back", ""))
		if back_name == "":
			continue
		for room_v in doc.get("rooms", []):
			if str((room_v as Dictionary).get("name", "")) != back_name:
				continue
			var back := _cell_room(room_v, bool(cell.get("mirror", false)))
			_match_open(back.rows, LandGen.back_open(room_v, cell))
			back["lx"] = int(cell.x)
			back["ly"] = int(cell.y)
			back["z"] = 1
			back["enemy_type"] = int(cell.get("enemy_type", -1))
			var back_options: Dictionary = (room_v as Dictionary).get("options", {})
			back["water"] = LandGen._to_int(back_options.wlevel, 100) if back_options.has("wlevel") else int(cell.get("base_water", 100))
			rooms.append(back)
			break
	var spec: Dictionary = LandGen.generated(next_id)
	var packed := _layout(rooms, Vector2i(int(spec.sx), int(spec.sy)), int(built.width), int(built.height))
	return packed


## Land.locs keeps z=0 on the land grid. The other layer and trial rooms
## get rows below it.
func _layout(rooms: Array, start: Vector2i, width: int, height: int) -> Dictionary:
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := Vector2i(-(1 << 20), -(1 << 20))
	for room_v in rooms:
		var room: Dictionary = room_v
		if int(room.z) != 0:
			continue
		lo = Vector2i(mini(lo.x, int(room.lx)), mini(lo.y, int(room.ly)))
		hi = Vector2i(maxi(hi.x, int(room.lx)), maxi(hi.y, int(room.ly)))
	if lo.x > hi.x:
		lo = Vector2i.ZERO
		hi = Vector2i.ZERO
	var band := hi.y - lo.y + 2
	set_meta("back_band", band)
	var below := band
	for room_v in rooms:
		var room: Dictionary = room_v
		room["x"] = int(room.lx) - lo.x
		room["y"] = int(room.ly) - lo.y
		if int(room.z) != 0:
			room["y"] = int(room.y) + band
			below = maxi(below, int(room.y) + 2)
	# Location.zoom: a sky room is zoom times wider and taller (maxX *= zoom).
	# It gets its own rows below the rest so it covers no other room; the
	# other cells of its block are empty copies with the same options.
	var start_at := start - lo
	var fill: Array = []
	for room_v in rooms:
		var room: Dictionary = room_v
		var zoom := SkyArena.zoom_of(room)
		if zoom <= 1:
			continue
		if Vector2i(int(room.lx), int(room.ly)) == start and int(room.z) == 0:
			start_at = Vector2i(0, below)
		room["x"] = 0
		room["y"] = below
		for i in zoom:
			for j in zoom:
				if i == 0 and j == 0:
					continue
				var part := room.duplicate()
				part["name"] = "%s_sky_%d_%d" % [str(room.get("name", "")), i, j]
				part["objs"] = []
				# No Land.locs cell of its own: off-grid lx/ly keep land keys unique.
				part["lx"] = -1000 - i
				part["ly"] = -1000 - j
				part["x"] = i
				part["y"] = below + j
				part["sky_part"] = true
				fill.append(part)
		below += zoom + 1
	rooms.append_array(fill)
	set_meta("trial_row", below)
	return {
		"error": "",
		"rooms": rooms,
		"start": start_at,
		"beg": start,
		"origin": lo,
		"trial_row": below,
		"width": width if width > 0 else hi.x - lo.x + 1,
		"height": height if height > 0 else hi.y - lo.y + 1,
	}


func _cell_room(src: Dictionary, mirror: bool) -> Dictionary:
	var rows: Array = []
	for row_v in src.get("rows", []):
		rows.append(str(row_v))
	var objs: Array = src.get("objs", [])
	if mirror:
		rows = RoomFile.mirror_rows(rows)
		objs = RoomFile.mirror_objs(objs)
	else:
		objs = objs.duplicate(true)
	var copy := src.duplicate()
	copy["rows"] = rows
	copy["objs"] = objs
	copy["mirror"] = mirror
	return copy


## Location / Land object pass. Trial rooms named by a used prob id are added
## to rooms here, then transitions learn where they lead.
func _plan(next_id: String, spec: Dictionary, packed: Dictionary, rooms: Array) -> Dictionary:
	var info: Dictionary = spec.get("info", {})
	var rnd := bool(spec.get("rnd", false))
	var land_dif := _land_dif(next_id, spec)
	var options: Dictionary = info.get("options", {})
	var origin: Vector2i = packed.origin
	var ctx := {
		"land_id": next_id,
		"rnd": rnd,
		"conf": Registry.int_of(info.get("conf"), int(spec.get("conf", -1))),
		"biom": Registry.int_of(info.get("biom"), int(spec.get("biom", 0))),
		"land_dif": land_dif,
		"glob_dif": GameState.difficulty() if GameState != null and GameState.has_method("difficulty") else 2,
		"stage": int(_build_input(next_id, "stage", Travel.land_stage(next_id))) if rnd else Travel.land_stage(next_id),
		"probs_done": _build_input(next_id, "probs_done", _probs_done(next_id)) if rnd else [],
		"exit_prob": str(info.get("exit", "")),
		"xp": Registry.int_of(options.get("xp"), 100),
		"beg": packed.get("beg", packed.start + origin),
		"width": int(packed.width),
		"height": int(packed.height),
	}
	var out := LandSpawn.plan(ctx, rooms)
	out["ctx"] = ctx
	out["missing_probs"] = []
	var force := str(GameState.debug_prob) if GameState != null else ""
	if GameState != null:
		GameState.debug_prob = ""
	if force != "" and not (out.probs as Array).has(force):
		(out.probs as Array).append(force)
	var doc := RoomFile.load_doc(PROB_FILE)
	var col := 0
	for pid_v in out.probs:
		var pid := str(pid_v)
		var src := {}
		for room_v in doc.get("rooms", []):
			if str((room_v as Dictionary).get("name", "")) == pid:
				src = room_v
				break
		if src.is_empty():
			out.missing_probs.append(pid)
			continue
		var room := _cell_room(src, false)
		room["x"] = col
		room["y"] = int(packed.trial_row)
		room["lx"] = 0
		room["ly"] = 0
		room["z"] = 0
		room["prob"] = pid
		rooms.append(room)
		col += 1
		LandSpawn.plan_prob(ctx, room, pid, out)
	_link_transitions(out.rows, rooms)
	return out


## Land.landDifLevel. Game.enterToCurLand passes player level - 1 (at least
## 1); a generated land takes at least its act dif.
func _land_dif(next_id: String, spec: Dictionary) -> int:
	var info: Dictionary = spec.get("info", {})
	var lvl := 0
	if Progression != null:
		lvl = maxi(1, int(Progression.level) - 1)
	var world := _world()
	if world:
		lvl = world.build_level(next_id, lvl)
	var dif := Registry.int_of(info.get("dif"), 0)
	if bool(spec.get("rnd", false)):
		return maxi(lvl, dif)
	return lvl if info.has("autolevel") else dif


static func _build_input(next_id: String, key: String, value: Variant) -> Variant:
	var world := _world()
	return world.build_value(next_id, key, value) if world else value


## Land.newRandomProb skips a trial whose prob_<id> trigger is set.
static func _probs_done(next_id: String) -> Array:
	var done: Array = []
	for row_v in Registry.land(next_id).get("probs", []):
		var pid := str((row_v as Dictionary).get("id", ""))
		if Travel.trigger("prob_" + pid) != null:
			done.append(pid)
	return done


## comein goes to the same spot one layer over (Land.gotoOtherLayer).
## A trial door goes to that trial's doorout, and doorout comes back.
func _link_transitions(rows: Array, rooms: Array) -> void:
	var layer := {}
	for room_v in rooms:
		var room: Dictionary = room_v
		if str(room.get("prob", "")) != "":
			continue
		layer["%d,%d,%d" % [int(room.lx), int(room.ly), int(room.z)]] = Vector2i(int(room.x), int(room.y))
	var doorout := {}
	var entry := {}
	for row_v in rows:
		var row: Dictionary = row_v
		if str(row.cat) != "transition":
			continue
		if str(row.id) == "doorout":
			doorout[str(row.prob_room)] = row
		elif str(row.get("prob", "")) != "" and not entry.has(str(row.prob)):
			entry[str(row.prob)] = row
	for row_v in rows:
		var row: Dictionary = row_v
		if str(row.cat) != "transition":
			continue
		var kind := str(row.get("kind", ""))
		if kind == "comein":
			var lr: Array = row.lroom
			var key := "%d,%d,%d" % [int(lr[0]), int(lr[1]), int(row.get("layer", 0))]
			if layer.has(key):
				var dest: Vector2i = layer[key]
				var here: Array = row.room
				row["target"] = [
					float(row.feet[0]) + float((dest.x - int(here[0])) * COLS) * TILE,
					float(row.feet[1]) + float((dest.y - int(here[1])) * ROWS) * TILE,
				]
		elif str(row.id) == "doorout":
			var back: Dictionary = entry.get(str(row.prob_room), {})
			if not back.is_empty():
				row["target"] = back.feet
		elif str(row.get("prob", "")) != "" and doorout.has(str(row.prob)):
			row["target"] = (doorout[str(row.prob)] as Dictionary).feet


func _match_open(rows: Array, open: Array) -> void:
	for y in rows.size():
		var parts := str(rows[y]).split(".")
		var line: Array = open[y] if y < open.size() else []
		var changed := false
		for x in parts.size():
			var want_open := x < line.size() and bool(line[x])
			var is_open := RoomFile.is_open_code(parts[x])
			if want_open and not is_open:
				parts[x] = "_"
				changed = true
			elif not want_open and is_open:
				parts[x] = "C"
				changed = true
		if changed:
			rows[y] = ".".join(parts)


func _spawn_cell(objs: Array, fallback: Vector2i) -> Vector2i:
	for obj_v in objs:
		var obj: Dictionary = obj_v
		if str(obj.get("id", "")) == "player":
			return Vector2i(int(obj.get("x", fallback.x)), int(obj.get("y", fallback.y)))
	return fallback


func _feet(room: Vector2i, cell: Vector2i) -> Vector2:
	return Vector2((room.x * COLS + cell.x + 1) * TILE, (room.y * ROWS + cell.y + 1) * TILE - 1.0)


func _take_room(room: Dictionary, solids: Dictionary, platforms: Dictionary, ladders: Dictionary, slopes: Array, door_cells: Dictionary, doors: Array, dressing: Node2D, dim: Node2D) -> void:
	var rx := int(room.x)
	var ry := int(room.y)
	var rows: Array = room.rows
	var grid: Array = []
	for j in rows.size():
		var parts := str(rows[j]).split(".")
		var decoded: Array = []
		for i in parts.size():
			var code := parts[i]
			var info := Catalog.decode(code)
			decoded.append(info)
			var at := Vector2i(rx * COLS + i, ry * ROWS + j)
			var block := str(info.block)
			var slope := str(info.slope_side)
			var ladder := str(info.ladder_side)
			if slope != "":
				slopes.append({"x": at.x, "y": at.y, "side": slope, "frame": int(info.slope_frame), "top": _lip(int(info.height)), "code": block if block != "" else code})
			elif block != "":
				solids[at] = "%d|%s|%s" % [int(info.height), str(info.texture), block]
			elif not (info.beams as Array).is_empty():
				var beam := str((info.beams as Array)[0])
				platforms[at] = "%d|%s" % [int(info.height), Catalog.beam_texture(beam)]
			if ladder != "":
				ladders[at] = ladder
		grid.append(decoded)
		for i in decoded.size():
			_paint_cell(dim, dressing, Vector2i(rx * COLS + i, ry * ROWS + j), decoded[i], grid, i, j)
	for obj_v in room.get("objs", []):
		var obj: Dictionary = obj_v
		if str(obj.get("tag", "obj")) != "obj":
			continue
		var oid := str(obj.get("id", ""))
		var info := Registry.obj(oid)
		if str(info.get("tip", "")) != "door":
			continue
		var w := maxi(Registry.int_of(info.get("size"), 1), 1)
		var h := maxi(Registry.int_of(info.get("wid"), 1), 1)
		var ox := int(obj.get("x", 0))
		var oy := int(obj.get("y", 0))
		# The object cell is the bottom of the gap. The footprint extends upward.
		for dx in w:
			for dy in h:
				var cy := oy - (h - 1) + dy
				if cy < 0:
					continue
				door_cells[Vector2i(rx * COLS + ox + dx, ry * ROWS + cy)] = "hatch" if w > h else true
		var attrs: Dictionary = obj.get("attrs", {})
		doors.append({
			"id": oid,
			"x": (rx * COLS + ox) * TILE,
			"y": (ry * ROWS + oy) * TILE,
			"w": w * TILE,
			"h": h * TILE,
			"opac": Registry.float_of(info.get("opac"), 1.0),
			"hp": Registry.int_of(info.get("hp"), 0),
			"thre": Registry.int_of(info.get("thre"), 0),
			"room": [rx, ry],
			"cell": [ox, oy],
			"open": str(attrs.get("open", "")) == "1",
			"uid": str(attrs.get("uid", "")),
			"indestruct": str(attrs.get("indestruct", "")) not in ["", "0"],
		})


func _paint_cell(dim: Node, front: Node, at: Vector2i, info: Dictionary, grid: Array, i: int, j: int) -> void:
	var cell := Vector2(at) * TILE
	var solid := str(info.block) != ""
	var full := solid and int(info.height) == 4
	if not full:
		var wall := _texture(str(info.wall))
		if wall:
			_paint_aligned(dim, wall, Rect2(cell, Vector2(TILE, TILE)), -8)
	if solid and str(info.top) != "":
		var above_open := true
		if j > 0 and i < (grid[j - 1] as Array).size():
			above_open = str((grid[j - 1] as Array)[i].block) == ""
		if above_open:
			var top := _lip(int(info.height))
			var lip := _texture(str(info.top))
			if lip:
				var band := minf(Catalog.FLOOR_LIP, TILE - top)
				_paint_aligned(front, lip, Rect2(cell + Vector2(0, top), Vector2(TILE, band)), 1)


## A ladder that goes on from the room above (seamless rooms) has no lip at the edge.
func _lift_ladders(platforms: Dictionary, grids: Dictionary, ladders: Dictionary) -> void:
	for key in grids:
		var grid: Array = grids[key]
		var origin: Vector2i = key
		for j in grid.size():
			var row: Array = grid[j]
			for i in row.size():
				var info: Dictionary = row[i]
				var ladder := str(info.ladder_side)
				if ladder == "":
					continue
				if str(info.block) != "" or not (info.beams as Array).is_empty() or str(info.slope_side) != "":
					continue
				var above := ""
				if j > 0:
					above = str((grid[j - 1] as Array)[i].ladder_side)
				else:
					above = str(ladders.get(Vector2i(origin.x + i, origin.y - 1), ""))
				if above == ladder:
					continue
				platforms[Vector2i(origin.x + i, origin.y + j)] = "4|ladder_top"


func _grids(rooms: Array) -> Dictionary:
	var out := {}
	for room_v in rooms:
		var room: Dictionary = room_v
		var grid: Array = []
		for row_v in room.rows:
			var decoded: Array = []
			for code in str(row_v).split("."):
				decoded.append(Catalog.decode(code))
			grid.append(decoded)
		out[Vector2i(int(room.x) * COLS, int(room.y) * ROWS)] = grid
	return out


func _spawn_collision(solids: Dictionary, platforms: Dictionary, ladders: Dictionary, slopes: Array) -> void:
	var solid_root := Node2D.new()
	solid_root.name = "Solids"
	add_child(solid_root)
	var full := {}
	var partial := {}
	for pos in solids:
		var parts: PackedStringArray = str(solids[pos]).split("|")
		var height := int(parts[0])
		if height >= 4:
			full[pos] = solids[pos]
		else:
			partial[pos] = solids[pos]
	for rect_v in _mesh(full, true):
		_add_solid(solid_root, rect_v)
	for rect_v in _mesh(partial, false):
		_add_solid(solid_root, rect_v)
	var plat_rows: Array = []
	for rect_v in _mesh(platforms, false):
		plat_rows.append(_pixel_platform(rect_v))
	var ladder_rows: Array = []
	for rect_v in _mesh(ladders, true):
		var rect: Dictionary = rect_v
		ladder_rows.append({
			"x": float(rect.x) * TILE,
			"y": float(rect.y) * TILE,
			"w": float(rect.w) * TILE,
			"h": float(rect.h) * TILE,
			"side": str(rect.key),
		})
	var solid_rows: Array = []
	for child in solid_root.get_children():
		var shape_node := child.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape_node == null or not (shape_node.shape is RectangleShape2D):
			continue
		var size := (shape_node.shape as RectangleShape2D).size
		solid_rows.append({"x": child.position.x, "y": child.position.y, "w": size.x, "h": size.y})
	_widen_ladder_lips(plat_rows, ladder_rows, solid_rows)
	var plat_root := Node2D.new()
	plat_root.name = "Platforms"
	add_child(plat_root)
	for row_v in plat_rows:
		_add_platform(plat_root, row_v)
	var ladder_root := Node2D.new()
	ladder_root.name = "Ladders"
	add_child(ladder_root)
	for row_v in ladder_rows:
		_add_ladder(ladder_root, row_v)
	var slope_root := Node2D.new()
	slope_root.name = "Slopes"
	add_child(slope_root)
	for row_v in slopes:
		_add_slope(slope_root, row_v)


func _add_solid(parent: Node, rect: Dictionary) -> void:
	var parts: PackedStringArray = str(rect.key).split("|")
	var height := int(parts[0])
	var texture := parts[1] if parts.size() > 1 else ""
	var block := parts[2] if parts.size() > 2 else "C"
	var top := _lip(height)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector2(float(rect.x) * TILE, float(rect.y) * TILE + top)
	body.set_meta("blocks_sight", true)
	var size := Vector2(float(rect.w) * TILE, float(rect.h) * TILE - top)
	if size.y < 1.0:
		return
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var box := RectangleShape2D.new()
	box.size = size
	shape.shape = box
	shape.position = size * 0.5
	body.add_child(shape)
	var art := _texture(texture)
	var visual: Node2D = null
	if art:
		visual = _tiled_sprite(art, size)
		body.add_child(visual)
	else:
		body.add_child(_quad(size, Color(0.46, 0.47, 0.43)))
	body.set_meta("code", block)
	parent.add_child(body)
	_Wall.attach(body, block, Catalog.border_for(land_id))
	if visual != null:
		_Outline.dress(body, visual, block, size)


func _pixel_platform(rect: Dictionary) -> Dictionary:
	var parts: PackedStringArray = str(rect.key).split("|")
	var height := int(parts[0]) if parts.size() > 0 and parts[0].is_valid_int() else 4
	var texture := parts[1] if parts.size() > 1 else ""
	var top := _lip(height)
	return {
		"x": float(rect.x) * TILE,
		"y": float(rect.y) * TILE + top,
		"w": float(rect.w) * TILE,
		"h": maxf(8.0, float(height) * (TILE / 4.0)),
		"texture": texture,
	}


func _add_platform(parent: Node, row: Dictionary) -> void:
	var size := Vector2(float(row.w), float(row.h))
	if size.x < 1.0 or size.y < 1.0:
		return
	var body := StaticBody2D.new()
	body.collision_layer = 64
	body.collision_mask = 0
	body.position = Vector2(float(row.x), float(row.y))
	body.set_meta("blocks_sight", false)
	body.set_meta("sight_transparency", 1.0)
	var lip := minf(10.0, size.y)
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var box := RectangleShape2D.new()
	box.size = Vector2(size.x, lip)
	shape.shape = box
	shape.position = Vector2(size.x * 0.5, lip * 0.5)
	shape.one_way_collision = true
	shape.one_way_collision_margin = 8.0
	body.add_child(shape)
	var texture_name := str(row.get("texture", ""))
	if texture_name != "ladder_top":
		var art := _texture(texture_name)
		if art:
			var draw := size
			draw.y = minf(float(art.get_height()), size.y)
			body.add_child(_tiled_sprite(art, draw))
	parent.add_child(body)


func _add_ladder(parent: Node, row: Dictionary) -> void:
	var size := Vector2(float(row.w), float(row.h))
	var area := Area2D.new()
	area.add_to_group("ladders")
	area.collision_layer = 32
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	area.position = Vector2(float(row.x), float(row.y)) + size * 0.5
	var side := str(row.get("side", "right"))
	# Feet stand on this edge. The grab shape continues above it so the lip still overlaps.
	area.set_meta("ladder_side", side)
	area.set_meta("rail_top_local", -size.y * 0.5)
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var box := RectangleShape2D.new()
	# 36px above the tile so standing on the lip still overlaps the ladder.
	# The sensor is the 19px rail, not the 40px tile plus a 24px grab.
	var grab_up := 36.0
	var rail_w := Catalog.LADDER_RAIL_W
	var sprite_left := -size.x * 0.5 - Catalog.FRONT_ORIGIN.x
	var rail_center := sprite_left + Catalog.ladder_rail_sprite_x(side) + rail_w * 0.5
	box.size = Vector2(rail_w, size.y + grab_up)
	shape.shape = box
	shape.position = Vector2(rail_center, -grab_up * 0.5)
	area.add_child(shape)
	var base := Catalog.ladder_frame(side)
	var origin := -size * 0.5
	var tiles := maxi(1, int(round(size.y / TILE)))
	for i in tiles:
		var frame := base + (1 if i == 0 else 0)
		var rail := _front(frame)
		if rail:
			var sprite := Sprite2D.new()
			sprite.texture = rail
			sprite.centered = false
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.z_index = 2
			sprite.position = origin + Vector2(0, float(i) * TILE) - Catalog.FRONT_ORIGIN
			area.add_child(sprite)
	parent.add_child(area)


func _add_slope(parent: Node, row: Dictionary) -> void:
	var top := float(row.get("top", 0))
	var body := StaticBody2D.new()
	# Platform layer, same as beams. Down+jump already drops through that layer.
	# stair_slope.gd opens the ramp while the feet are still below the walk line.
	body.collision_layer = 64
	body.collision_mask = 0
	body.position = Vector2(float(row.x) * TILE, float(row.y) * TILE)
	body.set_meta("blocks_sight", true)
	body.set_script(_Stair)
	body.set("side", str(row.get("side", "right")))
	body.set("lip", top)
	var points: PackedVector2Array
	if str(row.get("side", "right")) == "left":
		points = PackedVector2Array([Vector2(0, top), Vector2(0, TILE), Vector2(TILE, TILE)])
	else:
		points = PackedVector2Array([Vector2(0, TILE), Vector2(TILE, TILE), Vector2(TILE, top)])
	var shape := CollisionPolygon2D.new()
	shape.polygon = points
	body.add_child(shape)
	var step := _front(int(row.get("frame", 0)))
	if step:
		var sprite := Sprite2D.new()
		sprite.texture = step
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = -Catalog.FRONT_ORIGIN
		sprite.z_index = -5
		body.add_child(sprite)
	parent.add_child(body)


func _spawn_doors(doors: Array) -> void:
	var root := Node2D.new()
	root.name = "Doors"
	add_child(root)
	var index := 0
	for row_v in doors:
		var row: Dictionary = row_v
		var id := str(row.id)
		var body := _DoorArt.spawn(id, Vector2(float(row.x), float(row.y)), float(row.w), float(row.opac), bool(row.open))
		body.name = "%s_%d" % [id, index]
		body.set_meta("uid", str(row.get("uid", "")))
		body.set_meta("indestruct", bool(row.get("indestruct", false)))
		var room: Array = row.room
		var cell: Array = row.cell
		body.set_meta("room_x", int(room[0]))
		body.set_meta("room_y", int(room[1]))
		body.set_meta("cell_x", int(cell[0]))
		body.set_meta("cell_y", int(cell[1]))
		if not _DoorArt.known(id):
			_stand_in_door(body, row)
		_DoorArt.apply_instance(body)
		body.set_meta("usable", true)
		root.add_child(body)
		index += 1


## objs.xml tip=door with no texture1.swf art yet: its own footprint and
## tile hp, drawn as a flat panel.
func _stand_in_door(body: Node, row: Dictionary) -> void:
	var size := Vector2(float(row.w), float(row.h))
	var cell_y := float(row.y)
	(body as Node2D).position = Vector2(float(row.x), cell_y + TILE - size.y)
	body.set_meta("door_w", size.x)
	body.set_meta("door_h", size.y)
	body.set_meta("hp", int(row.get("hp", 0)))
	body.set_meta("thre", int(row.get("thre", 0)))
	body.set_meta("breakable", int(row.get("hp", 0)) > 0)
	body.set_meta("stand_in", true)
	var shape := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape and shape.shape is RectangleShape2D:
		var box := RectangleShape2D.new()
		box.size = size
		shape.shape = box
		shape.position = size * 0.5
	var panel := _quad(size, Color(0.38, 0.4, 0.44, 0.9 if float(row.opac) >= 0.5 else 0.45))
	panel.name = "StandIn"
	panel.z_index = 1
	panel.visible = not bool(row.open)
	body.add_child(panel)


func _mesh(cells: Dictionary, vertical: bool) -> Array:
	var remaining := cells.duplicate()
	var keys: Array = remaining.keys()
	keys.sort()
	var rects: Array = []
	for key in keys:
		var pos: Vector2i = key
		if not remaining.has(pos):
			continue
		var payload = remaining[pos]
		remaining.erase(pos)
		var w := 1
		while remaining.get(Vector2i(pos.x + w, pos.y)) == payload:
			remaining.erase(Vector2i(pos.x + w, pos.y))
			w += 1
		var h := 1
		if vertical:
			while true:
				var row_ok := true
				for dx in w:
					if remaining.get(Vector2i(pos.x + dx, pos.y + h)) != payload:
						row_ok = false
						break
				if not row_ok:
					break
				for dx in w:
					remaining.erase(Vector2i(pos.x + dx, pos.y + h))
				h += 1
		rects.append({"x": pos.x, "y": pos.y, "w": w, "h": h, "key": payload})
	return rects


func _widen_ladder_lips(platforms: Array, ladders: Array, solids: Array) -> void:
	for entry in platforms:
		var row: Dictionary = entry
		if str(row.get("texture", "")) != "ladder_top":
			continue
		if float(row.w) > TILE + 1.0:
			continue
		var x := float(row.x)
		var y := float(row.y)
		var side := "right"
		for ladder_v in ladders:
			var ladder: Dictionary = ladder_v
			if absf(float(ladder.x) - x) < 1.0 and absf(float(ladder.y) - y) < 1.0:
				side = str(ladder.get("side", "right"))
				break
		var dir := 1.0 if side == "left" else -1.0
		var neighbor_cx := x + dir * TILE + TILE * 0.5
		var beyond_cx := neighbor_cx + dir * TILE
		var probe_y := y + 8.0
		if _solid_at(solids, neighbor_cx, probe_y):
			continue
		if not _solid_at(solids, beyond_cx, probe_y):
			continue
		if dir > 0.0:
			row.w = float(row.w) + TILE
		else:
			row.x = x + dir * TILE
			row.w = float(row.w) + TILE


func _solid_at(solids: Array, x: float, y: float) -> bool:
	for entry in solids:
		var rect: Dictionary = entry
		var rx := float(rect.x)
		var ry := float(rect.y)
		if x >= rx and x < rx + float(rect.w) and y >= ry and y < ry + float(rect.h):
			return true
	return false


func _lip(height: int) -> float:
	return (4 - height) * (TILE / 4.0)


func _paint_backwall(parent: Node, rx: int, ry: int, wall_name: String, form: int = 0) -> void:
	if wall_name == "sky":
		return
	var texture := _texture(wall_name)
	if texture == null:
		texture = _texture("tBackWall")
	if texture == null:
		return
	var origin := Vector2(rx * COLS * TILE, ry * ROWS * TILE)
	for rect_v in _Look.backwall_rects(form):
		var rect: Rect2 = rect_v
		var wall := Sprite2D.new()
		wall.texture = texture
		wall.centered = false
		wall.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		wall.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		wall.region_enabled = true
		wall.region_rect = rect
		wall.position = origin + rect.position
		wall.z_index = -12
		parent.add_child(wall)


func _paint_aligned(parent: Node, texture: Texture2D, dest: Rect2, z: int) -> void:
	var tw := float(texture.get_width())
	var th := float(texture.get_height())
	var y := dest.position.y
	var y_end := dest.position.y + dest.size.y
	while y < y_end - 0.05:
		var src_y := fposmod(y, th)
		var dh := minf(th - src_y, y_end - y)
		var x := dest.position.x
		var x_end := dest.position.x + dest.size.x
		while x < x_end - 0.05:
			var src_x := fposmod(x, tw)
			var dw := minf(tw - src_x, x_end - x)
			_add_slice(parent, texture, Vector2(x, y), src_x, src_y, dw, dh, z)
			x += dw
		y += dh


func _add_slice(parent: Node, texture: Texture2D, at: Vector2, src_x: float, src_y: float, width: float, height: float, z: int) -> void:
	_TileCanvas.at(parent, at, z).add(texture, Rect2(at, Vector2(width, height)), Rect2(src_x, src_y, width, height))


func _tiled_sprite(texture: Texture2D, size: Vector2) -> Node2D:
	var root := Node2D.new()
	var tw := float(texture.get_width())
	var th := float(texture.get_height())
	var y := 0.0
	while y < size.y - 0.5:
		var x := 0.0
		var dh := minf(th, size.y - y)
		while x < size.x - 0.5:
			var dw := minf(tw, size.x - x)
			var sprite := Sprite2D.new()
			sprite.texture = texture
			sprite.centered = false
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.region_enabled = true
			sprite.region_rect = Rect2(0, 0, dw, dh)
			sprite.position = Vector2(x, y)
			root.add_child(sprite)
			x += dw
		y += dh
	return root


func _quad(size: Vector2, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.color = color
	poly.polygon = PackedVector2Array([
		Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)
	])
	return poly


func _front(frame: int) -> Texture2D:
	var key := "front_%d" % frame
	if _tex.has(key):
		var cached = _tex[key]
		return cached if cached is Texture2D else null
	var path := Catalog.front_file(frame)
	var texture: Texture2D = load(path) if path != "" else null
	_tex[key] = texture
	return texture


func _texture(key: String) -> Texture2D:
	if key == "":
		return null
	if _tex.has(key):
		var cached = _tex[key]
		return cached if cached is Texture2D else null
	var path := Catalog.file_for(key)
	var texture: Texture2D = load(path) if path != "" else null
	_tex[key] = texture
	return texture
