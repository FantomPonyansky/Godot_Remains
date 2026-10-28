extends Control

## PipPageInfo local map (page2 1). visPipMap sits at page 12,75; its fon is the
## 707 x 570 frame at 15.5,15. Minimap.drawLevel paints one pixel per tile of the
## visited rooms, alpha by how lit the tile is, with containers, quest exits,
## checkpoints and NPCs filled over their bounding boxes, scaled by mapScale (1..6).
## butZoomP / butZoomM / butCenter sit right of the frame. plTag is playerTag:
## the playerTagKvad square cycling red / white under the 45° inverting cross.
## Mouse: drag pans, the wheel zooms at the cursor. Pad: the right stick pans,
## the triggers zoom, A centres on the player.

const AT := Vector2(12, 75)
const FON_AT := Vector2(15.5, 15.0)
const FRAME := Vector2(707, 570)
const TILE := 40.0
const COLOR_EMPTY := Color8(0x00, 0x33, 0x23)
const COLOR_WHITE := Color8(0xFF, 0xFF, 0xFF)
const COLOR_WALL := Color8(0x00, 0xFF, 0x99)
const COLOR_DOOR := Color8(0x63, 0x91, 0x04)
const COLOR_STAIR := Color8(0x66, 0x66, 0x66)
const COLOR_SHELFSTAIR := Color8(0x7B, 0x48, 0x2F)
const COLOR_WATER := Color8(0x00, 0x66, 0xFF)
const COLOR_DAMAGED := Color8(0x01, 0x99, 0x5A)
const COLOR_CONTAINER := Color8(0xFF, 0xCC, 0x00)
const COLOR_QUEST := Color8(0xFF, 0x00, 0x77)
const COLOR_CHECKPOINT := Color8(0xFF, 0x00, 0xFF)
const COLOR_NPC := Color8(0x55, 0x00, 0xFF)
const PAN_SPEED := 600.0
const ART := "res://assets/ui/pip/map/%s.png"
## playerTag: 30 frames at 30 fps. The red playerTagKvad keeps R 1; its colour
## transform gives G, B per frame (red, yellow, white at frame 14, back).
const TAG_GB := [[0.0, 0.0], [0.1667, 0.0712], [0.3333, 0.1425], [0.5, 0.2137], [0.6667, 0.285], [0.8333, 0.3562],
	[1.0, 0.4275], [1.0, 0.499], [1.0, 0.5706], [1.0, 0.6422], [1.0, 0.7137], [1.0, 0.7853], [1.0, 0.8569], [1.0, 0.9284],
	[1.0, 1.0], [1.0, 0.9182], [1.0, 0.8364], [1.0, 0.7546], [1.0, 0.6728], [1.0, 0.591], [1.0, 0.5092], [1.0, 0.4275],
	[0.875, 0.374], [0.75, 0.3206], [0.625, 0.2672], [0.5, 0.2137], [0.375, 0.1603], [0.25, 0.1069], [0.125, 0.0534], [0.0, 0.0]]
const TAG_SIZE := 10.0
## The cross has blend "invert": it shows the inverse of what lies under it.
const INVERT := "shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_nearest;
void fragment() {
	COLOR = vec4(vec3(1.0) - texture(screen, SCREEN_UV).rgb, texture(TEXTURE, UV).a);
}"
const CROSS_SIZE := 144.0
## visPipMap butZoomP / butZoomM / butCenter centres.
const BUTTONS := [["butZoomP", Vector2(747.1, 27.1)], ["butZoomM", Vector2(747.1, 63.1)], ["butCenter", Vector2(747.1, 99.1)]]
const CHECKPOINT_SIZE := Vector2(80, 120)

static var map_scale := 3

var _tex: ImageTexture
var _size := Vector2i.ZERO
var _offset := Vector2.ZERO
var _player_px := Vector2.ZERO
var _drag := false
var _blink := 0.0
var _trig_held := 0
var _cross: TextureRect
var _buttons: Array[Control] = []


func _ready() -> void:
	position += AT + FON_AT
	size = FRAME
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_cross = TextureRect.new()
	_cross.texture = load(ART % "cross")
	_cross.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cross.size = Vector2.ONE * CROSS_SIZE
	_cross.pivot_offset = _cross.size * 0.5
	_cross.rotation = PI * 0.25
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cross.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var shader := Shader.new()
	shader.code = INVERT
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_cross.material = mat
	_cross.visible = false
	add_child(_cross)
	_build()
	center()
	_add_buttons.call_deferred()


func _exit_tree() -> void:
	for b in _buttons:
		if is_instance_valid(b):
			b.queue_free()
	_buttons.clear()


func has_map() -> bool:
	return _tex != null


func center() -> void:
	_offset = FRAME * 0.5 - _player_px * map_scale
	queue_redraw()


