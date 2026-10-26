extends Node2D

## Hand-authored opening land (Lands.xml id begin, file rooms_begin).
## Geometry is res://assets/data/maps/begin_land.json, taken from the room
## document embedded in pfe.swf. Tiles are 40px. Rooms sit at x*48, y*25.

const Catalog := preload("res://scripts/map/tile_catalog.gd")
const _Wall := preload("res://scripts/wall_span.gd")
const _DoorArt := preload("res://scripts/door_art.gd")
const Decor := preload("res://scripts/map/back_decor.gd")
const RoomFile := preload("res://scripts/map/room_file.gd")
const _Stair := preload("res://scripts/stair_slope.gd")
const _Flags := preload("res://scripts/map/room_flags.gd")
const _Look := preload("res://scripts/map/room_look.gd")
const _Registry := preload("res://scripts/map/land_registry.gd")
const _Fog := preload("res://scripts/fog.gd")
const _Outline := preload("res://scripts/map/tile_outline.gd")
const _TileCanvas := preload("res://scripts/map/tile_canvas.gd")
const _RoomActivity := preload("res://scripts/map/room_activity.gd")
const _LandSpawn := preload("res://scripts/map/land_spawn.gd")
const DATA := "res://assets/data/maps/begin_land.json"
const VISUAL := "res://assets/data/maps/begin_visual.json"
const TILE := 40.0
const ROOM_COLS := 48
const ROOM_ROWS := 25

var spawn_px := Vector2(320, 639)
var map_px := Vector2(9600, 5000)

const _COLORS := {
	"A": Color(0.52, 0.55, 0.58),
	"B": Color(0.30, 0.34, 0.38),
	"C": Color(0.46, 0.47, 0.43),
	"D": Color(0.38, 0.35, 0.31),
	"E": Color(0.44, 0.40, 0.34),
	"F": Color(0.42, 0.30, 0.18),
	"G": Color(0.34, 0.33, 0.31),
	"H": Color(0.38, 0.28, 0.18),
	"L": Color(0.30, 0.40, 0.30),
}

