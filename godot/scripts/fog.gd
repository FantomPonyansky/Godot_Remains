extends Node2D

## Location.lighting / lighting2 with seamless rooms (a port deviation: the
## original lights only the active Location). Opacity and visibility are kept
## land-wide, one value per tile. Each lighting pass covers the room the eye is
## in plus a room-sized window centred on the eye, so light reaches into the
## next room through an open edge and stops at solid tiles like anywhere else.
## Tiles of missing rooms are opaque and never lit. Reach (lDist, visMult)
## comes from the room the eye is in.
## Grafon draws the bitmap at (-20, -60), scaled by 40, with smoothing; pixel
## (i, j + 1) is tile (i, j). All rooms of a land share one stitched bitmap.
## Opacity is TileRegistry.decode of the room codes, then Box.initDoor door spans.
## Wall cells call mark_dirty when they break. Doors near the eye are polled.
## Tiles that leave the pass window keep fading with each pass until dark.
##
## Layout memory (a port feature): the bitmap's red channel keeps the most a
## tile was ever lit. fog_memory.gdshader draws the scene under the fog at
## max(live, memory * MEM_LEVEL), greyer where only memory lights it. Rooms
## with @retdark keep no memory. fog_sight.gd does the same for things.

const RoomFile := preload("res://scripts/map/room_file.gd")
const Catalog := preload("res://scripts/map/tile_catalog.gd")
const FogSight := preload("res://scripts/fog_sight.gd")
const MEMORY_SHADER := preload("res://assets/shaders/fog_memory.gdshader")

const TILE := 40
const COLS := 48
const ROWS := 25
const MAX_X := COLS * TILE
const MAX_Y := ROWS * TILE
const INV_TILE := 1.0 / 40.0
const LDIST1 := 300
const LDIST2 := 1000
const TICK := 1.0 / 30.0
const MOVE_PX := 0.5
## Settings.json fogRegenerates (Location.retDark).
const FOG_RETURNS := true
## FOG_RETURNS for the current land; off in a camp.
var _returns := FOG_RETURNS
const FADE := 0.025
## Land.setGGToSpawnPoint lights from coordinates.Y - 75.
const SPAWN_LIFT := 75
const BEGIN_VISUAL := "res://assets/data/maps/begin_visual.json"
## Half of the eye-centred window, in tiles. Together it is one room in size.
const WIN_HALF_X := COLS / 2
const WIN_HALF_Y := ROWS / 2
const MEM_LEVEL := 0.4
const MEM_SATURATION := 0.55
## live values: 0 no room, 1 a room, 2 a room with @retdark, 3 a room with
## @noblack (Location.black off: always lit, never passed over).
const LIVE_DARK := 2
const LIVE_OPEN := 3
## Camp (Lands.xml tip base) solid: stays black, lighting never raises it.
## Open tiles of those lands are LIVE_OPEN (fully lit at any distance).
const LIVE_WALL := 4
const _Flags := preload("res://scripts/map/room_flags.gd")
const _Registry := preload("res://scripts/map/land_registry.gd")

## Lands.xml options vis (LandAct.visMult). A room's own @vis replaces it.
const LAND_VIS := {
	"surf": 10.0, "raiders": 10.0, "garages": 10.0, "random_mane": 2.0, "mtn": 2.0,
	"way": 10.0, "covert": 10.0, "src": 10.0, "hql": 10.0, "post": 10.0,
	"stable_pi_surf": 3.0, "thunder": 3.0, "grave": 10.0,
}

## objs.xml objects with a door attribute. Missing opac is Box.door_opac, 1.
const DOOR_OPAC := {
	"septum": 1.0, "platform1": 1.0, "door2": 1.0, "door2a": 1.0, "stdoor": 1.0,
	"basedoor": 1.0, "door3": 1.0, "hatch2": 1.0, "encldoor": 1.0,
	"door1": 0.8, "door1a": 0.8, "door1b": 0.8, "hatch1": 0.8,
	"door4": 0.3, "enclpole": 0.3,
	"window1": 0.2, "window2": 0.2,
	"grate": 0.1, "hgrate": 0.1, "alib1": 0.1, "alib2": 0.1,
}


class Room:
	var key := Vector2i.ZERO
	var ox := 0
	var oy := 0
	var dist1 := 300
	var dist2 := 1000
	var doors: Array = []


class LandFog:
	## Camp (Lands.xml tip base), port choice: seen tiles never fade and
	## fog_sight hides nothing.
	var camp := false
	var tiles_w := 1
	var tiles_h := 1
	var img_w := 1
	var img_h := 1
	var rooms := {}
	var door_tiles := {}
	## Per tile, land-wide: decoded opacity, current opacity, drawn and goal visibility.
	var base := PackedFloat64Array()
	var opac := PackedFloat64Array()
	var vis := PackedFloat64Array()
	var target := PackedFloat64Array()
	## 1 where a room exists, LIVE_DARK in an @retdark room, LIVE_OPEN in @noblack
	## or camp air, LIVE_WALL in a camp solid.
	var live := PackedByteArray()
	## Location.lighting opacWater: tile index -> the room's wopac under its water line.
	var wet := {}
	var has_open := false
	## Rows of the last lighting pass: row, first column, last column.
	var spans := PackedInt32Array()
	## Lit tiles outside the pass window, still fading; in_res marks them.
	var residual := PackedInt32Array()
	var in_res := PackedByteArray()
	## Tiles fog_sight.gd watches, and those whose visibility crossed its SEEN.
	var watch := PackedByteArray()
	var crossed := PackedInt32Array()
	var relight_t := 0
	var bytes := PackedByteArray()
	var image: Image
	var texture: ImageTexture
	var dirty := false
	## Minimap tile kinds (map_kinds), built on first PipBuck map open.
	var kinds := {}
	var kinds_built := false


var _lands := {}
var _state: LandFog
var _land: Node
var _room: Room
var _sprite: Sprite2D
var _player: Node2D
var _last_pos := Vector2.ZERO
var _acc := 0.0
var _force := false
var _relight_ticks := 0
var _pending: Array[Rect2] = []
## Land instance id -> fog data waiting for that land's state to be built.
var _restore := {}
var _sight: Node
## Union of this land's room rectangles. The bars paint everything in view outside it.
var _hole := Rect2()
var _bars: Array[ColorRect] = []


