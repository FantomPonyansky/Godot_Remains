extends CanvasLayer

## GUI.dialText windows: dial (portrait and a speaker's line, at the bottom)
## and inform (a centred text panel; mod 2 also shows its OK button).
## Lines come from StoryText rows {p, mod, push, m, keys, text} or a ready
## line {mod, push, text, plain}. [..] is the yellow span, lp* portraits turn
## into lpa (crimson text) in the alicorn armour. The blinking hint is
## GUI.dial.lmb: shown while the script waits for a click.
## Input while a script waits: left click / A / accept / interact advance,
## right click / B / cancel skip the rest (Ctr.keyPressed / keyPressed2).

const StoryText := preload("res://scripts/story/story_text.gd")
const PORTRAITS := "res://assets/portraits/%s.png"
const PORTRAIT_FILES := {"enc1": "encl1", "enc2": "encl2"}
const FONT := "res://theme/hud_sans.tres"
const GREEN := Color("00ff99")
const YELLOW := "ffff33"
const CRIMSON := "ff3333"
const PANEL := Color(0.0, 0.07, 0.04, 0.88)
const DIAL_SIZE := Vector2(860, 170)
const INFORM_W := 620.0

var _root: Control
var _dial: Panel
var _portrait: TextureRect
var _dial_text: RichTextLabel
var _inform: Panel
var _inform_text: RichTextLabel
var _hint: Button
var _ok: Label
var _font: Font
var _wait := false
var _blink := 0.0
var _dial_bb := ""
var _inform_bb := ""
var _last: Dictionary = {}


func _ready() -> void:
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = load(FONT) if ResourceLoader.exists(FONT) else null
	_root = Control.new()
	_root.name = "DialogueRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)
	_dial = _panel()
	_root.add_child(_dial)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.position = Vector2(12, 12)
	_portrait.size = Vector2(146, 146)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dial.add_child(_portrait)
	_dial_text = _rich()
	_dial.add_child(_dial_text)
	_inform = _panel()
	_root.add_child(_inform)
	_inform_text = _rich()
	_inform.add_child(_inform_text)
	_ok = Label.new()
	_ok.add_theme_color_override("font_color", GREEN)
	if _font != null:
		_ok.add_theme_font_override("font", _font)
	_ok.add_theme_font_size_override("font_size", 16)
	_ok.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ok.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inform.add_child(_ok)
	_hint = Button.new()
	_hint.flat = true
	_hint.focus_mode = Control.FOCUS_ALL
	_hint.add_theme_color_override("font_color", GREEN)
	_hint.add_theme_color_override("font_focus_color", GREEN)
	_hint.add_theme_color_override("font_hover_color", GREEN)
	if _font != null:
		_hint.add_theme_font_override("font", _font)
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.pressed.connect(func() -> void: ScriptsEngine.key_pressed = true)
	_root.add_child(_hint)
	UiNav.add_screen(_root, {"default": _hint, "back": func() -> void: ScriptsEngine.key_pressed2 = true})
	Locale.language_changed.connect(_on_language)
	Prompts.device_changed.connect(func(_pad: bool) -> void: _relabel_hint())
	get_viewport().size_changed.connect(_layout)
	_relabel_hint()
	_layout()


func show_line(line: Dictionary, _down: bool, wait: bool, alicorn: bool) -> bool:
	_last = {"line": line, "wait": wait, "alicorn": alicorn}
	var s := str(line.get("text", "")) if bool(line.get("plain", false)) else StoryText.line_text(line)
	s = _bb(s)
	var mod := int(line.get("mod", 0))
	var pushed := int(line.get("push", line.get("pushed", 0))) > 0
	_root.visible = true
	if mod >= 1:
		_dial.visible = false
		_inform.visible = true
		_inform_bb = (_inform_bb + "\n\n" + s) if pushed and _inform_bb != "" else s
		_inform_text.text = _inform_bb
		_ok.visible = mod == 2
		_ok.text = OriginalLines.gui("ok") if OriginalLines.has("gui", "ok") else "OK"
	else:
		_inform.visible = false
		_dial.visible = true
		var p := str(line.get("p", ""))
		if p.begins_with("lp") and alicorn:
			p = "lpa"
			s = "[color=#%s]%s[/color]" % [CRIMSON, s]
		_portrait.texture = _portrait_tex(p)
		_dial_bb = (_dial_bb + "\n" + s) if pushed and _dial_bb != "" else s
		_dial_text.text = _dial_bb
	_wait = wait
	_hint.visible = wait
	_blink = 0.0
	_layout()
	if wait:
		_hint.grab_focus.call_deferred()
	return true


