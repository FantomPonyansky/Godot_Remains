extends Control
## Stand.as: the base weapon stand (Interact allact stand). Nine pages
## (gui stand0-8): weapons by skill, armour, the six arts. Owned weapons show
## their name and a gold star (brighter with the unique variant); a click
## leaves a weapon, armour or amulet on the stand or takes it back
## (storeWeapon / storeArmor), stored ones are dim. Laid out in the
## original 1200×800 space and scaled like Stand.resizeScreen.
## Gamepad (UiNav): A toggles, B closes, LB/RB switch the page.

signal closed

const GREEN := Color("00ff99")
const DARK := Color("007e4b")
const GOLD := Color("ffcc00")
const BUT := Color("004629")
const BUT_ON := Color("006d40")
const FONT := "res://theme/hud_sans.tres"
const DATA := "res://assets/data/trade.json"
const WEAPON_ICONS := "res://assets/sprites/loot/weapons/%s.png"
const ITEM_ICONS := "res://assets/sprites/loot/items/%s.png"
const PAGES := 9
const LEVELS := 6
const ARTS: PackedStringArray = ["stat_aj", "stat_tw", "stat_fl", "stat_rr", "stat_rd", "stat_pp"]

var page := 0
var _font: Font
var _stage: Control
var _buttons: Array[Button] = []
var _pages: Array[Control] = []
var _scroll: ScrollContainer
var _holder: Control
var _top: Label
var _bottom: Label
var _info: Label
var _close_button: Button
var _cells: Dictionary = {}
var _weapons: Dictionary = {}
var _armors: Dictionary = {}


static func open(tree: SceneTree) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var screen: Control = load("res://scripts/stand_screen.gd").new()
	layer.add_child(screen)
	tree.root.add_child(layer)
	GameState.set_paused(true)
	screen.closed.connect(func() -> void:
		GameState.set_paused(false)
		layer.queue_free())


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = load(FONT)
	_load()
	_build()
	get_viewport().size_changed.connect(_fit)
	_fit()
	UiNav.add_screen(self, {"default": _default_focus, "back": _close, "tabs": _cycle})
	_show(page)


func _load() -> void:
	var file := FileAccess.open(DATA, FileAccess.READ)
	if file == null:
		return
	var doc: Variant = JSON.parse_string(file.get_as_text())
	if doc is Dictionary:
		_weapons = (doc as Dictionary).get("weapons", {})
		_armors = (doc as Dictionary).get("armors", {})


func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.85)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_stage = Control.new()
	_stage.size = Vector2(1200, 800)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	var fon := ColorRect.new()
	fon.color = Color(0.0, 0.1, 0.06, 0.92)
	fon.size = _stage.size
	fon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(fon)
	for i in PAGES:
		var b := _button(OriginalLines.gui("stand%d" % i), Rect2(20, 25 + 75 * i, 160, 66), 18)
		b.pressed.connect(_on_page.bind(i))
		_buttons.append(b)
	_close_button = _button(OriginalLines.gui("close"), Rect2(20, 725, 160, 50), 18)
	_close_button.pressed.connect(_close)
	_top = _label(16, GREEN)
	_top.position = Vector2(200, 4)
	_top.size = Vector2(980, 30)
	_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(200, 34)
	_scroll.size = Vector2(980, 700)
	_stage.add_child(_scroll)
	_holder = Control.new()
	_holder.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(_holder)
	for i in PAGES:
		var p := Control.new()
		p.visible = false
		p.mouse_filter = Control.MOUSE_FILTER_PASS
		_pages.append(p)
		_holder.add_child(p)
	for n in LEVELS:
		_weapon_list(n)
	_armor_list(6)
	_armor_list(7)
	_art_list(8)
	_bottom = _label(16, GREEN)
	_bottom.position = Vector2(200, 742)
	_bottom.size = Vector2(980, 50)
	_info = _label(15, GREEN)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.size = Vector2(300, 0)
	_info.visible = false
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.0, 0.16, 0.1, 0.95)
	box.border_color = GREEN
	box.set_border_width_all(1)
	box.set_content_margin_all(8)
	_info.add_theme_stylebox_override("normal", box)
	_info.z_index = 5


func _skill_ok(n: int, skill: int) -> bool:
	return (n == 0 and skill == 1) or (n == 1 and skill == 2) or (n == 2 and skill == 4) \
		or (n == 3 and skill == 5) or (n == 4 and skill == 3) or (n == 5 and skill >= 6)


