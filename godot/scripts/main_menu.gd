extends Control

## MainMenu.as / visMainMenu (Zastavki/_mainMenu): background art, the five
## left-hand buttons (Продолжить, Загрузить, Начать новую игру, Настройки,
## Создатели), the info links block, site links and version bottom-left,
## language buttons bottom-right, and the dialNew / dialLoad / dialAbout
## dialogs. The Flash stage is not scaled: visMainMenu is laid out 1:1 for a
## 1920x1080 stage, so everything here sits on a Stage control in those
## coordinates, scaled to the viewport height. Dialog children use the
## visMainMenu-space positions (dialogs are authored at 750, 400).
## Управление, Выход, Enemy Lab and Map Builder are port extras, top right.

const GREEN := Color("00ff99")
const LINK := Color("66ff66")
const FOCUS := Color("8affd0")
const BACK := "res://assets/ui/menu/main_back.jpg"
const ART := "res://assets/ui/menu/mainmenu.png"
const LOGO := "res://assets/ui/menu/nazv.png"
const FONT := "res://theme/hud_sans.tres"
const PARTS := "res://assets/ui/menu/art/%s.png"
const STAGE_H := 1080.0
## visMainMenu places dialLoad / dialNew / dialAbout at this point.
const DIAL_AT := Vector2(750.0, 400.0)
const VERSION := "1.0"
## Main button glyph lift, as a fraction of the font height.
const MENU_TEXT_LIFT := 0.2
const _CURSOR := preload("res://assets/ui/cursor/arrow.png")
## dialNew checkOpt1..6, in MainMenu.mainStep's opt order.
const NEW_OPTS: PackedStringArray = ["propusk", "hardcore", "fastxp", "rndpump", "hardskills", "hardinv"]
## _dialNew checkOpt1..6 y (checkbox at x 910, infoOpt text from x 940).
const NEW_OPT_Y: Array[float] = [150.0, 252.0, 182.0, 285.0, 316.0, 347.0]
var _look
var _pip: Node
var _font: Font
var _menu_font: FontVariation
var _stage: Control
var _buttons: Array[Button] = []
var _dialog: Control
var _dbox: Control
var _dialog_focus: Array[Control] = []
var _back_to: Button
var _dif := 2
var _dif_buttons: Array[Button] = []
var _mode_info: Label
var _name_edit: LineEdit
var _lang_buttons: Array[Button] = []
var _opt_on: Array[bool] = [false, false, false, false, false, false]
const ADVICE := "res://assets/data/advice.json"
const ADV_COLOR := Color("01bd72")
static var _nadv := -1
static var _advice: Dictionary = {}
static var _inform: Dictionary = {}
var _adv: Button
var _pers: Node2D
var _displ: MenuDispl
## MainMenu.animOn: off while dialLoad or dialNew is open.
var _anim_on := true


func _ready() -> void:
	GameState.set_paused(false)
	UiSettings.apply_audio()
	AudioManager.play_menu()
	# The menu arrow; play scenes hide the OS cursor and draw it in aim_cursor.
	for shape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND]:
		Input.set_custom_mouse_cursor(_CURSOR, shape, Vector2.ZERO)
	_font = load(FONT)
	# Lucida Console widths, bundled: SteamOS has neither Lucida Console nor Consolas.
	_menu_font = FontVariation.new()
	_menu_font.base_font = load("res://theme/fonts/LiberationMono-Regular.ttf")
	_menu_font.fallbacks = [load("res://theme/OpenSans-Regular.ttf")]
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_build()
	get_viewport().size_changed.connect(_layout)
	_layout()
	UiNav.add_screen(self, {"default": func() -> Control: return _buttons[0] if not _buttons.is_empty() else null})
	Locale.language_changed.connect(_on_language)
	_buttons[0].grab_focus()


## Rebuilds the menu in the new language; an open PipBuck or appearance
## screen stays and relabels itself.
func _on_language(_lang: String) -> void:
	var focus := get_viewport().gui_get_focus_owner()
	var lang_at := _lang_buttons.find(focus)
	var at := _buttons.find(focus)
	_close_dialog()
	for child in _stage.get_children():
		_stage.remove_child(child)
		child.queue_free()
	_buttons.clear()
	_lang_buttons.clear()
	_build()
	_layout()
	if lang_at >= 0 and lang_at < _lang_buttons.size():
		_lang_buttons[lang_at].grab_focus()
	elif at >= 0 and at < _buttons.size():
		_buttons[at].grab_focus()


