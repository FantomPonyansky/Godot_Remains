extends CanvasLayer

## Appear.as / dialVid (607): the appearance window. Laid out in dialVid
## coordinates (origin at its centre), on a stage scaled to the viewport
## height like the main menu, placed at (stageW / 2, max(280, stageH - 400))
## as MainMenu.setMenuSize does. The ColorPicker, Slider and CheckBox
## components are drawn here; Flash only stores their placeholder boxes.

signal closed

const Look := preload("res://scripts/pony_look.gd")
const PARTS := "res://assets/ui/menu/art/%s.png"
const FONT := "res://theme/hud_sans.tres"
const GREEN := Color("00ff99")
const FOCUS := Color("8affd0")
const STAGE_H := 1080.0

const _CHANNELS: PackedStringArray = ["fur", "hair", "hair1", "eye", "magic"]
## colorFur / colorHair / colorHair1 / colorEye / colorMagic y; all at x 31.2.
const _ROW_Y: Array[float] = [-239.0, -205.0, -171.0, -137.0, -103.0]
## slRed / slGreen / slBlue at x 99, 256 wide; nRed.. labels at x 33.2.
const _SLIDER_Y: Array[float] = [-32.5, -8.4, 15.6]
const _NUM_Y: Array[float] = [-37.5, -13.4, 10.4]
## butDef / butCancel / butOk x, at y 230.4.
const _BUT_X: Array[float] = [-318.2, -99.2, 118.8]

var _root: Control
var _stage: Control
var _dial: Control
var _font: Font
var _title: Label
var _labels: Array[Label] = []
var _swatches: Array[Button] = []
var _sliders: Array[HSlider] = []
var _nums: Array[Label] = []
var _actions: Array[Button] = []
var _check: CheckBox
var _arrows: Array[Button] = []
var _state: Dictionary = {}
var _opened: Dictionary = {}
var _tek := "fur"
var _preview: Node2D
var _lock := false
var _fon: TextureRect
## PipPageApp: dialVid attached to the PipBuck page at a point, fon hidden.
var _host: Control
var _host_at := Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 40
	_font = load(FONT)
	_build()
	_relabel()
	Locale.language_changed.connect(_relabel)
	get_viewport().size_changed.connect(_layout)
	_layout()
	UiNav.add_screen(_root, {"default": func() -> Control: return _swatches[0], "back": _close.bind(false)})


func is_open() -> bool:
	return _root != null and _root.visible


## PipPageApp.setSubPages: over the PipBuck stage `host` at `at`, without the fon.
func open_in(host: Control, at: Vector2, over_layer: int) -> void:
	_host = host
	_host_at = at
	layer = over_layer + 1
	_fon.visible = false
	open()


## Leaves without the closed signal (the PipBuck moved to another page).
func cancel_quiet() -> void:
	if not is_open():
		return
	Look.set_state(_opened, false)
	_state = _opened.duplicate(true)
	_apply_live()
	_root.visible = false
	_detach()


func _detach() -> void:
	_host = null
	layer = 40
	_fon.visible = true
	_layout()


func open() -> void:
	_state = Look.state().duplicate(true)
	_opened = _state.duplicate(true)
	_tek = "fur"
	_refresh()
	_apply_live()
	_layout()
	_root.visible = true
	_swatches[0].call_deferred("grab_focus")


func _close(save_it: bool) -> void:
	if save_it:
		Look.set_state(_state, true)
	else:
		Look.set_state(_opened, false)
		_state = _opened.duplicate(true)
	_apply_live()
	_root.visible = false
	if _host != null:
		_detach()
	closed.emit()


func _process(delta: float) -> void:
	if not is_open() or _preview == null:
		return
	if _preview.has_method("update_pose"):
		_preview.update_pose("idle", 1.0, Vector2.RIGHT, delta)


## Appear.setLang.
func _relabel(_lang := "") -> void:
	_title.text = OriginalLines.gui("butvid")
	for i in _CHANNELS.size():
		_labels[i].text = OriginalLines.gui("vid" + _CHANNELS[i])
	_actions[0].text = OriginalLines.pip("default")
	_actions[1].text = OriginalLines.gui("cancel")
	_actions[2].text = "OK"