## Stand.createWeaponLists: a column per weapon level; spells roll through them.
func _weapon_list(n: int) -> void:
	var levels := [0, 0, 0, 0, 0, 0, 0]
	var col := -1
	var bottom := 0.0
	for id: String in _weapons:
		var w: Dictionary = _weapons[id]
		if int(w.get("tip", 0)) <= 0 or w.has("nostand") or not _skill_ok(n, int(w.get("skill", 0))):
			continue
		var spell := int(w.get("tip", 0)) == 5
		if spell:
			col = (col + 1) % LEVELS
		else:
			col = clampi(int(w.get("lvl", 0)), 0, LEVELS)
		levels[col] += 1
		var y: float = 40.0 + int(levels[col]) * (140.0 if spell else 100.0) - 100.0
		var cell := _cell(n, id, Vector2(col * 160.0, y), WEAPON_ICONS if not spell else ITEM_ICONS)
		cell.set_meta("weapon", true)
		cell.pressed.connect(_on_weapon.bind(id))
		bottom = maxf(bottom, y + 96.0)
	_pages[n].custom_minimum_size = Vector2(980, bottom)


func _armor_list(n: int) -> void:
	var col := 0
	var row := 0
	for id: String in _armors:
		var a: Dictionary = _armors[id]
		if (n == 6 and int(a.get("tip", 1)) != 1) or (n == 7 and int(a.get("tip", 1)) != 3):
			continue
		var cell := _cell(n, id, Vector2(col * 160.0, row * 120.0), "")
		cell.pressed.connect(_on_armor.bind(id))
		col += 1
		if col >= LEVELS:
			col = 0
			row += 1
	_pages[n].custom_minimum_size = Vector2(980, (row + 1) * 120.0)


func _art_list(n: int) -> void:
	for i in ARTS.size():
		_cell(n, ARTS[i], Vector2(i * 160.0, 0), ITEM_ICONS)
	_pages[n].custom_minimum_size = Vector2(980, 120)


func _cell(n: int, id: String, at: Vector2, icons: String) -> Button:
	var b := Button.new()
	b.position = at + Vector2(4, 4)
	b.size = Vector2(150, 94)
	b.focus_mode = Control.FOCUS_ALL
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.0, 0.25, 0.15, 0.35) if state in ["normal", "disabled"] else Color(0.0, 0.43, 0.25, 0.5)
		box.border_color = GREEN
		box.set_border_width_all(1 if state in ["hover", "focus"] else 0)
		b.add_theme_stylebox_override(state, box)
	var icon := TextureRect.new()
	icon.position = Vector2(10, 6)
	icon.size = Vector2(130, 56)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icons != "" and ResourceLoader.exists(icons % id):
		icon.texture = load(icons % id)
	b.add_child(icon)
	var name := _label(13, GREEN, b)
	name.position = Vector2(2, 64)
	name.size = Vector2(146, 28)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.clip_text = true
	var star := Polygon2D.new()
	var points := PackedVector2Array()
	for k in 10:
		points.append(Vector2.from_angle(-PI / 2.0 + k * PI / 5.0) * (9.0 if k % 2 == 0 else 4.0))
	star.polygon = points
	star.color = GOLD
	star.position = Vector2(14, 14)
	b.add_child(star)
	b.set_meta("id", id)
	b.set_meta("icon", icon)
	b.set_meta("name", name)
	b.set_meta("star", star)
	b.focus_entered.connect(_on_focus.bind(b))
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	b.focus_exited.connect(func() -> void: _info.visible = false)
	_pages[n].add_child(b)
	_cells[id] = b
	return b


## Stand.ownedWeapon: carried or on the stand (a spell only once learned).
func _has(id: String) -> bool:
	return Inventory.count(id) > 0


## Stand.shownWeapon: the carried one (the unique variant first), otherwise
## the one on the stand. [id, 1 plain / 2 unique, 0 none].
func _owned(id: String) -> Array:
	var u := id + "^1"
	if _has(u) and not Stash.is_hidden(u):
		return [u, 2]
	if _has(id) and not Stash.is_hidden(id):
		return [id, 1]
	if _has(u):
		return [u, 2]
	if _has(id):
		return [id, 1]
	return ["", 0]


## Stand.showWeaponList.
func _show(n: int) -> void:
	page = n
	for i in PAGES:
		_pages[i].visible = i == n
		_skin_button(_buttons[i], BUT_ON if i == n else BUT, 18)
	_holder.custom_minimum_size = _pages[n].custom_minimum_size
	_top.visible = n <= 7
	_top.text = OriginalLines.pip("infostand").replace("@", " ") if n <= 5 else Locale.t("pip_infostand3", "")
	for id: String in _cells:
		var b: Button = _cells[id]
		if not _pages[n].is_ancestor_of(b):
			continue
		var name: Label = b.get_meta("name")
		var star: Polygon2D = b.get_meta("star")
		var icon: TextureRect = b.get_meta("icon")
		if b.has_meta("weapon"):
			var own := _owned(id)
			var v := int(own[1])
			star.visible = v > 0
			star.modulate = Color.WHITE if v == 2 else Color(0.75, 0.75, 0.75)
			name.visible = v > 0
			name.text = Inventory.name_of(str(own[0])) if v > 0 else ""
			# showFamily: the brighter star when the unique variant is owned.
			star.modulate = Color.WHITE if _has(id + "^1") else Color(0.75, 0.75, 0.75)
			var hidden := v > 0 and Stash.is_hidden(str(own[0]))
			icon.modulate = Color(0.0, 0.35, 0.2, 0.55) if v == 0 else Color(1, 1, 1, 0.5 if hidden else 1.0)
			name.modulate.a = 0.35 if hidden else 1.0
		else:
			var have := Inventory.count(id) > 0
			var stored := have and Stash.is_stored(id)
			name.visible = have
			name.text = Inventory.name_of(id)
			name.modulate.a = 0.35 if stored else 1.0
			star.visible = false
			icon.modulate = Color(0.0, 0.35, 0.2, 0.55) if not have else Color(1, 1, 1, 0.5 if stored else 1.0)
	_show_mass()
	_scroll.scroll_vertical = 0


