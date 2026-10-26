extends CanvasLayer
## GUI.impMess: the important-item window. ItemInteraction.take opens it once
## per mess id (trigger mess_<id>) while helpMess is on, or always for art.
## It pauses the game (guiPause) and closes on the first key, button or click
## after t_bulb (30 ticks). Title, icon and text sit where GUI.imp has them.

const DATA := "res://assets/data/item_mess.json"
const DIR := "res://assets/ui/imp/"
const FONT := "res://theme/hud_sans.tres"
const NODE_NAME := "ImpMess"
const BULB := 1.0
const TITLE_COLOR := Color("00ff99")
const YELLOW := "ffff66"
const _StoryText := preload("res://scripts/story/story_text.gd")

static var _data: Dictionary = {}

var _left := BULB
var _was_paused := false
var _root: Control


## GameContainer.helpMess (settings: help).
static func help_on() -> bool:
	return bool(UiSettings.value("game", "help", true))


## ItemInteraction.take: the window for an item whose items.xml row has mess.
static func item_taken(tree: SceneTree, item_id: String) -> void:
	_ensure()
	var row: Dictionary = (_data.get("items", {}) as Dictionary).get(item_id, {})
	var mess := str(row.get("mess", ""))
	if mess == "" or not (help_on() or bool(row.get("art", false))):
		return
	if int(Travel.triggers.get("mess_" + mess, 0)) > 0:
		return
	Travel.set_trigger("mess_" + mess, 1)
	show_mess(tree, mess)


static func show_mess(tree: SceneTree, mess: String) -> void:
	_ensure()
	var texts: Dictionary = _data.get("text", {})
	var lang: Dictionary = texts.get(OriginalLines.language(), texts.get("en", {}))
	var row: Dictionary = lang.get(mess, {})
	if row.is_empty() or tree == null:
		return
	var old := tree.root.get_node_or_null(NODE_NAME)
	if old != null:
		old.queue_free()
	var w := new()
	w.name = NODE_NAME
	tree.root.add_child(w)
	w.call("_open", str(row.get("title", "")), _body(row), mess)


static func is_open(tree: SceneTree) -> bool:
	return tree != null and tree.root.get_node_or_null(NODE_NAME) != null


static func _body(row: Dictionary) -> String:
	var s: String = _StoryText.add_keys(str(row.get("text", "")), row.get("keys", {}))
	s = s.replace("[br]", "\n")
	return s.replace("[", "\u0001").replace("]", "\u0002").replace("\u0001", "[color=#%s]" % YELLOW).replace("\u0002", "[/color]")


static func _ensure() -> void:
	if _data.is_empty() and FileAccess.file_exists(DATA):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		if parsed is Dictionary:
			_data = parsed


func _open(title: String, body: String, mess: String) -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_paused = GameState.paused
	GameState.set_paused(true)
	var font: Font = load(FONT) if ResourceLoader.exists(FONT) else null
	var anchors: Dictionary = {}
	if FileAccess.file_exists(DIR + "anchors.json"):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + "anchors.json"))
		if parsed is Dictionary:
			anchors = parsed
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var view := _root.get_viewport_rect().size
	var center := Vector2(roundf(view.x * 0.5), roundf(view.y * 0.5 - 50.0))
	var back := TextureRect.new()
	back.texture = load(DIR + "back.png")
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.position = center - _anchor(anchors, "back")
	_root.add_child(back)
	var title_l := Label.new()
	title_l.text = title
	title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_l.size = Vector2(428, 30)
	title_l.position = center + Vector2(-214, -236)
	if font:
		title_l.add_theme_font_override("font", font)
	title_l.add_theme_font_size_override("font_size", 20)
	title_l.add_theme_color_override("font_color", TITLE_COLOR)
	_root.add_child(title_l)
	var ico_y := -195.0
	var ico_h := 0.0
	var ico_path := DIR + "ico_%s.png" % mess
	if ResourceLoader.exists(ico_path):
		var ico := TextureRect.new()
		ico.texture = load(ico_path)
		ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ico.position = center + Vector2(0, ico_y) - _anchor(anchors, "ico_" + mess)
		ico_h = ico.texture.get_size().y
		_root.add_child(ico)
	var txt := RichTextLabel.new()
	txt.bbcode_enabled = true
	txt.fit_content = true
	txt.scroll_active = false
	txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	txt.focus_mode = Control.FOCUS_NONE
	txt.text = body
	txt.position = center + Vector2(-214, ico_y + ico_h + 15.0)
	txt.size = Vector2(428, 0)
	if font:
		txt.add_theme_font_override("normal_font", font)
	txt.add_theme_font_size_override("normal_font_size", 15)
	txt.add_theme_color_override("default_color", Color(0.85, 1.0, 0.9))
	_root.add_child(txt)
	var hint := Label.new()
	hint.text = Prompts.ui("accept")
	hint.position = center + Vector2(160, 300)
	if font:
		hint.add_theme_font_override("font", font)
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", TITLE_COLOR)
	_root.add_child(hint)
	for label: Control in [title_l, hint]:
		label.focus_mode = Control.FOCUS_NONE
	UiNav.add_screen(_root, {"back": _close})
	SfxBank.play("quest")


func _anchor(anchors: Dictionary, key: String) -> Vector2:
	var a: Variant = anchors.get(key, [0, 0])
	return Vector2(float(a[0]), float(a[1])) if a is Array and (a as Array).size() >= 2 else Vector2.ZERO


func _process(delta: float) -> void:
	_left = maxf(0.0, _left - delta)


func _input(event: InputEvent) -> void:
	if _root == null:
		return
	var press := (event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo) \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
		or (event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed)
	if not press:
		return
	get_viewport().set_input_as_handled()
	if _left <= 0.0:
		_close()


func _close() -> void:
	if _root == null:
		return
	UiNav.remove_screen(_root)
	_root = null
	if not _was_paused:
		GameState.set_paused(false)
	queue_free()
