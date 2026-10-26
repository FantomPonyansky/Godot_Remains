extends CanvasLayer

## PipPageOpt Управление as a PipBuck-framed screen. Each action has a
## keyboard/mouse button and a gamepad button; pressing one waits for the
## next input of that kind (gui setkeyinfo: Esc cancels, Del clears).
## Port extras below the list: stick dead zone, cursor speed, aim assist,
## camera distance and auto-pickup.

signal closed

const _Chrome := preload("res://scripts/pip_chrome.gd")
const PAD_WAIT := 6.0

var _listening := ""
var _listen_pad := false
var _listen_frame := -1
var _listen_left := 0.0
var _keys: Dictionary = {}
var _pads: Dictionary = {}
var _prompt: Label
var _root: Control
var _first: Control
var _dz_slider: HSlider
var _dz_value: Label
var _aim_slider: HSlider
var _aim_value: Label
var _assist: CheckButton
var _pull_slider: HSlider
var _pull_value: Label
var _slow_slider: HSlider
var _slow_value: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	_build()
	_root.visible = false
	Locale.language_changed.connect(_on_language)
	Prompts.device_changed.connect(func(_pad: bool) -> void: _idle_prompt())
	InputBindings.changed.connect(_refresh)


func is_open() -> bool:
	return _root != null and _root.visible


func open() -> void:
	_listening = ""
	_refresh()
	_root.visible = true
	_idle_prompt()
	if _first != null:
		_first.call_deferred("grab_focus")


func close() -> void:
	if not is_open():
		return
	_listening = ""
	_root.visible = false
	get_viewport().gui_release_focus()
	closed.emit()


func _on_language(_lang: String) -> void:
	var was_open := is_open()
	_root.queue_free()
	_keys.clear()
	_pads.clear()
	_build()
	_root.visible = was_open
	if was_open:
		_refresh()
		_idle_prompt()
		_first.call_deferred("grab_focus")


func _process(delta: float) -> void:
	if _listening == "" or not _listen_pad:
		return
	_listen_left -= delta
	if _listen_left <= 0.0:
		_stop_listen(Locale.t("ctl_cancelled"))


func _input(event: InputEvent) -> void:
	if not is_open() or _listening == "":
		return
	get_viewport().set_input_as_handled()
	if Engine.get_process_frames() <= _listen_frame:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var code := (event as InputEventKey).keycode
		if code == KEY_ESCAPE:
			_stop_listen(Locale.t("ctl_cancelled"))
			return
		if code == KEY_DELETE:
			InputBindings.clear_binding(_listening, _listen_pad)
			_stop_listen(Locale.t("ctl_cleared"))
			return
		if not _listen_pad:
			InputBindings.set_binding(_listening, event)
			_stop_listen(Locale.t("ctl_saved"))
		return
	if _listen_pad:
		if event is InputEventJoypadButton and event.pressed:
			InputBindings.set_binding(_listening, event)
			_stop_listen(Locale.t("ctl_saved"))
		elif event is InputEventJoypadMotion:
			var motion := event as InputEventJoypadMotion
			if motion.axis_value >= 0.5 and (motion.axis == JOY_AXIS_TRIGGER_LEFT or motion.axis == JOY_AXIS_TRIGGER_RIGHT):
				InputBindings.set_binding(_listening, motion)
				_stop_listen(Locale.t("ctl_saved"))
		return
	if event is InputEventMouseButton and event.pressed:
		if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_stop_listen(Locale.t("ctl_cancelled"))
			return
		InputBindings.set_binding(_listening, event)
		_stop_listen(Locale.t("ctl_saved"))


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = load("res://theme/wasteland.tres")
	add_child(_root)
	var screen := _Chrome.build_screen(_root)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	screen.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	var title := Label.new()
	title.text = OriginalLines.pip("opt4")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", _Chrome.AMBER)
	box.add_child(title)
	_prompt = Label.new()
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.custom_minimum_size = Vector2(0, 40)
	_prompt.add_theme_font_size_override("font_size", 14)
	_prompt.add_theme_color_override("font_color", _Chrome.AMBER_DIM)
	box.add_child(_prompt)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	list.add_child(head)
	head.add_child(_cell_label("", true))
	for key in ["ctl_col_keys", "ctl_col_pad"]:
		var col := _cell_label(Locale.t(key), false)
		col.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.custom_minimum_size = Vector2(150, 0)
		head.add_child(col)
	var column: Array = []
	for action in InputBindings.ACTIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(_cell_label(InputBindings.label_for(action), true))
		var key_b := _bind_button(action, false)
		var pad_b := _bind_button(action, true)
		row.add_child(key_b)
		row.add_child(pad_b)
		list.add_child(row)
		_keys[action] = key_b
		_pads[action] = pad_b
		column.append([key_b, pad_b])
	for i in column.size():
		var pair: Array = column[i]
		var up: Array = column[i - 1] if i > 0 else column[i]
		var down: Array = column[i + 1] if i + 1 < column.size() else column[i]
		for side in 2:
			var b := pair[side] as Control
			b.focus_neighbor_left = b.get_path_to(pair[0])
			b.focus_neighbor_right = b.get_path_to(pair[1])
			if i > 0:
				b.focus_neighbor_top = b.get_path_to(up[side])
			if i + 1 < column.size():
				b.focus_neighbor_bottom = b.get_path_to(down[side])
	_first = column[0][0]
	var pad_head := _cell_label(Locale.t("ctl_pad_options"), false)
	pad_head.add_theme_color_override("font_color", _Chrome.AMBER)
	list.add_child(pad_head)
	var dz := _slider_row(list, Locale.t("ctl_deadzone"), 0.05, 0.9, 0.05)
	_dz_slider = dz[0]
	_dz_value = dz[1]
	_dz_slider.value = UiSettings.stick_deadzone()
	_dz_slider.value_changed.connect(func(v: float) -> void:
		UiSettings.set_stick_deadzone(v)
		InputBindings.apply_deadzone()
		_refresh_options())
	var aim := _slider_row(list, Locale.t("ctl_aim_speed"), 0.25, 3.0, 0.05)
	_aim_slider = aim[0]
	_aim_value = aim[1]
	_aim_slider.value = UiSettings.aim_sensitivity()
	_aim_slider.value_changed.connect(func(v: float) -> void:
		UiSettings.set_aim_sensitivity(v)
		_refresh_options())
	_assist = CheckButton.new()
	_assist.text = Locale.t("ctl_aim_assist")
	_assist.focus_mode = Control.FOCUS_ALL
	_assist.button_pressed = UiSettings.aim_assist()
	_assist.toggled.connect(func(on: bool) -> void:
		SfxBank.play("ui_click")
		UiSettings.set_aim_assist(on))
	list.add_child(_assist)
	var pull := _slider_row(list, Locale.t("ctl_assist_pull"), 0.0, 2.0, 0.05)
	_pull_slider = pull[0]
	_pull_value = pull[1]
	_pull_slider.value = UiSettings.assist_pull()
	_pull_slider.value_changed.connect(func(v: float) -> void:
		UiSettings.set_assist_pull(v)
		_refresh_options())
	var slow := _slider_row(list, Locale.t("ctl_assist_slow"), 0.0, 0.6, 0.05)
	_slow_slider = slow[0]
	_slow_value = slow[1]
	_slow_slider.value = UiSettings.assist_slow()
	_slow_slider.value_changed.connect(func(v: float) -> void:
		UiSettings.set_assist_slow(v)
		_refresh_options())
	list.add_child(CameraDistance.make_block())
	var pickup_block := Autopick.make_block()
	list.add_child(pickup_block)
	(pickup_block.get_meta("toggle") as CheckButton).toggled.connect(func(_on: bool) -> void: SfxBank.play("ui_click"))
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	box.add_child(actions)
	var reset := Button.new()
	reset.text = OriginalLines.pip("default")
	reset.focus_mode = Control.FOCUS_ALL
	reset.pressed.connect(_reset)
	actions.add_child(reset)
	var back := Button.new()
	back.text = OriginalLines.pip("mainclose")
	back.focus_mode = Control.FOCUS_ALL
	back.pressed.connect(close)
	actions.add_child(back)
	UiNav.add_screen(_root, {"default": func() -> Control: return _first, "back": close})
	_refresh_options()


