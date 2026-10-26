extends CanvasLayer

## Owns the PipBuck keys (Ctr.as keyPip Tab, gamepad Back, I/O/K/L/M) and
## hosts the PipBuck. Esc (and Start) open it on the Menu page; the old pause
## panel below is never shown.

const _Chrome := preload("res://scripts/pip_chrome.gd")
const _Pip := preload("res://scripts/pipbuck.gd")
const _ExitTrace := preload("res://scripts/exit_trace.gd")

@onready var panel: Control = $Panel
@onready var resume_btn: Button = %Resume
@onready var menu_btn: Button = %MainMenu
@onready var box: VBoxContainer = %MenuBox
@onready var camera_box: VBoxContainer = %CameraDistance
@onready var camera_slider: HSlider = %CameraSlider
@onready var camera_value: Label = %CameraValue

var _controls_btn: Button
var _look_btn: Button
var _pip_btn: Button
var _hint: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_Pip.ensure_actions()
	panel.visible = false
	resume_btn.pressed.connect(_resume)
	menu_btn.pressed.connect(_to_menu)
	_wrap_in_scroll()
	var controls_btn := Button.new()
	_controls_btn = controls_btn
	box.add_child(controls_btn)
	box.move_child(controls_btn, menu_btn.get_index())
	controls_btn.pressed.connect(_open_controls)
	var look_btn := Button.new()
	_look_btn = look_btn
	box.add_child(look_btn)
	box.move_child(look_btn, menu_btn.get_index())
	look_btn.pressed.connect(_open_look)
	var pip_btn := Button.new()
	_pip_btn = pip_btn
	box.add_child(pip_btn)
	box.move_child(pip_btn, menu_btn.get_index())
	pip_btn.pressed.connect(_open_pipbuck)
	box.move_child(camera_box, menu_btn.get_index())
	var pickup_block := Autopick.make_block()
	box.add_child(pickup_block)
	box.move_child(pickup_block, camera_box.get_index() + 1)
	var pickup_toggle := pickup_block.get_meta("toggle") as BaseButton
	pickup_toggle.toggled.connect(func(_on: bool) -> void: SfxBank.play("ui_click"))
	camera_slider.focus_mode = Control.FOCUS_ALL
	camera_slider.min_value = CameraDistance.MIN_DISTANCE
	camera_slider.max_value = CameraDistance.MAX_DISTANCE
	camera_slider.step = CameraDistance.STEP
	CameraDistance.refresh_block(camera_slider, camera_value)
	camera_slider.value_changed.connect(CameraDistance.set_distance)
	if not CameraDistance.changed.is_connected(_on_camera_changed):
		CameraDistance.changed.connect(_on_camera_changed)
	for button in [resume_btn, menu_btn, controls_btn, look_btn, pip_btn]:
		button.pressed.connect(func() -> void: SfxBank.play("ui_click"))
	_apply_text()
	Locale.language_changed.connect(_apply_text)
	Prompts.device_changed.connect(_on_device)
	UiNav.add_screen(panel, {"default": resume_btn, "back": _resume})


## The scene's MenuBox does not fit the PipBuck screen with every block, so
## it scrolls; the footer shows the controller hint.
func _wrap_in_scroll() -> void:
	var margin := box.get_parent()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.remove_child(box)
	margin.add_child(column)
	column.add_child(scroll)
	scroll.add_child(box)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.add_theme_color_override("font_color", _Chrome.AMBER_DIM)
	column.add_child(_hint)


func _apply_text(_lang: String = "") -> void:
	resume_btn.text = OriginalLines.gui("contgame")
	menu_btn.text = Locale.t("pause_main_menu")
	var title := box.get_node_or_null("Title") as Label
	if title:
		title.text = Locale.t("pause_title")
	_controls_btn.text = OriginalLines.pip("opt4")
	_look_btn.text = OriginalLines.pip("main8")
	_pip_btn.text = OriginalLines.key("keyPip")
	CameraDistance.label_block(
		camera_box.get_node("Header/Title") as Label, camera_box.get_node("Hint") as Label,
		camera_box.get_node("Row/Closer") as Label, camera_box.get_node("Row/Farther") as Label)
	CameraDistance.refresh_block(camera_slider, camera_value)
	_hint.text = Prompts.hint([["accept", OriginalLines.pip("choose")], ["back", OriginalLines.gui("contgame")]])


func _on_device(_pad: bool) -> void:
	_apply_text()