func _layout() -> void:
	if _stage == null:
		return
	if _host != null and is_instance_valid(_host):
		var xf := _host.get_global_transform()
		_stage.scale = xf.get_scale()
		_stage.position = xf.origin
		_dial.position = _host_at
		return
	_stage.position = Vector2.ZERO
	var view := get_viewport().get_visible_rect().size
	var k := view.y / STAGE_H
	_stage.scale = Vector2(k, k)
	_stage.size = view / k
	_dial.position = Vector2(_stage.size.x * 0.5, maxf(280.0, _stage.size.y - 400.0))


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_stage)
	_dial = Control.new()
	_dial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_dial)
	# fon (shape 495) and the three 524 boxes.
	_fon = _art("495", Rect2(-411.6, -332.5, 823.2, 610.1))
	_art("524_1", Rect2(18.9, -250.1, 349.6, 186.1))
	_art("524_1", Rect2(18.9, -52.2, 349.6, 94.4))
	_art("524_1", Rect2(-314.6, -250.1, 294.9, 292.4))
	_title = _label(Rect2(-389.1, -317.6, 778.0, 26.0), 20)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# pers is 514 at 3.01; the puppet's own scale makes 2.0 the same size on screen.
	var pony: Array = preload("res://scripts/pony_puppet.gd").preview(Vector2(-165.9, -9.6), 2.3, 3.0)
	_dial.add_child(pony[0])
	_preview = pony[1]
	if _preview.has_method("set_magic_preview"):
		_preview.set_magic_preview(true)
	for i in _CHANNELS.size():
		_swatches.append(_swatch(i))
		_labels.append(_label(Rect2(108.0, _ROW_Y[i] + 2.1, 250.0, 22.0), 16))
	_arrows.append(_arrow(Vector2(70.8, -193.0), -1, "hair_style", Look.MAX_HAIR))
	_arrows.append(_arrow(Vector2(89.0, -193.0), 1, "hair_style", Look.MAX_HAIR))
	_arrows.append(_arrow(Vector2(70.8, -125.0), -1, "eye_style", Look.MAX_EYE))
	_arrows.append(_arrow(Vector2(89.0, -125.0), 1, "eye_style", Look.MAX_EYE))
	_check = _checkbox(Vector2(72.0, -165.0))
	for i in 3:
		_nums.append(_label(Rect2(31.2, _NUM_Y[i] - 2.0, 60.0, 22.0), 16))
		_sliders.append(_slider(i))
	for i in 3:
		_actions.append(_button(Rect2(_BUT_X[i] + 0.6, 230.4, 186.2, 28.0), [_on_default, _on_cancel, _on_ok][i]))
	_wire_focus()


func _tex(id: String) -> Texture2D:
	var path := PARTS % id
	return load(path) if ResourceLoader.exists(path) else null


