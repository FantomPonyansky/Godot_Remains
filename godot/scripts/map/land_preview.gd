extends Control

## Textured preview of the land the map builder is showing.
## The builder keeps the build; Esc only closes this view.

const RoomFile := preload("res://scripts/map/room_file.gd")
const Catalog := preload("res://scripts/map/tile_catalog.gd")

const TILE := 40.0
const COLS := 48
const ROWS := 25

## Footprint in tiles (width, height) from objs.xml. Wood doors use the brown fill.
const _DOOR := {
	"septum": Vector2i(1, 3), "grate": Vector2i(1, 3), "hgrate": Vector2i(3, 1),
	"platform1": Vector2i(3, 1), "window1": Vector2i(1, 2), "window2": Vector2i(1, 2),
	"door1": Vector2i(1, 2), "door1a": Vector2i(1, 2), "door1b": Vector2i(1, 2),
	"door2": Vector2i(1, 2), "door2a": Vector2i(1, 2), "stdoor": Vector2i(1, 3),
	"basedoor": Vector2i(1, 3), "door3": Vector2i(1, 3), "door4": Vector2i(1, 3),
	"hatch1": Vector2i(2, 1), "hatch2": Vector2i(2, 1), "encldoor": Vector2i(1, 3),
	"enclpole": Vector2i(1, 3), "indoor1": Vector2i(2, 2), "indoor2": Vector2i(2, 2),
	"indoor3": Vector2i(2, 2), "indoor4": Vector2i(2, 2), "alib1": Vector2i(1, 7),
	"alib2": Vector2i(7, 1), "doorout": Vector2i(2, 3), "doorprob": Vector2i(2, 3),
	"doorboss": Vector2i(2, 3), "door": Vector2i(1, 2),
}
const _WOOD := {
	"septum": true, "door1": true, "door1a": true, "hatch1": true,
	"indoor1": true, "indoor2": true,
}
const _CRATE := {
	"woodbox": Vector2i(2, 2), "box": Vector2i(2, 2), "mcrate1": Vector2i(2, 2),
	"mcrate2": Vector2i(2, 2), "mcrate3": Vector2i(2, 2), "mcrate4": Vector2i(2, 2),
	"bigbox": Vector2i(3, 2), "mcrate5": Vector2i(3, 3), "bigbox2": Vector2i(3, 3),
}
const _WOOD_CRATE := {"woodbox": true, "box": true}
const _CONTAINER := {
	"safe": Vector2i(2, 2), "wallsafe": Vector2i(1, 1), "chest": Vector2i(2, 1),
	"case": Vector2i(1, 1), "ammobox": Vector2i(1, 1), "explbox": Vector2i(1, 1),
	"bigexpl": Vector2i(3, 1), "weapbox": Vector2i(2, 2), "weapcase": Vector2i(3, 1),
	"bookcase": Vector2i(2, 3), "medbox": Vector2i(1, 1), "bigmed": Vector2i(2, 3),
	"instr1": Vector2i(2, 2), "instr2": Vector2i(2, 1), "table": Vector2i(2, 1),
	"wallcab": Vector2i(1, 1), "locker": Vector2i(2, 3), "trash": Vector2i(1, 1),
	"cup": Vector2i(2, 2), "tumba1": Vector2i(1, 1), "tumba2": Vector2i(1, 1),
	"filecab": Vector2i(1, 2), "fridge": Vector2i(1, 2), "ccup": Vector2i(1, 1),
	"wcup": Vector2i(1, 1), "tap": Vector2i(1, 1), "cryocap": Vector2i(2, 3),
	"basechest": Vector2i(2, 1), "enclchest": Vector2i(2, 1), "enclcase": Vector2i(3, 1),
}
const _UP := {"enl1": true, "enl2": true, "enf1": true, "enc1": true, "lov": true}
const _UNIT := {
	0: "zombie", 1: "raider", 2: "robot", 3: "slaver", 4: "merc", 5: "alicorn",
	6: "zebra", 7: "ranger", 8: "zombie", 9: "encl", 10: "hellhound", 11: "encl",
}