func _add_buttons() -> void:
	var host := get_parent()
	if host == null:
		return
	for spec: Array in BUTTONS:
		var b := TextureButton.new()
		var id := str(spec[0])
		b.texture_normal = load(ART % (id + "_up"))
		b.texture_hover = load(ART % (id + "_over"))
		b.texture_pressed = b.texture_hover
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_SCALE
		b.size = Vector2(29, 29)
		b.position = position - FON_AT + (spec[1] as Vector2) - Vector2(14.5, 14.5)
		b.focus_mode = Control.FOCUS_NONE
		var ico := TextureRect.new()
		ico.texture = load(ART % (id + "_ico"))
		ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ico.size = ico.texture.get_size() * 0.5
		ico.position = (b.size - ico.size) * 0.5
		b.add_child(ico)
		match id:
			"butZoomP":
				b.pressed.connect(func() -> void: _zoom(1, FRAME * 0.5))
			"butZoomM":
				b.pressed.connect(func() -> void: _zoom(-1, FRAME * 0.5))
			_:
				b.pressed.connect(center)
		b.pressed.connect(func() -> void: SfxBank.play("pip1"))
		host.add_child(b)
		_buttons.append(b)


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
	var kinds: Dictionary = m.get("kinds", {})
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
			var kind := str(kinds.get(index, ""))
			if kind == "shelf":
				c = COLOR_SHELFSTAIR
			elif kind == "stair":
				c = COLOR_STAIR
			if doors.has(index):
				c = COLOR_DOOR
			elif base[index] >= 1.0:
				c = COLOR_WHITE if kind == "white" else COLOR_WALL
			elif base[index] > 0.0 and kind != "shelf" and kind != "stair":
				c = COLOR_DAMAGED
			c.a = vid
			img.set_pixel(i, j, c)
	var props := get_tree().get_first_node_in_group("land_props")
	if props != null:
		for crate in props.get("_loot"):
			if is_instance_valid(crate) and not bool(crate.get_meta("spent", false)) and crate is Node2D:
				_mark(img, crate as Node2D, COLOR_CONTAINER, seen, w)
		for exit in props.get("_passages"):
			if is_instance_valid(exit) and exit is Node2D and str((exit as Node).get_meta("dest_prob", "")) != "":
				_mark(img, exit as Node2D, COLOR_QUEST, seen, w)
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


## Minimap.drawObj: every tile the bounding box covers, rounded inward
## (left + 0.5, right - 0.5, top + 0.4, bottom - 0.5 tiles).
func _mark(img: Image, node: Node2D, c: Color, seen: PackedFloat32Array, w: int) -> void:
	var box := _box(node)
	var x0 := int(box.position.x / TILE + 0.5)
	var x1 := int(box.end.x / TILE - 0.5)
	var y0 := int(box.position.y / TILE + 0.4)
	var y1 := int(box.end.y / TILE - 0.5)
	var mid := Vector2i(clampi((x0 + x1) / 2, 0, img.get_width() - 1), clampi((y0 + y1) / 2, 0, img.get_height() - 1))
	if seen[mid.y * w + mid.x] <= 0.0:
		return
	for i in range(maxi(x0, 0), mini(x1, img.get_width() - 1) + 1):
		for j in range(maxi(y0, 0), mini(y1, img.get_height() - 1) + 1):
			img.set_pixel(i, j, c)


## The object's boundingBox: feet at the bottom centre, size from the node.
func _box(node: Node2D) -> Rect2:
	var feet: Vector2 = node.get_meta("feet", node.global_position)
	var sz := TILE * Vector2.ONE
	if node.has_meta("size"):
		sz = node.get_meta("size")
	elif node.is_in_group("checkpoints"):
		sz = CHECKPOINT_SIZE
	else:
		var shape := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape != null and shape.shape is RectangleShape2D:
			sz = (shape.shape as RectangleShape2D).size * node.global_scale.abs()
	return Rect2(feet.x - sz.x * 0.5, feet.y - sz.y, sz.x, sz.y)


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
	queue_redraw()


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


func _tag_color() -> Color:
	var gb: Array = TAG_GB[int(_blink * 30.0) % TAG_GB.size()]
	return Color(1.0, float(gb[0]), float(gb[1]))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, FRAME), Color(0, 0, 0, 0.25))
	if _tex != null:
		draw_set_transform(_offset, 0.0, Vector2(map_scale, map_scale))
		draw_texture(_tex, Vector2.ZERO)
		var p := _offset + _player_px * map_scale
		_cross.visible = true
		_cross.position = p - _cross.pivot_offset
		draw_set_transform(p)
		draw_rect(Rect2(-Vector2.ONE * TAG_SIZE * 0.5, Vector2.ONE * TAG_SIZE), _tag_color())
		draw_set_transform(Vector2.ZERO)
	if has_focus():
		draw_rect(Rect2(Vector2.ZERO, FRAME), COLOR_WALL, false, 1.0)