func _ready() -> void:
	name = "Fog"
	z_index = 20
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_to_group("fog")
	# The shader reads what is drawn under the fog; other screen readers
	# (horn magic) may have taken the screen copy earlier in the frame.
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(copy)
	_sprite = Sprite2D.new()
	var mat := ShaderMaterial.new()
	mat.shader = MEMORY_SHADER
	mat.set_shader_parameter("mem_level", MEM_LEVEL)
	mat.set_shader_parameter("mem_saturation", MEM_SATURATION)
	_sprite.material = mat
	# The shader ignores vertex colour. If it fails to compile (weak GPUs), the
	# plain draw stays black fog instead of showing the red memory channel.
	_sprite.self_modulate = Color(0, 0, 0, 1)
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.position = Vector2(-float(TILE) * 0.5, -float(TILE) * 1.5)
	_sprite.scale = Vector2(TILE, TILE)
	add_child(_sprite)
	_sight = FogSight.new(self)
	add_child(_sight)
	for _i in 4:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.z_as_relative = false
		bar.z_index = 80
		bar.visible = false
		add_child(bar)
		_bars.append(bar)
	_player = get_tree().get_first_node_in_group("player") as Node2D
	var land := get_parent().get_node_or_null("BeginLand") if get_parent() else null
	retarget(land)


## Switches to land's fog. A land seen before gets its rooms back as they were.
func retarget(land: Node) -> void:
	_pending.clear()
	_room = null
	_land = land
	if land == null:
		_state = null
		_sprite.texture = null
		_hole = Rect2()
		_layout_cover()
		_sight.attach(null)
		return
	_state = _state_of(land)
	_sprite.texture = _state.texture
	_hole = _rooms_bounds(_state)
	_returns = FOG_RETURNS and not _state.camp
	_sight.attach(null if _state.camp else land)
	if is_instance_valid(_player):
		_last_pos = _player.global_position
		if not WorldState.resuming():
			_spawn_light()
	_flush()
	_layout_cover()
	_after_pass()


## land_memory.gd: land's ghosts and things were replaced by a save.
func rewatch(land: Node) -> void:
	if land == _land and land != null and not (_state != null and _state.camp):
		_sight.attach(land)


func _state_of(land: Node) -> LandFog:
	var id := land.get_instance_id()
	if not _lands.has(id):
		_lands[id] = _build_land(land)
		if _restore.has(id):
			var saved: Array = _restore[id]
			_apply_explored(_lands[id], saved[0], saved[1])
			_restore.erase(id)
	return _lands[id]


## Live visibility per room, for saves: "x,y" -> base64 bytes, 0..255 per tile.
func capture_land(land: Node) -> Dictionary:
	return _capture(land, false)


## Layout memory per room, the same way. @retdark rooms have none.
func capture_memory(land: Node) -> Dictionary:
	return _capture(land, true)


func _capture(land: Node, memory: bool) -> Dictionary:
	if land == null or not _lands.has(land.get_instance_id()):
		return {}
	var state: LandFog = _lands[land.get_instance_id()]
	var out := {}
	for key in state.rooms:
		var room: Room = state.rooms[key]
		var cells := PackedByteArray()
		cells.resize(COLS * ROWS)
		var any := false
		for j in ROWS:
			var row := (room.oy + j) * state.tiles_w + room.ox
			var pix_row := (room.oy + j + 1) * state.img_w + room.ox
			for i in COLS:
				var v := 0
				if memory:
					v = state.bytes[(pix_row + i) * 4]
				else:
					v = clampi(int(round(state.vis[row + i] * 255.0)), 0, 255)
				cells[j * COLS + i] = v
				if v > 0:
					any = true
		if any:
			out["%d,%d" % [room.key.x, room.key.y]] = Marshalls.raw_to_base64(cells)
	return out


## A save's fog for land. Without memory (older saves) the saved visibility
## seeds it.
func restore_land(land: Node, data: Dictionary, memory: Dictionary = {}) -> void:
	if land == null or (data.is_empty() and memory.is_empty()):
		return
	var id := land.get_instance_id()
	if _lands.has(id):
		_apply_explored(_lands[id], data, memory)
		_flush_state(_lands[id])
	else:
		_restore[id] = [data, memory]


func _apply_explored(state: LandFog, data: Dictionary, memory: Dictionary) -> void:
	var vis := state.vis
	var target := state.target
	var bytes := state.bytes
	var residual := state.residual
	var in_res := state.in_res
	state.vis = PackedFloat64Array()
	state.target = PackedFloat64Array()
	state.bytes = PackedByteArray()
	state.residual = PackedInt32Array()
	state.in_res = PackedByteArray()
	for key_v in data:
		var room := _saved_room(state, key_v, data[key_v])
		if room == null:
			continue
		var cells := Marshalls.base64_to_raw(str(data[key_v]))
		for j in ROWS:
			var row := (room.oy + j) * state.tiles_w + room.ox
			var pix_row := (room.oy + j + 1) * state.img_w + room.ox
			for i in COLS:
				var b := cells[j * COLS + i]
				var v := float(b) / 255.0
				var p := (pix_row + i) * 4
				vis[row + i] = v
				target[row + i] = v
				bytes[p + 3] = clampi(int((1.0 - v) * 255.0), 0, 255)
				if v > 0.0 and in_res[row + i] == 0:
					in_res[row + i] = 1
					residual.append(row + i)
				if memory.is_empty() and state.live[row + i] == 1 and b > bytes[p]:
					bytes[p] = b
	for key_v in memory:
		var room := _saved_room(state, key_v, memory[key_v])
		if room == null:
			continue
		var cells := Marshalls.base64_to_raw(str(memory[key_v]))
		for j in ROWS:
			var row := (room.oy + j) * state.tiles_w + room.ox
			var pix_row := (room.oy + j + 1) * state.img_w + room.ox
			for i in COLS:
				if state.live[row + i] == 1:
					bytes[(pix_row + i) * 4] = cells[j * COLS + i]
	state.vis = vis
	state.target = target
	state.bytes = bytes
	state.residual = residual
	state.in_res = in_res
	_open_rooms(state)
	state.dirty = true