var _build: Dictionary = {}
var _zoom := 1.0
var _origin := Vector2.ZERO
var _fit := 1.0
var _moved := false
var _stick := 0.0
var _printed := false
var _tex: Dictionary = {}
var _flat_block: Dictionary = {}
var _flat_patch: Dictionary = {}
var _flat_beam: Dictionary = {}
var _flat_slope: Dictionary = {}
var _raider: Texture2D
var _protect: Texture2D
var _raider_cell := Vector2i(120, 120)
var _protect_cell := Vector2i(130, 130)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_on_resized)
	_load_sheets()
	hide()


func show_land(built: Dictionary) -> void:
	_build = built
	_moved = false
	_printed = false
	_flat_block.clear()
	_flat_patch.clear()
	_flat_beam.clear()
	_flat_slope.clear()
	_frame()
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if dir != Vector2.ZERO:
		_origin += dir * 720.0 * delta
		_moved = true
		queue_redraw()
	var axis := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if absf(axis) < 0.35:
		_stick = 0.0
		return
	_stick -= delta
	if _stick > 0.0:
		return
	_stick = 0.05
	var factor := 1.0 - axis * 0.12
	_zoom_at(size * 0.5, factor)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if not button.pressed:
			return
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(button.position, 1.12)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(button.position, 1.0 / 1.12)
			accept_event()


func _on_resized() -> void:
	if visible and not _moved:
		_frame()
		queue_redraw()


func _frame() -> void:
	var vp := size
	if vp.x < 8.0 or vp.y < 8.0:
		_zoom = 0.0
		return
	var span := _span()
	if span.x < 1.0 or span.y < 1.0:
		_zoom = 1.0
		_origin = Vector2.ZERO
		return
	var map_origin := Vector2(float(int(_build.get("min_x", 0))) * COLS, float(int(_build.get("min_y", 0))) * ROWS) * TILE
	_fit = minf((vp.x - 12.0) / span.x, (vp.y - 12.0) / span.y)
	_zoom = _fit
	_origin = (vp - span * _zoom) * 0.5 - map_origin * _zoom


func _zoom_at(screen_at: Vector2, factor: float) -> void:
	if _zoom <= 0.0:
		_frame()
	if _zoom <= 0.0:
		return
	var world := (screen_at - _origin) / _zoom
	var cap := maxf(_fit * 8.0, 2.0)
	_zoom = clampf(_zoom * factor, maxf(_fit * 0.35, 0.02), cap)
	_origin = screen_at - world * _zoom
	_moved = true
	queue_redraw()


func _span() -> Vector2:
	if _build.is_empty():
		return Vector2.ZERO
	var cells: Dictionary = _build.get("cells", {})
	if cells.is_empty():
		return Vector2.ZERO
	var w := maxi(int(_build.get("max_x", 1)) - int(_build.get("min_x", 0)), 1)
	var h := maxi(int(_build.get("max_y", 1)) - int(_build.get("min_y", 0)), 1)
	return Vector2(float(w) * COLS * TILE, float(h) * ROWS * TILE)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.025, 0.03))
	var cells: Dictionary = _build.get("cells", {})
	if cells.is_empty() or _zoom <= 0.0:
		_hud("No land is on screen.")
		return
	draw_set_transform(_origin, 0.0, Vector2(_zoom, _zoom))
	for key in cells.keys():
		_draw_room(cells[key])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_hud("Esc returns    wheel or right stick zooms    arrows pan")
	if not _printed:
		_printed = true
		print("LandPreview flat blocks: %s" % ", ".join(_names(_flat_block)))
		print("LandPreview flat patches: %s" % ", ".join(_names(_flat_patch)))
		print("LandPreview flat beams: %s" % ", ".join(_names(_flat_beam)))
		print("LandPreview flat slopes: %s" % ", ".join(_names(_flat_slope)))