var _loaded: Dictionary = {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var text := FileAccess.get_file_as_string(DATA)
	var data: Variant = JSON.parse_string(text)
	if data is Dictionary:
		_build(data)
	_RoomActivity.attach(self)


func _build(data: Dictionary) -> void:
	var size: Array = data.get("map_px", [9600, 5000])
	map_px = Vector2(float(size[0]), float(size[1]))
	var spawn: Dictionary = data.get("spawn", {})
	var px: Array = spawn.get("px", [320, 639])
	spawn_px = Vector2(float(px[0]), float(px[1]))

	var backdrop := ColorRect.new()
	backdrop.name = "BackWall"
	backdrop.z_index = -20
	backdrop.offset_right = map_px.x
	backdrop.offset_bottom = map_px.y
	backdrop.color = Color(0, 0, 0, 1)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	_begin_outline(data)
	var solids := Node2D.new()
	solids.name = "Solids"
	add_child(solids)
	for entry in data.get("solids", []):
		_add_box(solids, entry, 1, false, true, _color(str(entry.get("code", "C"))))

	var slopes := Node2D.new()
	slopes.name = "Slopes"
	add_child(slopes)
	for entry in data.get("slopes", []):
		_add_slope(slopes, entry)

	var platforms := Node2D.new()
	platforms.name = "Platforms"
	add_child(platforms)
	var platform_rows: Array = data.get("platforms", [])
	_widen_ladder_lips(platform_rows, data.get("ladders", []), data.get("solids", []))
	for entry in platform_rows:
		_add_box(platforms, entry, 64, true, false, Color(0.55, 0.42, 0.24, 1))

	var ladders := Node2D.new()
	ladders.name = "Ladders"
	add_child(ladders)
	var door_rows: Array = data.get("doors", [])
	for entry in data.get("ladders", []):
		_add_ladder(ladders, entry)
	for entry in _hatch_ladders(data.get("ladders", []), door_rows):
		_add_ladder(ladders, entry, false)

	_restore_door_floors(solids, door_rows)
	var doors := Node2D.new()
	doors.name = "Doors"
	add_child(doors)
	var door_i := 0
	for entry in door_rows:
		_add_door(doors, entry, door_i)
		door_i += 1
	call_deferred("_spawn_actors")
	_paint_rooms()


func _add_box(parent: Node, entry: Dictionary, layer: int, one_way: bool, blocks_sight: bool, color: Color) -> void:
	var size := Vector2(float(entry["w"]), float(entry["h"]))
	if size.x < 1.0 or size.y < 1.0:
		return
	var body := StaticBody2D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = Vector2(float(entry["x"]), float(entry["y"]))
	body.set_meta("blocks_sight", blocks_sight)
	if not blocks_sight:
		body.set_meta("sight_transparency", 1.0)
	var tex_key := str(entry.get("texture", ""))
	var ladder_lip := tex_key == "ladder_top"
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	# One-way shelves keep their tile, but only the top 10px is solid.
	# A full-tile lip plugs the ladder shaft beside it.
	var lip := minf(10.0, size.y) if one_way else size.y
	box.size = Vector2(size.x, lip)
	shape.shape = box
	shape.position = Vector2(size.x * 0.5, lip * 0.5)
	shape.one_way_collision = one_way
	if one_way:
		shape.one_way_collision_margin = 8.0
	body.add_child(shape)
	var visual: Node2D = null
	if ladder_lip:
		pass
	else:
		var texture := _texture(tex_key)
		if texture:
			var draw := size
			if one_way:
				draw.y = minf(float(texture.get_height()), size.y)
			visual = _tiled_sprite(texture, draw)
			body.add_child(visual)
		else:
			body.add_child(_quad(size, color))
	parent.add_child(body)
	if layer == 1 and not one_way:
		_Wall.attach(body, str(entry.get("code", "")), Catalog.border_for("begin"))
		if visual != null:
			_Outline.dress(body, visual, str(entry.get("code", "")), size)


## tile_outline's cell grid: every 40px cell a solid row covers, doors, and the room area.
func _begin_outline(data: Dictionary) -> void:
	var cells := {}
	for entry in data.get("solids", []):
		var x0 := floori(float(entry["x"]) / TILE)
		var y0 := floori(float(entry["y"]) / TILE)
		var x1 := ceili((float(entry["x"]) + float(entry["w"])) / TILE)
		var y1 := ceili((float(entry["y"]) + float(entry["h"])) / TILE)
		for cy in range(y0, y1):
			for cx in range(x0, x1):
				cells[Vector2i(cx, cy)] = true
	var doors := {}
	for entry in data.get("doors", []):
		var x0 := floori(float(entry.get("x", 0)) / TILE)
		var y0 := floori(float(entry.get("y", 0)) / TILE)
		var x1 := ceili((float(entry.get("x", 0)) + float(entry.get("w", TILE))) / TILE)
		var y1 := ceili((float(entry.get("y", 0)) + float(entry.get("h", TILE))) / TILE)
		for cy in range(y0, y1):
			for cx in range(x0, x1):
				doors[Vector2i(cx, cy)] = true
	var rooms: Array = []
	for ry in ceili(map_px.y / (TILE * ROOM_ROWS)):
		for rx in ceili(map_px.x / (TILE * ROOM_COLS)):
			rooms.append({"x": rx, "y": ry})
	_Outline.begin(self, cells, doors, rooms, ROOM_COLS, ROOM_ROWS)


func _add_slope(parent: Node, entry: Dictionary) -> void:
	var top := float(entry.get("top", 0))
	var body := StaticBody2D.new()
	# Platform layer, same as beams. Down+jump already drops through that layer.
	# stair_slope.gd opens the ramp while the feet are still below the walk line.
	body.collision_layer = 64
	body.collision_mask = 0
	body.position = Vector2(float(entry["x"]), float(entry["y"]))
	body.set_meta("blocks_sight", true)
	body.set_script(_Stair)
	body.set("side", str(entry.get("side", "right")))
	body.set("lip", top)
	var points: PackedVector2Array
	if str(entry.get("side", "right")) == "left":
		points = PackedVector2Array([Vector2(0, top), Vector2(0, TILE), Vector2(TILE, TILE)])
	else:
		points = PackedVector2Array([Vector2(0, TILE), Vector2(TILE, TILE), Vector2(TILE, top)])
	var shape := CollisionPolygon2D.new()
	shape.polygon = points
	body.add_child(shape)
	var info := Catalog.decode(str(entry.get("code", "")))
	var step := _front(int(info.slope_frame))
	if step:
		var sprite := Sprite2D.new()
		sprite.texture = step
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = -Catalog.FRONT_ORIGIN
		sprite.z_index = -5
		body.add_child(sprite)
	else:
		var poly := Polygon2D.new()
		poly.polygon = points
		poly.color = _color(str(entry.get("code", "C")))
		body.add_child(poly)
	parent.add_child(body)


func _widen_ladder_lips(platforms: Array, ladders: Array, solids: Array) -> void:
	# A 40px ladder-top lip beside one open tile leaves a 40px slot. The body is 50px
	# and wedges there instead of standing on the ladder. Stretch that lip across the
	# single open neighbor when the tile after it is solid. The shaft below stays open.
	for entry in platforms:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = entry
		if str(row.get("texture", "")) != "ladder_top":
			continue
		if float(row["w"]) > TILE + 1.0:
			continue
		var x := float(row["x"])
		var y := float(row["y"])
		var side := "right"
		for ladder_v in ladders:
			if typeof(ladder_v) != TYPE_DICTIONARY:
				continue
			var ladder: Dictionary = ladder_v
			if absf(float(ladder["x"]) - x) < 1.0 and absf(float(ladder["y"]) - y) < 1.0:
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
			row["w"] = float(row["w"]) + TILE
		else:
			row["x"] = x + dir * TILE
			row["w"] = float(row["w"]) + TILE


func _solid_at(solids: Array, x: float, y: float) -> bool:
	for entry in solids:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var rect: Dictionary = entry
		var rx := float(rect["x"])
		var ry := float(rect["y"])
		if x >= rx and x < rx + float(rect["w"]) and y >= ry and y < ry + float(rect["h"]):
			return true
	return false


## Port rule: a ladder runs on through an open hatch (a door wider than tall)
## right above or below it. One tile of rail without art inside the hatch.
func _hatch_ladders(ladders: Array, doors: Array) -> Array:
	var out: Array = []
	for door_v in doors:
		var door: Dictionary = door_v
		if int(door.get("w", 1)) <= int(door.get("h", 1)):
			continue
		var hatch := Rect2(float(door["px"]), float(door["py"]), float(door["w"]) * TILE, TILE)
		for ladder_v in ladders:
			var l: Dictionary = ladder_v
			var x := float(l["x"])
			var rect := Rect2(x, float(l["y"]), float(l["w"]), float(l["h"]))
			if x < hatch.position.x - 0.5 or x + rect.size.x > hatch.end.x + 0.5:
				continue
			if absf(rect.end.y - hatch.position.y) < 1.0 or absf(rect.position.y - hatch.end.y) < 1.0:
				out.append({"x": x, "y": hatch.position.y, "w": rect.size.x, "h": TILE, "side": l.get("side", "right")})
				break
	return out


func _add_ladder(parent: Node, entry: Dictionary, art := true) -> void:
	var size := Vector2(float(entry["w"]), float(entry["h"]))
	var area := Area2D.new()
	area.add_to_group("ladders")
	area.collision_layer = 32
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	area.position = Vector2(float(entry["x"]), float(entry["y"])) + size * 0.5
	var side := str(entry.get("side", "right"))
	# Feet stand on this edge. The grab shape continues above it so the lip still overlaps.
	area.set_meta("ladder_side", side)
	area.set_meta("rail_top_local", -size.y * 0.5)
	var shape := CollisionShape2D.new()
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
	# tileFront frame, origin at the tile top-left. The top frame is the next frame.
	var base := Catalog.ladder_frame(side)
	var origin := -size * 0.5
	var tiles := maxi(1, int(round(size.y / TILE))) if art else 0
	for i in tiles:
		var frame := base + (1 if i == 0 else 0)
		var rail := _front(frame)
		if rail:
			_add_ladder_sprite(area, rail, origin + Vector2(0, float(i) * TILE) - Catalog.FRONT_ORIGIN)
	parent.add_child(area)


func _add_ladder_sprite(area: Node, texture: Texture2D, at: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = 2
	sprite.position = at
	area.add_child(sprite)


func _add_door(parent: Node, entry: Dictionary, index: int) -> void:
	var id := str(entry.get("id", "door"))
	var cell := Vector2(float(entry["px"]), float(entry["py"]))
	var body := _DoorArt.spawn(id, cell, float(entry.get("w", 1)) * TILE, float(entry.get("opac", 1.0)), bool(entry.get("open", false)))
	var uid := str(entry.get("uid", ""))
	body.name = "%s_%d" % [uid if uid != "" else id, index]
	var room: Array = entry.get("room", [0, 0])
	var at: Array = entry.get("cell", [0, 0])
	body.set_meta("room_x", int(room[0]))
	body.set_meta("room_y", int(room[1]))
	body.set_meta("cell_x", int(at[0]))
	body.set_meta("cell_y", int(at[1]))
	body.set_meta("uid", uid)
	# septum has no Interact. A placed inter="0" stays shut until it breaks.
	body.set_meta("usable", bool(entry.get("inter", true)))
	parent.add_child(body)


## The room file stores a door on the bottom cell of its gap. An older extract
## deleted that many cells downward, which ate the floor. Put those blocks back.
func _restore_door_floors(solids: Node, doors: Array) -> void:
	if not FileAccess.file_exists(VISUAL):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(VISUAL))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var grids := {}
	for room_v in (parsed as Dictionary).get("rooms", []):
		if typeof(room_v) != TYPE_DICTIONARY:
			continue
		var room: Dictionary = room_v
		if int(room.get("z", 0)) != 0:
			continue
		var rows: Array = []
		for row_v in room.get("rows", []):
			rows.append(str(row_v).split("."))
		grids[Vector2i(int(room.get("x", 0)), int(room.get("y", 0)))] = rows
	var sealed := {}
	for entry_v in doors:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v
		var tall := int(entry.get("h", 1))
		if tall <= 1:
			continue
		var room_at: Array = entry.get("room", [0, 0])
		var cell_at: Array = entry.get("cell", [0, 0])
		var wide := int(entry.get("w", 1))
		var wx0 := int(room_at[0]) * ROOM_COLS + int(cell_at[0])
		var wy0 := int(room_at[1]) * ROOM_ROWS + int(cell_at[1])
		for dy in range(1, tall):
			for dx in range(wide):
				var wx := wx0 + dx
				var wy := wy0 + dy
				var key := Vector2i(wx, wy)
				if sealed.has(key):
					continue
				var rx := int(wx / ROOM_COLS)
				var ry := int(wy / ROOM_ROWS)
				var lx := wx - rx * ROOM_COLS
				var ly := wy - ry * ROOM_ROWS
				var grid: Array = grids.get(Vector2i(rx, ry), [])
				if ly < 0 or ly >= grid.size():
					continue
				var row: Array = grid[ly]
				if lx < 0 or lx >= row.size():
					continue
				var code := str(row[lx])
				var info := Catalog.decode(code)
				if str(info.block) == "":
					continue
				sealed[key] = true
				var height := int(info.height)
				var top := (4 - height) * (TILE / 4.0)
				_add_box(solids, {
					"x": float(wx) * TILE,
					"y": float(wy) * TILE + top,
					"w": TILE,
					"h": maxf(8.0, float(height) * TILE / 4.0),
					"texture": str(info.texture),
					"code": code,
				}, 1, false, true, _color(code))


func _spawn_actors() -> void:
	var actors := preload("res://scripts/land_props.gd").new()
	actors.name = "Actors"
	var rooms := _plan_rooms()
	actors.bind_rooms(rooms)
	actors.bind_plan(_LandSpawn.plan(_plan_ctx(), rooms).get("rows", []), spawn_px)
	add_child(actors)


## rooms_begin as a story land: Location.setObjects over every room, the way
## play_land plans a non-random land.
func _plan_rooms() -> Array:
	var rooms: Array = []
	for room_v in RoomFile.load_doc("rooms_begin").get("rooms", []):
		var room: Dictionary = room_v
		if not room.has("x") or not room.has("y"):
			continue
		var copy := room.duplicate()
		copy["lx"] = int(room.x)
		copy["ly"] = int(room.y)
		copy["z"] = int(room.get("z", 0))
		copy["mirror"] = false
		rooms.append(copy)
	return rooms


func _plan_ctx() -> Dictionary:
	var info := _Registry.land("begin")
	var options: Dictionary = info.get("options", {})
	return {
		"land_id": "begin",
		"rnd": false,
		"conf": _Registry.int_of(info.get("conf"), -1),
		"biom": _Registry.int_of(info.get("biom"), 0),
		"land_dif": _Registry.int_of(info.get("dif"), 0),
		"glob_dif": GameState.difficulty() if GameState.has_method("difficulty") else 2,
		"stage": Travel.land_stage("begin"),
		"probs_done": [],
		"exit_prob": str(info.get("exit", "")),
		"xp": _Registry.int_of(options.get("xp"), 100),
		"beg": Vector2i(int(spawn_px.x / (ROOM_COLS * TILE)), int(spawn_px.y / (ROOM_ROWS * TILE))),
		"width": int(map_px.x / (ROOM_COLS * TILE)),
		"height": int(map_px.y / (ROOM_ROWS * TILE)),
	}


func _paint_rooms() -> void:
	if not FileAccess.file_exists(VISUAL):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(VISUAL))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var dressing := Node2D.new()
	dressing.name = "RoomDressing"
	dressing.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(dressing)
	var layers := Decor.layers(dressing, Color(0, 0, 0, 1))
	var backs := _back_rooms()
	var rooms: Array = (parsed as Dictionary).get("rooms", [])
	for room_v in rooms:
		if typeof(room_v) != TYPE_DICTIONARY:
			continue
		var room: Dictionary = room_v
		if int(room.get("z", 0)) != 0:
			continue
		var origin := Vector2(int(room.get("x", 0)) * ROOM_COLS * TILE, int(room.get("y", 0)) * ROOM_ROWS * TILE)
		var wall_name := str(room.get("backwall", "tBackWall"))
		_paint_backwall(layers.dim, origin, wall_name)
		var grid: Array = []
		for row_v in room.get("rows", []):
			grid.append(str(row_v).split("."))
		for j in grid.size():
			var cells: Array = grid[j]
			for i in cells.size():
				var code := str(cells[i])
				var cell := origin + Vector2(i, j) * TILE
				var info := Catalog.decode(code)
				var solid := str(info.block) != ""
				# A full block covers its back patch. A lowered block leaves the patch in the gap.
				if not (solid and int(info.height) == 4):
					var wall_tex := _texture(str(info.wall))
					if wall_tex:
						_paint_aligned(layers.dim, wall_tex, Rect2(cell, Vector2(TILE, TILE)), -8)
				# Outline bitmap of the block below. Concrete (C) is tBorder, not the grass edge (tMoss, code L).
				if not solid and j + 1 < grid.size() and i < (grid[j + 1] as Array).size():
					var below_info := Catalog.decode(str((grid[j + 1] as Array)[i]))
					var edge_name := str(below_info.edge)
					if str(below_info.block) != "" and edge_name != "":
						var edge_tex := _texture(edge_name)
						if edge_tex:
							var band := Catalog.FLOOR_LIP
							_stamp_slice(dressing, edge_tex, cell + Vector2(0, TILE - band), TILE, band, -4)
				var top_name := str(info.top)
				if solid and top_name != "":
					var above_open := j == 0
					if j > 0 and i < (grid[j - 1] as Array).size():
						above_open = not _cell_solid(str((grid[j - 1] as Array)[i]))
					if above_open:
						var top := _lip_top(code)
						var lip_tex := _texture(top_name)
						if lip_tex:
							var band := minf(Catalog.FLOOR_LIP, TILE - top)
							_paint_aligned(dressing, lip_tex, Rect2(cell + Vector2(0, top), Vector2(TILE, band)), 1)
		var placed: Dictionary = backs.get(Vector2i(int(room.get("x", 0)), int(room.get("y", 0))), {})
		if not placed.is_empty():
			Decor.paint(layers, placed, origin, 0)
	_paint_looks()