func _saved_room(state: LandFog, key: Variant, cells: Variant) -> Room:
	var parts := str(key).split(",")
	if parts.size() != 2:
		return null
	var room: Room = state.rooms.get(Vector2i(int(parts[0]), int(parts[1])))
	if room == null or Marshalls.base64_to_raw(str(cells)).size() != COLS * ROWS:
		return null
	return room


## Wall cells or anything else whose opacity changed inside rect (world px).
func mark_dirty(rect: Rect2) -> void:
	_pending.append(rect)


## Unit.getTileVisi reads the drawn visibility of the tile at a point.
## The cursor target needs at least 0.10.
func tile_visibility(world_pos: Vector2) -> float:
	if _state == null:
		return 0.0
	var i := floori(world_pos.x / TILE)
	var j := floori(world_pos.y / TILE)
	if i < 0 or j < 0 or i >= _state.tiles_w or j >= _state.tiles_h:
		return 0.0
	return _state.vis[j * _state.tiles_w + i]


## Tile.visibility as checkPort reads it: lit now or remembered from before.
func tile_seen(world_pos: Vector2) -> float:
	if _state == null:
		return 0.0
	var i := floori(world_pos.x / TILE)
	var j := floori(world_pos.y / TILE)
	if i < 0 or j < 0 or i >= _state.tiles_w or j >= _state.tiles_h:
		return 0.0
	var mem := float(_state.bytes[((j + 1) * _state.img_w + i) * 4]) / 255.0
	return maxf(_state.vis[j * _state.tiles_w + i], mem)


## Minimap.drawLevel input: per tile opacity, room kind, water and doors, and
## how lit each tile is or was (max of live visibility and layout memory).
func map_tiles() -> Dictionary:
	if _state == null:
		return {}
	var seen := PackedFloat32Array()
	seen.resize(_state.tiles_w * _state.tiles_h)
	for j in _state.tiles_h:
		for i in _state.tiles_w:
			var index := j * _state.tiles_w + i
			var mem := float(_state.bytes[((j + 1) * _state.img_w + i) * 4]) / 255.0
			seen[index] = maxf(_state.vis[index], mem)
	return {"w": _state.tiles_w, "h": _state.tiles_h, "base": _state.base, "live": _state.live,
		"wet": _state.wet, "doors": _state.door_tiles, "seen": seen, "kinds": map_kinds()}


## Minimap.drawRoom tile classes by index: "shelf" (platform or slope),
## "stair" (ladder), "white" (indestructible solid). Other tiles are absent.
func map_kinds() -> Dictionary:
	if _state == null:
		return {}
	if _state.kinds_built or _land == null:
		return _state.kinds
	_state.kinds_built = true
	var id := str(_land.get("land_id")) if _land.get("land_id") != null else ""
	if id == "":
		id = "begin"
	for room_v in _room_rows(_land, id):
		var src: Dictionary = room_v
		var ox := int(src.x) * COLS
		var oy := int(src.y) * ROWS
		if ox < 0 or oy < 0 or ox + COLS > _state.tiles_w or oy + ROWS > _state.tiles_h:
			continue
		var rows: Array = src.get("rows", [])
		for j in mini(ROWS, rows.size()):
			var parts := str(rows[j]).split(".")
			for i in mini(COLS, parts.size()):
				var code := parts[i]
				if code == "" or code == "_":
					continue
				var info := Catalog.decode(code)
				var kind := ""
				if not (info.beams as Array).is_empty() or str(info.slope_side) != "":
					kind = "shelf"
				if str(info.ladder_side) != "":
					kind = "stair"
				var block := str(info.block)
				if block != "" and str(info.slope_side) == "":
					kind = "white" if Catalog.WALL.has(block) and bool((Catalog.WALL[block] as Array)[3]) else ""
				if kind != "":
					_state.kinds[(oy + j) * _state.tiles_w + ox + i] = kind
	return _state.kinds


func _process(delta: float) -> void:
	_layout_cover()
	if GameState.paused or _state == null:
		return
	# A loaded save puts the player back a few frames in; sight from the
	# entrance meanwhile would wipe remembered ghosts there.
	if WorldState.resuming():
		_force = true
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return
		_last_pos = _player.global_position
		_force = true
	_acc += delta
	if _acc < TICK:
		return
	_acc -= TICK
	if _acc > TICK:
		_acc = 0.0
	if not _pending.is_empty():
		_apply_dirty()
	var moving := _moved()
	var eye := _eye()
	var room := _room_at(Vector2(eye))
	if room != _room:
		_room = room
		_force = true
	if room == null:
		_flush()
		return
	if _poll_doors(room):
		_force = true
	if _force or moving or _relight_ticks > 0:
		_force = false
		_relight_ticks = maxi(0, _relight_ticks - 1)
		_lighting(room, eye.x, eye.y)
	elif _state.relight_t > 0:
		_lighting2()
	_flush()
	_after_pass()


func _after_pass() -> void:
	if not _state.crossed.is_empty():
		var tiles := _state.crossed
		_state.crossed = PackedInt32Array()
		_sight.crossed(tiles)
	_sight.poll()


func _room_at(pos: Vector2) -> Room:
	return _state.rooms.get(Vector2i(floori(pos.x / MAX_X), floori(pos.y / MAX_Y)))


## Port: a teleport jumps without velocity, so lighting() runs as if moving
## until the old view has had time to fade (1 / FADE passes).
func relight_after_jump() -> void:
	_relight_ticks = ceili(1.0 / FADE)


## Location.step: lighting() when velocity + osnd tops 0.5 px a tick.
func _moved() -> bool:
	var pos := _player.global_position
	var dx := pos.x - _last_pos.x
	var dy := pos.y - _last_pos.y
	_last_pos = pos
	if absf(dx) > MOVE_PX or absf(dy) > MOVE_PX:
		return true
	var vel = _player.get("velocity")
	if vel is Vector2:
		var step := (vel as Vector2) * TICK
		return absf(step.x) > MOVE_PX or absf(step.y) > MOVE_PX
	return false