func _draw_room(cell: Dictionary) -> void:
	var src := _room_src(cell)
	if src.is_empty():
		return
	var mirror := bool(cell.get("mirror", false))
	var rows: Array = src.get("rows", [])
	if mirror:
		rows = RoomFile.mirror_rows(rows)
	var objs: Array = src.get("objs", [])
	if mirror:
		objs = RoomFile.mirror_objs(objs)
	var options: Dictionary = src.get("options", {})
	var origin := Vector2(float(int(cell.get("x", 0))) * COLS, float(int(cell.get("y", 0))) * ROWS) * TILE
	var back_name := str(options.get("backwall", "tBackWall"))
	var back := _named(back_name)
	if back == null:
		back = _named("tBackWall")
	if back:
		_paint(back, Rect2(origin, Vector2(COLS, ROWS) * TILE))
	else:
		draw_rect(Rect2(origin, Vector2(COLS, ROWS) * TILE), Color(0.08, 0.08, 0.09))
	var open: Array = cell.get("open", [])
	var carved: Array = cell.get("carved", [])
	var grid: Array = []
	for y in ROWS:
		var parts := PackedStringArray()
		if y < rows.size():
			parts = str(rows[y]).split(".")
		var line: Array = []
		for x in COLS:
			var code := parts[x] if x < parts.size() else ""
			line.append(code)
		grid.append(line)
	# Back patches, then beams and slopes, then blocks. Same order as Grafon's bitmaps.
	for layer in 3:
		for y in ROWS:
			for x in COLS:
				_draw_tile(origin, grid, open, carved, x, y, layer)
	var water := int(cell.get("water", 100))
	if water < ROWS:
		var top := maxi(water, 0)
		draw_rect(Rect2(origin + Vector2(0.0, float(top) * TILE), Vector2(COLS * TILE, float(ROWS - top) * TILE)), Color(0.12, 0.4, 0.72, 0.28))
	for y in ROWS:
		for x in COLS:
			if _cell_flag(carved, x, y):
				continue
			_draw_ladder(origin, grid, x, y)
	for obj_v in objs:
		_draw_obj(origin, obj_v)
	var enemy := int(cell.get("enemy_type", -1))
	for obj_v in objs:
		_draw_enemy(origin, obj_v, enemy)
	for spot_v in cell.get("xp", []):
		var spot := _spot(spot_v)
		if spot.x < 0:
			continue
		var at := origin + Vector2(float(spot.x) + 0.5, float(spot.y) + 0.5) * TILE
		draw_circle(at, 11.0, Color(0.95, 0.82, 0.2, 0.95))
		draw_circle(at, 5.0, Color(1.0, 0.95, 0.7, 1.0))


