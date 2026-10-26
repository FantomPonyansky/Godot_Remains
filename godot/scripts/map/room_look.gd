extends RefCounted

## Grafon per-room looks from the room options (RoomFlags rows):
## - dark: colorBmp is black at alpha 0xAA + darkness over the back layer, so
##   the room's back layer is scaled by (1 - a) / (1 - 0xAA / 255) on top of
##   back_decor's DIM;
## - backform: drawBackWall sposob (0 all, 1 sides, 2 bottom, 3 last row);
## - water: tileVoda on the water tiles (RoomFlags wmask; frame tipWater + 1,
##   the surface frame where the tile above is open), on visVoda at alpha 0.6;
## - color: cTransform multipliers over everything under the fog.

const TILE := 40.0
const COLS := 48
const ROWS := 25
const WATER_Z := 15
const TINT_Z := 19
const WATER_ALPHA := 0.6
const BASE_DARK := 0xAA
const TINT_SHADER := preload("res://assets/shaders/room_tint.gdshader")
const _Catalog := preload("res://scripts/map/tile_catalog.gd")
const _Flags := preload("res://scripts/map/room_flags.gd")


## The back layer this room paints into: dim itself, or a child scaled for @dark.
static func dim_for(dim: Node2D, env: Dictionary, rx: int, ry: int) -> Node2D:
	var dark := int(env.get("dark", 0))
	if dark == 0:
		return dim
	var node := Node2D.new()
	node.name = "Dim_%d_%d" % [rx, ry]
	var k := dark_scale(dark)
	node.modulate = Color(k, k, k, 1.0)
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dim.add_child(node)
	return node


static func dark_scale(dark: int) -> float:
	var a := clampf(float(BASE_DARK + dark) / 255.0, 0.0, 1.0)
	return (1.0 - a) / (1.0 - float(BASE_DARK) / 255.0)


## drawBackWall sposob rects in room pixels.
static func backwall_rects(form: int) -> Array:
	var w := COLS * TILE
	var h := ROWS * TILE
	match form:
		1:
			var left := 11.0 * TILE - 10.0
			var right := 37.0 * TILE + 10.0
			return [Rect2(0, 0, left, h), Rect2(right, 0, w - right, h)]
		2:
			var y2 := 16.0 * TILE + 10.0
			return [Rect2(0, y2, w, h - y2)]
		3:
			var y3 := 24.0 * TILE + 10.0
			return [Rect2(0, y3, w, h - y3)]
	return [Rect2(0, 0, w, h)]


## Water and colour layers of the land.
static func build(land: Node2D, rooms: Array, envs: Dictionary) -> void:
	var water_root: Node2D = null
	var tint_root: Node2D = null
	var cells := {}
	for room_v in rooms:
		var r: Dictionary = room_v
		var cell := Vector2i(int(r.x), int(r.y))
		var c := str((envs.get(cell, {}) as Dictionary).get("color", ""))
		cells[cell] = _Flags.COLORS[c] if _Flags.COLORS.has(c) else Color(1, 1, 1)
	land.set_meta("room_mults", cells)
	for room_v in rooms:
		var room: Dictionary = room_v
		var key := Vector2i(int(room.x), int(room.y))
		var env: Dictionary = envs.get(key, {})
		if env.is_empty():
			continue
		var origin := Vector2(key.x * COLS, key.y * ROWS) * TILE
		var wmask: PackedByteArray = env.get("wmask", PackedByteArray())
		if not wmask.is_empty():
			if water_root == null:
				water_root = _water_root(land)
			_water(water_root, room, origin, wmask, int(env.get("wtip", 0)))
		var color := str(env.get("color", ""))
		if color != "" and _Flags.COLORS.has(color):
			if tint_root == null:
				tint_root = Node2D.new()
				tint_root.name = "RoomTint"
				tint_root.z_index = TINT_Z
				land.add_child(tint_root)
			_tint(tint_root, key, cells)


static func _water_root(land: Node2D) -> Node2D:
	var root := land.get_node_or_null("Water") as Node2D
	if root != null:
		return root
	root = Node2D.new()
	root.name = "Water"
	root.z_index = WATER_Z
	root.modulate = Color(1, 1, 1, WATER_ALPHA)
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	land.add_child(root)
	return root


## Grafon.drawWater after the room's water tiles changed (WaterFlow).
static func redraw_water(land: Node2D, cell: Vector2i, env: Dictionary) -> void:
	var root := _water_root(land)
	for child in root.get_children():
		if child.get_meta("room", Vector2i(-9999, -9999)) == cell:
			child.queue_free()
	var mask: PackedByteArray = env.get("wmask", PackedByteArray())
	if not mask.is_empty():
		_water(root, {"rows": env.get("rows", [])}, Vector2(cell.x * COLS, cell.y * ROWS) * TILE, mask, int(env.get("wtip", 0)))