func _exit_tree() -> void:
	if CameraDistance.changed.is_connected(_on_camera_changed):
		CameraDistance.changed.disconnect(_on_camera_changed)


func _on_camera_changed(_zoom: float) -> void:
	CameraDistance.refresh_block(camera_slider, camera_value)


var _look
var _pip: Node


func _open_look() -> void:
	panel.visible = false
	if _look == null:
		_look = preload("res://scripts/appearance_screen.gd").new()
		_look.closed.connect(_on_look_closed)
		add_child(_look)
	_look.open()


func _on_look_closed() -> void:
	if GameState.paused:
		panel.visible = true
		resume_btn.grab_focus()


var _pip_direct := false


func _open_pipbuck(page: int = -1, sub: int = -1) -> void:
	panel.visible = false
	if _pip == null or not is_instance_valid(_pip):
		_pip = load("res://scenes/pipbuck.tscn").instantiate()
		if page > 0:
			_pip.open_at(page, sub)
		_pip.closed.connect(_on_pip_closed)
		_pip.to_main_menu.connect(_to_menu)
		add_child(_pip)


## PipBuck.toggle from gameplay: pauses the world without the pause panel.
func _open_pipbuck_direct(action: String) -> void:
	_pip_direct = true
	GameState.set_paused(true)
	var jump: Array = _Pip.JUMPS.get(action, [-1, -1])
	_open_pipbuck(int(jump[0]), int(jump[1]))


## Interact allact map / Npc travel: PipBuck.onoff(3,3) from a world object.
func open_pipbuck(action: String) -> void:
	if _pip != null and is_instance_valid(_pip):
		return
	_open_pipbuck_direct(action)


## Script pip / Npc pages: PipBuck.onoff(page, sub), sub counted from 1.
func open_pipbuck_at(page: int, sub: int = 0) -> void:
	if _pip != null and is_instance_valid(_pip):
		_pip.open_at(page, sub - 1)
		return
	_pip_direct = true
	GameState.set_paused(true)
	_open_pipbuck(page, sub - 1)


## PipBuck.onoff(-1).
func close_pipbuck() -> void:
	if _pip != null and is_instance_valid(_pip) and _pip.has_method("_close"):
		_pip.call("_close")


func _on_pip_closed() -> void:
	_pip = null
	_pip_direct = false
	_resume()


func _open_controls() -> void:
	panel.visible = false
	if not ControlsUI.closed.is_connected(_on_controls_closed):
		ControlsUI.closed.connect(_on_controls_closed)
	ControlsUI.open()


func _on_controls_closed() -> void:
	if GameState.paused:
		panel.visible = true
		resume_btn.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if ControlsUI.is_open():
		return
	if _look != null and _look.is_open():
		return
	if _pip != null and is_instance_valid(_pip):
		return
	var pip_action := _Pip.action_of(event)
	if pip_action != "":
		if panel.visible:
			_open_pipbuck(int(_Pip.JUMPS.get(pip_action, [-1])[0]), int(_Pip.JUMPS.get(pip_action, [-1, -1])[1]))
		else:
			_open_pipbuck_direct(pip_action)
		get_viewport().set_input_as_handled()
		return
	# The pause panel is retired (user decision): Esc opens the PipBuck on Menu.
	if event.is_action_pressed("pause"):
		_pip_direct = true
		GameState.set_paused(true)
		_open_pipbuck(_Pip.MENU, -1)
		get_viewport().set_input_as_handled()


func _pause() -> void:
	panel.visible = true
	GameState.set_paused(true)
	resume_btn.grab_focus()


func focus_menu() -> void:
	if panel.visible and resume_btn != null:
		resume_btn.grab_focus()


func _resume() -> void:
	panel.visible = false
	GameState.set_paused(false)
	get_viewport().gui_release_focus()


func _to_menu() -> void:
	# Autosave (slot 0) so Продолжить on the main menu can resume this run.
	# World.onDeactivate and the t_save autosave skip the alicorn.
	_ExitTrace.arm(get_tree(), "pause menu")
	if GameState.health > 0 and not ScriptsEngine.alicorn:
		_ExitTrace.step("autosave slot 0")
		SaveSlots.save(0)
		_ExitTrace.step("autosave done")
	GameState.set_paused(false)
	_ExitTrace.step("unpaused")
	AudioManager.play_menu()
	_ExitTrace.step("menu music started")
	var err := get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	_ExitTrace.step("change_scene_to_file returned %d" % err)