func _art(id: String, r: Rect2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = _tex(id)
	t.position = r.position
	t.size = r.size
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dial.add_child(t)
	return t


func _label(r: Rect2, size: int) -> Label:
	var l := Label.new()
	l.position = r.position
	l.size = r.size
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _font:
		l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", GREEN)
	_dial.add_child(l)
	return l


func _focus_box(grow := 2.0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = FOCUS
	box.set_border_width_all(1)
	box.set_expand_margin_all(grow)
	return box


func _hover(b: Control) -> void:
	b.mouse_entered.connect(func() -> void:
		if b.focus_mode != Control.FOCUS_NONE:
			b.grab_focus())


## ColorPicker swatch: the 491 box at 0.30 x 1.09 (24 x 24).
func _swatch(i: int) -> Button:
	var b := Button.new()
	b.position = Vector2(31.2, _ROW_Y[i])
	b.size = Vector2(24.0, 24.0)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("focus", _focus_box())
	var key := _CHANNELS[i]
	b.focus_entered.connect(_pick.bind(key))
	b.pressed.connect(_pick.bind(key))
	_hover(b)
	_dial.add_child(b)
	return b


func _paint_swatch(b: Button, c: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = c
	box.border_color = Color(0.62, 0.86, 0.76)
	box.set_border_width_all(2)
	for s in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(s, box)


## b1 / b2 Hair / Eye (button 606): a 524 tile with the white arrow 605; b1 is mirrored.
func _arrow(at: Vector2, dir: int, key: String, count: int) -> Button:
	var b := Button.new()
	b.position = at + Vector2(-8.0, -9.5)
	b.size = Vector2(16.0, 22.0)
	b.focus_mode = Control.FOCUS_ALL
	var fon := StyleBoxTexture.new()
	fon.texture = _tex("524_1")
	fon.set_texture_margin_all(2)
	var lit := fon.duplicate() as StyleBoxTexture
	lit.modulate_color = Color(1.4, 1.4, 1.4)
	for s in ["normal", "disabled"]:
		b.add_theme_stylebox_override(s, fon)
	for s in ["hover", "pressed"]:
		b.add_theme_stylebox_override(s, lit)
	b.add_theme_stylebox_override("focus", _focus_box(1.0))
	var c := Vector2(8.0, 9.5)
	var d := float(dir)
	var tri := PackedVector2Array([c + Vector2(-3.35 * d, -7.8), c + Vector2(4.55 * d, 0.0), c + Vector2(-3.35 * d, 7.95)])
	b.draw.connect(func() -> void: b.draw_colored_polygon(tri, Color.WHITE))
	b.pressed.connect(func() -> void:
		SfxBank.play("ui_click")
		_step_style(key, dir, count))
	_hover(b)
	_dial.add_child(b)
	return b


## checkHair1: 13 px box, green tick on / red cross off, as the main menu's checkboxes.
func _checkbox(at: Vector2) -> CheckBox:
	var cb := CheckBox.new()
	cb.position = at - Vector2(2.0, 4.0)
	cb.size = Vector2(17.0, 21.0)
	cb.focus_mode = Control.FOCUS_ALL
	cb.add_theme_icon_override("checked", _check_icon(true))
	cb.add_theme_icon_override("unchecked", _check_icon(false))
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		cb.add_theme_stylebox_override(s, empty)
	cb.add_theme_stylebox_override("focus", _focus_box(0.0))
	cb.toggled.connect(_on_highlight)
	_hover(cb)
	_dial.add_child(cb)
	return cb


func _check_icon(on: bool) -> ImageTexture:
	var img := Image.create_empty(13, 13, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	for i in 13:
		img.set_pixel(i, 0, Color(0.55, 0.55, 0.55))
		img.set_pixel(0, i, Color(0.55, 0.55, 0.55))
		img.set_pixel(i, 12, Color(0.75, 0.75, 0.75))
		img.set_pixel(12, i, Color(0.75, 0.75, 0.75))
	CheckMark.draw(img, on)
	return ImageTexture.create_from_image(img)


## Slider: track 256 x 3 (491 at 3.2 x 0.14) with the arrow-house thumb.
func _slider(i: int) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 255
	s.step = 1
	s.position = Vector2(99.0, _SLIDER_Y[i] - 7.0)
	s.size = Vector2(256.0, 18.0)
	s.focus_mode = Control.FOCUS_ALL
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.25, 0.85, 0.6)
	track.border_color = Color(0.7, 1.0, 0.85)
	track.border_width_top = 1
	track.content_margin_top = 1.5
	track.content_margin_bottom = 1.5
	s.add_theme_stylebox_override("slider", track)
	var empty := StyleBoxEmpty.new()
	s.add_theme_stylebox_override("grabber_area", empty)
	s.add_theme_stylebox_override("grabber_area_highlight", empty)
	s.add_theme_stylebox_override("focus", _focus_box(1.0))
	var thumb := _thumb()
	for icon in ["grabber", "grabber_highlight", "grabber_disabled"]:
		s.add_theme_icon_override(icon, thumb)
	s.value_changed.connect(_on_slider.bind(i))
	_hover(s)
	_dial.add_child(s)
	return s


func _thumb() -> ImageTexture:
	var w := 11
	var h := 15
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var mid := w / 2
	for y in h:
		var half := mini(y, mid) if y < 6 else mid
		for x in range(mid - half, mid + half + 1):
			var edge := x == mid - half or x == mid + half or y == h - 1 or (y < 6 and absi(x - mid) == half)
			img.set_pixel(x, y, Color.WHITE if edge else Color(0.05, 0.2, 0.14))
	return ImageTexture.create_from_image(img)


## butDef / butCancel / butOk (508): the 506 bar, _sans 20.
func _button(r: Rect2, action: Callable) -> Button:
	var b := Button.new()
	b.position = r.position
	b.size = r.size
	b.focus_mode = Control.FOCUS_ALL
	b.clip_text = true
	var normal := StyleBoxTexture.new()
	normal.texture = _tex("506")
	normal.set_texture_margin_all(2)
	var lit := normal.duplicate() as StyleBoxTexture
	lit.modulate_color = Color(1.4, 1.4, 1.4)
	for s in ["normal", "disabled"]:
		b.add_theme_stylebox_override(s, normal)
	for s in ["hover", "pressed"]:
		b.add_theme_stylebox_override(s, lit)
	b.add_theme_stylebox_override("focus", _focus_box(0.0))
	if _font:
		b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 20)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, GREEN)
	b.pressed.connect(func() -> void:
		SfxBank.play("ui_click")
		action.call())
	_hover(b)
	_dial.add_child(b)
	return b


## Rows top to bottom: each swatch with its arrows or checkbox, the three
## sliders (left / right change the value), then the three buttons.
func _wire_focus() -> void:
	var rows: Array = [
		[_swatches[0]],
		[_swatches[1], _arrows[0], _arrows[1]],
		[_swatches[2], _check],
		[_swatches[3], _arrows[2], _arrows[3]],
		[_swatches[4]],
		[_sliders[0]], [_sliders[1]], [_sliders[2]],
		_actions,
	]
	for r in rows.size():
		var row: Array = rows[r]
		var up: Control = rows[maxi(0, r - 1)][0]
		var down: Control = rows[mini(rows.size() - 1, r + 1)][0]
		for i in row.size():
			var c := row[i] as Control
			c.focus_neighbor_top = c.get_path_to(up)
			c.focus_neighbor_bottom = c.get_path_to(down)
			if c is HSlider:
				continue
			c.focus_neighbor_left = c.get_path_to(row[maxi(0, i - 1)])
			c.focus_neighbor_right = c.get_path_to(row[mini(row.size() - 1, i + 1)])
	for b in _actions:
		b.focus_neighbor_bottom = b.get_path_to(b)


## The picker under focus (or clicked) is the one the sliders edit (Appear.tek).
func _pick(key: String) -> void:
	if _tek == key:
		return
	_tek = key
	_refresh()


func _on_slider(value: float, axis: int) -> void:
	if _lock:
		return
	var rgb: Array = _state[_tek]
	rgb[axis] = int(value)
	_state[_tek] = rgb
	_refresh_labels()
	_apply_live()


func _on_highlight(on: bool) -> void:
	if _lock:
		return
	_state.vis_hair1 = on
	_apply_live()


func _step_style(key: String, dir: int, count: int) -> void:
	var n := int(_state[key]) + dir
	if n < 1:
		n = count
	if n > count:
		n = 1
	_state[key] = n
	_apply_live()


func _on_default() -> void:
	_state = Look.defaults()
	_tek = "fur"
	_refresh()
	_apply_live()


func _on_cancel() -> void:
	_close(false)


func _on_ok() -> void:
	_close(true)


func _refresh() -> void:
	_lock = true
	var rgb: Array = _state[_tek]
	for i in 3:
		_sliders[i].value = int(rgb[i])
	_check.button_pressed = bool(_state.vis_hair1)
	_lock = false
	_refresh_labels()


## Appear.setRGB and the pickers' selectedColor.
func _refresh_labels() -> void:
	for i in _CHANNELS.size():
		var rgb: Array = _state[_CHANNELS[i]]
		_paint_swatch(_swatches[i], Color8(int(rgb[0]), int(rgb[1]), int(rgb[2])))
	var cur: Array = _state[_tek]
	_nums[0].text = "R:%d" % int(cur[0])
	_nums[1].text = "G:%d" % int(cur[1])
	_nums[2].text = "B:%d" % int(cur[2])


func _apply_live() -> void:
	Look.set_state(_state, false)
	for node in get_tree().get_nodes_in_group("pony_puppet"):
		if node.has_method("apply_appearance"):
			node.apply_appearance()