func _spawn_light() -> void:
	var pos := _player.global_position
	var room := _room_at(pos)
	_room = room
	if room == null:
		return
	_poll_doors(room)
	_lighting(room, int(pos.x), int(pos.y) - SPAWN_LIFT)


## gg.coordinates.X + storona.X * 12, boundingBox.top + int(height * 0.247), land px.
## An eye inside an opaque tile (ceiling, slope, jump) moves toward the body
## center until it is in an open tile, so the far side is not lit.
func _eye() -> Vector2i:
	var pos := _player.global_position
	var face := 1.0
	var facing = _player.get("facing")
	if facing != null:
		face = signf(float(facing)) if float(facing) != 0.0 else 1.0
	var height := 64.0
	var top := pos.y - height
	var shape_node := _player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node and shape_node.shape is RectangleShape2D:
		height = (shape_node.shape as RectangleShape2D).size.y
		top = pos.y + shape_node.position.y - height * 0.5
	var eye := Vector2i(int(pos.x + face * 12.0), int(top + float(int(height * 0.247))))
	if not _opaque(eye.x, eye.y):
		return eye
	var from := Vector2(eye)
	var center := Vector2(pos.x, top + height * 0.5)
	var steps := maxi(1, int(ceil(from.distance_to(center) / 4.0)))
	for k in range(1, steps + 1):
		var p := from.lerp(center, float(k) / float(steps))
		if not _opaque(int(p.x), int(p.y)):
			return Vector2i(int(p.x), int(p.y))
	return Vector2i(int(center.x), int(center.y))


func _opaque(x: int, y: int) -> bool:
	if x < 0 or y < 0:
		return false
	var i := int(x * INV_TILE)
	var j := int(y * INV_TILE)
	if i >= _state.tiles_w or j >= _state.tiles_h:
		return false
	return _state.opac[j * _state.tiles_w + i] > 0.0


## Rows of one pass: the eye's room, joined with a room-sized window around
## the eye. Both contain the eye column, so each row is one run.
func _window(room: Room, light_x: int, light_y: int) -> PackedInt32Array:
	var tw := _state.tiles_w
	var th := _state.tiles_h
	var ex := clampi(floori(float(light_x) / TILE), 0, tw - 1)
	var ey := clampi(floori(float(light_y) / TILE), 0, th - 1)
	var wx0 := maxi(0, ex - WIN_HALF_X)
	var wx1 := mini(tw - 1, ex + WIN_HALF_X - 1)
	var wy0 := maxi(0, ey - WIN_HALF_Y)
	var wy1 := mini(th - 1, ey + WIN_HALF_Y)
	var rx0 := room.ox
	var rx1 := mini(tw - 1, room.ox + COLS - 1)
	var ry0 := room.oy
	var ry1 := mini(th - 1, room.oy + ROWS - 1)
	var out := PackedInt32Array()
	for j in range(mini(wy0, ry0), maxi(wy1, ry1) + 1):
		var in_room := j >= ry0 and j <= ry1
		var in_win := j >= wy0 and j <= wy1
		var i0 := tw
		var i1 := -1
		if in_room:
			i0 = rx0
			i1 = rx1
		if in_win:
			i0 = mini(i0, wx0)
			i1 = maxi(i1, wx1)
		if i1 >= i0:
			out.append(j)
			out.append(i0)
			out.append(i1)
	return out


## Location.lighting over the pass window. One step is one tile along the
## longer axis; each sampled tile's opacity comes off, the target's too.
func _lighting(room: Room, light_x: int, light_y: int) -> void:
	_state.relight_t = 10
	light_x = clampi(light_x, 0, _state.tiles_w * TILE - 1)
	light_y = clampi(light_y, 0, _state.tiles_h * TILE - 1)
	var fx := float(light_x) * INV_TILE
	var fy := float(light_y) * INV_TILE
	var spans := _window(room, light_x, light_y)
	_leave_window(_state.spans, spans)
	_state.spans = spans
	var d1 := room.dist1 * room.dist1
	var d2 := room.dist2 * room.dist2
	var inv := 1.0 / float(d2 - d1)
	var opac := _state.opac
	var live := _state.live
	var watch := _state.watch
	# Taken out of the state while written, so the packed arrays are not copied on write.
	var vis := _state.vis
	var target := _state.target
	var bytes := _state.bytes
	var crossed := _state.crossed
	_state.vis = PackedFloat64Array()
	_state.target = PackedFloat64Array()
	_state.bytes = PackedByteArray()
	_state.crossed = PackedInt32Array()
	var img_w := _state.img_w
	var tw := _state.tiles_w
	var touched := false
	for s in range(0, spans.size(), 3):
		var j := spans[s]
		var row := j * tw
		var row_dy := j * TILE - light_y
		var row_dy2 := row_dy * row_dy
		var pix_row := (j + 1) * img_w
		for i in range(spans[s + 1], spans[s + 2] + 1):
			var index := row + i
			var kind := live[index]
			if kind == 0 or kind == LIVE_OPEN or kind == LIVE_WALL:
				continue
			var n1 := vis[index]
			if not _returns and n1 >= 1.0:
				continue
			var dx := i * TILE - light_x
			var dy := row_dy
			var rasst := dx * dx + row_dy2
			var goal := target[index]
			if rasst >= d2:
				if not _returns or goal <= 0.0:
					continue
				goal = maxf(goal - FADE, 0.0)
			else:
				var n2 := 1.0 if rasst <= d1 else float(d2 - rasst) * inv
				var cutoff := 0.0 if _returns else n1 + 0.01
				if n2 > cutoff:
					var adx := absi(dx)
					var ady := absi(dy)
					if adx == ady:
						dy += 1
						ady = absi(dy)
					var dex: float
					var dey: float
					var maxe: int
					if adx >= ady:
						if dx > 0:
							dex = TILE
							dey = float(dy) / float(dx) * TILE
						else:
							dex = -TILE
							dey = float(-dy) / float(dx) * TILE
						maxe = int(float(dx) / dex)
					else:
						if dy > 0:
							dey = TILE
							dex = float(dx) / float(dy) * TILE
						else:
							dey = -TILE
							dex = float(-dx) / float(dy) * TILE
						maxe = int(float(dy) / dey)
					# Tile units. The eye and the tile are both inside the land,
					# so every sample between them is too.
					var px := fx
					var py := fy
					var sx := dex * INV_TILE
					var sy := dey * INV_TILE
					for e in maxe:
						px += sx
						py += sy
						var o := opac[int(py) * tw + int(px)]
						if o > 0.0:
							n2 -= o
							if n2 <= cutoff:
								n2 = 0.0
								break
				if n2 > n1 + 0.01:
					goal = n2
				elif _returns and n2 < n1 - 0.01:
					goal = maxf(goal - FADE, n2)
				else:
					continue
			target[index] = goal
			# Tile.updVisi
			var v := n1 + 0.10
			if v > goal:
				v = goal
			vis[index] = v
			var p := (pix_row + i) * 4
			bytes[p + 3] = clampi(int((1.0 - v) * 255.0), 0, 255)
			if kind == 1:
				var m := int(v * 255.0)
				if m > bytes[p]:
					bytes[p] = m
			if watch[index] != 0 and (n1 >= FogSight.SEEN) != (v >= FogSight.SEEN):
				crossed.append(index)
			touched = true
	_state.vis = vis
	_state.target = target
	_state.bytes = bytes
	_state.crossed = crossed
	if _fade_residual(spans):
		touched = true
	if touched:
		_state.dirty = true