func _cell_label(text: String, name_col: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", _Chrome.AMBER if name_col else _Chrome.AMBER_DIM)
	if name_col:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.custom_minimum_size = Vector2(120, 0)
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


func _bind_button(action: String, pad: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(150, 30)
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 14)
	b.pressed.connect(_start_listen.bind(action, pad))
	return b


func _slider_row(list: VBoxContainer, text: String, lo: float, hi: float, step: float) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	list.add_child(row)
	row.add_child(_cell_label(text, true))
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.focus_mode = Control.FOCUS_ALL
	slider.custom_minimum_size = Vector2(200, 28)
	row.add_child(slider)
	var value := _cell_label("", false)
	value.custom_minimum_size = Vector2(64, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	return [slider, value]


func _start_listen(action: String, pad: bool) -> void:
	SfxBank.play("ui_click")
	_listening = action
	_listen_pad = pad
	_listen_left = PAD_WAIT
	_listen_frame = Engine.get_process_frames()
	var b: Button = (_pads if pad else _keys)[action]
	b.text = "…"
	if pad:
		_prompt.text = Locale.tf("ctl_listen_pad", [InputBindings.label_for(action)])
	else:
		_prompt.text = "%s\n%s" % [InputBindings.label_for(action), OriginalLines.gui("setkeyinfo")]


func _stop_listen(message: String) -> void:
	_listening = ""
	_refresh()
	_prompt.text = message


func _idle_prompt() -> void:
	if _prompt == null or _listening != "":
		return
	_prompt.text = Locale.t("ctl_help") + "\n" + Prompts.hint([["accept", Locale.t("ctl_rebind")], ["back", OriginalLines.pip("mainclose")]])


func _reset() -> void:
	SfxBank.play("ui_click")
	_listening = ""
	InputBindings.reset_defaults()
	_dz_slider.set_value_no_signal(UiSettings.stick_deadzone())
	_aim_slider.set_value_no_signal(UiSettings.aim_sensitivity())
	_assist.set_pressed_no_signal(UiSettings.aim_assist())
	_pull_slider.set_value_no_signal(UiSettings.assist_pull())
	_slow_slider.set_value_no_signal(UiSettings.assist_slow())
	_refresh()
	_refresh_options()
	_prompt.text = Locale.t("ctl_defaults")


func _refresh() -> void:
	for action in _keys.keys():
		if not is_instance_valid(_keys[action]):
			continue
		(_keys[action] as Button).text = InputBindings.binding_text(action, false)
		(_pads[action] as Button).text = InputBindings.binding_text(action, true)


func _refresh_options() -> void:
	if _dz_value != null:
		_dz_value.text = "%d%%" % int(round(UiSettings.stick_deadzone() * 100.0))
	if _aim_value != null:
		_aim_value.text = "%d%%" % int(round(UiSettings.aim_sensitivity() * 100.0))
	if _pull_value != null:
		_pull_value.text = "%d%%" % int(round(UiSettings.assist_pull() * 100.0))
	if _slow_value != null:
		_slow_value.text = "%d%%" % int(round(UiSettings.assist_slow() * 100.0))