func _draw_tile(origin: Vector2, grid: Array, open: Array, carved: Array, x: int, y: int, layer: int) -> void:
	if _cell_flag(carved, x, y):
		return
	var code := str(grid[y][x])
	var info := Catalog.decode(code)
	var cell := origin + Vector2(x, y) * TILE
	if layer == 0:
		if str(info.block) != "" and int(info.height) == 4:
			return
		var wall := str(info.wall)
		if wall == "":
			return
		var wall_tex := _named(wall)
		if wall_tex:
			_paint(wall_tex, Rect2(cell, Vector2(TILE, TILE)))
		else:
			var patch := str(info.patch)
			draw_rect(Rect2(cell, Vector2(TILE, TILE)), _swatch(patch if patch != "" else wall))
			if patch != "":
				_flat_patch[patch] = true
		return
	if layer == 1:
		for beam_v in info.beams:
			var beam := str(beam_v)
			var beam_tex := _named(Catalog.beam_texture(beam))
			if beam_tex:
				var bh := minf(float(beam_tex.get_height()), TILE)
				_paint(beam_tex, Rect2(cell, Vector2(TILE, bh)))
			else:
				draw_rect(Rect2(cell.x, cell.y, TILE, 8.0), _swatch(beam))
				_flat_beam[beam] = true
		var frame := int(info.slope_frame)
		if frame > 0:
			var step := _front(frame)
			if step:
				draw_texture(step, cell - Catalog.FRONT_ORIGIN)
			else:
				var side := str(info.slope_side)
				var points: PackedVector2Array
				if side == "left":
					points = PackedVector2Array([cell, cell + Vector2(0, TILE), cell + Vector2(TILE, TILE)])
				else:
					points = PackedVector2Array([cell + Vector2(0, TILE), cell + Vector2(TILE, TILE), cell + Vector2(TILE, 0)])
				draw_colored_polygon(points, _swatch(str(info.slope_code)))
				_flat_slope[str(info.slope_code)] = true
		return
	var block := str(info.block)
	if block != "":
		var rect := _solid_rect(cell, int(info.height))
		var tex := _named(str(info.texture))
		if tex:
			_paint(tex, rect)
		else:
			draw_rect(rect, _swatch(block))
			_flat_block[block] = true
		var top_name := str(info.top)
		if top_name != "":
			var above_open := y == 0 or _is_open_code(str(grid[y - 1][x])) or _cell_flag(carved, x, y - 1)
			if above_open:
				var lip := _named(top_name)
				if lip:
					var lip_h := minf(Catalog.FLOOR_LIP, rect.size.y)
					_paint(lip, Rect2(rect.position, Vector2(rect.size.x, lip_h)))
		return
	var walk := _cell_flag(open, x, y) if not open.is_empty() else true
	var bare := code.is_empty() or code == "_"
	if not walk and bare:
		var metal := _named("tMetal")
		if metal:
			_paint(metal, Rect2(cell, Vector2(TILE, TILE)))
		else:
			draw_rect(Rect2(cell, Vector2(TILE, TILE)), Color(0.35, 0.36, 0.38))


func _draw_ladder(origin: Vector2, grid: Array, x: int, y: int) -> void:
	var info: Dictionary = Catalog.decode(str(grid[y][x]))
	var frame := int(info.ladder_frame)
	if frame == 0:
		return
	var above := 0
	if y > 0:
		above = int(Catalog.decode(str(grid[y - 1][x])).ladder_frame)
	if above != frame:
		frame += 1
	var tex := _front(frame)
	if tex == null:
		return
	draw_texture(tex, origin + Vector2(x, y) * TILE - Catalog.FRONT_ORIGIN)


func _draw_obj(origin: Vector2, obj_v) -> void:
	if typeof(obj_v) != TYPE_DICTIONARY:
		return
	var obj: Dictionary = obj_v
	var id := str(obj.get("id", ""))
	var kind := str(obj.get("kind", ""))
	if kind == "up" or _UP.has(id):
		return
	var footprint := Vector2i.ZERO
	var fill := Color(0.72, 0.55, 0.22, 0.92)
	var crate := false
	if _is_door(id):
		footprint = _DOOR[id] if _DOOR.has(id) else Vector2i(maxi(int(obj.get("size", 1)), 1), 2 if not id.begins_with("hatch") else 1)
		fill = Color(0.45, 0.28, 0.14, 0.95) if _WOOD.has(id) or (id.begins_with("door1") and id != "door1b") else Color(0.62, 0.64, 0.66, 0.95)
	elif _CRATE.has(id):
		footprint = _CRATE[id]
		fill = Color(0.55, 0.36, 0.16, 0.95) if _WOOD_CRATE.has(id) else Color(0.48, 0.5, 0.52, 0.95)
		crate = true
	elif kind == "loot" or _CONTAINER.has(id):
		if _CONTAINER.has(id):
			footprint = _CONTAINER[id]
		else:
			footprint = Vector2i(maxi(int(obj.get("size", 1)), 1), 1)
	else:
		return
	var placed := maxi(int(obj.get("size", footprint.x)), 1)
	var width := float(footprint.x) * TILE
	var height := float(footprint.y) * TILE
	if id == "tap":
		height = 45.0
	elif id == "door2a":
		width = 40.0
	var left := origin.x + (float(int(obj.get("x", 0))) + float(placed) * 0.5) * TILE - width * 0.5
	var bottom := origin.y + float(int(obj.get("y", 0)) + 1) * TILE - 1.0
	var rect := Rect2(left, bottom - height, width, height)
	var art := _crate_texture(id) if crate else null
	if art:
		var aw := float(art.get_width())
		var ah := float(art.get_height())
		draw_texture(art, Vector2(left + width * 0.5 - aw * 0.5, bottom - ah))
	else:
		draw_rect(rect, fill)
		draw_rect(rect, fill.darkened(0.45), false, 2.0)
		if crate:
			draw_line(rect.position, rect.position + rect.size, Color(0.2, 0.16, 0.1), 2.0)
			draw_line(rect.position + Vector2(rect.size.x, 0), rect.position + Vector2(0, rect.size.y), Color(0.2, 0.16, 0.1), 2.0)
	if _is_door(id):
		if width > height * 1.15:
			draw_line(rect.position + Vector2(3, height * 0.5), rect.position + Vector2(width - 3, height * 0.5), Color(0.15, 0.1, 0.06), 2.0)
		else:
			draw_line(rect.position + Vector2(width * 0.5, 3), rect.position + Vector2(width * 0.5, height - 3), Color(0.15, 0.12, 0.1), 2.0)