func _build() -> void:
	var black := ColorRect.new()
	black.name = "Black"
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(black)
	if _displ != null:
		_displ.queue_free()
	_displ = MenuDispl.new()
	add_child(_displ)
	var animated := _displ.has_parts()
	for path in [BACK, ART]:
		if ResourceLoader.exists(path):
			var art := TextureRect.new()
			art.texture = load(path)
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_stage.add_child(art)
		if animated:
			_stage.add_child(_displ.make_groza() if path == BACK else _displ.make_pipka())
	if ResourceLoader.exists(LOGO):
		var logo := TextureRect.new()
		logo.name = "Logo"
		logo.texture = load(LOGO)
		logo.position = Vector2(465, 0)
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.add_child(logo)
	# butContGame is full size; the other four are scaled 0.6.
	_menu_button(OriginalLines.gui("contgame"), Vector2(288.7, 88.85), 1.0, _on_continue)
	_menu_button(OriginalLines.gui("loadgame"), Vector2(208.7, 147.85), 0.6, _open_load)
	_menu_button(OriginalLines.gui("newgame"), Vector2(208.7, 190.85), 0.6, _open_new)
	_menu_button(OriginalLines.gui("options"), Vector2(208.7, 234.85), 0.6, _open_options)
	_menu_button(OriginalLines.gui("about"), Vector2(208.7, 277.8), 0.6, _open_about)
	# Port extra: Выход one step below Создатели, in the same style.
	_menu_button(Locale.t("menu_exit"), Vector2(208.7, 320.8), 0.6, func() -> void: get_tree().quit())
	_build_extras()
	_build_version()
	var langs := UiSettings.languages()
	if langs.size() > 1:
		var box := Control.new()
		box.name = "Lang"
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.add_child(box)
		# MainMenu: one 399 box per language, m.y = -i * 40.
		for i in langs.size():
			var lb := _box_button(Locale.language_name(langs[i]), Rect2(-129.4, -21.25 - 40.0 * i, 132, 34), 22)
			lb.pressed.connect(_set_lang.bind(langs[i]))
			box.add_child(lb)
			_lang_buttons.push_front(lb)
	_build_advice()
	UiNav.link_column(_buttons + [_adv] + _lang_buttons)


## Debug-only tools in the language-box style, top right. Управление is in
## PipBuck options (opt4), as in the original.
func _build_extras() -> void:
	var box := Control.new()
	box.name = "Extras"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(box)
	var extras := []
	# Dev scenes are left out of the tester pck, so their buttons follow the files.
	if OS.is_debug_build() and ResourceLoader.exists("res://scenes/enemy_lab.tscn"):
		extras.append([Locale.t("menu_enemy_lab"), func() -> void: get_tree().change_scene_to_file("res://scenes/enemy_lab.tscn")])
	if OS.is_debug_build() and ResourceLoader.exists("res://scenes/map_builder.tscn"):
		extras.append([Locale.t("menu_map_builder"), func() -> void: get_tree().change_scene_to_file("res://scenes/map_builder.tscn")])
	for i in extras.size():
		var b := _box_button(str(extras[i][0]), Rect2(-220.0, 40.0 * i, 220, 34), 18)
		var action: Callable = extras[i][1]
		b.pressed.connect(func() -> void:
			SfxBank.play("ui_click")
			action.call())
		box.add_child(b)
		_buttons.append(b)


## The main screen's info block (gui inform) and site links (l1, l2) are
## shown at the end of dialAbout instead (port layout). Links are #66FF66
## (MainMenu style "a").
func _links_text() -> String:
	var text := ""
	var data := _inform_data()
	if not data.is_empty():
		text += "[color=#%s]%s[/color]\n" % [GREEN.to_html(false), str(data["head"])]
		for link in data["links"]:
			text += "\n[url=%s][color=#%s]%s[/color][/url]" % [link[0], LINK.to_html(false), link[1]]
		text += "\n"
	for row in [["http://foe.ucoz.org", "foe.ucoz.org"], ["https://www.deviantart.com/empalu", "deviantart.com/empalu"]]:
		text += "\n[url=%s][color=#%s]%s[/color][/url]" % [row[0], LINK.to_html(false), row[1]]
	return text