## Lit tiles of the last window that the new one leaves out start fading.
func _leave_window(old: PackedInt32Array, now: PackedInt32Array) -> void:
	if old.is_empty():
		return
	var tw := _state.tiles_w
	var target := _state.target
	var live := _state.live
	var in_res := _state.in_res
	var residual := _state.residual
	_state.in_res = PackedByteArray()
	_state.residual = PackedInt32Array()
	var first := now[0] if not now.is_empty() else 0
	var rows := now.size() / 3
	for s in range(0, old.size(), 3):
		var j := old[s]
		var a := old[s + 1]
		var b := old[s + 2]
		var k := j - first
		var c := tw
		var d := -1
		if k >= 0 and k < rows:
			c = now[k * 3 + 1]
			d = now[k * 3 + 2]
		var row := j * tw
		for i in range(a, mini(b, c - 1) + 1):
			if target[row + i] > 0.0 and in_res[row + i] == 0 and not _held(live[row + i]):
				in_res[row + i] = 1
				residual.append(row + i)
		for i in range(maxi(a, d + 1), b + 1):
			if target[row + i] > 0.0 and in_res[row + i] == 0 and not _held(live[row + i]):
				in_res[row + i] = 1
				residual.append(row + i)
	_state.in_res = in_res
	_state.residual = residual


## Tiles outside the window fade the way out-of-reach tiles in it do.
func _fade_residual(spans: PackedInt32Array) -> bool:
	if _state.residual.is_empty():
		return false
	if not _returns:
		_state.residual = PackedInt32Array()
		_state.in_res.fill(0)
		return false
	var tw := _state.tiles_w
	var img_w := _state.img_w
	var watch := _state.watch
	var in_res := _state.in_res
	var residual := _state.residual
	var vis := _state.vis
	var target := _state.target
	var bytes := _state.bytes
	var crossed := _state.crossed
	_state.in_res = PackedByteArray()
	_state.residual = PackedInt32Array()
	_state.vis = PackedFloat64Array()
	_state.target = PackedFloat64Array()
	_state.bytes = PackedByteArray()
	_state.crossed = PackedInt32Array()
	var first := spans[0] if not spans.is_empty() else 0
	var rows := spans.size() / 3
	var keep := PackedInt32Array()
	for index in residual:
		var j := index / tw
		var i := index - j * tw
		if _held(_state.live[index]):
			in_res[index] = 0
			continue
		var k := j - first
		if k >= 0 and k < rows and i >= spans[k * 3 + 1] and i <= spans[k * 3 + 2]:
			in_res[index] = 0
			continue
		var n1 := vis[index]
		var goal := maxf(target[index] - FADE, 0.0)
		target[index] = goal
		vis[index] = goal
		bytes[((j + 1) * img_w + i) * 4 + 3] = clampi(int((1.0 - goal) * 255.0), 0, 255)
		if watch[index] != 0 and (n1 >= FogSight.SEEN) != (goal >= FogSight.SEEN):
			crossed.append(index)
		if goal > 0.0:
			keep.append(index)
		else:
			in_res[index] = 0
	_state.in_res = in_res
	_state.residual = keep
	_state.vis = vis
	_state.target = target
	_state.bytes = bytes
	_state.crossed = crossed
	return true


## Location.lighting2 eases every tile of the last pass that is not at its target yet.
func _lighting2() -> void:
	_state.relight_t -= 1
	var spans := _state.spans
	var target := _state.target
	var vis := _state.vis
	var bytes := _state.bytes
	var crossed := _state.crossed
	var live := _state.live
	var watch := _state.watch
	_state.vis = PackedFloat64Array()
	_state.bytes = PackedByteArray()
	_state.crossed = PackedInt32Array()
	var img_w := _state.img_w
	var tw := _state.tiles_w
	var touched := false
	for s in range(0, spans.size(), 3):
		var j := spans[s]
		var row := j * tw
		var pix_row := (j + 1) * img_w
		for i in range(spans[s + 1], spans[s + 2] + 1):
			var index := row + i
			if _held(live[index]):
				continue
			var goal := target[index]
			var n1 := vis[index]
			if n1 == goal:
				continue
			var v := n1 + 0.10
			if v > goal:
				v = goal
			vis[index] = v
			var p := (pix_row + i) * 4
			bytes[p + 3] = clampi(int((1.0 - v) * 255.0), 0, 255)
			if live[index] == 1:
				var m := int(v * 255.0)
				if m > bytes[p]:
					bytes[p] = m
			if watch[index] != 0 and (n1 >= FogSight.SEEN) != (v >= FogSight.SEEN):
				crossed.append(index)
			touched = true
	_state.vis = vis
	_state.bytes = bytes
	_state.crossed = crossed
	if touched:
		_state.dirty = true