func _draw_enemy(origin: Vector2, obj_v, enemy_type: int) -> void:
	if typeof(obj_v) != TYPE_DICTIONARY:
		return
	var obj: Dictionary = obj_v
	var id := str(obj.get("id", ""))
	if str(obj.get("kind", "")) != "up" and not _UP.has(id):
		return
	var label := id
	if enemy_type >= 0 and _UNIT.has(enemy_type) and id == "enl2":
		label = str(_UNIT[enemy_type])
	elif enemy_type >= 0 and _UNIT.has(enemy_type):
		label = "%s %s" % [id, str(_UNIT[enemy_type])]
	var placed := maxi(int(obj.get("size", 1)), 1)
	var foot := origin + Vector2((float(int(obj.get("x", 0))) + float(placed) * 0.5) * TILE, float(int(obj.get("y", 0)) + 1) * TILE)
	var sheet := _raider if label == "raider" else null
	var cell := _raider_cell
	if label == "robot" and _protect:
		sheet = _protect
		cell = _protect_cell
	if sheet:
		var frame := Vector2(cell)
		draw_texture_rect_region(sheet, Rect2(foot - Vector2(frame.x * 0.5, frame.y), frame), Rect2(Vector2.ZERO, frame))
	else:
		var body := Rect2(foot - Vector2(14, 40), Vector2(28, 40))
		draw_rect(body, Color(0.75, 0.22, 0.18, 0.95))
		draw_rect(body, Color(0.3, 0.05, 0.04), false, 2.0)
	_text(foot + Vector2(8, -6), label, 14, Color(1, 0.95, 0.85))


func _room_src(cell: Dictionary) -> Dictionary:
	var template = cell.get("template", null)
	if template != null:
		var src = template.src
		if src is Dictionary:
			return src
	var file_name := str(_build.get("file", ""))
	var want := str(cell.get("name", ""))
	if file_name == "" or want == "":
		return {}
	var doc := RoomFile.load_doc(file_name)
	for room_v in doc.get("rooms", []):
		var room: Dictionary = room_v
		if str(room.get("name", "")) == want:
			return room
	return {}


func _solid_rect(cell: Vector2, height: int) -> Rect2:
	var h := clampi(height, 1, 4)
	var top := float(4 - h) * (TILE / 4.0)
	return Rect2(cell + Vector2(0, top), Vector2(TILE, TILE - top))


func _is_open_code(code: String) -> bool:
	return RoomFile.is_open_code(code)


func _is_door(id: String) -> bool:
	if _DOOR.has(id):
		return true
	return id.begins_with("door") or id.begins_with("hatch")