## Version at stageHeight - 58, bold yellow.
func _build_version() -> void:
	var v := Label.new()
	v.name = "Version"
	v.text = "%s %s" % [OriginalLines.gui("version"), VERSION]
	var bold := FontVariation.new()
	bold.base_font = _font
	bold.variation_embolden = 0.8
	v.add_theme_font_override("font", bold)
	v.add_theme_font_size_override("font_size", 15)
	v.add_theme_color_override("font_color", Color("ffff00"))
	v.position = Vector2(86.1, 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(v)


## gui inform: the plain text reader keeps only the first <a>, so the block
## is read from the text pack directly.
func _inform_data() -> Dictionary:
	var lang := OriginalLines.language()
	if _inform.has(lang):
		return _inform[lang]
	var out := {}
	var path := "res://assets/data/text_%s.xml" % lang
	if FileAccess.file_exists(path):
		var src := FileAccess.get_file_as_string(path)
		var block := RegEx.create_from_string("id=['\"]inform['\"][\\s\\S]*?</gui>").search(src)
		if block:
			var s := block.get_string()
			var head := RegEx.create_from_string("<n>([\\s\\S]*?)</n>").search(s)
			var links: Array = []
			for m in RegEx.create_from_string("<a href=['\"]([^'\"]+)['\"]>([^<]+)</a>").search_all(s):
				links.append([m.get_string(1), m.get_string(2).strip_edges()])
			out = {"head": head.get_string(1).strip_edges() if head else "", "links": links}
	_inform[lang] = out
	return out


func _rich_style(t: RichTextLabel, size: int) -> void:
	if _font:
		t.add_theme_font_override("normal_font", _font)
	t.add_theme_font_size_override("normal_font_size", size)
	t.add_theme_color_override("default_color", GREEN)
	t.focus_mode = Control.FOCUS_NONE


## MainMenu adv: text_*.advice[nadv] at x 359, 648 wide, 40px off the bottom,
## Lucida Console 15. Click or Accept shows the next tip, right click the
## previous one; nadv steps once per launch (GameContainer init).
func _build_advice() -> void:
	if _advice.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(ADVICE)) if FileAccess.file_exists(ADVICE) else null
		if data is Dictionary:
			_advice = data
	if _nadv < 0:
		var saved := int(UiSettings.value("ui", "nadv", 0))
		_nadv = 0
		if saved > 0:
			_nadv = saved
			saved += 1
		else:
			saved = 1
		UiSettings.set_value("ui", "nadv", saved if saved < _advice_list().size() else 0)
	_adv = Button.new()
	_adv.name = "Advice"
	_adv.flat = true
	_adv.focus_mode = Control.FOCUS_ALL
	_adv.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_adv.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	_adv.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_adv.custom_minimum_size = Vector2(648, 0)
	_text_style(_adv, 15, ADV_COLOR)
	_adv.add_theme_font_override("font", _menu_font)
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "disabled"]:
		_adv.add_theme_stylebox_override(s, empty)
	_adv.add_theme_stylebox_override("focus", _focus_box())
	_adv.pressed.connect(_step_advice.bind(1))
	_adv.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
			_step_advice(-1)
		elif e.is_action_pressed("ui_left") or e.is_action_pressed("ui_right"):
			_step_advice(1 if e.is_action_pressed("ui_right") else -1)
			_adv.accept_event())
	_stage.add_child(_adv)
	_show_advice()


func _advice_list() -> Array:
	var lang := OriginalLines.language()
	return _advice.get(lang, _advice.get("en", [])) as Array


func _step_advice(d: int) -> void:
	var n := _advice_list().size()
	if n > 0:
		_nadv = posmod(_nadv + d, n)
	_show_advice()


func _show_advice() -> void:
	if _adv == null:
		return
	var list := _advice_list()
	_adv.text = str(list[clampi(_nadv, 0, list.size() - 1)]) if not list.is_empty() else ""
	_adv.reset_size()
	_layout()