func _flush() -> void:
	if _state != null:
		_flush_state(_state)


func _flush_state(state: LandFog) -> void:
	if not state.dirty:
		return
	state.dirty = false
	state.image.set_data(state.img_w, state.img_h, false, Image.FORMAT_RGBA8, state.bytes)
	state.texture.update(state.image)


# --- opacity -------------------------------------------------------------

func _build_land(land: Node) -> LandFog:
	var state := LandFog.new()
	var map := Vector2(9600, 5000)
	if land.get("map_px") is Vector2:
		map = land.get("map_px")
	state.tiles_w = maxi(1, int(ceil(map.x / TILE)))
	state.tiles_h = maxi(1, int(ceil(map.y / TILE)))
	state.img_w = state.tiles_w + 1
	state.img_h = state.tiles_h + 2
	var image := Image.create(state.img_w, state.img_h, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 1))
	state.bytes = image.get_data()
	state.image = image
	state.texture = ImageTexture.create_from_image(image)
	var count := state.tiles_w * state.tiles_h
	var base := PackedFloat64Array()
	base.resize(count)
	base.fill(1.0)
	var live := PackedByteArray()
	live.resize(count)
	state.vis.resize(count)
	state.target.resize(count)
	state.in_res.resize(count)
	state.watch.resize(count)
	var id := str(land.get("land_id")) if land.get("land_id") != null else ""
	if id == "":
		id = "begin"
	var land_opts: Dictionary = _Registry.land(id).get("options", {})
	var land_vis := float(LAND_VIS.get(id, 1.0))
	if land_opts.has("vis") and str(land_opts.vis).is_valid_float():
		land_vis = float(str(land_opts.vis))
	var camp := str(_Registry.land(id).get("tip", "")) == "base"
	var envs := _Flags.envs(land)
	for room_v in _room_rows(land, id):
		var src: Dictionary = room_v
		var room := Room.new()
		room.key = Vector2i(int(src.x), int(src.y))
		room.ox = room.key.x * COLS
		room.oy = room.key.y * ROWS
		if room.ox < 0 or room.oy < 0 or room.ox + COLS > state.tiles_w or room.oy + ROWS > state.tiles_h:
			continue
		_set_reach(room, land_vis, src.get("options", {}))
		var env: Dictionary = envs.get(room.key, {})
		var kind := LIVE_DARK if _ret_dark(src.get("options", {})) else 1
		# Location.black off (@noblack, and not alwaysFogOfWar there).
		if not bool(env.get("black", true)):
			kind = LIVE_OPEN
			state.has_open = true
		var wmask: PackedByteArray = env.get("wmask", PackedByteArray())
		var wopac := float(env.get("wopac", 0.0)) if not wmask.is_empty() else 0.0
		var rows: Array = src.get("rows", [])
		for j in ROWS:
			var parts := str(rows[j]).split(".") if j < rows.size() else PackedStringArray()
			var row := (room.oy + j) * state.tiles_w + room.ox
			for i in COLS:
				var code_o := _code_opacity(parts[i]) if i < parts.size() else 0.0
				var o := code_o
				if wopac > 0.0 and wmask[j * COLS + i] == 1:
					state.wet[row + i] = wopac
					o = maxf(o, wopac)
				base[row + i] = o
				live[row + i] = kind
		state.rooms[room.key] = room
	state.camp = camp
	state.base = base
	state.live = live
	_air_opacity(land, state)
	state.opac = base.duplicate()
	_open_rooms(state)
	_bind_doors(land, state)
	return state


## Area tileop (RoomFlags.set_air_opacity): Tile.opacity of tiles without collision.
func _air_opacity(land: Node, state: LandFog) -> void:
	var air: Dictionary = land.get_meta(_Flags.META_OP, {})
	for cell_v in air:
		var cell: Vector2i = cell_v
		if cell.x < 0 or cell.y < 0 or cell.x >= state.tiles_w or cell.y >= state.tiles_h:
			continue
		var index := cell.y * state.tiles_w + cell.x
		if state.base[index] > float(state.wet.get(index, 0.0)):
			continue
		state.base[index] = float(air[cell])
		state.wet[index] = float(air[cell])
		if state.opac.size() == state.base.size():
			state.opac[index] = float(air[cell])


## Location.recalcWater filled (1) or drained (0) tiles of a land: cells are
## Vector3i (tile x, tile y, water); the room's opacWater follows them.
func water_changed(land: Node, cells: Array, wopac: float) -> void:
	var id := land.get_instance_id()
	if wopac <= 0.0 or not _lands.has(id):
		return
	var state: LandFog = _lands[id]
	for c_v in cells:
		var c: Vector3i = c_v
		if c.x < 0 or c.y < 0 or c.x >= state.tiles_w or c.y >= state.tiles_h:
			continue
		var index := c.y * state.tiles_w + c.x
		if c.z == 1:
			state.wet[index] = wopac
		else:
			state.wet.erase(index)
		if state == _state:
			mark_dirty(Rect2(c.x * TILE, c.y * TILE, TILE, TILE))


## A land's tileop cells changed after its fog was built.
func air_opacity_changed(land: Node) -> void:
	var id := land.get_instance_id()
	if not _lands.has(id):
		return
	var state: LandFog = _lands[id]
	_air_opacity(land, state)
	if state == _state:
		_force = true