func _cell_flag(grid: Array, x: int, y: int) -> bool:
	if y < 0 or x < 0 or y >= grid.size():
		return false
	var line: Array = grid[y]
	if x >= line.size():
		return false
	return bool(line[x])


func _spot(value) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(-1, -1)


func _paint(texture: Texture2D, dest: Rect2) -> void:
	if texture == null or dest.size.x < 0.5 or dest.size.y < 0.5:
		return
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
			draw_texture_rect_region(texture, Rect2(x, y, dw, dh), Rect2(src_x, src_y, dw, dh))
			x += dw
		y += dh


func _crate_texture(id: String) -> Texture2D:
	const paths := {
		"woodbox": "res://assets/sprites/props/woodbox.png",
		"box": "res://assets/sprites/props/box.png",
		"mcrate1": "res://assets/sprites/props/mcrate1.png",
		"mcrate2": "res://assets/sprites/props/mcrate2.png",
		"mcrate3": "res://assets/sprites/props/mcrate3.png",
		"mcrate4": "res://assets/sprites/props/mcrate4.png",
		"mcrate5": "res://assets/sprites/props/mcrate5.png",
		"bigbox": "res://assets/sprites/props/bigbox.png",
		"bigbox2": "res://assets/sprites/props/bigbox2.png",
	}
	var path := str(paths.get(id, ""))
	if path == "":
		return null
	if _tex.has(path):
		var cached = _tex[path]
		return cached if cached is Texture2D else null
	if not ResourceLoader.exists(path):
		_tex[path] = null
		return null
	var texture := load(path) as Texture2D
	_tex[path] = texture
	return texture


func _named(key: String) -> Texture2D:
	if key == "":
		return null
	if _tex.has(key):
		var cached = _tex[key]
		return cached if cached is Texture2D else null
	var path := Catalog.file_for(key)
	if path == "":
		_tex[key] = null
		return null
	var texture := load(path) as Texture2D
	_tex[key] = texture
	return texture


func _front(frame: int) -> Texture2D:
	var key := "front_%d" % frame
	if _tex.has(key):
		var cached = _tex[key]
		return cached if cached is Texture2D else null
	var path := Catalog.front_file(frame)
	if path == "":
		_tex[key] = null
		return null
	var texture := load(path) as Texture2D
	_tex[key] = texture
	return texture


func _swatch(letter: String) -> Color:
	var n := 0
	if letter.length() > 0:
		n = letter.unicode_at(0)
	return Color.from_hsv(fmod(float(n) * 0.137, 1.0), 0.42, 0.58)


func _load_sheets() -> void:
	_raider = _sheet("res://assets/sprites/sheets/raider.png")
	_protect = _sheet("res://assets/sprites/sheets/protect.png")
	if _raider:
		_raider_cell = _cell_of(_raider, 120)
	if _protect:
		_protect_cell = _cell_of(_protect, 140)


func _sheet(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _cell_of(texture: Texture2D, preferred: int) -> Vector2i:
	var w := texture.get_width()
	var h := texture.get_height()
	if preferred > 0 and w % preferred == 0 and h % preferred == 0:
		return Vector2i(preferred, preferred)
	for n in [120, 130, 140, 100]:
		if w % n == 0 and h % n == 0:
			return Vector2i(n, n)
	return Vector2i(mini(w, 120), mini(h, 120))


func _names(bucket: Dictionary) -> PackedStringArray:
	var names: Array = bucket.keys()
	names.sort()
	var out := PackedStringArray()
	for name in names:
		out.append(str(name))
	return out


func _text(at: Vector2, text: String, font_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	if font == null or text == "":
		return
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var ascent := font.get_ascent(font_size)
	draw_rect(Rect2(at - Vector2(2, ascent), text_size + Vector2(4, 4)), Color(0, 0, 0, 0.72))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _hud(text: String) -> void:
	_text(Vector2(16, 28), text, 16, Color(0.92, 0.9, 0.8))