## RoomFlags rows of the begin rooms, then their water and colour filters (RoomLook).
func _paint_looks() -> void:
	var rooms: Array = _Fog.begin_rooms()
	var act: Dictionary = _Registry.land("begin").get("options", {})
	var envs := {}
	for room_v in rooms:
		var room: Dictionary = room_v
		envs[Vector2i(int(room.x), int(room.y))] = _Flags.row_of(room, act, "begin")
	set_meta(_Flags.META, envs)
	_Look.build(self, rooms, envs)


func _back_rooms() -> Dictionary:
	var out := {}
	var doc := RoomFile.load_doc("rooms_begin")
	for room_v in doc.get("rooms", []):
		if typeof(room_v) != TYPE_DICTIONARY:
			continue
		var src: Dictionary = room_v
		if not src.has("x") or not src.has("y"):
			continue
		if int(src.get("z", 0)) != 0:
			continue
		out[Vector2i(int(src.x), int(src.y))] = src
	return out


func _paint_backwall(parent: Node, origin: Vector2, wall_name: String) -> void:
	var texture := _texture(wall_name)
	if texture == null:
		texture = _texture("tBackWall")
	if texture == null:
		return
	var room_size := Vector2(ROOM_COLS * TILE, ROOM_ROWS * TILE)
	var wall := _tiled_sprite(texture, room_size)
	wall.position = origin
	wall.z_index = -12
	parent.add_child(wall)