## Grafon tileVoda on every water tile; the surface frame where the tile above
## is neither water nor solid. Runs of a row share one strip.
static func _water(root: Node2D, room: Dictionary, origin: Vector2, mask: PackedByteArray, tip: int) -> void:
	var cell := Vector2i(roundi(origin.x / (COLS * TILE)), roundi(origin.y / (ROWS * TILE)))
	var body := load("res://assets/sprites/water/water%d_body.png" % clampi(tip, 0, 2)) as Texture2D
	var top := load("res://assets/sprites/water/water%d_top.png" % clampi(tip, 0, 2)) as Texture2D
	if body == null or top == null:
		return
	var rows: Array = room.get("rows", [])
	for j in ROWS:
		var above := str(rows[j - 1]).split(".") if j > 0 and j - 1 < rows.size() else PackedStringArray()
		var run_start := -1
		var run_top := false
		for i in COLS + 1:
			var wet := i < COLS and mask[j * COLS + i] == 1
			var is_top := false
			if wet and j > 0 and mask[(j - 1) * COLS + i] == 0:
				is_top = i >= above.size() or str(_Catalog.decode(above[i]).block) == ""
			if run_start >= 0 and (not wet or is_top != run_top):
				var strip := Sprite2D.new()
				strip.texture = top if run_top else body
				strip.centered = false
				strip.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
				strip.region_enabled = true
				strip.position = origin + Vector2(run_start * TILE, j * TILE)
				strip.region_rect = Rect2(0, 0, (i - run_start) * TILE, TILE)
				strip.set_meta("room", cell)
				root.add_child(strip)
				run_start = -1
			if wet and run_start < 0:
				run_start = i
				run_top = is_top


## Location.cTransform changed at run time (allon / alloff): the room's colour
## layer is replaced by this colour filter.
static func retint(land: Node2D, cell: Vector2i, color: String) -> void:
	if land == null:
		return
	var root := land.get_node_or_null("RoomTint") as Node2D
	if root == null:
		root = Node2D.new()
		root.name = "RoomTint"
		root.z_index = TINT_Z
		land.add_child(root)
	var cells: Dictionary = land.get_meta("room_mults", {})
	cells[cell] = _Flags.COLORS[color] if _Flags.COLORS.has(color) else Color(1, 1, 1)
	land.set_meta("room_mults", cells)
	# The neighbours' edges ease toward this room, so they are redone too.
	var redo: Array[Vector2i] = [cell, cell + Vector2i.LEFT, cell + Vector2i.RIGHT, cell + Vector2i.UP, cell + Vector2i.DOWN]
	for child in root.get_children():
		if child.has_meta("cell") and redo.has(child.get_meta("cell")):
			child.queue_free()
	for c in redo:
		if cells.has(c) and cells[c] != Color(1, 1, 1):
			_tint(root, c, cells)


## Feather of the colour filter across a room edge.
const TINT_FEATHER := 120.0


static func _tint(root: Node2D, cell: Vector2i, cells: Dictionary) -> void:
	var mult: Color = cells[cell]
	var size := Vector2(COLS, ROWS) * TILE
	var sides := [Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN]
	var ext := [0.0, 0.0, 0.0, 0.0]
	var near: Array[Vector3] = []
	for i in 4:
		var other: Vector2i = cell + sides[i]
		var m: Color = cells.get(other, mult)
		near.append(Vector3(m.r, m.g, m.b))
		# An unfiltered neighbour has no rect of its own, so this one reaches over it.
		if cells.has(other) and m == Color(1, 1, 1):
			ext[i] = TINT_FEATHER
	var origin := Vector2(cell.x * COLS, cell.y * ROWS) * TILE - Vector2(ext[0], ext[1])
	var full := size + Vector2(ext[0] + ext[2], ext[1] + ext[3])
	# One viewport copy under all the rects: they never overlap, and a per-room
	# rect copy that is partly off screen leaves stale back buffer under the rect.
	if root.get_node_or_null("Copy") == null:
		var copy := BackBufferCopy.new()
		copy.name = "Copy"
		copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		root.add_child(copy)
		root.move_child(copy, 0)
	var rect := ColorRect.new()
	rect.position = origin
	rect.size = full
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_meta("cell", cell)
	var mat := ShaderMaterial.new()
	mat.shader = TINT_SHADER
	mat.set_shader_parameter("mult", Vector3(mult.r, mult.g, mult.b))
	mat.set_shader_parameter("room_size", size)
	mat.set_shader_parameter("ext", Vector4(ext[0], ext[1], ext[2], ext[3]))
	mat.set_shader_parameter("n_left", near[0])
	mat.set_shader_parameter("n_top", near[1])
	mat.set_shader_parameter("n_right", near[2])
	mat.set_shader_parameter("n_bottom", near[3])
	mat.set_shader_parameter("feather", TINT_FEATHER)
	rect.material = mat
	root.add_child(rect)