## @noblack rooms: every tile fully seen, and the lighting passes skip them.
func _open_rooms(state: LandFog) -> void:
	if not state.has_open:
		return
	var live := state.live
	var vis := state.vis
	var target := state.target
	var bytes := state.bytes
	state.vis = PackedFloat64Array()
	state.target = PackedFloat64Array()
	state.bytes = PackedByteArray()
	for index in live.size():
		var kind := live[index]
		if kind != LIVE_OPEN and kind != LIVE_WALL:
			continue
		var shown := 1.0 if kind == LIVE_OPEN else 0.0
		vis[index] = shown
		target[index] = shown
		var j := index / state.tiles_w
		var p := ((j + 1) * state.img_w + index - j * state.tiles_w) * 4
		bytes[p + 3] = 0 if kind == LIVE_OPEN else 255
		bytes[p] = 255 if kind == LIVE_OPEN else 0
	state.vis = vis
	state.target = target
	state.bytes = bytes
	# The texture was created from the opaque fill, before these bytes changed.
	# Lighting never writes LIVE_OPEN tiles, so without this the GPU image stays black.
	state.dirty = true


## Camp air and @noblack stay at the visibility they were given.
func _held(kind: int) -> bool:
	return kind == LIVE_OPEN or kind == LIVE_WALL


func _rooms_bounds(state: LandFog) -> Rect2:
	var hole := Rect2()
	var any := false
	for key in state.rooms:
		var room: Room = state.rooms[key]
		var rect := Rect2(room.ox * TILE, room.oy * TILE, MAX_X, MAX_Y)
		hole = rect if not any else hole.merge(rect)
		any = true
	return hole


## Camera.setZoom ram frames: the view past the location is black. The fog
## sprite only covers the room grid, so a zoomed-out camera would show the
## backdrop beside it. These bars cover that margin, above world sprites.
func _layout_cover() -> void:
	if _bars.is_empty():
		return
	var view := _view_rect()
	if _state == null or view.size.x <= 1.0:
		for bar in _bars:
			bar.visible = false
		return
	var hole := _hole
	if hole.size.x <= 1.0 or hole.size.y <= 1.0:
		_place_bar(0, view)
		for i in range(1, 4):
			_bars[i].visible = false
		return
	var x0 := view.position.x
	var y0 := view.position.y
	var x1 := view.end.x
	var y1 := view.end.y
	_place_bar(0, Rect2(x0, y0, minf(hole.position.x, x1) - x0, y1 - y0))
	_place_bar(1, Rect2(maxf(hole.end.x, x0), y0, x1 - maxf(hole.end.x, x0), y1 - y0))
	_place_bar(2, Rect2(x0, y0, x1 - x0, minf(hole.position.y, y1) - y0))
	_place_bar(3, Rect2(x0, maxf(hole.end.y, y0), x1 - x0, y1 - maxf(hole.end.y, y0)))


func _place_bar(index: int, rect: Rect2) -> void:
	var bar := _bars[index]
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		bar.visible = false
		return
	bar.visible = true
	bar.position = rect.position
	bar.size = rect.size


func _view_rect() -> Rect2:
	var viewport := get_viewport()
	if viewport == null:
		return Rect2()
	var cam := viewport.get_camera_2d()
	if cam == null or cam.zoom.x == 0.0 or cam.zoom.y == 0.0:
		return Rect2()
	var size := viewport.get_visible_rect().size / cam.zoom
	return Rect2(cam.get_screen_center_position() - size * 0.5, size).grow(TILE)


## Room option retdark: the fog comes back there and nothing is remembered.
func _ret_dark(options: Variant) -> bool:
	if not options is Dictionary or not (options as Dictionary).has("retdark"):
		return false
	var raw := str((options as Dictionary).retdark)
	return raw != "" and raw != "0" and raw != "false"


## Location: lDist *= visMult. A non-number @vis is NaN there, which resets 300/1000.
func _set_reach(room: Room, land_vis: float, options: Variant) -> void:
	var mult := land_vis
	if options is Dictionary and (options as Dictionary).has("vis"):
		var raw := str((options as Dictionary).vis)
		mult = raw.to_float() if raw.is_valid_float() else NAN
	if is_nan(mult):
		room.dist1 = LDIST1
		room.dist2 = LDIST2
		return
	room.dist1 = int(LDIST1 * mult)
	room.dist2 = int(LDIST2 * mult)


func _room_rows(land: Node, id: String) -> Array:
	var actors := land.get_node_or_null("Actors")
	if actors:
		var bound: Variant = actors.get("_bound_rooms")
		if bound is Array and not (bound as Array).is_empty():
			return bound
	if id != "begin":
		return []
	return begin_rooms()


## rooms_begin z=0 rooms with their tile rows (begin_visual.json) and options.
static func begin_rooms() -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BEGIN_VISUAL))
	if not parsed is Dictionary:
		return []
	var options := {}
	for src_v in RoomFile.load_doc("rooms_begin").get("rooms", []):
		var src: Dictionary = src_v
		if src.has("x") and src.has("y") and int(src.get("z", 0)) == 0:
			options[Vector2i(int(src.x), int(src.y))] = src.get("options", {})
	var out: Array = []
	for room_v in (parsed as Dictionary).get("rooms", []):
		var room: Dictionary = room_v
		if int(room.get("z", 0)) != 0:
			continue
		out.append({
			"x": int(room.get("x", 0)),
			"y": int(room.get("y", 0)),
			"rows": room.get("rows", []),
			"options": options.get(Vector2i(int(room.get("x", 0)), int(room.get("y", 0))), {}),
		})
	return out


## TileRegistry.decode: a solid block is opacity 1, a height mark (, ; :) sets 0,
## and any later piece on a solid tile sets it back to 1.
func _code_opacity(code: String) -> float:
	if code.is_empty():
		return 0.0
	var head := code.substr(0, 1)
	var solid := head != "_" and head.unicode_at(0) > 64 and Catalog.BLOCK.has(head)
	var opac := 1.0 if solid else 0.0
	for n in range(1, code.length()):
		var ch := code.substr(n, 1)
		if ch == "," or ch == ";" or ch == ":":
			opac = 0.0
		elif solid and Catalog.OVERLAY.has(ch):
			opac = 1.0
	return opac