func hide_all() -> void:
	_root.visible = false
	_dial.visible = false
	_inform.visible = false
	_wait = false
	_dial_bb = ""
	_inform_bb = ""
	_last = {}


func dial_visible() -> bool:
	return _root.visible and _dial.visible


func visible_any() -> bool:
	return _root.visible


func _input(event: InputEvent) -> void:
	if not _root.visible or not _wait or GameState.paused or not ScriptsEngine.is_waiting():
		return
	if event.is_action_pressed("pause"):
		return
	var advance := false
	var skip := false
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := (event as InputEventMouseButton).button_index
		advance = mb == MOUSE_BUTTON_LEFT
		skip = mb == MOUSE_BUTTON_RIGHT
	elif event is InputEventKey and (event as InputEventKey).echo:
		return
	else:
		for action in ["ui_accept", "interact", "shoot", "jump"]:
			if InputMap.has_action(action) and event.is_action_pressed(action):
				advance = true
		if InputMap.has_action("ui_cancel") and event.is_action_pressed("ui_cancel"):
			skip = true
			advance = false
	if skip:
		ScriptsEngine.key_pressed2 = true
	elif advance:
		ScriptsEngine.key_pressed = true
	else:
		return
	GameState.hold_until_released(event)
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _wait or not _hint.visible:
		return
	_blink += delta
	_hint.modulate.a = 0.55 + 0.45 * absf(cos(_blink * 3.0))


func _on_language(_lang: String) -> void:
	_relabel_hint()
	if _last.is_empty():
		return
	_dial_bb = ""
	_inform_bb = ""
	show_line(_last.line, false, bool(_last.wait), bool(_last.alicorn))


func _relabel_hint() -> void:
	_hint.text = Prompts.hint([["accept", Locale.t("story_next", "Next")], ["back", Locale.t("story_skip", "Skip")]])


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	_dial.size = DIAL_SIZE
	_dial.position = Vector2((view.x - DIAL_SIZE.x) * 0.5, view.y - DIAL_SIZE.y - 70.0)
	_dial_text.position = Vector2(172, 14)
	_dial_text.size = Vector2(DIAL_SIZE.x - 186, DIAL_SIZE.y - 28)
	_inform_text.position = Vector2(20, 16)
	_inform_text.size = Vector2(INFORM_W - 40, 0)
	_inform_text.fit_content = true
	var text_h := clampf(_inform_text.get_content_height(), 40.0, view.y * 0.6)
	_inform_text.fit_content = false
	_inform_text.size = Vector2(INFORM_W - 40, text_h)
	var inform_h := text_h + 32.0 + (28.0 if _ok.visible else 0.0)
	_inform.size = Vector2(INFORM_W, inform_h)
	_inform.position = Vector2((view.x - INFORM_W) * 0.5, (view.y - inform_h) * 0.5)
	_ok.position = Vector2(0, inform_h - 32.0)
	_ok.size = Vector2(INFORM_W, 24)
	var under: Control = _dial if _dial.visible else _inform
	_hint.size = Vector2(0, 0)
	_hint.reset_size()
	_hint.position = under.position + Vector2(under.size.x - _hint.size.x, under.size.y + 4.0)


func _panel() -> Panel:
	var p := Panel.new()
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL
	box.border_color = GREEN
	box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	p.add_theme_stylebox_override("panel", box)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.visible = false
	return p


func _rich() -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.scroll_active = true
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_color_override("default_color", GREEN)
	if _font != null:
		r.add_theme_font_override("normal_font", _font)
	r.add_theme_font_size_override("normal_font_size", 17)
	return r


func _portrait_tex(p: String) -> Texture2D:
	if p == "":
		return null
	var path := PORTRAITS % str(PORTRAIT_FILES.get(p, p))
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## [..] is the highlight span; anything else stays literal text.
func _bb(s: String) -> String:
	return s.replace("[", "\u0001").replace("]", "\u0002").replace("\u0001", "[color=#%s]" % YELLOW).replace("\u0002", "[/color]")
