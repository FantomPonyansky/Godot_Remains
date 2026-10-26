extends Control

## PipPageInfo local map (page2 1). visPipMap sits at page 12,75; Minimap.drawLevel
## paints one pixel per tile of the visited rooms, alpha by how lit the tile is,
## with containers, checkpoints and NPCs marked, scaled by mapScale (1..6).
## Mouse: drag pans, the wheel zooms at the cursor. Pad: the right stick pans,
## the triggers zoom, A centres on the player.
## Port: wall, door and water colours come from the fog's opacity grid, so
## ladders and platforms are not told apart.

const AT := Vector2(12, 75)
const FRAME := Vector2(560, 560)
const TILE := 40.0
const COLOR_EMPTY := Color8(0x00, 0x33, 0x23)
const COLOR_WALL := Color8(0x00, 0xFF, 0x99)
const COLOR_DOOR := Color8(0x63, 0x91, 0x04)
const COLOR_WATER := Color8(0x00, 0x66, 0xFF)
const COLOR_DAMAGED := Color8(0x01, 0x99, 0x5A)
const COLOR_CONTAINER := Color8(0xFF, 0xCC, 0x00)
const COLOR_CHECKPOINT := Color8(0xFF, 0x00, 0xFF)
const COLOR_NPC := Color8(0x55, 0x00, 0xFF)
const PAN_SPEED := 600.0

static var map_scale := 3

var _tex: ImageTexture
var _size := Vector2i.ZERO
var _offset := Vector2.ZERO
var _player_px := Vector2.ZERO
var _drag := false
var _blink := 0.0
var _trig_held := 0


func _ready() -> void:
	position += AT
	size = FRAME
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	center()


func has_map() -> bool:
	return _tex != null


func center() -> void:
	_offset = FRAME * 0.5 - _player_px * map_scale
	queue_redraw()


func _build() -> void:
	var fog: Node = get_tree().current_scene.get_node_or_null("Fog") if get_tree().current_scene != null else null
	if fog == null or not fog.has_method("map_tiles"):
		return
	var m: Dictionary = fog.map_tiles()
	if m.is_empty():
		return
	var w := int(m.w)
	var h := int(m.h)
	var base: PackedFloat64Array = m.base
	var live: PackedByteArray = m.live
	var seen: PackedFloat32Array = m.seen
	var wet: Dictionary = m.wet
	var doors: Dictionary = m.doors
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for j in h:
		for i in w:
			var index := j * w + i
			if live[index] == 0:
				continue
			var vid := seen[index]
			if i + 1 < w:
				vid = maxf(vid, seen[index + 1])
				if j + 1 < h:
					vid = maxf(vid, seen[index + w + 1])
			if j + 1 < h:
				vid = maxf(vid, seen[index + w])
			if vid <= 0.0:
				continue
			var c := COLOR_EMPTY
			if wet.has(index):
				c = COLOR_WATER
			if doors.has(index):
				c = COLOR_DOOR
			elif base[index] >= 1.0:
				c = COLOR_WALL
			elif base[index] > 0.0:
				c = COLOR_DAMAGED
			c.a = vid
			img.set_pixel(i, j, c)
	var props := get_tree().get_first_node_in_group("land_props")
	if props != null:
		for crate in props.get("_loot"):
			if is_instance_valid(crate) and not bool(crate.get_meta("spent", false)) and crate is Node2D:
				_mark(img, crate as Node2D, COLOR_CONTAINER, seen, w)
	for cp in get_tree().get_nodes_in_group("checkpoints"):
		if cp is Node2D:
			_mark(img, cp as Node2D, COLOR_CHECKPOINT, seen, w)
	for npc in get_tree().get_nodes_in_group("story_npc"):
		if npc is Node2D:
			_mark(img, npc as Node2D, COLOR_NPC, seen, w)
	_tex = ImageTexture.create_from_image(img)
	_size = Vector2i(w, h)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		_player_px = (player.global_position - Vector2(0, 35)) / TILE


func _mark(img: Image, node: Node2D, c: Color, seen: PackedFloat32Array, w: int) -> void:
	var feet: Vector2 = node.get_meta("feet", node.global_position)
	var i := floori(feet.x / TILE)
	var j := floori(feet.y / TILE) - 1
	if i < 0 or j < 0 or i >= img.get_width() or j >= img.get_height() or seen[j * w + i] <= 0.0:
		return
	img.set_pixel(i, j, c)


func _process(delta: float) -> void:
	_blink += delta
	var pan := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if has_focus() and pan.length() > 0.25:
		_offset -= pan * PAN_SPEED * delta
	var trig := 0
	if Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.5:
		trig = 1
	elif Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT) > 0.5:
		trig = -1
	if has_focus() and trig != 0 and trig != _trig_held:
		_zoom(trig, FRAME * 0.5)
	_trig_held = trig
	queue_redraw()


func _zoom(dn: int, at: Vector2) -> void:
	var old := map_scale
	map_scale = clampi(map_scale + dn, 1, 6)
	_offset = at + (_offset - at) * float(map_scale) / float(old)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_drag = mb.pressed
			grab_focus()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(1, mb.position)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(-1, mb.position)
		accept_event()
	elif event is InputEventMouseMotion and _drag:
		_offset += (event as InputEventMouseMotion).relative
		accept_event()
	elif event.is_action_pressed("ui_accept"):
		center()
		accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, FRAME), Color(0, 0, 0, 0.25))
	if _tex != null:
		draw_set_transform(_offset, 0.0, Vector2(map_scale, map_scale))
		draw_texture(_tex, Vector2.ZERO)
		draw_set_transform(Vector2.ZERO)
		if fmod(_blink, 0.8) < 0.5:
			var p := _offset + _player_px * map_scale
			draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color.WHITE)
	if has_focus():
		draw_rect(Rect2(Vector2.ZERO, FRAME), COLOR_WALL, false, 1.0)