func _show_mass() -> void:
	_bottom.text = ""
	if Inventory.hard_inv():
		if page <= 4:
			_bottom.text = Stash.ret_mass(4)
		elif page == 5:
			_bottom.text = Stash.ret_mass(5)
	if Prompts.pad:
		_bottom.text += ("\n" if _bottom.text != "" else "") + Prompts.hint([["accept", OriginalLines.pip("choose")], ["back", OriginalLines.gui("close")]])


func _on_page(i: int) -> void:
	SfxBank.play("ui_click")
	_show(i)


func _cycle(step: int) -> void:
	_show(posmod(page + step, PAGES))
	_buttons[page].grab_focus()


## Stand.itemClick: storeWeapon. With both variants the clicks go carry both
## -> store the plain one -> swap them -> store both -> carry both.
func _on_weapon(id: String) -> void:
	var u := id + "^1"
	var base := _has(id)
	var unique := _has(u)
	if not base and not unique:
		return
	SfxBank.play("ui_click")
	if not base or not unique:
		var w := id if base else u
		_store(w, not Stash.is_hidden(w))
	else:
		var base_stored := Stash.is_hidden(id)
		var unique_stored := Stash.is_hidden(u)
		if not base_stored and not unique_stored:
			_store(id, true)
		elif base_stored and not unique_stored:
			_store(u, true)
			_store(id, false)
		elif not base_stored and unique_stored:
			_store(id, true)
		else:
			_store(id, false)
			_store(u, false)
	_show(page)
	(_cells[id] as Button).grab_focus()


func _store(id: String, stored: bool) -> void:
	if Stash.is_hidden(id) != stored:
		Stash.toggle_hidden(id)


## Stand.armorClick: storeArmor.
func _on_armor(id: String) -> void:
	if Inventory.count(id) <= 0:
		return
	SfxBank.play("ui_click")
	if Stash.store_armor(id, not Stash.is_stored(id)):
		_show(page)
	(_cells[id] as Button).grab_focus()


## Stand.itemOver / itemOver2: the info box beside an owned item.
func _on_focus(b: Button) -> void:
	var id := str(b.get_meta("id"))
	var name: Label = b.get_meta("name")
	if not name.visible:
		_info.visible = false
		return
	var key := str(_owned(id)[0]) if b.has_meta("weapon") else id
	var desc := OriginalLines.desc_of(key)
	if desc == "":
		desc = OriginalLines.desc_of(id)
	_info.text = name.text + ("\n\n" + desc if desc != "" else "")
	_info.reset_size()
	var at := b.get_global_transform_with_canvas().origin
	var local := _stage.get_global_transform_with_canvas().affine_inverse() * at
	var x := local.x + 160.0
	if x + _info.size.x > 1190.0:
		x = local.x - 10.0 - _info.size.x
	_info.position = Vector2(x, clampf(local.y - 20.0, 10.0, 790.0 - _info.size.y))
	_info.visible = true


func _default_focus() -> Control:
	return _buttons[page]


func _close() -> void:
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		_close()
		get_viewport().set_input_as_handled()


func _fit() -> void:
	var view := get_viewport_rect().size
	if view.x >= 1200.0 and view.y >= 800.0:
		_stage.scale = Vector2.ONE
		_stage.position = (view - Vector2(1200, 800)) * 0.5
	else:
		var s := minf(view.x / 1200.0, view.y / 800.0)
		_stage.scale = Vector2(s, s)
		_stage.position = Vector2((view.x - 1200.0 * s) * 0.5, 0.0)


func _label(size: int, color: Color, parent: Node = null) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else _stage).add_child(l)
	return l


func _button(text: String, rect: Rect2, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.position = rect.position
	b.size = rect.size
	b.focus_mode = Control.FOCUS_ALL
	b.clip_text = true
	_skin_button(b, BUT, size)
	_stage.add_child(b)
	return b


func _skin_button(b: Button, fill: Color, size: int) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = fill if state in ["normal", "disabled"] else BUT_ON
		box.border_color = GREEN
		box.set_border_width_all(1)
		b.add_theme_stylebox_override(state, box)
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", GREEN)
	b.add_theme_color_override("font_focus_color", GREEN)
	b.add_theme_color_override("font_hover_color", GREEN)
