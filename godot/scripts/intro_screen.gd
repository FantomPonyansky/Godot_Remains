extends CanvasLayer
## World.setLoadScreen(0): a new game without the propusk option opens on the
## vstup picture with gui "story"; the run starts on a click
## (waitLoadClick / clickReq). The world is paused meanwhile.

const PICTURE := "res://assets/ui/menu/vstup.jpg"
const FONT := "res://theme/hud_sans.tres"
const GREEN := Color("00ff99")
## visualWait.story: the vstup bitmap (shape 385) at the origin, txt at (56, 46.95),
## lmb (sprite 390, registration 0.5, 0.5, 18.7 x 13) at (54.4, 574.35) scaled 1.713.
const STAGE := Vector2(1350, 900)
const LMB_AT := Vector2(53.54, 573.49)
const LMB_SIZE := Vector2(32.03, 22.27)
const _LMB_ON := preload("res://assets/ui/lmb/on.png")
const _LMB_OFF := preload("res://assets/ui/lmb/off.png")

## MainMenu.mainStep: set for "new" without checkOpt1, read by Travel.begin_run.
static var pending := false

var _stage: Control
var _hint: Label
var _lmb: TextureRect
var _back: TextureRect
var _t := 0.0


## Until the land is loaded the story cannot be clicked away and shows no hint.
var _loading := true


static func show_if_pending(tree: SceneTree) -> void:
	if not pending:
		return
	pending = false
	tree.root.add_child.call_deferred(load("res://scripts/intro_screen.gd").new())


## World.setLoadScreen(0) replaces the ordinary load screen for a new game.
static func show_now(tree: SceneTree) -> void:
	pending = false
	tree.root.add_child(load("res://scripts/intro_screen.gd").new())


## Travel.hide_load_screen: loading is over, waitLoadClick starts.
static func loaded(tree: SceneTree) -> void:
	for node in tree.get_nodes_in_group("intro_screen"):
		node.call("_on_loaded")


func _on_loaded() -> void:
	if not _loading:
		return
	_loading = false
	GameState.set_paused(true)
	_refresh_hint()


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("intro_screen")
	var font: Font = load(FONT)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.focus_mode = Control.FOCUS_ALL
	add_child(root)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(black)
	_stage = Control.new()
	_stage.size = STAGE
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_stage)
	_back = TextureRect.new()
	_back.size = STAGE
	_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(PICTURE):
		_back.texture = load(PICTURE)
	_stage.add_child(_back)
	# Bundled Arial-metric font: SteamOS has no Arial, and its stand-in is wider.
	var italic := FontVariation.new()
	italic.base_font = load("res://theme/fonts/LiberationSans-Italic.ttf")
	if font != null:
		italic.fallbacks = [font]
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.position = Vector2(56, 46.95)
	text.size = Vector2(422.9, 583)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.scroll_active = false
	text.add_theme_font_override("normal_font", italic)
	text.add_theme_font_override("italics_font", italic)
	text.add_theme_font_size_override("normal_font_size", 14)
	text.add_theme_font_size_override("italics_font_size", 14)
	# Flash _sans 14 with leading 2 steps 20 px per line in the original.
	text.add_theme_constant_override("line_separation", 2)
	text.add_theme_color_override("default_color", GREEN)
	# gui "story" is missing from the extracted text_*.xml; port_strings carries it.
	var story := OriginalLines.gui("story")
	if story == "" or story == "story":
		story = Locale.t("intro_story", "")
	# htmlText: every line break in the gui text is a paragraph, drawn with a blank line.
	text.text = "[i]%s[/i]" % story.replace("[", "[lb]").replace("\r", "").replace("\n", "\n\n")
	_stage.add_child(text)
	_lmb = TextureRect.new()
	_lmb.position = LMB_AT
	_lmb.size = LMB_SIZE
	_lmb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_lmb.texture = _LMB_ON
	_lmb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_lmb)
	_hint = Label.new()
	if font != null:
		_hint.add_theme_font_override("font", font)
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", GREEN)
	_hint.position = LMB_AT + Vector2(LMB_SIZE.x + 8, -4)
	_hint.size = Vector2(300, 30)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_hint)
	_refresh_hint()
	Prompts.device_changed.connect(func(_pad: bool) -> void: _refresh_hint())
	get_viewport().size_changed.connect(_fit)
	_fit()
	UiNav.add_screen(root, {"default": root, "back": _done})
	root.grab_focus()
	GameState.set_paused(true)


## story.lmb shows and plays once loading is over (waitLoadClick). The pad
## prompt beside it is a port extra.
func _refresh_hint() -> void:
	_lmb.visible = not _loading
	_hint.text = Prompts.ui("accept") if Prompts.pad and not _loading else ""


## lmb: 30 frames at 30 fps, 1-15 with the left button lit, 16-30 unlit.
func _process(delta: float) -> void:
	_t = fmod(_t + delta, 1.0)
	_lmb.texture = _LMB_ON if _t < 0.5 else _LMB_OFF


func _input(event: InputEvent) -> void:
	if _loading:
		if event is InputEventMouseButton or event is InputEventKey or event is InputEventJoypadButton:
			get_viewport().set_input_as_handled()
		return
	var click: bool = event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	if click or event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_done()


func _done() -> void:
	if is_queued_for_deletion() or _loading:
		return
	GameState.set_paused(false)
	queue_free()


func _fit() -> void:
	var view := get_viewport().get_visible_rect().size
	var s := minf(view.x / STAGE.x, view.y / STAGE.y)
	_stage.scale = Vector2(s, s)
	_stage.position = (view - STAGE * s) * 0.5