func _menu_button(text: String, at: Vector2, scale_k: float, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var size := int(round(28.0 * scale_k))
	b.position = at + Vector2(-201.95, -15.85) * scale_k
	b.size = Vector2(367.95, 31.7) * scale_k
	# Lucida Console's box sits low on the butFon band; lift the glyphs to its middle.
	var centred := FontVariation.new()
	centred.base_font = _menu_font
	centred.baseline_offset = -(MENU_TEXT_LIFT + (1.0 - scale_k) * 0.3)
	b.add_theme_font_override("font", centred)
	b.add_theme_font_size_override("font_size", size)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.add_theme_color_override("font_outline_color", Color(GREEN, 0.55))
	b.add_theme_constant_override("outline_size", maxi(2, int(6 * scale_k)))
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(s, empty)
	var glow := _glow(scale_k)
	glow.position = Vector2(-188.5 - 42.5 * 0.7 + 201.95, -28.0 + 15.85) * scale_k
	b.add_child(glow)
	b.show_behind_parent = false
	glow.show_behind_parent = true
	b.focus_entered.connect(_glow_on.bind(glow, true))
	b.focus_exited.connect(_glow_on.bind(glow, false))
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	b.pressed.connect(func() -> void:
		SfxBank.play("ui_click")
		action.call())
	_stage.add_child(b)
	_buttons.append(b)
	return b


## butFon: shape 474, scaleX 0.7 (1.0 on over).
func _glow(scale_k: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = _tex("474")
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size = Vector2(431.0 * 0.7, 56.0) * scale_k
	r.set_meta("k", scale_k)
	return r


func _glow_on(glow: TextureRect, on: bool) -> void:
	var k := float(glow.get_meta("k", 1.0))
	glow.size.x = 431.0 * (1.0 if on else 0.7) * k
	glow.modulate.a = 1.5 if on else 1.0


func _text_style(b: Button, size: int, color: Color) -> void:
	if _font:
		b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", size)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		b.add_theme_color_override(c, color)


func _tex(id: String) -> Texture2D:
	var path := PARTS % id
	return load(path) if ResourceLoader.exists(path) else null


func _art(parent: Control, id: String, at: Vector2, size := Vector2.ZERO) -> TextureRect:
	var r := TextureRect.new()
	r.texture = _tex(id)
	r.position = at
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if size != Vector2.ZERO:
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.size = size
	parent.add_child(r)
	return r


func _tex_box(id: String, margin := 2.0) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = _tex(id)
	box.set_texture_margin_all(margin)
	return box


func _focus_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = FOCUS
	box.set_border_width_all(1)
	return box


## The 399 language box (white _sans text), also used for the port extras.
func _box_button(text: String, rect: Rect2, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.position = rect.position
	b.size = rect.size
	b.focus_mode = Control.FOCUS_ALL
	b.clip_text = true
	var fon := _tex_box("399")
	var lit := _tex_box("399")
	lit.modulate_color = Color(1.5, 1.5, 1.5)
	for s in ["normal", "disabled"]:
		b.add_theme_stylebox_override(s, fon)
	for s in ["hover", "pressed"]:
		b.add_theme_stylebox_override(s, lit)
	b.add_theme_stylebox_override("focus", _focus_box())
	_text_style(b, size, Color.WHITE)
	b.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	return b


func _layout() -> void:
	if _stage == null:
		return
	var view := get_viewport_rect().size
	var k := view.y / STAGE_H
	_stage.scale = Vector2(k, k)
	_stage.size = view / k
	var s := _stage.size
	var black := _stage.get_node_or_null("Black") as Control
	if black:
		black.size = s
	var lang := _stage.get_node_or_null("Lang") as Control
	if lang:
		lang.position = Vector2(s.x - 30.0, s.y - 50.0)
	var extras := _stage.get_node_or_null("Extras") as Control
	if extras:
		extras.position = Vector2(s.x - 30.0, 20.0)
	var version := _stage.get_node_or_null("Version") as Control
	if version:
		version.position.y = s.y - 58.0
	if _adv != null and is_instance_valid(_adv):
		_adv.position = Vector2(358.95, s.y - _adv.size.y - 40.0)
	if _dialog != null and is_instance_valid(_dialog):
		_place_dialog()


# --- Buttons ---

func _on_continue() -> void:
	var slot := SaveSlots.latest()
	if slot < 0:
		_open_new()
		return
	SaveSlots.request_load(slot)
	Travel.enter_game()


func _open_options() -> void:
	if _pip != null and is_instance_valid(_pip):
		return
	_pip = load("res://scenes/pipbuck.tscn").instantiate()
	_pip.menu_only = true
	_pip.closed.connect(func() -> void:
		_pip = null
		_buttons[3].grab_focus())
	add_child(_pip)


func _open_look() -> void:
	if _look == null:
		_look = preload("res://scripts/appearance_screen.gd").new()
		_look.closed.connect(_on_look_closed)
		add_child(_look)
	_look.open()


func _on_look_closed() -> void:
	if _dialog != null and is_instance_valid(_dialog):
		_dialog.visible = true
		if not _dialog_focus.is_empty():
			_dialog_focus[0].grab_focus()
		return
	_buttons[2].grab_focus()


func _set_lang(lang: String) -> void:
	SfxBank.play("ui_click")
	if lang == OriginalLines.language():
		return
	# Deferred: the rebuild frees the button that is emitting pressed.
	Locale.call_deferred("set_language", lang)


# --- Dialogs (mmDialFon, shape 495) ---

func _open_dialog(title: String, title_at: Vector2, title_w: float) -> Control:
	_close_dialog()
	_back_to = get_viewport().gui_get_focus_owner() as Button
	for b in _buttons + _lang_buttons:
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog = Control.new()
	_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	_stage.add_child(_dialog)
	UiNav.add_screen(_dialog, {"back": _close_dialog})
	_dbox = Control.new()
	_dbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog.add_child(_dbox)
	# 2 px scanlines band when scaled below 1:1; mipmaps average them instead.
	_art(_dbox, "495", Vector2(338.5, 67.4)).texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_dlabel(title, title_at, title_w, 20).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialog_focus.clear()
	_place_dialog()
	return _dbox


func _place_dialog() -> void:
	# setMenuSize: x = stageWidth/2, y = max(280, stageHeight - 400).
	var s := _stage.size
	_dialog.position = Vector2.ZERO
	_dialog.size = s
	_dbox.position = Vector2(s.x * 0.5, maxf(280.0, s.y - 400.0)) - DIAL_AT


func _close_dialog() -> void:
	if _dialog != null and is_instance_valid(_dialog):
		UiNav.remove_screen(_dialog)
		_dialog.visible = false
		_dialog.queue_free()
	_dialog = null
	_dbox = null
	_anim_on = true
	_dialog_focus.clear()
	_dif_buttons.clear()
	for b in _buttons + _lang_buttons:
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_filter = Control.MOUSE_FILTER_STOP
	if _back_to != null and is_instance_valid(_back_to):
		_back_to.grab_focus()
	elif not _buttons.is_empty():
		_buttons[0].grab_focus()


## A Flash text field: at is where its text starts (field x + 2 gutter).
func _dlabel(text: String, at: Vector2, width: float, size: int, parent: Control = null) -> Label:
	var l := Label.new()
	l.text = text
	if _font:
		l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", GREEN)
	l.position = at
	l.size = Vector2(width, size + 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent else _dbox).add_child(l)
	return l


## mmButton (508): shape 506 at scaleX 0.35, 186 x 28, _sans 20.
func _dbutton(text: String, rect: Rect2, action: Callable, size := 20, fon := "506") -> Button:
	var b := Button.new()
	b.text = text
	b.position = rect.position
	b.size = rect.size
	b.focus_mode = Control.FOCUS_ALL
	b.clip_text = true
	_skin(b, fon, size)
	b.mouse_entered.connect(func() -> void:
		if b.focus_mode != Control.FOCUS_NONE:
			b.grab_focus())
	b.pressed.connect(func() -> void:
		SfxBank.play("ui_click")
		action.call())
	_dbox.add_child(b)
	_dialog_focus.append(b)
	return b


func _skin(b: Button, fon: String, size: int) -> void:
	var normal := _tex_box(fon)
	var lit := _tex_box(fon)
	lit.modulate_color = Color(1.4, 1.4, 1.4)
	for s in ["normal", "disabled"]:
		b.add_theme_stylebox_override(s, normal)
	for s in ["hover", "pressed"]:
		b.add_theme_stylebox_override(s, lit)
	b.add_theme_stylebox_override("focus", _focus_box())
	if _font:
		b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", size)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, GREEN)
	b.add_theme_color_override("font_disabled_color", GREEN)


# --- dialNew ---

func _open_new() -> void:
	var d := _open_dialog(OriginalLines.gui("newgame"), Vector2(362.9, 84.4), 776)
	_anim_on = false
	_dlabel(OriginalLines.gui("inputname"), Vector2(613.1, 154.0), 270, 16).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_art(d, "517", Vector2(632.9, 185.9))
	_name_edit = LineEdit.new()
	_name_edit.text = str(UiSettings.value("game", "name", OriginalLines.unit("littlepip")))
	_name_edit.max_length = 20
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.position = Vector2(632.9, 185.9)
	_name_edit.size = Vector2(232, 30)
	if _font:
		_name_edit.add_theme_font_override("font", _font)
	_name_edit.add_theme_font_size_override("font_size", 20)
	_name_edit.add_theme_color_override("font_color", GREEN)
	_name_edit.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_name_edit.add_theme_stylebox_override("focus", _focus_box())
	d.add_child(_name_edit)
	_dialog_focus.append(_name_edit)
	_dif = UiSettings.difficulty()
	_dif_buttons.clear()
	# dif0..4: tile 524 (frame 2 = chosen) centred at 485.9, 177 + 60 i, 252 x 52.
	for i in 5:
		var b := _dbutton(OriginalLines.gui("dif%d" % i), Rect2(359.6, 151.0 + 60.0 * i, 252, 52), _pick_dif.bind(i), 20, "524_1")
		b.focus_entered.connect(_show_dif.bind(i))
		b.mouse_entered.connect(_show_dif.bind(i))
		_dif_buttons.append(b)
	# pers: the player's pony, registration 751.2, 352.8, scale 1.76.
	var pony: Array = preload("res://scripts/pony_puppet.gd").preview(Vector2(751.2, 352.8), 1.76, 4.0)
	d.add_child(pony[0])
	_pers = pony[1]
	var vid := _dbutton(OriginalLines.gui("butvid"), Rect2(622.8, 391.0, 252, 52), _new_look, 20, "524_1")
	vid.focus_entered.connect(func() -> void: _mode_info.text = "")
	_mode_info = _dlabel("", Vector2(355.1, 454.9), 790, 15)
	_mode_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mode_info.size.y = 125
	_dlabel(OriginalLines.gui("loadwarn"), Vector2(364.9, 591.5), 774, 16).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dlabel(OriginalLines.gui("hardopt"), Vector2(916.0, 219.9), 223, 16).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var checks: Array[CheckBox] = []
	for i in NEW_OPTS.size():
		checks.append(_opt_check(i, Vector2(910.0, NEW_OPT_Y[i])))
	# Screen order top to bottom: opt1, opt3, then under hardOpt opt2, opt4, opt5, opt6.
	var column: Array[CheckBox] = [checks[0], checks[2], checks[1], checks[3], checks[4], checks[5]]
	var cancel := _dbutton(OriginalLines.gui("cancel"), Rect2(547.9, 630.4, 186.2, 28), _close_dialog)
	var ok := _dbutton("OK", Rect2(765.9, 630.4, 186.2, 28), _start_new)
	_name_edit.focus_neighbor_bottom = _name_edit.get_path_to(_dif_buttons[0])
	_name_edit.focus_neighbor_left = _name_edit.get_path_to(_dif_buttons[0])
	_name_edit.focus_neighbor_right = _name_edit.get_path_to(column[0])
	for i in 5:
		var b := _dif_buttons[i]
		b.focus_neighbor_top = b.get_path_to(_dif_buttons[i - 1] if i > 0 else _name_edit)
		b.focus_neighbor_bottom = b.get_path_to(_dif_buttons[i + 1] if i < 4 else cancel)
		b.focus_neighbor_right = b.get_path_to(vid)
	for i in column.size():
		var cb := column[i]
		cb.focus_neighbor_top = cb.get_path_to(column[i - 1] if i > 0 else _name_edit)
		cb.focus_neighbor_bottom = cb.get_path_to(column[i + 1] if i < column.size() - 1 else ok)
		cb.focus_neighbor_left = cb.get_path_to(vid)
		cb.focus_neighbor_right = cb.get_path()
	vid.focus_neighbor_left = vid.get_path_to(_dif_buttons[_dif])
	vid.focus_neighbor_right = vid.get_path_to(column[0])
	vid.focus_neighbor_top = vid.get_path_to(_name_edit)
	vid.focus_neighbor_bottom = vid.get_path_to(ok)
	cancel.focus_neighbor_top = cancel.get_path_to(_dif_buttons[4])
	cancel.focus_neighbor_right = cancel.get_path_to(ok)
	ok.focus_neighbor_top = ok.get_path_to(column[column.size() - 1])
	ok.focus_neighbor_left = ok.get_path_to(cancel)
	_mark_dif()
	_dif_buttons[_dif].grab_focus()


## A Flash CheckBox (checkOpt, a 13 px green box, green tick when on, red cross when off) with its
## infoOpt label from x 940; hovering or focusing either shows the option's
## description (MainMenu.infoOpt).
func _opt_check(i: int, at: Vector2) -> CheckBox:
	var cb := CheckBox.new()
	cb.name = "CheckOpt%d" % (i + 1)
	cb.text = OriginalLines.gui("opt%d" % (i + 1))
	cb.position = at + Vector2(0, -2)
	cb.size = Vector2(232, 22)
	cb.focus_mode = Control.FOCUS_ALL
	cb.button_pressed = _opt_on[i]
	if _font:
		cb.add_theme_font_override("font", _font)
	cb.add_theme_font_size_override("font_size", 16)
	for col in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		cb.add_theme_color_override(col, GREEN)
	cb.add_theme_icon_override("checked", _check_icon(true))
	cb.add_theme_icon_override("unchecked", _check_icon(false))
	cb.add_theme_constant_override("h_separation", 17)
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		cb.add_theme_stylebox_override(s, empty)
	cb.add_theme_stylebox_override("focus", _focus_box())
	cb.toggled.connect(func(on: bool) -> void:
		SfxBank.play("ui_click")
		_opt_on[i] = on)
	cb.focus_entered.connect(_show_opt.bind(i))
	cb.mouse_entered.connect(_show_opt.bind(i))
	_dbox.add_child(cb)
	_dialog_focus.append(cb)
	return cb


func _check_icon(on: bool) -> ImageTexture:
	return CheckMark.icon(on, GREEN)


func _show_opt(i: int) -> void:
	if _mode_info != null and is_instance_valid(_mode_info):
		_mode_info.text = _one_spaced(OriginalLines.desc("gui", "opt%d" % (i + 1)))


func _show_dif(i: int) -> void:
	if _mode_info != null and is_instance_valid(_mode_info):
		_mode_info.text = _one_spaced(OriginalLines.desc("gui", "dif%d" % i))


## modeinfo holds 127 px; blank lines between paragraphs would run into warn.
func _one_spaced(s: String) -> String:
	var lines := PackedStringArray()
	for line in s.replace("\r", "").split("\n"):
		if line.strip_edges() != "":
			lines.append(line.strip_edges())
	return "\n".join(lines)


func _pick_dif(i: int) -> void:
	_dif = i
	_mark_dif()


func _mark_dif() -> void:
	for i in _dif_buttons.size():
		_skin(_dif_buttons[i], "524_2" if i == _dif else "524_1", 20)
	_show_dif(_dif)


func _new_look() -> void:
	_dialog.visible = false
	_open_look()


func _start_new() -> void:
	var who := _name_edit.text.strip_edges()
	if who == "":
		who = OriginalLines.unit("littlepip")
	UiSettings.set_value("game", "name", who)
	UiSettings.set_difficulty(_dif)
	for i in NEW_OPTS.size():
		UiSettings.set_value("game", NEW_OPTS[i], _opt_on[i])
	Travel.set_hardcore(_opt_on[1])
	UiSettings.set_value("game", "autosave_n", 0)
	if _opt_on[1]:
		_open_load(true)
		return
	_begin_new()


func _begin_new() -> void:
	GameState.reset_run()
	preload("res://scripts/intro_screen.gd").pending = not bool(UiSettings.value("game", "propusk", false))
	Travel.enter_game()


## Hardcore keeps its autosave in the slot picked here (MainMenu loadReg 1).
func _pick_auto_slot(slot: int) -> void:
	UiSettings.set_value("game", "autosave_n", slot)
	SaveSlots.clear(slot)
	_begin_new()


# --- dialLoad ---

## pick_auto: the hardcore autosave picker (title2 select_slot, no slot 0,
## free slots can be chosen). Rows slot0..10: back 498 (561 x 25) from
## 358.5, 142.5 + 30 n; nazv, ggName, land (right) and date (right) fields.
## butFile (load from file) is not ported.
func _open_load(pick_auto := false) -> void:
	_open_dialog(OriginalLines.gui("select_slot" if pick_auto else "loadgame"), Vector2(350.9, 95.4), 801)
	_anim_on = false
	if pick_auto:
		_back_to = _buttons[2]
	var first: Button = null
	for slot in range(1 if pick_auto else 0, SaveSlots.SLOTS + 1):
		var row := SaveSlots.info(slot)
		var action := _pick_auto_slot.bind(slot) if pick_auto else _load_slot.bind(slot)
		var b := _dbutton("", Rect2(358.5, 142.5 + 30.0 * slot, 561, 25), action, 16, "498")
		var nazv := OriginalLines.pip("autoslot") if slot == 0 else "%s %d" % [OriginalLines.pip("saveslot"), slot]
		if row.is_empty():
			_dlabel(OriginalLines.pip("freeslot"), Vector2(10, 3.6), 300, 16, b)
		else:
			_dlabel(nazv, Vector2(10, 3.6), 92, 16, b)
			var who := "%s (%d)" % [str(row.get("name", "")), int(row.get("level", 1))]
			if bool(row.get("dead", false)):
				who += " [†]"
			elif bool(row.get("hardcore", false)):
				who += " {!}"
			_dlabel(who, Vector2(109.5, 3.6), 120, 16, b).clip_text = true
			var land := _dlabel(SaveSlots.land_name(row), Vector2(230.0, 3.6), 169, 16, b)
			land.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			land.clip_text = true
			_dlabel(_slot_date(str(row.get("date", ""))), Vector2(419.0, 3.6), 137, 16, b).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.disabled = row.is_empty() and not pick_auto
		if b.disabled:
			b.focus_mode = Control.FOCUS_NONE
		elif first == null:
			first = b
	_dlabel(OriginalLines.gui("loadwarn"), Vector2(362.2, 490.5), 557, 16).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cancel := _dbutton(OriginalLines.gui("cancel"), Rect2(666.9, 612.4, 186.2, 28), _close_dialog)
	_link_vertical()
	if first:
		first.grab_focus()
	else:
		cancel.grab_focus()


## PipPageOpt date: "Y.M.D H:MM" from the saved "Y-M-D HH:MM:SS".
func _slot_date(raw: String) -> String:
	var parts := raw.split(" ")
	if parts.size() < 2:
		return raw.replace("-", ".")
	var hm := parts[1].split(":")
	if hm.size() < 2:
		return raw.replace("-", ".")
	return "%s  %d:%s" % [parts[0].replace("-", "."), int(hm[0]), hm[1]]


func _link_vertical() -> void:
	var live: Array[Control] = []
	for c in _dialog_focus:
		if c.focus_mode != Control.FOCUS_NONE:
			live.append(c)
	for i in live.size():
		var c := live[i]
		c.focus_neighbor_top = c.get_path_to(live[posmod(i - 1, live.size())])
		c.focus_neighbor_bottom = c.get_path_to(live[posmod(i + 1, live.size())])
		c.focus_neighbor_left = c.get_path()
		c.focus_neighbor_right = c.get_path()


func _load_slot(slot: int) -> void:
	SaveSlots.request_load(slot)
	Travel.enter_game()


# --- dialAbout ---

func _open_about() -> void:
	var d := _open_dialog(OriginalLines.gui("about"), Vector2(364.9, 86.4), 774)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(364.9, 137.0)
	scroll.size = Vector2(770, 462)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	d.add_child(scroll)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	scroll.add_child(column)
	var text := Label.new()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(748, 0)
	if _font:
		text.add_theme_font_override("font", _font)
	text.add_theme_font_size_override("font_size", 16)
	text.add_theme_color_override("font_color", GREEN)
	text.text = OriginalLines.desc("gui", "about").replace("[", "").replace("]", "") \
		+ "\n\n" + OriginalLines.gui("usedmusic") + "\n" + OriginalLines.desc("gui", "usedmusic")
	column.add_child(text)
	var links := RichTextLabel.new()
	links.bbcode_enabled = true
	links.meta_underlined = false
	links.fit_content = true
	links.scroll_active = false
	links.custom_minimum_size = Vector2(748, 0)
	_rich_style(links, 16)
	links.text = _links_text()
	links.meta_clicked.connect(func(meta: Variant) -> void: OS.shell_open(str(meta)))
	column.add_child(links)
	var close := _dbutton(OriginalLines.pip("mainclose"), Rect2(656.6, 624.5, 186.2, 28), _close_dialog)
	close.grab_focus()
	_back_to = _buttons[4]
	_dialog.set_meta("scroll", scroll)


func _exit_tree() -> void:
	for shape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND]:
		Input.set_custom_mouse_cursor(null, shape)


func _process(delta: float) -> void:
	if _displ != null:
		_displ.playing = _anim_on and not (_pip != null and is_instance_valid(_pip))
	if _pers != null and is_instance_valid(_pers) and _pers.is_visible_in_tree():
		_pers.update_pose("idle", 1.0, Vector2.RIGHT, delta)


# --- Input ---

func _input(event: InputEvent) -> void:
	if _look != null and _look.is_open():
		return
	if ControlsUI.is_open():
		return
	if _pip != null and is_instance_valid(_pip):
		return
	if _dialog != null and is_instance_valid(_dialog) and _dialog.visible:
		if _dialog.has_meta("scroll") and (event.is_action_pressed("ui_up", true) or event.is_action_pressed("ui_down", true)) and not event is InputEventJoypadMotion:
			var scroll := _dialog.get_meta("scroll") as ScrollContainer
			scroll.scroll_vertical += 40 if event.is_action_pressed("ui_down", true) else -40
			get_viewport().set_input_as_handled()
