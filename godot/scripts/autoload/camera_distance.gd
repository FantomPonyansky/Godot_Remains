extends Node

## How much of the room the gameplay camera shows.
## Distance 1 is today's view. Higher distance shows more of the room
## (a smaller Camera2D.zoom). Missing user://camera.cfg keeps distance 1.

signal changed(zoom: float)

const _UserDir := preload("res://scripts/user_dir.gd")
static var PATH := _UserDir.settings("camera.cfg")
const MIN_DISTANCE := 0.5
const MAX_DISTANCE := 2.0
const DEFAULT_DISTANCE := 1.0
const STEP := 0.1

const _Chrome := preload("res://scripts/pip_chrome.gd")

var distance: float = DEFAULT_DISTANCE
## Camera.setZoom(2) in a sky room fits the whole room on screen; 0 is off.
var room_zoom := 0.0
## Camera.isZoom from keyZoom: 0 the distance above, 1 fill the screen with
## the room, 2 show the whole room. A scale above 0.98 stays at 1.
var zoom_mode := 0


func _init() -> void:
	_load()


func current_zoom() -> float:
	return 1.0 / distance


func caption() -> String:
	if is_equal_approx(distance, DEFAULT_DISTANCE):
		return Locale.t("cam_normal")
	return Locale.tf("cam_more", [distance])


func set_distance(value: float) -> void:
	var next := _clamp_distance(value)
	if is_equal_approx(next, distance):
		return
	distance = next
	_save()
	apply()
	changed.emit(current_zoom())


func apply() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var body := tree.get_first_node_in_group("player")
	if body == null:
		return
	var cam := body.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	var z := room_zoom if room_zoom > 0.0 else current_zoom()
	if room_zoom <= 0.0 and zoom_mode > 0:
		var room := Vector2(cam.limit_right - cam.limit_left, cam.limit_bottom - cam.limit_top)
		var view := cam.get_viewport_rect().size
		if room.x > 0.0 and room.y > 0.0 and room.x < 100000.0 and room.y < 100000.0:
			var fit := view / room
			var s := maxf(fit.x, fit.y) if zoom_mode == 1 else minf(fit.x, fit.y)
			if s <= 0.98:
				z = s
	cam.zoom = Vector2(z, z)


func cycle_zoom() -> void:
	zoom_mode = (zoom_mode + 1) % 3
	apply()


func set_room_zoom(value: float) -> void:
	room_zoom = maxf(value, 0.0)
	apply()


func refresh_block(slider: HSlider, value_label: Label) -> void:
	if is_instance_valid(value_label):
		value_label.text = caption()
	if is_instance_valid(slider) and not is_equal_approx(slider.value, distance):
		slider.set_value_no_signal(distance)


func make_block() -> VBoxContainer:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 2)
	var header := HBoxContainer.new()
	var title := Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", _Chrome.AMBER)
	var value_label := Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", _Chrome.AMBER)
	header.add_child(title)
	header.add_child(value_label)
	var hint := Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", _Chrome.AMBER_DIM)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var closer := Label.new()
	closer.add_theme_color_override("font_color", _Chrome.AMBER_DIM)
	var slider := HSlider.new()
	slider.min_value = MIN_DISTANCE
	slider.max_value = MAX_DISTANCE
	slider.step = STEP
	slider.focus_mode = Control.FOCUS_ALL
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(80, 28)
	var farther := Label.new()
	farther.add_theme_color_override("font_color", _Chrome.AMBER_DIM)
	row.add_child(closer)
	row.add_child(slider)
	row.add_child(farther)
	block.add_child(header)
	block.add_child(hint)
	block.add_child(row)
	slider.value_changed.connect(set_distance)
	var on_changed := func(_zoom: float) -> void:
		refresh_block(slider, value_label)
	var on_language := func(_lang: String) -> void:
		label_block(title, hint, closer, farther)
		refresh_block(slider, value_label)
	changed.connect(on_changed)
	Locale.language_changed.connect(on_language)
	block.tree_exiting.connect(func() -> void:
		if changed.is_connected(on_changed):
			changed.disconnect(on_changed)
		if Locale.language_changed.is_connected(on_language):
			Locale.language_changed.disconnect(on_language)
	)
	label_block(title, hint, closer, farther)
	refresh_block(slider, value_label)
	block.set_meta("slider", slider)
	block.set_meta("value", value_label)
	return block


func label_block(title: Label, hint: Label, closer: Label, farther: Label) -> void:
	title.text = Locale.t("cam_title")
	hint.text = Locale.t("cam_hint")
	closer.text = Locale.t("cam_closer")
	farther.text = Locale.t("cam_farther")


func handle_horizontal(slider: HSlider, event: InputEvent) -> bool:
	if slider == null or not is_instance_valid(slider):
		return false
	if not event is InputEventJoypadMotion:
		return false
	var motion := event as InputEventJoypadMotion
	if motion.axis != JOY_AXIS_LEFT_X:
		return false
	var viewport := slider.get_viewport()
	if viewport == null or viewport.gui_get_focus_owner() != slider:
		return false
	if _Chrome.ui_pressed(event, "ui_left"):
		slider.value = maxf(slider.min_value, slider.value - slider.step)
	elif _Chrome.ui_pressed(event, "ui_right"):
		slider.value = minf(slider.max_value, slider.value + slider.step)
	return true


func _clamp_distance(value: float) -> float:
	if not is_finite(value):
		return DEFAULT_DISTANCE
	return clampf(snappedf(value, STEP), MIN_DISTANCE, MAX_DISTANCE)


func _load() -> void:
	distance = DEFAULT_DISTANCE
	if not FileAccess.file_exists(PATH):
		return
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	if not cfg.has_section_key("camera", "distance"):
		return
	distance = _clamp_distance(float(cfg.get_value("camera", "distance")))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("camera", "distance", distance)
	cfg.save(PATH)