## Box.initDoor: tiles int(left / 40 + 0.5) .. int(right / 40 - 0.5), same for y.
func _bind_doors(land: Node, state: LandFog) -> void:
	var doors := land.get_node_or_null("Doors")
	if doors == null:
		return
	for body in doors.get_children():
		if not body is Node2D:
			continue
		var id := str(body.get_meta("door_id", ""))
		if not DOOR_OPAC.has(id):
			continue
		var rect := _body_rect(body as Node2D)
		if rect.size.x < 1.0 or rect.size.y < 1.0:
			continue
		var tiles := PackedInt32Array()
		var keys := {}
		for j in range(int(rect.position.y / TILE + 0.5), int(rect.end.y / TILE - 0.5) + 1):
			for i in range(int(rect.position.x / TILE + 0.5), int(rect.end.x / TILE - 0.5) + 1):
				if i < 0 or j < 0 or i >= state.tiles_w or j >= state.tiles_h:
					continue
				var index := j * state.tiles_w + i
				if state.live[index] == 0:
					continue
				tiles.append(index)
				keys[Vector2i(i / COLS, j / ROWS)] = true
				state.door_tiles[index] = true
		if tiles.is_empty():
			continue
		var entry := {"body": body, "opac": float(DOOR_OPAC[id]), "tiles": tiles, "now": -1.0}
		for key in keys:
			(state.rooms[key] as Room).doors.append(entry)
		_door_apply(state, entry)


## Box.setDoor and Box.die: an open or broken door is 0, a shut one door_opac.
func _door_apply(state: LandFog, entry: Dictionary) -> bool:
	var body: Node = entry.body
	var now := 0.0
	if is_instance_valid(body):
		now = _door_opacity(body, float(entry.opac))
	if now == float(entry.now):
		return false
	entry.now = now
	var opac := state.opac
	state.opac = PackedFloat64Array()
	var tiles: PackedInt32Array = entry.tiles
	for index in tiles:
		opac[index] = now
	state.opac = opac
	return true


## Doors of the eye's room and the rooms around it, where the pass can reach.
func _poll_doors(room: Room) -> bool:
	var changed := false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var near: Room = _state.rooms.get(room.key + Vector2i(dx, dy))
			if near == null:
				continue
			for entry in near.doors:
				if _door_apply(_state, entry):
					changed = true
	return changed


func _door_opacity(body: Node, closed: float) -> float:
	if bool(body.get_meta("dead", false)) or bool(body.get_meta("door_open", false)):
		return 0.0
	if bool(body.get_meta("breakable", false)) and int(body.get_meta("hp", 1)) <= 0:
		return 0.0
	if body is CollisionObject2D and (body as CollisionObject2D).collision_layer == 0:
		return 0.0
	var shape := _rect_shape(body)
	if shape and shape.disabled:
		return 0.0
	return closed


## A broken wall cell is Tile.die: opacity 0. Tiles in the dirty rects keep
## their decoded opacity only while a live wall cell still covers them.
func _apply_dirty() -> void:
	var rects := _pending.duplicate()
	_pending.clear()
	if _state == null or _land == null or not is_instance_valid(_land):
		return
	var walls: Array = []
	var solids := _land.get_node_or_null("Solids")
	if solids:
		for child in solids.get_children():
			if not child is Node2D or bool(child.get_meta("dead", false)):
				continue
			if child is CollisionObject2D and (child as CollisionObject2D).collision_layer == 0:
				continue
			var rect := _body_rect(child as Node2D)
			if rect.size.x >= 1.0 and rect.size.y >= 1.0:
				walls.append([child, rect])
	var tw := _state.tiles_w
	var changed := false
	var cells := _state.opac
	_state.opac = PackedFloat64Array()
	for dirty_v in rects:
		var dirty: Rect2 = dirty_v
		for j in range(floori(dirty.position.y / TILE), floori((dirty.end.y - 0.01) / TILE) + 1):
			for i in range(floori(dirty.position.x / TILE), floori((dirty.end.x - 0.01) / TILE) + 1):
				if i < 0 or j < 0 or i >= tw or j >= _state.tiles_h:
					continue
				var index := j * tw + i
				if _state.door_tiles.has(index) or _state.live[index] == 0:
					continue
				var tile := Rect2(i * TILE, j * TILE, TILE, TILE)
				var opac := _state.base[index] if _covered(walls, tile) else float(_state.wet.get(index, 0.0))
				if cells[index] != opac:
					cells[index] = opac
					changed = true
	_state.opac = cells
	if changed:
		_force = true


func _covered(walls: Array, tile: Rect2) -> bool:
	for pair in walls:
		var rect: Rect2 = pair[1]
		var overlap := rect.intersection(tile)
		if overlap.size.x < 1.0 or overlap.size.y < 1.0:
			continue
		var body: Node = pair[0]
		var alive: Variant = body.get("_alive")
		if alive is Array and int(body.get("_cols")) > 0:
			if _cell_alive(body, overlap.get_center()):
				return true
			continue
		if body.has_meta("blocks_sight") and not bool(body.get_meta("blocks_sight")) and not body.has_meta("code"):
			continue
		return true
	return false


func _cell_alive(body: Node, at: Vector2) -> bool:
	var alive: Array = body.get("_alive")
	var cw: Array = body.get("_cw")
	var ch: Array = body.get("_ch")
	var origin: Vector2 = body.get("_origin")
	var cols := cw.size()
	var cx := 0
	var x := origin.x
	while cx < cols - 1 and at.x >= x + float(cw[cx]):
		x += float(cw[cx])
		cx += 1
	var cy := 0
	var y := origin.y
	while cy < ch.size() - 1 and at.y >= y + float(ch[cy]):
		y += float(ch[cy])
		cy += 1
	var i := cy * cols + cx
	return i < alive.size() and bool(alive[i])


func _body_rect(body: Node2D) -> Rect2:
	var shape := _rect_shape(body)
	if shape == null:
		return Rect2()
	var size := (shape.shape as RectangleShape2D).size
	return Rect2(body.to_global(shape.position - size * 0.5), size)


func _rect_shape(body: Node) -> CollisionShape2D:
	for child in body.get_children():
		if child is CollisionShape2D and (child as CollisionShape2D).shape is RectangleShape2D:
			return child as CollisionShape2D
	return null