func _cell_solid(code: String) -> bool:
	if code.is_empty():
		return false
	return code.unicode_at(0) > 64 and code[0] != "_"


func _lip_top(code: String) -> float:
	var height := 4
	if ":" in code:
		height = 1
	elif ";" in code:
		height = 2
	elif "," in code:
		height = 3
	return (4 - height) * (TILE / 4.0)


func _stamp_slice(parent: Node, texture: Texture2D, at: Vector2, width: float, height: float, z: int) -> void:
	var tw := float(texture.get_width())
	var th := float(texture.get_height())
	var src_y := maxf(0.0, th - height)
	var band := minf(height, th)
	var phase := fmod(at.x, tw)
	if phase < 0.0:
		phase += tw
	var draw_w := minf(width, tw - phase)
	_add_slice(parent, texture, at + Vector2(0, height - band), phase, src_y, draw_w, band, z)
	if draw_w + 0.5 < width:
		_add_slice(parent, texture, at + Vector2(draw_w, height - band), 0.0, src_y, width - draw_w, band, z)


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


func _color(code: String) -> Color:
	var letter := code.substr(0, 1)
	if _COLORS.has(letter):
		return _COLORS[letter]
	return Color(0.4, 0.4, 0.38)


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


func _front(frame: int) -> Texture2D:
	var key := "front_%d" % frame
	if _loaded.has(key):
		var cached = _loaded[key]
		return cached if cached is Texture2D else null
	var path := Catalog.front_file(frame)
	var texture: Texture2D = load(path) if path != "" else null
	_loaded[key] = texture
	return texture


func _texture(key: String) -> Texture2D:
	if key == "":
		return null
	if _loaded.has(key):
		var cached = _loaded[key]
		return cached if cached is Texture2D else null
	var path := Catalog.file_for(key)
	var texture: Texture2D = load(path) if path != "" else null
	_loaded[key] = texture
	return texture
