extends Control
## PipBuck (PipBuck.as + PipPage*.as, LIBRARY/PipBuck in pfe.fla), laid out in
## the original 1200×800 space and scaled like PipBuck.resizeScreen.
## Pages: Статус, Инвентарь, Информация, Меню. but4 is the contextual page the
## PipBuck was opened at: Торговля 4, Лечение 6, Ремесло 7 or Хранилище 9
## (scripts/pip_trade.gd).
## Gamepad (UiNav): A accepts, B closes, LB/RB switch the subpage, LT/RT
## page the list, X is the row's second action (drop, or bind a quick-spell key),
## Y the third (take all on trade rows, hide a weapon).

signal closed
signal to_main_menu

const GREEN := Color("00ff99")
const DARK := Color("007e4b")
const LIGHT := Color("8affd0")
const RED := Color("ff3333")
const ORANGE := Color("ff9900")
const YELLOW := Color("ffff33")
const PINK := Color("fc7fed")
const BUT := Color("004629")
const BUT_ON := Color("006d40")
const ROW := Color("004127")
const FON_IN := Color("03513e")
const FON_OUT := Color("393939")
const SKIN := "res://assets/ui/pipbuck_skin.png"
## extracted_swf/export_pip_art.py.
const ART := "res://assets/ui/pip/%s.png"
## OTHER PipBuck/pipFon.tscn layers (L1 under L0), copied from
## Godot_project/art/ui/PipBuck/pipFon/.
const FON_L1 := "res://assets/ui/pip/fon_l1.png"
const FON_L0 := "res://assets/ui/pip/fon_l0.png"
## OTHER PipBuck/trol_2 frames 1..15 (L0_F0..F14), one per right-panel row.
const TROL := "res://assets/ui/pip/trol/f%d.png"
const ROW_ART := "res://assets/ui/menu/art/498.png"
const _PipParams := preload("res://scripts/pip_params.gd")
## OTHER PipBuck/SkillKusok (box) and SkillKusok2 (lvl) frames 0..2.
const SK_BOX := "res://assets/ui/pip/skill/%s%d.png"
## Pers.getSkLevel thresholds: the boxes that mark skill levels 1..5.
const SK_LEVELS: Array[int] = [2, 5, 9, 14, 20]
## OTHER PipBuck/vskills/vskill frames, one per skill / perk id.
const SK_PIC := "res://assets/ui/pip/vskill/%s.png"
## AllData perk / skill textvar and eff rows (tools/export_pip_eff.py).
const PIP_EFF := "res://assets/data/pip_eff.json"
## Label text is this much larger than the Flash sizes (OTHER draws _sans as OS Arial).
const TEXT_K := 1.08
const MEMORY_PAGES: Array[int] = [1, 2, 3, 5]
## PipBuck helpText per page: [page, sub or -1, pip id, s1.. key actions].
const HELPS := [
	[2, 0, "helpInv1", ["sprint", "grenade", "magic_attack", "grenade", "magic_attack"]],
	[2, 1, "helpInv2", ["sprint"]],
	[2, 2, "helpInv3", ["sprint", "cast_spell"]],
	[2, 3, "helpInv4", []],
	[2, 4, "helpInv5", ["sprint"]],
	[5, 1, "helpSave", []],
	[3, 2, "helpWorld", []],
]
const ITEMS_PATH := "res://assets/data/content/items.json"
const FONT := "res://theme/hud_sans.tres"
const PAGE := Vector2(165.0, 72.0)
## items.xml heal="pet": the food each pet eats (the robo owl is repaired at a bench).
const PET_FOOD := {"phoenix": "radcookie"}
const WorldMapPage := preload("res://scripts/world_map_page.gd")
const PipTrade := preload("res://scripts/pip_trade.gd")
const QUEST_STAR := preload("res://assets/ui/pip/quest_main.png")
const LocalMapPage := preload("res://scripts/local_map_page.gd")
const PipScroll := preload("res://scripts/pip_scroll.gd")
const _WeaponVis := preload("res://scripts/weapon_vis.gd")
const STATUS := 1
const INVENT := 2
const INFO := 3
const MENU := 5
const SUBS := {
	STATUS: ["stat1", "stat2", "stat3", "stat4", "stat5"],
	INVENT: ["inv1", "inv2", "inv3", "inv4", "inv5"],
	INFO: ["info1", "info2", "info3", "info4", "info5"],
	MENU: ["opt1", "opt2", "opt3", "opt4", "opt5"],
	4: ["vend1", "vend2", "vend3", "vend4", ""],
	6: ["med1", "med2", "", "", ""],
	7: ["work1", "work2", "work3", "", ""],
	9: ["vault1", "vault2", "vault3", "", ""],
	8: ["", "", "", "", ""],
}
## PipPageApp: the appearance window (dialVid at 444, 400 in the page).
const APP := 8
const APP_AT := Vector2(444.0, 400.0)
const PAGE_Y := {STATUS: 135.5, INVENT: 213.5, INFO: 293.5, MENU: 453.5}
const BUT4_Y := 373.5
const AMMO_TYPES: PackedStringArray = ["a", "e"]
## visPipInvItem text fields (x, width); trol is centred at INV_TROL_X.
const INV_FAV := Vector2(-30.5, 63.0)
const INV_NAZV := Vector2(58.5, 281.5)
const INV_HP := Vector2(211.5, 122.5)
const INV_AMMO := Vector2(340.5, 61.45)
const INV_AMMOTIP := Vector2(408.45, 149.5)
const INV_MASS := Vector2(347.45, 53.5)
const INV_TROL_X := 45.0
const MASS_COLOR := Color("99ccff")
## pipInvent ico / item / pers (+2, +2 like the info box); info drops below them.
const ICO_AT := Vector2(632.0, 162.05)
const ICO_ITEM := Vector2(732.75, 163.55)
const ICO_ITEM_DROP := 96.5
const ICO_PERS := Vector2(784.35, 305.9)
const ICO_PERS_DROP := 168.85
const ITEM_ICO := "res://assets/ui/pip/itemico/%s.png"
const PIP_INFO := "res://scripts/pip_info.gd"
const GEAR_TYPES: PackedStringArray = ["med", "pot", "him", "equip", "food"]
## PipPageInv tips: the filter buttons of each inventory subpage. Weapons and
## armour match the row's trol ("w" + skill, "armor" + tip), items their tip.
const INV_CATS := {
	0: ["", "w1", "w2", "w4", "w5", "w6", "w3"],
	1: ["", "armor1", "armor3"],
	2: ["", "med", ["him", "pot"], "food", ["equip", "spell"], ["book", "sphera", "note"], "paint"],
	3: ["", ["valuables", "money"], ["spec", "key"], ["impl", "art", "instr", "equip"], ["stuff", "compa", "compw", "compe", "compm"], ["compp", "food"], "scheme"],
	4: ["", "a", "e"],
}
## Ctr.as keyPip (Tab, plus the free gamepad Back) and the page keys.
const ACTIONS := {
	"pip_toggle": [KEY_TAB, JOY_BUTTON_BACK],
	"pip_invent": [KEY_I, -1],
	"pip_status": [KEY_O, -1],
	"pip_skills": [KEY_K, -1],
	"pip_med": [KEY_L, -1],
	"pip_map": [KEY_M, -1],
	"pip_quest": [KEY_J, -1],
}
const JUMPS := {
	"pip_invent": [INVENT, -1],
	"pip_status": [STATUS, 0],
	"pip_skills": [STATUS, 1],
	"pip_med": [STATUS, 4],
	"pip_map": [INFO, 0],
	"pip_quest": [INFO, 1],
	"pip_world": [INFO, 2],
}

static var _types: Dictionary = {}

## Main menu Настройки: the light PipBuck with only the Меню page.
var menu_only := false
var _app: CanvasLayer

var _page := STATUS
var _sub := {STATUS: 0, INVENT: 0, INFO: 0, MENU: 2, 4: 0, 6: 0, 7: 0, 8: 0, 9: 0}
## PipBuck.onoff(4/6/7/9): the page but4 opens. 0 hides but4.
var _ctx_page := 0
var _ctx_button: Button
var _trade: PipTrade
## pip.showHidden.
var _show_hidden := false
## PipPageInv obj.drop: id -> count marked on the open inventory page.
var _drops: Dictionary = {}
## PipPage cat[page2]: the chosen filter of each inventory subpage.
var _inv_cat := {0: 0, 1: 0, 2: 0, 3: 0, 4: 0}
var _inv_cat_buttons: Array[Button] = []
var _focus_inv_cat := -1
var _font: Font
var _stage: Control
var _skin: TextureRect
var _fon: Control
var _page_buttons: Dictionary = {}
var _close_button: Button
var _sub_buttons: Array[Button] = []
var _header: Control
var _scroll: ScrollContainer
var _list: VBoxContainer
## List column width: pipInvent rows run to the detail; pipInfo stops at scBar.
var _list_w := 560.0
var _rows: Array[Button] = []
var _title: Label
var _info: Label
var _info_y0 := 0.0
var _info_h0 := 471.0
var _pic: TextureRect
var _ico: CanvasGroup
var _ico_sprite: Sprite2D
var _item_ico: TextureRect
## The armour preview [CanvasGroup, PonyPuppet], made on first use.
var _pers: Array = []
var _pip_info_gd: GDScript
## PipPageStat.skills lvl - minlvl: points placed on the Skills page, not yet accepted.
var _sk_add: Dictionary = {}
var _pip_eff: Dictionary = {}
var _bottom_rich: RichTextLabel
## PipPage info in html: quests and notes (coloured spans).
var _rich: RichTextLabel
var _bottom: Label
var _empty: Label
var _nav_hint: Label
var _ok: Button
var _rpanel: Control
var _rp_labels: Array[Label] = []
var _choosing := false
var _listen_id := ""
var _listen_frame := -1
var _listen_cell := 0
## PipPageOpt PAGE_AUTOPICKUP_OPT, opened from the autotake row.
var _opt_auto := false
## PAGE_CONTROLS arr: action -> [a1, a2] until Accept (transOk).
var _kb_edit: Dictionary = {}
## The focused row's cell: 0 key1, 1 key2, 2 the port's pad cell.
var _key_cell := 0
var _key_action := ""
var _key_frame := -1
var _def: Button
## PipPage.setTopText: pip.vis.toptext (1150) above the page.
var _top: Label
var _top_box: Control
## Port extra: the button hints, in a second toptext box.
var _hint_box: Control
## pip.vis.butHelp (1144) and vishelp (visPipHelp 1160), shown while hovered.
var _help_b: Button
var _help_box: Control
var _help_rich: RichTextLabel
var _help_text_now := ""
var _exit_b: Button
## PipBuck.onoff() reopens the last page; pages an object opens are not kept.
static var _last_page := STATUS
static var _last_sub: Dictionary = {}
var _rp_wait := 0.0
var _dirty := false
## _invent_key of the built inventory list.
var _inv_key: Array = []
var _focus_row := 0
var _map: WorldMapPage
var _lmap: Control
var _log_text: RichTextLabel
var _pers_thaw_until := 0
var _map_target := ""


static func ensure_actions() -> void:
	for action: String in ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var spec: Array = ACTIONS[action]
		var key := InputEventKey.new()
		key.physical_keycode = spec[0]
		InputMap.action_add_event(action, key)
		if int(spec[1]) >= 0:
			var pad := InputEventJoypadButton.new()
			pad.button_index = spec[1]
			InputMap.action_add_event(action, pad)


## Which PipBuck action the event presses, or "".
static func action_of(event: InputEvent) -> String:
	if event is InputEventKey and (event as InputEventKey).echo:
		return ""
	for action: String in ACTIONS:
		if InputMap.has_action(action) and event.is_action_pressed(action):
			return action
	return ""


func _init() -> void:
	if MEMORY_PAGES.has(_last_page):
		_page = _last_page
	for p: int in _last_sub:
		_sub[p] = _last_sub[p]


## The page and subpages to reopen on. World-map travel and the pages an
## object opens (but4, the appearance window) are not kept.
func _remember() -> void:
	if menu_only:
		return
	var travel := _page == INFO and int(_sub[INFO]) == 2 and Travel.map_travel()
	for p: int in MEMORY_PAGES:
		if not (p == INFO and travel):
			_last_sub[p] = int(_sub[p])
	if MEMORY_PAGES.has(_page) and not travel:
		_last_page = _page


func open_at(page: int, sub: int = -1) -> void:
	if SUBS.has(page):
		_page = page
		if sub >= 0:
			_sub[page] = sub
		if PipTrade.handles(page):
			var to: Array = PipTrade.new(self).redirect(page, int(_sub[page]))
			if not to.is_empty():
				_page = int(to[0])
				_sub[_page] = int(to[1])
			_ctx_page = _page
		elif page == APP:
			_ctx_page = APP
	if is_inside_tree() and _stage != null:
		_show_page()


func _ready() -> void:
	ensure_actions()
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = load(FONT)
	if menu_only:
		_page = MENU
	_trade = PipTrade.new(self)
	_build()
	get_viewport().size_changed.connect(_fit)
	var bags := get_node_or_null("/root/Inventory")
	if bags != null and bags.has_signal("changed"):
		bags.changed.connect(_mark_dirty)
	var prog := get_node_or_null("/root/Progression")
	if prog != null and prog.has_signal("changed"):
		prog.changed.connect(_mark_dirty)
	if MagicBinds != null:
		MagicBinds.changed.connect(_mark_dirty)
	Story.quests_changed.connect(_mark_dirty)
	Story.notes_changed.connect(_mark_dirty)
	Stash.changed.connect(_mark_dirty)
	Locale.language_changed.connect(_on_language)
	Prompts.device_changed.connect(_on_device)
	UiNav.add_screen(self, {"default": _default_focus, "tabs": _cycle_sub})
	_show_page()


func _on_language(_lang: String) -> void:
	_relabel()


func _on_device(_pad: bool) -> void:
	_mark_dirty()


func _default_focus() -> Control:
	var mark := _map_focus()
	if mark != null:
		return mark
	if not _rows.is_empty() and is_instance_valid(_rows[0]):
		return _rows[0]
	return _sub_buttons[int(_sub[_page])]


func _mark_dirty() -> void:
	_dirty = true


## After an action: update the rows in place when only their text changed.
func _refresh() -> void:
	if not _invent_in_place():
		_fill()


func _process(delta: float) -> void:
	if _dirty:
		_dirty = false
		_refresh()
	_rp_wait -= delta
	if _rp_wait <= 0.0:
		_rp_wait = 0.25
		_refresh_rpanel()
		if _page == STATUS and int(_sub[STATUS]) in [3, 4]:
			_fill()


# --- Build ---

func _build() -> void:
	for child in get_children():
		child.queue_free()
	_page_buttons.clear()
	_sub_buttons.clear()
	_rp_labels.clear()
	_rows.clear()
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.85)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_stage = Control.new()
	_stage.size = Vector2(1200, 800)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_fon = _build_fon()
	_stage.add_child(_fon)
	_skin = TextureRect.new()
	_skin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skin.position = Vector2(600 - 960, 403 - 540)
	_skin.size = Vector2(1920, 1080)
	_skin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if ResourceLoader.exists(SKIN):
		_skin.texture = load(SKIN)
	_stage.add_child(_skin)
	_skin.visible = not menu_only
	_fon.visible = not menu_only
	# visPipInv InstanceName_0: shape 838, the page panel with the green border.
	_stage.add_child(_art(838, Rect2(PAGE + Vector2(463.4 - 600.0 * 0.77, 353.1 - 320.1 * 0.91), Vector2(1207.2 * 0.77, 688.2 * 0.91))))
	for page: int in [STATUS, INVENT, INFO, MENU]:
		var b := _button(Locale.t("pip_menu_tab") if page == MENU else OriginalLines.pip("main%d" % page), Rect2(17, PAGE_Y[page], 129.7, 66), 20)
		b.pressed.connect(_go.bind(page, -1))
		b.visible = not menu_only
		_page_buttons[page] = b
	_help_b = _button("?", Rect2(17, 531.9, 48, 48), 35)
	_help_b.visible = false
	_help_b.mouse_entered.connect(_show_help.bind(true))
	_help_b.mouse_exited.connect(_show_help.bind(false))
	_help_b.focus_entered.connect(_show_help.bind(true))
	_help_b.focus_exited.connect(_show_help.bind(false))
	# Port: the pause menu's "to main menu", on the Menu page after the tabs.
	_exit_b = _button(Locale.t("pause_main_menu"), Rect2(PAGE + Vector2(700, 26.45), Vector2(132, 31)), 16)
	_exit_b.visible = false
	_exit_b.pressed.connect(func() -> void: to_main_menu.emit())
	_ctx_button = _button("", Rect2(17, BUT4_Y, 129.7, 66), 18)
	_ctx_button.pressed.connect(func() -> void: _go(_ctx_page, -1))
	_ctx_button.visible = false
	_close_button = _button(OriginalLines.pip("mainclose" if menu_only else "main0"), Rect2(30, 693.45, 129.7, 66), 18)
	_close_button.pressed.connect(_close)
	for i in 5:
		var sb := _button("", Rect2(PAGE + Vector2(140.0 * i, 26.45), Vector2(132, 31)), 20)
		sb.pressed.connect(_go_sub.bind(i))
		_sub_buttons.append(sb)
	_header = Control.new()
	_header.position = PAGE + Vector2(30, 70)
	_header.size = Vector2(560, 24)
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_header)
	_scroll = ScrollContainer.new()
	_scroll.position = PAGE + Vector2(30, 100)
	_scroll.size = Vector2(578, 18 * 30 - 6)
	_scroll.follow_focus = true
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_stage.add_child(_scroll)
	_list = VBoxContainer.new()
	# visPipBackItem is 566x29 at a 30 px row pitch.
	_list.add_theme_constant_override("separation", 2)
	_list.custom_minimum_size = Vector2(560, 0)
	_scroll.add_child(_list)
	_empty = _label(PAGE + Vector2(30, 100), 560, 16, GREEN)
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title = _label(PAGE + Vector2(630.95, 87), 281, 20, GREEN)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_info = _label(PAGE + Vector2(625.95, 162.05), 284, 14, GREEN)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.size.y = 471
	_info.clip_text = true
	_rich = RichTextLabel.new()
	_rich.bbcode_enabled = true
	_rich.position = _info.position
	_rich.size = Vector2(284, 471)
	_rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rich.add_theme_color_override("default_color", GREEN)
	_rich.add_theme_font_override("normal_font", _font)
	_rich.add_theme_font_size_override("normal_font_size", roundi(14 * TEXT_K))
	_rich.visible = false
	_stage.add_child(_rich)
	# setIco tip 5: vis.skill frame per skill / perk id, info 220 below it.
	_pic = TextureRect.new()
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pic.position = _info.position + Vector2(42, 0)
	_pic.size = Vector2(200, 200)
	_pic.visible = false
	_stage.add_child(_pic)
	# setIco tip 1: the weapon's own sprite centred at ico.x + 140 with GlowFilter 00FF88.
	_ico = CanvasGroup.new()
	var glow := ShaderMaterial.new()
	glow.shader = preload("res://assets/shaders/group_glow.gdshader")
	glow.set_shader_parameter("blur", 3.0)
	_ico.material = glow
	_ico.visible = false
	_stage.add_child(_ico)
	_ico_sprite = Sprite2D.new()
	_ico_sprite.centered = false
	_ico.add_child(_ico_sprite)
	# setIco tip 3: Objects/Items/itemIco frame (spells, orb, books of the stable).
	_item_ico = TextureRect.new()
	_item_ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_item_ico.position = PAGE + ICO_ITEM
	_item_ico.visible = false
	_stage.add_child(_item_ico)
	_bottom = _label(PAGE + Vector2(19.5, 653.1), 870, 18, GREEN)
	_bottom.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bottom.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_bottom.size.y = 22
	_bottom_rich = RichTextLabel.new()
	_bottom_rich.bbcode_enabled = true
	_bottom_rich.scroll_active = false
	_bottom_rich.position = _bottom.position
	_bottom_rich.size = Vector2(600, 26)
	_bottom_rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom_rich.add_theme_color_override("default_color", GREEN)
	_bottom_rich.add_theme_font_override("normal_font", _font)
	_bottom_rich.add_theme_font_size_override("normal_font_size", roundi(18 * TEXT_K))
	_stage.add_child(_bottom_rich)
	_ok = _button("", Rect2(PAGE + Vector2(679.7, 651.1), Vector2(150, 30)), 16)
	_ok.visible = false
	_ok.pressed.connect(_on_ok)
	_def = _button("", Rect2(PAGE + Vector2(448.7, 651.1), Vector2(150, 30)), 16)
	_def.visible = false
	_def.pressed.connect(_keys_default)
	# toptext 1152: shape 1150 at 250.4, 4.5, txt at 262.5, 11.7.
	_top_box = _art(1150, Rect2(250.4, 4.5, 361.1, 74))
	_stage.add_child(_top_box)
	_top = _label(Vector2(12.1, 7.2), 344, 14, GREEN)
	_top.reparent(_top_box, false)
	_top.position = Vector2(12.1, 7.2)
	_top.size = Vector2(344, 62)
	_top.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_top.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_top.clip_text = true
	_hint_box = _art(1150, Rect2(620.0, 4.5, 361.1, 74))
	_stage.add_child(_hint_box)
	_nav_hint = _label(Vector2.ZERO, 344, 13, LIGHT)
	_nav_hint.reparent(_hint_box, false)
	_nav_hint.position = Vector2(8.5, 5)
	_nav_hint.size = Vector2(344, 64)
	_nav_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_nav_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_nav_hint.clip_text = true
	# vishelp at 168, 138: shape 1158, txt at 9.2, 10.1.
	_help_box = _art(1158, Rect2(168, 138, 616, 619))
	_help_box.visible = false
	_stage.add_child(_help_box)
	_help_rich = RichTextLabel.new()
	_help_rich.bbcode_enabled = true
	_help_rich.position = Vector2(9.2, 10.1)
	_help_rich.size = Vector2(597, 600)
	_help_rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help_rich.add_theme_color_override("default_color", GREEN)
	_help_rich.add_theme_font_override("normal_font", _font)
	_help_rich.add_theme_font_size_override("normal_font_size", roundi(14 * TEXT_K))
	_help_box.add_child(_help_rich)
	_build_rpanel()
	_apply_columns()
	_fit()


## Port extra: controller hints above the subpage tabs.
func _refresh_nav_hint() -> void:
	if _nav_hint == null:
		return
	_nav_hint.text = Prompts.hint([
		["tabs", Locale.t("hint_tabs")],
		["pages", Locale.t("hint_pages")],
		["accept", OriginalLines.pip("choose")],
		["back", OriginalLines.pip("mainclose")],
	])


## visPipBuck fon: pipFon at (599.5, 399.5). L1 then L0, both offset (-601.5, -322.5).
## Falls back to shape 1131 if the copied layers are missing.
func _build_fon() -> Control:
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var at := Vector2(599.5 - 601.5, 399.5 - 322.5)
	var placed := false
	for spec in [[FON_L1, Vector2(1204, 693)], [FON_L0, Vector2(1203, 693)]]:
		var path := str(spec[0])
		if not ResourceLoader.exists(path):
			continue
		var t := TextureRect.new()
		t.texture = load(path)
		t.position = at
		t.size = spec[1]
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(t)
		placed = true
	if placed:
		return box
	return _art(1131, Rect2(-0.5, 79.4, 1200, 688.2))


func _art(id: int, r: Rect2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(ART % id)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.position = r.position
	t.size = r.size
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## A nine-slice of an exported button shape.
static var _tex_cache: Dictionary = {}


func _slice(path: String, margin: float) -> StyleBoxTexture:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path)
	var box := StyleBoxTexture.new()
	box.texture = _tex_cache[path]
	box.set_texture_margin_all(margin)
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return box


func _build_rpanel() -> void:
	_rpanel = Control.new()
	_rpanel.position = Vector2(1105.65, 135.5)
	_rpanel.size = Vector2(160, 510)
	_rpanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_rpanel)
	# pr: shape 1153; rows are visPipRItem bars.
	_rpanel.add_child(_art(1153, Rect2(-0.5, -0.6, 161, 511.2)))
	for j in 15:
		var row := Panel.new()
		row.add_theme_stylebox_override("panel", _slice(ROW_ART, 2.0))
		row.position = Vector2(5, 40 + j * 30)
		row.size = Vector2(150, 24)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rpanel.add_child(row)
		var tag := Label.new()
		_style(tag, 11, DARK.lightened(0.3))
		tag.position = Vector2(2, 4)
		tag.size = Vector2(40, 16)
		tag.clip_text = true
		tag.visible = false
		row.add_child(tag)
		var icon := TextureRect.new()
		icon.name = "Trol"
		var icon_path := TROL % j
		if ResourceLoader.exists(icon_path):
			icon.texture = load(icon_path)
		else:
			tag.visible = true
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(2, 1)
		icon.size = Vector2(20, 22)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var txt := Label.new()
		_style(txt, 15, GREEN)
		txt.position = Vector2(26, 1)
		txt.size = Vector2(124, 22)
		txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(txt)
		txt.set_meta("tag", tag)
		txt.set_meta("row", row)
		_rp_labels.append(txt)
	_rpanel.visible = not menu_only


func _fit() -> void:
	if _stage == null:
		return
	# resizeScreen works in stage pixels; the port's canvas is 1280×720 stretched,
	# so the window size in pixels drives it and k converts back.
	var view := get_viewport_rect().size
	var px := Vector2(get_window().size)
	var k := px.y / view.y if view.y > 0.0 else 1.0
	var s := 1.0
	var at := Vector2.ZERO
	if px.x >= 1200.0 and px.y >= 800.0:
		if px.x > 1320.0:
			at = Vector2((px.x - 1200.0) * 0.5 - 60.0, (px.y - 800.0) * 0.5)
	else:
		s = minf(px.x / 1200.0, px.y / 800.0)
		# resizeScreen pins the scaled PipBuck at 0,0; centre the spare width
		# because the port's expand aspect can be much wider than 1200:800.
		at = Vector2(maxf(0.0, (px.x - 1265.0 * s) * 0.5), 0.0)
	_stage.scale = Vector2(s, s) / k
	_stage.position = at / k


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


## visPipBuck but* (1143: 1139 / 1142) and the subpage tabs (1011: 506 / 1007):
## black with a green rim, frame 2 lit for the open page.
func _skin_button(b: Button, fill: Color, size: int) -> void:
	var big := b.size.y >= 50.0
	var off := ART % (1139 if big else 506)
	var on := ART % (1142 if big else 1007)
	var lit := fill == BUT_ON
	for state in ["normal", "hover", "pressed", "disabled"]:
		var use_on: bool = lit or state in ["hover", "pressed"]
		b.add_theme_stylebox_override(state, _slice(on if use_on else off, 6.0 if big else 4.0))
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = LIGHT
	focus.set_border_width_all(2)
	b.add_theme_stylebox_override("focus", focus)
	if _font:
		b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", size)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, GREEN)
	b.add_theme_color_override("font_disabled_color", DARK)


func _frame(r: Rect2) -> ReferenceRect:
	var f := ReferenceRect.new()
	f.editor_only = false
	f.border_color = GREEN
	f.border_width = 1.0
	f.position = r.position
	f.size = r.size
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return f


func _label(at: Vector2, width: float, size: int, color: Color) -> Label:
	var l := Label.new()
	_style(l, size, color)
	l.position = at
	l.size = Vector2(width, size + 6)
	_stage.add_child(l)
	return l


func _style(l: Label, size: int, color: Color) -> void:
	if _font:
		l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", roundi(size * TEXT_K))
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE


# --- Pages ---

func _go(page: int, sub: int) -> void:
	SfxBank.play("pip2")
	_choosing = false
	_page = page
	if sub >= 0:
		_sub[page] = sub
	_show_page()


func _go_sub(i: int) -> void:
	SfxBank.play("pip2")
	_choosing = false
	_opt_auto = false
	_kb_edit.clear()
	_key_action = ""
	if PipTrade.handles(_page):
		var to: Array = _trade.redirect(_page, i)
		if not to.is_empty():
			_ctx_page = int(to[0])
			_go(int(to[0]), int(to[1]))
			return
	_sub[_page] = i
	_trade.stale()
	_show_page(true)


func _show_page(focus_sub := false) -> void:
	_drops.clear()
	_rpanel.visible = not menu_only and _page != APP
	if _page != APP and _app != null and is_instance_valid(_app):
		_app.cancel_quiet()
	for page: int in _page_buttons:
		var b: Button = _page_buttons[page]
		_skin_button(b, BUT_ON if page == _page else BUT, 20)
	_ctx_button.visible = _ctx_page > 0 and not menu_only
	if _ctx_page > 0:
		_ctx_button.text = OriginalLines.pip("main%d" % _ctx_page)
		_skin_button(_ctx_button, BUT_ON if _page == _ctx_page else BUT, 20)
	var names: Array = SUBS[_page]
	for i in 5:
		var sb := _sub_buttons[i]
		sb.text = _trade.sub_label(_page, i) if PipTrade.handles(_page) else OriginalLines.pip(names[i])
		sb.visible = _sub_visible(_page, i)
		_skin_button(sb, BUT_ON if i == int(_sub[_page]) else BUT, 20)
	if not _sub_visible(_page, int(_sub[_page])):
		_sub[_page] = 2 if _page == MENU else (_trade.first_sub(_page) if PipTrade.handles(_page) else 0)
	_focus_row = 0
	_fill()
	_wire_focus()
	if focus_sub:
		_sub_buttons[int(_sub[_page])].grab_focus()
	elif _map_focus() != null:
		_map_focus().grab_focus()
	elif not _rows.is_empty():
		_rows[0].grab_focus()
	else:
		_sub_buttons[int(_sub[_page])].grab_focus()


func _sub_visible(page: int, i: int) -> bool:
	if page == APP:
		return false
	# PipPageOpt.setStatus: light mode hides but1, but2 and but5.
	if menu_only and page == MENU:
		return i in [2, 3]
	if PipTrade.handles(page):
		return _trade.sub_visible(page, i)
	return true


## pipInvent detail (status, inventory, menu) vs pipInfo (map, quests, notes, enemies).
## World map shifts the title right (PipPageInfo.setSubPages page2 == 3).
func _apply_columns() -> void:
	if _title == null:
		return
	var sub := int(_sub.get(_page, 0))
	var world := _page == INFO and sub == 2
	var wide := _page == INFO and not world
	var title_r := Rect2(630.95, 87, 281, 59)
	var info_r := Rect2(625.95, 162.05, 284, 471)
	_list_w = 560.0
	if world:
		title_r = Rect2(584, 87, 287, 59)
		info_r = Rect2(584, 162.05, 332, 471)
	elif wide:
		title_r = Rect2(459, 87, 409, 59)
		info_r = Rect2(460, 162.05, 445, 480)
		_list_w = 400.0
	_title.position = PAGE + title_r.position
	_title.size = title_r.size
	_info.position = PAGE + info_r.position
	_info.size = info_r.size
	_info_y0 = _info.position.y
	_info_h0 = _info.size.y
	_pic.position = _info.position + Vector2((info_r.size.x - 200.0) / 2.0, 0.0)
	_rich.position = _info.position
	_rich.size = info_r.size
	# List first: the ScrollContainer grows back to its child's minimum width.
	if _list != null:
		_list.custom_minimum_size.x = _list_w
		_list.size.x = _list_w
	_scroll.size.x = _list_w + 18.0
	_fit_scroll.call_deferred()
	_header.size.x = _list_w


func _fill() -> void:
	_apply_columns()
	var keep := _focused_row_index()
	var keep_mark := ""
	if _map != null:
		var owner := get_viewport().gui_get_focus_owner()
		if owner != null and owner.get_parent() == _map:
			keep_mark = owner.name
		_map.queue_free()
		_map = null
	if _lmap != null:
		_lmap.queue_free()
		_lmap = null
	if _log_text != null:
		_log_text.queue_free()
		_log_text = null
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.visible = true
	var keep_scroll := _scroll.scroll_vertical if keep >= 0 else 0
	for row in _rows:
		# Out of the list now: freed rows left in place push the new ones down
		# and follow_focus scrolls after them.
		if row.get_parent() != null:
			row.get_parent().remove_child(row)
		row.queue_free()
	_rows.clear()
	for child in _header.get_children():
		child.queue_free()
	_title.text = ""
	_info.text = ""
	_info.visible = true
	_rich.text = ""
	_rich.visible = false
	_bottom.text = ""
	_bottom_rich.text = ""
	_top.text = ""
	_bottom.add_theme_color_override("font_color", GREEN)
	_empty.text = ""
	_ok.visible = false
	_def.visible = false
	var sub := int(_sub[_page])
	_pic.visible = false
	_set_ico([])
	_info.position.y = _info_y0
	_info.size.y = _info_h0
	if not (_page == STATUS and sub == 1):
		_sk_add.clear()
	match _page:
		STATUS:
			_fill_status(sub)
		INVENT:
			_fill_invent(sub)
		INFO:
			_fill_info(sub)
		MENU:
			_fill_menu(sub)
		APP:
			_fill_app()
		_:
			_trade.fill(_page, sub)
	_bottom.text = _glyphs(_bottom.text)
	_top.text = _glyphs(_top.text)
	_top_box.visible = _top.text != ""
	_help_text_now = _page_help()
	_help_b.visible = _help_text_now != ""
	_exit_b.visible = _page == MENU and not menu_only
	if not _help_b.visible:
		_help_box.visible = false
	_refresh_nav_hint()
	_wire_focus()
	if keep_mark != "" and _map != null and _map.marks().has(keep_mark):
		(_map.marks()[keep_mark] as Control).call_deferred("grab_focus")
	elif keep >= 0 and not _rows.is_empty():
		var at := clampi(keep, 0, _rows.size() - 1)
		_rows[at].call_deferred("grab_focus")
		_restore_scroll.call_deferred(keep_scroll)
	elif keep >= 0:
		_sub_buttons[sub].call_deferred("grab_focus")


func _focused_row_index() -> int:
	var owner := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if owner is Button:
		return _rows.find(owner as Button)
	return -1


func _wire_focus() -> void:
	var page_b: Button = _close_button if menu_only else _page_buttons.get(_page, _ctx_button)
	var sub_b := _sub_buttons[int(_sub[_page])]
	for page: int in _page_buttons:
		var b: Button = _page_buttons[page]
		b.focus_neighbor_right = b.get_path_to(sub_b)
	for sb in _sub_buttons:
		sb.focus_neighbor_left = sb.get_path_to(page_b) if sb == _first_sub() else NodePath("")
		if not _rows.is_empty():
			sb.focus_neighbor_bottom = sb.get_path_to(_rows[0])
		elif _map_focus() != null:
			sb.focus_neighbor_bottom = NodePath("")
		elif _ok.visible:
			sb.focus_neighbor_bottom = sb.get_path_to(_ok)
		else:
			sb.focus_neighbor_bottom = sb.get_path_to(_close_button)
	for i in _rows.size():
		var row := _rows[i]
		row.focus_neighbor_left = row.get_path_to(page_b)
		row.focus_neighbor_right = row.get_path_to(_ok) if _ok.visible else row.get_path()
		row.focus_neighbor_top = row.get_path_to(_rows[i - 1] if i > 0 else sub_b)
		var below: Control = _rows[i + 1] if i + 1 < _rows.size() else (_ok if _ok.visible else _close_button)
		row.focus_neighbor_bottom = row.get_path_to(below)
	if _ok.visible:
		_ok.focus_neighbor_left = _ok.get_path_to(_rows[0] if not _rows.is_empty() else page_b)
		_ok.focus_neighbor_top = _ok.get_path_to(_rows[-1] if not _rows.is_empty() else sub_b)
	if _def.visible and not _rows.is_empty():
		_rows[-1].focus_neighbor_bottom = _rows[-1].get_path_to(_def)
		_def.focus_neighbor_top = _def.get_path_to(_rows[-1])
		_def.focus_neighbor_right = _def.get_path_to(_ok) if _ok.visible else NodePath("")
		_ok.focus_neighbor_left = _ok.get_path_to(_def)
	_close_button.focus_neighbor_top = _close_button.get_path_to(_page_buttons[MENU])
	if _help_b.visible:
		var menu_b: Button = _page_buttons[MENU]
		menu_b.focus_neighbor_bottom = menu_b.get_path_to(_help_b)
		_help_b.focus_neighbor_top = _help_b.get_path_to(menu_b)
		_help_b.focus_neighbor_bottom = _help_b.get_path_to(_close_button)
		_help_b.focus_neighbor_right = _help_b.get_path_to(_rows[0] if not _rows.is_empty() else sub_b)
		_close_button.focus_neighbor_top = _close_button.get_path_to(_help_b)
	elif menu_only:
		_close_button.focus_neighbor_top = _close_button.get_path_to(sub_b)
	_close_button.focus_neighbor_right = _close_button.get_path_to(_rows[0] if not _rows.is_empty() else sub_b)
	_ctx_button.focus_neighbor_right = _ctx_button.get_path_to(sub_b)
	if PipTrade.handles(_page):
		_trade.after_wire()
	elif _page == INVENT:
		PipTrade.wire_cats(self, _inv_cat_buttons, int(_inv_cat[int(_sub[INVENT])]), _focus_inv_cat)
		_focus_inv_cat = -1


func _first_sub() -> Button:
	for sb in _sub_buttons:
		if sb.visible:
			return sb
	return _sub_buttons[0]


## PipPage statHead: one more itemClass row 30 above the list (back hidden), so
## the same 16 px fields as the rows. cols: [text, x, width, align, color].
func _head(cols: Array) -> void:
	for c: Array in cols:
		var l := Label.new()
		_style(l, 16, c[4] if c.size() > 4 else GREEN)
		l.position = Vector2(float(c[1]), 2)
		l.size = Vector2(float(c[2]), 24)
		l.clip_text = true
		l.horizontal_alignment = c[3] if c.size() > 3 else HORIZONTAL_ALIGNMENT_LEFT
		l.text = str(c[0])
		_header.add_child(l)


## cols: [text, x, width, color, align]. data: primary/secondary Callables,
## title/info for the right column, adjust Callable(step) for left/right.
func _row(cols: Array, data: Dictionary = {}) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(_list_w, 28)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	# visPipOptItem back 498: a black bar with a dark green rim.
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		if state in ["normal", "disabled", "pressed"]:
			b.add_theme_stylebox_override(state, _slice(ROW_ART, 2.0))
			continue
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.0, 0.25, 0.15, 0.6)
		box.border_color = GREEN
		box.set_border_width_all(1)
		box.draw_center = state == "hover"
		b.add_theme_stylebox_override(state, box)
	_row_labels(b, cols)
	b.set_meta("data", data)
	b.focus_entered.connect(_on_row_focus.bind(b))
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	b.pressed.connect(_on_row_primary.bind(b))
	b.gui_input.connect(_on_row_input.bind(b))
	_list.add_child(b)
	_rows.append(b)
	return b


## The row's column labels; an in-place refresh drops the old ones first.
func _row_labels(b: Button, cols: Array) -> void:
	for c in b.get_children():
		if c is Label and c.has_meta("col"):
			b.remove_child(c)
			c.queue_free()
	for c: Array in cols:
		var l := Label.new()
		l.set_meta("col", true)
		_style(l, 16, c[3] if c.size() > 3 else GREEN)
		l.position = Vector2(float(c[1]), 2)
		l.size = Vector2(float(c[2]), 24)
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.horizontal_alignment = c[4] if c.size() > 4 else HORIZONTAL_ALIGNMENT_LEFT
		l.text = str(c[0])
		b.add_child(l)


func _on_row_focus(b: Button) -> void:
	var data: Dictionary = b.get_meta("data", {})
	var tipless := not (data.has("title") or data.has("info") or data.has("rich") or data.has("info_tip"))
	if data.has("title"):
		_title.text = str(data["title"])
	elif tipless:
		_title.text = ""
	if data.has("info"):
		_info.text = str(data["info"])
	elif tipless or not (data.has("rich") or data.has("info_tip")):
		_info.text = ""
	if data.has("bottom"):
		_bottom.text = ""
		_bottom_rich.text = (data["bottom"] as Callable).call()
	var pic := SK_PIC % str(data.get("pic", ""))
	_pic.visible = data.has("pic") and ResourceLoader.exists(pic)
	if _pic.visible:
		_pic.texture = load(pic)
	var drop := 220.0 if _pic.visible else _set_ico(data.get("ico", []))
	_info.position.y = _info_y0 + drop
	_info.size.y = _info_h0 - drop
	_rich.position.y = _info.position.y
	_rich.size.y = _info.size.y
	# PipPage.setStyle: [text] is .yel in every info box.
	_rich.visible = data.has("rich") or data.has("info")
	_info.visible = not _rich.visible
	if _rich.visible:
		var text := str(data["rich"]) if data.has("rich") else _bb(str(data["info"]))
		var stats := _info_str(data.get("info_tip", []))
		if stats != "":
			text = stats
		_rich.text = text
		_rich.scroll_to_line(0)


## PipPage.infoStr via pip_info.gd (the item text, stats and price), "" when absent.
func _info_str(spec: Array) -> String:
	if spec.size() < 2:
		return ""
	if _pip_info_gd == null and ResourceLoader.exists(PIP_INFO):
		_pip_info_gd = load(PIP_INFO)
	if _pip_info_gd == null:
		return ""
	return str(_pip_info_gd.info_str(str(spec[0]), str(spec[1])))


## PipPage.setIco: tip 1 weapon sprite, 2 the pony in that armour, 3 the
## itemIco frame. Returns how far the info box moves down.
func _set_ico(spec: Array) -> float:
	_ico.visible = false
	_item_ico.visible = false
	if not _pers.is_empty():
		(_pers[0] as CanvasItem).visible = false
	if spec.size() < 2:
		return 0.0
	var tip := int(spec[0])
	var id := str(spec[1])
	if tip == 1 and Stash.weapon_tip(id) == 5:
		tip = 3
		id = id.get_slice("^", 0)
	if tip == 2 or tip == 4:
		if _pers.is_empty():
			_pers = preload("res://scripts/pony_puppet.gd").preview(PAGE + ICO_PERS, 2.2, 3.0)
			_stage.add_child(_pers[0])
		# The suit frames load on a thread; a frozen puppet would never draw them.
		(_pers[1] as Node).process_mode = Node.PROCESS_MODE_INHERIT
		_pers_thaw_until = Time.get_ticks_msec() + 300
		get_tree().create_timer(0.31).timeout.connect(_freeze_pers)
		# 4: PipPageOpt.showSaveInfo, the slot's own look and suit.
		var look: Dictionary = spec[2] if tip == 4 and spec.size() > 2 and spec[2] is Dictionary else {}
		if _pers[1].look_override != look:
			_pers[1].look_override = look
			_pers[1].apply_appearance()
		(_pers[0] as CanvasItem).visible = true
		_pers[1].set_armor(id if tip == 4 else str(Inventory.body_armor_id(id)))
		return ICO_PERS_DROP
	match tip:
		1:
			if not _WeaponVis.has_art(id):
				return 0.0
			var tex := _WeaponVis.texture(id)
			if tex == null:
				return 0.0
			_ico_sprite.texture = tex
			_ico.position = PAGE + ICO_AT + Vector2(140.0 - tex.get_width() * 0.5, 0.0)
			_ico.visible = true
			return tex.get_height() + 10.0
		3:
			var path := ITEM_ICO % id
			if not ResourceLoader.exists(path):
				return 0.0
			_item_ico.texture = load(path)
			_item_ico.visible = true
			return ICO_ITEM_DROP
	return 0.0


## The armour preview stands still (setIco gotoAndStop on the pers frame).
func _freeze_pers() -> void:
	if Time.get_ticks_msec() < _pers_thaw_until:
		return
	if _pers.size() > 1 and is_instance_valid(_pers[1]):
		(_pers[1] as Node).process_mode = Node.PROCESS_MODE_DISABLED


## Res.txt razd 1: [ ] around a span is <span class='yel'>.
static func _bb(s: String) -> String:
	s = s.replace("[", "\u0001").replace("]", "\u0002")
	return s.replace("\u0001", "[color=#%s]" % YELLOW.to_html(false)).replace("\u0002", "[/color]")


## PipPage.effStr for a perk or skill at lvl: textvar (#N), the eff rows at
## that level and the requirements, yellow when met and red when not.
## Returns BBCode. req_lvl is the level the requirements are for.
func _eff_str(id: String, lvl: int, reqs: Array = [], req_lvl: int = 0) -> String:
	if _pip_eff.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PIP_EFF))
		_pip_eff = parsed if parsed is Dictionary else {"": {}}
	var s := OriginalLines.text_vars(OriginalLines.desc("eff", id), id, lvl)
	var dp: Dictionary = _pip_eff.get(id, {})
	var effs: Array = dp.get("eff", [])
	if not effs.is_empty() and lvl > 0:
		s += "\n"
		for e: Dictionary in effs:
			var eid := str(e.get("id", ""))
			s += "\n%s: [%s]" % [OriginalLines.pip(eid if eid != "" else "refeff"), str(e.get("n%d" % lvl, ""))]
	s = _bb(s)
	if not reqs.is_empty():
		s += "\n\n" + OriginalLines.pip("requir")
		for req_v in reqs:
			var req: Dictionary = req_v
			var need := int(req.get("level", 1))
			if req_lvl > 0:
				need += req_lvl * int(req.get("dlvl", 0))
			var rid := str(req.get("id", ""))
			var name := ""
			var have := 0
			if rid == "level":
				name = OriginalLines.pip("level")
				have = Progression.level
			elif rid == "guns":
				name = "%s %s %s" % [OriginalLines.eff("smallguns"), OriginalLines.pip("or"), OriginalLines.eff("energy")]
				have = maxi(Progression.skill_level_of("smallguns"), Progression.skill_level_of("energy"))
			else:
				name = OriginalLines.eff(rid)
				have = Progression.skill_level_of(rid)
			var col := YELLOW if have >= need else RED
			s += "\n[color=#%s]%s: %d[/color]" % [col.to_html(false), name, need]
	return s


## Skill / perk points line: the count is pink at 0, yellow above.
func _points(label_id: String, n: int) -> void:
	_bottom.text = ""
	_bottom_rich.text = "%s: [color=#%s]%d[/color]" % [OriginalLines.pip(label_id), (PINK if n <= 0 else YELLOW).to_html(false), n]


func _on_row_primary(b: Button) -> void:
	var data: Dictionary = b.get_meta("data", {})
	if data.has("primary"):
		SfxBank.play("pip1")
		(data["primary"] as Callable).call()
	elif data.has("adjust"):
		SfxBank.play("pip1")
		(data["adjust"] as Callable).call(1)


func _on_row_input(event: InputEvent, b: Button) -> void:
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		_secondary(b)
		accept_event()


func _secondary(b: Button) -> void:
	var data: Dictionary = b.get_meta("data", {})
	if data.has("secondary"):
		SfxBank.play("pip1")
		(data["secondary"] as Callable).call()


func _on_ok() -> void:
	SfxBank.play("pip3")
	if _page == MENU and int(_sub[MENU]) == 3:
		_keys_accept()
		return
	if _map != null and _map.travel_ok():
		_close()
		return
	if _page == STATUS and int(_sub[STATUS]) == 1:
		for id in _sk_add.keys():
			Progression.spend_skill(str(id), int(_sk_add[id]))
		_sk_add.clear()
		_fill()
	elif _page == STATUS and int(_sub[STATUS]) == 2:
		_choosing = not _choosing
		_fill()
		if not _rows.is_empty():
			_rows[0].grab_focus()
	elif _page == INVENT and not _drops.is_empty():
		_drop_marked()
	elif _page == INVENT and int(_sub[INVENT]) == 0:
		_show_hidden = not _show_hidden
		_fill()
	elif _page == INFO and int(_sub[INFO]) == 1:
		if Vendors.in_base():
			Vendors.take_all_tasks()
		_fill()
	elif PipTrade.handles(_page):
		_trade.ok(_page, int(_sub[_page]))


# --- Статус ---

func _fill_status(sub: int) -> void:
	match sub:
		0:
			_fill_main()
		1:
			_fill_skills()
		2:
			_fill_perks()
		3:
			_fill_effects()
		4:
			_fill_health()


func _pair(name: String, value: String, color := GREEN, data: Dictionary = {}) -> Button:
	return _row([[name, 7, 362], [value, 337, 218, color, HORIZONTAL_ALIGNMENT_RIGHT]], data)


func _fill_main() -> void:
	_pair(OriginalLines.pip("name"), _player_name())
	_pair(OriginalLines.pip("level"), str(Progression.level))
	_pair(OriginalLines.pip("expa"), "%d (%d)" % [Progression.xp, Progression.xp_next])
	var dif := "dif%d" % UiSettings.difficulty()
	_pair(OriginalLines.pip("diff"), OriginalLines.gui(dif), GREEN, {"title": OriginalLines.pip("diff"), "info": OriginalLines.desc("gui", dif)})
	_pair(OriginalLines.pip("reput"), "%d (%s)" % [int(Story.rep), Vendors.rep_text(int(Story.rep))], GREEN, _pip_info("reput"))
	if Progression.skill_points > 0:
		_pair(OriginalLines.pip("skillpoint"), str(Progression.skill_points), PINK)
	if Progression.perk_points > 0:
		_pair(OriginalLines.pip("perkpoint"), str(Progression.perk_points), PINK)
	for row in _PipParams.rows():
		var id: String = row[0]
		var label := OriginalLines.pip(id)
		if str(row[1]) != "":
			label = "-  " + label
		_pair(label, str(row[1]), GREEN, _pip_info(id))


func _fill_skills() -> void:
	_head([[OriginalLines.pip("is1"), 7, 300], [OriginalLines.pip("is2"), 335, 150]])
	for entry_v in Progression.skills():
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var id := str((entry_v as Dictionary).get("id", ""))
		if id == "" or not Progression.skill_visible(id):
			continue
		var base := Progression.rank(id)
		var lvl := base + int(_sk_add.get(id, 0))
		var data := {
			"title": OriginalLines.eff(id),
			"rich": _eff_str(id, Progression.skill_level_of(id)),
			"pic": id,
			"primary": _sel_skill.bind(id),
			"secondary": _unsel_skill.bind(id),
		}
		if Progression.is_post(id):
			# setStatItem post: points (+to next level), then the level, at numb.x 215.
			var sk_lvl := Progression.skill_level(lvl, true)
			var next := 100
			if sk_lvl < Progression.POST_SK_TAB.size():
				next = int(Progression.POST_SK_TAB[sk_lvl])
			var text := "%d  (+%d)        %s: %d" % [lvl, next - lvl, OriginalLines.pip("level"), sk_lvl]
			_row([[OriginalLines.eff(id), 7, 210], [text, 215, 335]], data)
		else:
			var row := _row([[OriginalLines.eff(id), 7, 210], [str(Progression.skill_level(lvl, false)), 500, 50, GREEN, HORIZONTAL_ALIGNMENT_RIGHT]], data)
			_skill_bar(row, base, lvl)
	_top.text = _help("infoskills")
	var left := _sk_left()
	_points("skillpoint", left)
	if left < Progression.skill_points:
		_ok.text = OriginalLines.pip("accept")
		_ok.visible = true


## PipPageStat.skillPoint: points not yet placed on the page.
func _sk_left() -> int:
	var used := 0
	for n in _sk_add.values():
		used += int(n)
	return Progression.skill_points - used


## selSkill: one pending point, kept until Accept (transOk).
func _sel_skill(id: String) -> void:
	if Progression.rank(id) + int(_sk_add.get(id, 0)) >= Progression.skill_cap(id):
		return
	if _sk_left() <= 0:
		Progression._info("noSkillPoint")
		return
	_sk_add[id] = int(_sk_add.get(id, 0)) + 1
	_fill()


func _unsel_skill(id: String) -> void:
	if int(_sk_add.get(id, 0)) <= 0:
		return
	_sk_add[id] = int(_sk_add[id]) - 1
	if int(_sk_add[id]) <= 0:
		_sk_add.erase(id)
	_fill()


## SkillProgress at (218.55, 12): p1..p20 every 12 px, SkillKusok2 on the level
## boxes with the level number. Frames: 0 empty, 1 owned (minlvl), 2 pending.
func _skill_bar(row: Control, owned: int, lvl: int) -> void:
	for k in range(1, 21):
		var at_level := SK_LEVELS.find(k)
		var frame := 1 if k <= owned else (2 if k <= lvl else 0)
		var path := SK_BOX % ["lvl" if at_level >= 0 else "box", frame]
		var box := TextureRect.new()
		box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		box.stretch_mode = TextureRect.STRETCH_SCALE
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if ResourceLoader.exists(path):
			box.texture = load(path)
		box.position = Vector2(218.55 + 12.0 * (k - 1) - 7.55, 1.5)
		box.size = Vector2(16, 25)
		row.add_child(box)
		if at_level >= 0:
			var num := Label.new()
			_style(num, 11, Color.BLACK)
			num.text = str(at_level + 1)
			num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			num.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# SkillKusok2 art fills x 0.55..15.95 of the 16 px plate.
			num.position = box.position + Vector2(0.55, 0.0)
			num.size = Vector2(15.4, box.size.y)
			row.add_child(num)


func _fill_perks() -> void:
	_head([[OriginalLines.pip("is5"), 7, 300], [OriginalLines.pip("is2"), 335, 150]])
	if _choosing:
		_title.text = OriginalLines.pip("chooseperk")
		var ready: Array = []
		var later: Array = []
		for entry_v in Progression.choosable_perks():
			var status := Progression.perk_status(str((entry_v as Dictionary).get("id", "")))
			if status == 1:
				ready.append(entry_v)
			elif status >= 0:
				later.append(entry_v)
		for entry_v in ready + later:
			var def: Dictionary = entry_v
			var id := str(def.get("id", ""))
			var status := Progression.perk_status(id)
			var color := GREEN if status == 1 else DARK
			var rank := Progression.perk_rank(id)
			_row([[OriginalLines.eff(id), 7, 330, color], [_perk_lvl(def, rank), 337, 218, color]], {
				"title": OriginalLines.eff(id),
				"rich": _eff_str(id, rank, def.get("reqs", []), rank),
				"pic": id,
				"primary": func() -> void:
					if Progression.spend_perk(id):
						_choosing = false
						_fill(),
			})
		_ok.text = OriginalLines.gui("cancel")
		_ok.visible = true
	else:
		for entry_v in Progression.perks():
			var def: Dictionary = entry_v
			var id := str(def.get("id", ""))
			var rank := Progression.perk_rank(id)
			if rank <= 0:
				continue
			_row([[OriginalLines.eff(id), 7, 330], [_perk_lvl(def, rank), 337, 218]], {
				"title": OriginalLines.eff(id),
				"rich": _eff_str(id, rank, def.get("reqs", []), rank - 1),
				"pic": id,
			})
		if _rows.is_empty():
			_empty.text = OriginalLines.pip("emptyperk")
		if Progression.perk_points > 0:
			_ok.text = OriginalLines.pip("choose")
			_ok.visible = true
		_points("perkpoint", Progression.perk_points)


## setStatItem: lvl, plus "/maxlvl" when the perk has more than one rank.
func _perk_lvl(def: Dictionary, rank: int) -> String:
	var mx := int(def.get("max_rank", 1))
	return "%d/%d" % [rank, mx] if mx > 1 and mx < 1000 else str(rank)


func _fill_effects() -> void:
	_head([[OriginalLines.pip("is3"), 7, 300], [OriginalLines.pip("is4"), 400, 150, HORIZONTAL_ALIGNMENT_RIGHT]])
	for row_v in Effects.pip_rows():
		var row: Dictionary = row_v
		_row([[str(row.name), 7, 380], [str(row.value), 400, 150, GREEN, HORIZONTAL_ALIGNMENT_RIGHT]], {
			"title": str(row.name),
			"info": str(row.info),
		})
	if _rows.is_empty():
		_empty.text = OriginalLines.pip("emptyeff")


func _fill_health() -> void:
	if _no_med():
		_empty.text = OriginalLines.pip("emptymed")
		return
	var maxh := float(Progression.max_health()) if Progression.has_method("max_health") else float(GameState.MAX_HEALTH)
	_top.text = OriginalLines.pip("usemed1")
	_hp_bar(_pair(OriginalLines.pip("hp"), "%d/%d" % [GameState.health, int(maxh)], _med(GameState.health, maxh), _med_row(_pip_info("hp"), "hp")), GameState.health / maxf(1.0, maxh))
	_pair(OriginalLines.pip("organism") + ":", "")
	var cap := maxf(1.0, GameState.organ_max())
	for spec: Array in [["head", "Head", GameState.head_hp, "head"], ["tors", "Tors", GameState.torso_hp, "torso"], ["legs", "Legs", GameState.legs_hp, "legs"], ["blood", "Blood", GameState.blood_hp, ""]]:
		var cur := float(spec[2])
		var part := str(spec[3])
		_hp_bar(_pair("   " + OriginalLines.pip(spec[0]), "%d/%d" % [int(round(cur)), int(cap)], _med(cur, cap), _med_row({
			"title": OriginalLines.pip(spec[0]),
			"info": OriginalLines.pip("stat%s%d" % [spec[1], _stage_of(cur, cap)]),
		}, "organ" if part != "" else "bloodpak", part)), cur / cap)
	if GameState.has_method("mana_max"):
		var mmax := maxf(1.0, float(GameState.mana_max()))
		var stage := 4 if GameState.mana_hp <= 0.0 else _stage_of(GameState.mana_hp, mmax)
		_hp_bar(_pair("   " + OriginalLines.pip("mana"), "%d/%d" % [int(round(GameState.mana_hp)), int(mmax)], _med(GameState.mana_hp, mmax), _med_row({
			"title": OriginalLines.pip("mana"),
			"info": OriginalLines.pip("statMana%d" % stage),
		}, "mana")), GameState.mana_hp / mmax)
	_pair(OriginalLines.pip("rad"), str(int(round(GameState.rad))), RED if GameState.rad > 0.0 else GREEN, _med_row(_pip_info("rad"), "antiradin"))
	_pair(OriginalLines.pip("radx"), "%d%%" % int(round((1.0 - GameState.rad_mult()) * 100.0)), GREEN, _pip_info("radx"))
	_pair(OriginalLines.pip("cut"), Effects._num(round(Effects.cut * 10.0) / 10.0), RED if Effects.cut > 0.0 else GREEN, _med_row(_pip_info("cut"), "pot0"))
	_pair(OriginalLines.pip("resbleeding"), "%d%%" % int(round((1.0 - Effects.player_vulner("DAM_BLEED")) * 100.0)), GREEN, _pip_info("resbleeding"))
	_pair(OriginalLines.pip("poison"), Effects._num(round(Effects.poison * 10.0) / 10.0), RED if Effects.poison > 0.0 else GREEN, _med_row(_pip_info("poison"), "antidote"))
	_pair(OriginalLines.pip("respoison"), "%d%%" % int(round((1.0 - Effects.player_vulner("DAM_POISON")) * 100.0)), GREEN, _pip_info("respoison"))
	var pet := _health_pet()
	if pet != "":
		var pet_data := {"title": Pets.pet_name(pet), "info": OriginalLines.desc("unit", pet)}
		if PET_FOOD.has(pet):
			pet_data = _med_row(pet_data, str(PET_FOOD[pet]))
		var pmax := maxf(1.0, float(Pets.stats(pet).maxhp))
		var php := maxf(0.0, Pets.hp_of(pet))
		_hp_bar(_pair(Pets.pet_name(pet), "%d/%d" % [int(round(php)), int(pmax)], _med(php, pmax), pet_data), php / pmax)
	# PipPageStat meant to list addictions here; its loop never ran (an Object has no length).
	for ad in Effects.addictions.keys():
		var proc := int(Effects.addictions[ad])
		if proc <= 0:
			continue
		var lvl := Effects.addiction_level(str(ad))
		_pair(OriginalLines.eff(str(ad) + "_ad"), "%d%% (%s)" % [proc, OriginalLines.pip("ad%d" % lvl)], ORANGE if lvl > 0 else GREEN, _med_row({
			"title": OriginalLines.eff(str(ad) + "_ad"),
			"info": Effects.describe(str(ad) + "_ad", maxi(1, lvl)),
		}, "detoxin"))
	# visPipStatItem numb is left-aligned at 335; the bar sits to its right.
	for row in _rows:
		for c in row.get_children():
			if c is Label and is_equal_approx((c as Label).position.x, 337.0):
				(c as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


## PipPageStat health rows: showBottext names the row's medicine and count
## (shown whether or not it is needed), itemClick spends it (Invent.usePotion).
## kind is an item id, "hp" / "mana" (best-fitting potion) or "organ" (getMed).
func _med_row(data: Dictionary, kind: String, part := "") -> Dictionary:
	data["bottom"] = _med_bottom.bind(kind, part)
	data["primary"] = _med_use.bind(kind, part)
	return data


func _med_bottom(kind: String, part: String) -> String:
	var label := ""
	var n := 0
	match kind:
		"hp":
			label = OriginalLines.pip("healpotions")
			for id in ["pot1", "pot2", "pot3"]:
				n += Inventory.count(id)
		"mana":
			label = OriginalLines.name_of("potm1")
			for id in ["potm1", "potm2", "potm3"]:
				n += Inventory.count(id)
		_:
			var id := _organ_med(part) if kind == "organ" else kind
			if id == "":
				return ""
			label = OriginalLines.name_of(id)
			n = Inventory.count(id)
	return "%s: [color=#%s]%d[/color]" % [label, YELLOW.to_html(false), n]


func _med_use(kind: String, part: String) -> void:
	var quick := get_tree().get_first_node_in_group("quick_keys")
	match kind:
		"hp", "mana":
			if quick != null:
				quick.use_potion("" if kind == "hp" else "mana")
		"organ":
			var id := _organ_med(part)
			if id != "":
				GameState.organ_target = part
				Inventory.use(id)
				GameState.organ_target = ""
		_:
			Inventory.use(kind)
	_fill()
	_refresh_rpanel()


## Invent.getMed: the owned heal="organ" item (within the medic skill) whose
## horgan best fits the part's loss plus 25.
func _organ_med(part: String) -> String:
	var cur: float = {"head": GameState.head_hp, "torso": GameState.torso_hp, "legs": GameState.legs_hp}.get(part, 0.0)
	var gap := GameState.organ_max() - cur
	var medic := Progression.skill_level_of("medic")
	var best := ""
	var best_d := 10000.0
	for id: String in Effects._items:
		var row: Dictionary = Effects._items[id]
		if str(row.get("heal", "")) != "organ" or Inventory.count(id) <= 0 or int(row.get("minmed", 0)) > medic:
			continue
		var d := absf(float(row.get("horgan", 0.0)) - gap + 25.0)
		if d < best_d:
			best_d = d
			best = id
	return best


## gg.pet: the called pet, else the phoenix once pet_phoenix is set.
func _health_pet() -> String:
	if Pets.current != "":
		return Pets.current
	var t: Variant = Travel.trigger("pet_phoenix")
	return "phoenix" if t != null and int(t) > 0 else ""


## Game triggers nomed: set on a new game, cleared on the first visit to rbl.
func _no_med() -> bool:
	var v: Variant = Travel.trigger("nomed")
	return v != null and int(v) > 0


## visPipStatItem hpbar (453.25, 6): hp_bar2 fill scaled by ratio, then the frame and quarter ticks.
func _hp_bar(row: Control, ratio: float) -> void:
	var r := clampf(ratio, 0.0, 1.0)
	var at := Vector2(453.25, 7.5)
	for spec: Array in [["fill", Vector2(-2.25 * r, -2.0), Vector2(105.0 * r, 16.0)], ["frame", Vector2(-2.25, -2.0), Vector2(106.0, 17.0)], ["ticks", Vector2(22.75, -2.0), Vector2(56.0, 17.0)]]:
		var path := "res://assets/ui/pip/hpbar/%s.png" % spec[0]
		if not ResourceLoader.exists(path) or (spec[2] as Vector2).x <= 0.0:
			continue
		var t := TextureRect.new()
		t.texture = load(path)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.position = at + spec[1]
		t.size = spec[2]
		row.add_child(t)


func _pip_info(id: String) -> Dictionary:
	var info := OriginalLines.desc("pip", id)
	if info == "":
		return {}
	return {"title": OriginalLines.pip(id), "info": info}


func _stage_of(cur: float, cap: float) -> int:
	var r := cur / maxf(1.0, cap)
	if r >= 0.75:
		return 0
	if r >= 0.5:
		return 1
	if r >= 0.25:
		return 2
	return 3


func _med(cur: float, cap: float) -> Color:
	if cur < cap * 0.25:
		return RED
	if cur < cap * 0.5:
		return ORANGE
	return GREEN


# --- Инвентарь ---

func _fill_invent(sub: int) -> void:
	var bags := get_node_or_null("/root/Inventory")
	if bags == null:
		return
	# PipPageInv.setSubPages statHead: the visPipInvItem fields; fav only where pip.reqKey.
	var head: Array = [[OriginalLines.pip("ii1") if sub <= 2 else "", INV_FAV.x, INV_FAV.y, HORIZONTAL_ALIGNMENT_RIGHT, YELLOW], [OriginalLines.pip("ii2"), INV_NAZV.x, INV_NAZV.y]]
	match sub:
		0:
			head.append_array([[OriginalLines.pip("ii3"), INV_HP.x, INV_HP.y, HORIZONTAL_ALIGNMENT_RIGHT], [OriginalLines.pip("ii4"), INV_AMMOTIP.x, INV_AMMOTIP.y]])
		1:
			head.append([OriginalLines.pip("ii3"), INV_HP.x, INV_HP.y, HORIZONTAL_ALIGNMENT_RIGHT])
		_:
			head.append_array([[OriginalLines.pip("ii5"), INV_HP.x, INV_HP.y, HORIZONTAL_ALIGNMENT_RIGHT], [OriginalLines.pip("ii6"), INV_AMMOTIP.x, INV_AMMOTIP.y]])
			if bags.hard_inv():
				head.append([OriginalLines.pip("ii8"), INV_MASS.x, INV_MASS.y])
	_head(head)
	_inv_cat_buttons = PipTrade.add_cats(self, INV_CATS[sub], int(_inv_cat[sub]), func(i: int) -> void: _set_inv_cat(sub, i))
	var listed := _invent_ids(bags, sub)
	for id: String in listed[0]:
		_inv_row(bags, id, sub)
	_inv_key = _invent_key(sub)
	if _rows.is_empty():
		_empty.text = OriginalLines.pip("emptyinv")
	_invent_footer(bags, sub, bool(listed[1]))
	var help := ""
	match sub:
		0:
			help = _help_text(Locale.t("pip_invupr1", OriginalLines.pip("invupr1")))
		1:
			help = _help_text(Locale.t("pip_invupr2", OriginalLines.pip("invupr2")))
		2, 3:
			help = _help("invupr3")
	if sub <= 2 and Prompts.pad:
		help += "\n" + Locale.tf("pip_fav_pad", [Prompts.ui("fav")])
	_top.text = help


## The ids the sub page lists, in order, and whether hidden spells exist.
func _invent_ids(bags: Node, sub: int) -> Array:
	var want: Variant = (INV_CATS[sub] as Array)[int(_inv_cat[sub])]
	var any_hidden := false
	var ids: Array = []
	for id: String in bags.carried():
		if not _in_sub(bags, id, sub):
			continue
		if sub == 0 and Stash.is_hidden(id) and Stash.hidden_listable(id):
			any_hidden = true
		if str(want) != "" and not _cat_match(want, _inv_trol(bags, id, sub) if sub <= 1 else _inv_tip(id)):
			continue
		if sub == 0 and Stash.is_hidden(id) and not _show_hidden:
			continue
		if sub == 1 and Stash.is_stored(id):
			continue
		ids.append(id)
	return [ids, any_hidden]


func _invent_key(sub: int) -> Array:
	return [sub, int(_inv_cat[sub]), _show_hidden, Inventory.hard_inv()]


## PipPageInv.setStatItem on each row in place: equip, use, favourite and
## drop marks change row text, not the rows. False when the rows themselves
## change (an item gone or new, another sub page or category): rebuild.
func _invent_in_place() -> bool:
	if _page != INVENT or _rows.is_empty():
		return false
	var sub := int(_sub[INVENT])
	var bags := get_node_or_null("/root/Inventory")
	if bags == null or _inv_key != _invent_key(sub):
		return false
	var listed := _invent_ids(bags, sub)
	var ids: Array = listed[0]
	if ids.size() != _rows.size():
		return false
	for i in ids.size():
		if str(_rows[i].get_meta("inv_id", "")) != str(ids[i]):
			return false
	for i in ids.size():
		_inv_apply(_rows[i], _inv_spec(bags, str(ids[i]), sub))
	_invent_footer(bags, sub, bool(listed[1]))
	var f := _focused_row_index()
	if f >= 0:
		_on_row_focus(_rows[f])
	_refresh_rpanel()
	return true


## PipPageInv.updateDropButton and the caps / mass line.
func _invent_footer(bags: Node, sub: int, any_hidden: bool) -> void:
	_ok.visible = false
	if not _drops.is_empty():
		_ok.text = OriginalLines.pip("drop")
		_ok.visible = true
	elif sub == 0 and any_hidden:
		_ok.text = OriginalLines.pip("showhidden")
		_ok.visible = true
	var mass := "%s: %d" % [OriginalLines.pip("caps"), int(bags.count("money"))]
	if bags.hard_inv():
		match sub:
			0:
				mass = Stash.ret_mass(4) + "    " + Stash.ret_mass(5)
			2:
				mass += "    " + Stash.ret_mass(1)
			3:
				mass += "    " + Stash.ret_mass(3)
			4:
				mass += "    " + Stash.ret_mass(2)
	_bottom.text = mass


## PipPageInv / Opt / Info: pip.helpText for the open page, "" hides butHelp.
## @N is the key of the entry's sN attribute.
func _page_help() -> String:
	if _choosing or _opt_auto:
		return ""
	for h: Array in HELPS:
		if int(h[0]) != _page or (int(h[1]) >= 0 and int(h[1]) != int(_sub[_page])):
			continue
		if int(h[0]) == MENU and menu_only:
			return ""
		var text := OriginalLines.pip(str(h[2]))
		var keys: Array = h[3]
		for i in range(keys.size(), 0, -1):
			text = text.replace("@%d" % i, Prompts.action_plain(str(keys[i - 1])))
		return _yellow(text)
	return ""


func _show_help(on: bool) -> void:
	_help_box.visible = on and _help_text_now != ""
	if _help_box.visible:
		_help_rich.text = _help_text_now
		_help_rich.scroll_to_line(0)


func _help(id: String) -> String:
	return _help_text(OriginalLines.pip(id))


func _help_text(text: String) -> String:
	# "@1"/"@2" are the keyWeapon1 / keyWeapon12 keys.
	text = text.replace("@1", Favorites.cell_text(1)).replace("@2", Favorites.cell_text(Favorites.HOTKEYS))
	var out: PackedStringArray = []
	for line in text.split("@"):
		if line.strip_edges() != "":
			out.append(line)
	return "\n".join(out)


## The original help says [click] / [right click]; on a pad those are A / X.
func _glyphs(text: String) -> String:
	if not Prompts.pad:
		return text
	for token in ["[клик]", "[click]"]:
		text = text.replace(token, Prompts.ui("accept"))
	for token in ["[правая кнопка]", "[right click]"]:
		text = text.replace(token, Prompts.ui("alt"))
	return text


## PipPageInv.setSubPages: weapons (explosives too) on 0, armour on 1; items
## by itemTip: a / e on Ammunition, us > 0 on Equipment, the rest on Other.
func _in_sub(bags: Node, id: String, sub: int) -> bool:
	var row := Vendors.item_data(id)
	var tip := str(row.get("tip", _type_of(id)))
	var weapon: bool = tip != "spell" and (bags.is_gun(id) or bags.is_spell(id) or (bags.weapon_def(id) as Dictionary).size() > 0)
	match sub:
		0:
			return weapon
		1:
			return not weapon and bags.can_wear(id)
	if bags.can_wear(id) or (weapon and not tip in AMMO_TYPES):
		return false
	if tip in AMMO_TYPES:
		return sub == 4
	var usable: bool = int(row.get("us", 0)) > 0 if not row.is_empty() else (tip in GEAR_TYPES or bags.is_consumable(id))
	return sub == (2 if usable else 3)


func _type_of(id: String) -> String:
	if _types.is_empty():
		var file := FileAccess.open(ITEMS_PATH, FileAccess.READ)
		if file != null:
			var doc: Variant = JSON.parse_string(file.get_as_text())
			if doc is Dictionary:
				for row_v in (doc as Dictionary).get("items", []):
					if row_v is Dictionary:
						_types[str(row_v.get("id", ""))] = str(row_v.get("type", ""))
		_types["__loaded"] = ""
	return str(_types.get(id, ""))


func _inv_tip(id: String) -> String:
	var tip := str(Vendors.item_data(id).get("tip", ""))
	return tip if tip != "" else _type_of(id)


## PipPageInv obj.trol: the row icon frame.
func _inv_trol(bags: Node, id: String, sub: int) -> String:
	if sub == 0:
		var skill := int(Vendors.weapon_data(id).get("skill", 0))
		return "w%d" % (6 if skill == 7 else skill)
	if sub == 1:
		return "armor%d" % int(Vendors.armor_data(id).get("tip", 1)) if bags.can_wear(id) else ""
	var tip := _inv_tip(id)
	if tip == "food" and int(Effects.item_row(id).get("ftip", 0)) == 1:
		return "drink"
	return tip


## PipPage.checkCat.
func _cat_match(want: Variant, tip: String) -> bool:
	return tip in (want as Array) if want is Array else tip == str(want)


func _set_inv_cat(sub: int, i: int) -> void:
	SfxBank.play("ui_click")
	_inv_cat[sub] = i
	_focus_inv_cat = i
	_drops.clear()
	_fill()


func _inv_row(bags: Node, id: String, sub: int) -> void:
	var spec := _inv_spec(bags, id, sub)
	var b := _row(spec.cols, spec.data)
	b.set_meta("inv_id", id)
	PipTrade.row_icon(b, str(spec.trol), INV_TROL_X)
	b.modulate.a = 0.4 if bool(spec.dim) else 1.0


func _inv_apply(b: Button, spec: Dictionary) -> void:
	_row_labels(b, spec.cols)
	b.set_meta("data", spec.data)
	b.modulate.a = 0.4 if bool(spec.dim) else 1.0


## One inventory row: its columns, row data, trol icon and dimming.
func _inv_spec(bags: Node, id: String, sub: int) -> Dictionary:
	var name := OriginalLines.name_of(id)
	if name == id:
		name = str(bags.name_of(id))
	var on := (sub == 0 and (str(bags.weapon_id) == id or str(bags.spell_id) == id)) or (sub == 1 and bool(bags.is_worn(id)))
	var color := YELLOW if on else GREEN
	var info := OriginalLines.desc_of(id)
	var cols: Array = [[name, INV_NAZV.x, INV_NAZV.y, color]]
	var data := {"title": name}
	var tip := str(Vendors.item_data(id).get("tip", _type_of(id)))
	match sub:
		0:
			var expl := Stash.weapon_tip(id) == 4
			if not expl:
				cols.append([_durability(id, true), INV_HP.x, INV_HP.y, color, HORIZONTAL_ALIGNMENT_RIGHT])
			var ammo := str((bags.weapon_def(id) as Dictionary).get("ammo", ""))
			var ammo_tip := ""
			if expl:
				cols.append([str(int(bags.count(id))), INV_AMMO.x, INV_AMMO.y, color, HORIZONTAL_ALIGNMENT_RIGHT])
			elif ammo != "":
				cols.append([str(int(bags.count(ammo))), INV_AMMO.x, INV_AMMO.y, color, HORIZONTAL_ALIGNMENT_RIGHT])
				ammo_tip = OriginalLines.name_of(ammo)
			if _drops.has(id):
				ammo_tip = OriginalLines.pip("drop") + (": %d" % int(_drops[id]) if expl else "")
			cols.append([ammo_tip, INV_AMMOTIP.x, INV_AMMOTIP.y, color])
			data["primary"] = func() -> void: bags.equip(id)
			data["ico"] = [1, id]
		1:
			if Vendors.armor_data(id).get("tip", 1) != 3:
				cols.append([_durability(id, false), INV_HP.x, INV_HP.y, color, HORIZONTAL_ALIGNMENT_RIGHT])
			data["primary"] = func() -> void:
				if bags.is_worn(id):
					bags.unworn(id)
				else:
					bags.wear(id)
			if _drops.has(id):
				cols.append([OriginalLines.pip("drop"), INV_AMMOTIP.x, INV_AMMOTIP.y, color])
			data["ico"] = [3 if int(Vendors.armor_data(id).get("tip", 1)) == 3 else 2, id]
		_:
			cols.append([str(int(bags.count(id))), INV_HP.x, INV_HP.y, color, HORIZONTAL_ALIGNMENT_RIGHT])
			if tip == "valuables" and float(Vendors.item_data(id).get("price", 0)) > 0.0:
				cols.append([Stash._numb(float(Vendors.item_data(id).price)), INV_AMMO.x, INV_AMMO.y, color, HORIZONTAL_ALIGNMENT_RIGHT])
			# PipPageInv: TextParser.istxt("p", tip) else "stuff"; cat.substring(2).
			var cat := OriginalLines.pip(tip) if tip != "" else ""
			if cat == tip or cat == "":
				cat = OriginalLines.pip("stuff")
			if cat.length() > 2 and cat.substr(1, 1) == " ":
				cat = cat.substr(2)
			cols.append([OriginalLines.pip("drop") + ": %d" % int(_drops[id]) if _drops.has(id) else cat, INV_AMMOTIP.x, INV_AMMOTIP.y, color])
			if tip != "spell" and not (bags.weapon_def(id) as Dictionary).is_empty():
				# Grenades and mines on Ammunition: the same weapon icon as on Weapons.
				data["ico"] = [1, id]
			if tip == "spell":
				data["ico"] = [3, id]
				color = YELLOW if str(bags.spell_id) == id else GREEN
				for c: Array in cols:
					c[3] = color
				data["primary"] = func() -> void: bags.equip(id)
			elif Craft.PORTABLE.has(id):
				data["primary"] = func() -> void:
					Vendors.work_tip = str(Craft.PORTABLE[id])
					_ctx_page = PipTrade.WORK
					_go(PipTrade.WORK, 0)
			elif sub == 2 and bags.is_consumable(id):
				data["primary"] = func() -> void: bags.use(id)
			elif Pets.item_pet(id) != "":
				data["primary"] = func() -> void: Pets.use_item(id)
				info += _pet_info(Pets.item_pet(id))
			elif Story.is_book(id) or Story.is_document(id) or id == "sphera":
				data["primary"] = func() -> void: Story.read_item(id)
	data["secondary"] = _mark_drop.bind(id, sub)
	# PipPageInv.assignKey: weapons, armour and equipment take favourite cells.
	if sub <= 2:
		data["fav_id"] = id
	# setStatItem fav: the cell's key, yellow, right-aligned left of the trol.
	cols.append([str(Favorites.label_of(id)), INV_FAV.x, INV_FAV.y, YELLOW, HORIZONTAL_ALIGNMENT_RIGHT])
	data["info"] = info
	data["info_tip"] = ["weapon" if sub == 0 else ("armor" if sub == 1 else ("a" if tip == "a" else ("e" if tip == "e" else "item"))), id]
	if sub >= 2 and bags.hard_inv() and float(bags.item_mass(id)) > 0.0:
		cols.append([Stash._numb(float(bags.count(id)) * float(bags.item_mass(id))), INV_MASS.x, INV_MASS.y, MASS_COLOR])
	return {
		"cols": cols,
		"data": data,
		"trol": _inv_trol(bags, id, sub),
		"dim": (sub == 0 and Stash.is_hidden(id)) or (sub == 1 and not on and Stash.armor_locked(id)),
	}


## PipPage item info pet_info: the companion's hp, skin, resistance and damage.
func _pet_info(pid: String) -> String:
	var st: Dictionary = Pets.stats(pid)
	var s := "\n\n%s: %d/%d" % [OriginalLines.pip("hp"), int(round(Pets.hp_of(pid))), int(round(float(st.maxhp)))]
	s += "\n%s: %d" % [OriginalLines.pip("skin"), int(round(float(st.skin)))]
	if float(st.vulner) < 1.0:
		s += "\n%s: %d%%" % [OriginalLines.pip("allresist"), int(round((1.0 - float(st.vulner)) * 100.0))]
	s += "\n%s: %d" % [OriginalLines.pip("damage"), int(round(float(st.dam)))]
	return s


func _durability(id: String, weapon: bool) -> String:
	if Condition == null:
		return ""
	var cap := float(Condition.weapon_max(id) if weapon else Condition.armor_max(id))
	if cap <= 0.0:
		return ""
	var hp := float(Condition.weapon_hp(id) if weapon else Condition.armor_hp(id))
	return "%d%%" % clampi(int(round(hp / cap * 100.0)), 0, 100)


func _drop(id: String, n: int = 1) -> void:
	# ItemInteraction.drop / dropWeapon / dropArmor: the item leaves the bag and
	# lands as a world drop beside the player, past the autopick box so it is
	# not taken straight back. Not in the base or as the alicorn.
	var bags := get_node_or_null("/root/Inventory")
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var host := get_tree().get_first_node_in_group("land_props")
	if bags == null or player == null or host == null or Stash.in_base() or ScriptsEngine.alicorn:
		return
	n = mini(n, int(bags.count(id)))
	var drop := GroundLoot.new()
	GroundLoot.keep_condition(drop, id)
	if n <= 0 or not bags.spend(id, n):
		drop.free()
		return
	drop.item_id = id
	drop.stack = n
	drop.auto = false
	host.add_child(drop)
	var side := -1.0 if player.get("facing") is int and int(player.get("facing")) < 0 else 1.0
	drop.global_position = player.global_position + Vector2(80.0 * side, -40.0)
	drop.shove_clear()


## PipPageInv.itemRightClick: spells and magic hide / come back; everything
## else is marked to be dropped (explosives and items one more each time, all
## with shift), and the "drop" button throws the marked ones out.
func _mark_drop(id: String, sub: int) -> void:
	if Travel.no_act():
		Story.info("noAct")
		return
	var all := Input.is_key_pressed(KEY_SHIFT)
	var have := Inventory.count(id)
	if sub <= 1:
		if sub == 0 and Stash.weapon_tip(id) == 5:
			Stash.toggle_hidden(id)
			_refresh()
			return
		if Stash.in_base():
			Story.info("noDrop1")
			return
		if sub == 0 and Stash.weapon_tip(id) == 4:
			if have <= 0:
				Story.info("noDrop2")
				return
			_drops[id] = have if all else mini(int(_drops.get(id, 0)) + 1, have)
		elif sub == 0 and not Stash.can_drop_weapon(id):
			Story.info("disWeapon" if Stash.is_hidden(id) else "noDrop2")
			return
		elif sub == 1 and not Stash.can_drop_armor(id):
			Story.info("noDrop2")
			return
		elif _drops.has(id):
			_drops.erase(id)
		else:
			_drops[id] = 1
	else:
		if Stash.in_base():
			Story.info("noDrop1")
			return
		var tip := _type_of(id)
		if Inventory.item_mass(id) <= 0.0 or tip == "book" or tip == "sphera":
			Story.info("noDrop2")
			return
		_drops[id] = have if all else int(_drops.get(id, 0)) + 1
	_refresh()


## PipPageInv.showH "drop", then PipBuck.onoff(-1).
func _drop_marked() -> void:
	for id: String in _drops.keys():
		var n := int(_drops[id])
		if n <= 0:
			continue
		if Inventory.can_wear(id):
			if Inventory.is_worn(id) and GameState._in_battle():
				Story.info("noChArmor")
				continue
			if Stash.can_drop_armor(id):
				_drop(id, 1)
		elif Stash.weapon_tip(id) in [1, 2, 3]:
			if Stash.can_drop_weapon(id):
				_drop(id, 1)
		else:
			_drop(id, n)
	_drops.clear()
	_close()


func _arm_listen(id: String) -> void:
	_listen_id = id
	_listen_frame = Engine.get_process_frames()
	var cell := int(Favorites.cell_of(id))
	if cell < 0:
		cell = MagicBinds.slot_of(id) + Favorites.CELL_SPELL if MagicBinds.slot_of(id) >= 0 else 1
	_listen_cell = maxi(_FAV_CELLS.find(cell), 0)
	_title.text = OriginalLines.name_of(id)
	_show_listen()


## Cells the pad picker walks: keyWeapon 1-12, ^1-^12, keySpell 1-4, keyGrenad, keyMagic.
const _FAV_CELLS: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30]


func _cell_label(cell: int) -> String:
	if cell < Favorites.CELL_SPELL:
		return Favorites.cell_text(cell)
	var action := "magic_attack" if cell == Favorites.CELL_MAGIC else MagicBinds.action_of(cell - Favorites.CELL_SPELL)
	if cell == Favorites.CELL_THROW:
		action = "grenade"
	var events := InputMap.action_get_events(action) if InputMap.has_action(action) else []
	return str(InputBindings.event_text(events[0])) if not events.is_empty() else Locale.t("unbound")


func _show_listen() -> void:
	var text := OriginalLines.pip("infokeys").replace("[клик] — ", "").replace("[click] - ", "")
	var cell: int = _FAV_CELLS[_listen_cell]
	text += "\n\n" + Locale.tf("pip_fav_pick", [_cell_label(cell), Prompts.ui("adjust"), Prompts.ui("accept"), Prompts.ui("back")])
	_info.text = text


func _bind_event(event: InputEvent) -> bool:
	var cell := int(Favorites.cell_of_event(event))
	if cell <= 0 and not (event is InputEventKey):
		if event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_right", true):
			var step := -1 if event.is_action_pressed("ui_left", true) else 1
			_listen_cell = posmod(_listen_cell + step, _FAV_CELLS.size())
			_show_listen()
			return true
		if event.is_action_pressed("ui_accept"):
			cell = _FAV_CELLS[_listen_cell]
	if cell <= 0:
		return false
	Favorites.fav_item(_listen_id, cell)
	_listen_id = ""
	_refresh()
	return true


# --- Информация ---

func _fill_info(sub: int) -> void:
	match sub:
		0:
			_fill_local_map()
		1:
			_fill_quests()
		2:
			_fill_world()
		3:
			_fill_notes()
		4:
			_fill_enemies()
		_:
			_empty.text = OriginalLines.pip("emptyinv")


## PipPageInfo PAGE_LOCAL_MAP: emptymap in a nomap room, else the minimap.
func _fill_local_map() -> void:
	if not RoomFlags.allows("map"):
		_empty.text = OriginalLines.pip("emptymap")
		return
	_lmap = LocalMapPage.new()
	_lmap.position = PAGE
	_stage.add_child(_lmap)
	_stage.move_child(_lmap, _scroll.get_index())
	_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.visible = false
	_lmap.focus_neighbor_top = _lmap.get_path_to(_sub_buttons[int(_sub[INFO])])
	_lmap.focus_neighbor_left = _lmap.get_path_to(_page_buttons.get(INFO, _ctx_button))
	_lmap.focus_neighbor_bottom = _lmap.get_path_to(_close_button)
	if not _lmap.has_map():
		_lmap.queue_free()
		_lmap = null
		_scroll.visible = true
		_empty.text = OriginalLines.pip("emptymap")


## PipPageInfo PAGE_ENEMIES: groups (cat 1), kinds (cat 2) summing their
## members' frag_<id> kills, and killed units (cat 3). Kills / dkill (5)
## unlock infoUnit's stat tiers.
func _fill_enemies() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/bestiary.json")) if FileAccess.file_exists("res://assets/data/bestiary.json") else null
	if not parsed is Dictionary:
		return
	var list: Array = []
	var kind: Dictionary = {}
	for u: Dictionary in (parsed as Dictionary).get("units", []):
		var n := {"row": u, "kol": -1}
		var cat := str(u.cat)
		if cat == "3" and Travel.triggers.has("frag_" + str(u.id)):
			n.kol = int(Travel.triggers["frag_" + str(u.id)])
		if cat == "2":
			kind = n
		elif cat == "3" and not kind.is_empty() and int(n.kol) >= 0:
			kind.kol = maxi(int(kind.kol), 0) + int(n.kol)
		list.append(n)
	# visPipQuestItem kol 218..371, inside the 400 px Info list.
	_head([[OriginalLines.pip("frag"), 218, 153, HORIZONTAL_ALIGNMENT_RIGHT]])
	for n: Dictionary in list:
		var u: Dictionary = n.row
		var cat := str(u.cat)
		if int(n.kol) < 0 and cat != "1":
			continue
		var name := OriginalLines.unit(str(u.id))
		var indent: int = {"1": 5, "2": 30, "3": 55}.get(cat, 5)
		var kol := str(n.kol) if int(n.kol) > 0 else ""
		_row([[name, indent, 300 - indent, LIGHT if cat != "3" else GREEN], [kol, 300, 71, GREEN, HORIZONTAL_ALIGNMENT_RIGHT]], {
			"title": name,
			"rich": _yellow(OriginalLines.desc("unit", str(u.id)) + "\n" + _unit_info(u, int(n.kol))).replace("\u0003", "[color=#00ffff]").replace("\u0004", "[/color]"),
		})


## PipPageInfo.infoUnit: hp/skin/armour at kills >= dkill, damage and weapons
## at 2 x, dodge/observ/skill and resists at 3 x.
func _unit_info(u: Dictionary, kol: int) -> String:
	if str(u.cat) != "3":
		return ""
	var st: Dictionary = u.get("stats", {})
	var delta := float(st.get("dkill", 5))
	var n := 10 if delta <= 0.0 else int(floor(kol / delta))
	var y := func(v: Variant) -> String: return "[%s]" % str(v)
	# PipPage .blu (#00FFFF): marked with \u0003..\u0004, swapped in after _yellow.
	var b := func(v: String) -> String: return "\u0003%s\u0004" % v
	var s := "\n"
	if bool(u.get("comb", false)):
		if n >= 1:
			s += "%s: %s\n" % [OriginalLines.pip("hp"), y.call(st.get("hp", ""))]
			if st.has("skin"):
				s += "%s: %s\n" % [OriginalLines.pip("skin"), y.call(st.skin)]
			if st.has("aqual"):
				var q := "%s%%" % str(snappedf(float(st.aqual) * 100.0, 0.01))
				if st.has("armor"):
					s += "%s: %s (%s)  " % [OriginalLines.pip("armor"), y.call(st.armor), q]
				if st.has("marmor"):
					s += "%s: %s (%s)" % [OriginalLines.pip("marmor"), y.call(st.marmor), q]
				if st.has("armor") or st.has("marmor"):
					s += "\n"
		if n >= 2:
			var vd := int(st.get("visdam", 0))
			if (vd == 1 or vd == 3) and st.has("damage"):
				s += "%s: %s (%s)\n" % [OriginalLines.pip("dam_melee"), b.call(_dam_name(st.get("tipdam", 2))), y.call(st.damage)]
			if (vd == 2 or vd == 3) and st.has("sdamage"):
				s += "%s: %s (%s)\n" % [OriginalLines.pip("dam_shoot"), b.call(_dam_name(st.get("stipdam", 0))), y.call(st.sdamage)]
			var guns: Array = []
			for w: Array in u.get("w", []):
				var dam := "" if w[1] == null else (str(int(w[1])) if float(w[1]) == floorf(float(w[1])) else str(snappedf(float(w[1]), 0.1)))
				guns.append(b.call(OriginalLines.text("weapon", str(w[0]))) + (" (%s)" % y.call(dam) if dam != "" else ""))
			if not guns.is_empty():
				s += "%s: %s\n" % [OriginalLines.pip("enemy_weap"), ", ".join(guns)]
		if n >= 3:
			if st.has("dexter"):
				var d := float(st.dexter)
				s += "%s: %s\n" % [OriginalLines.pip("dexter"), y.call(("+" if d > 1.0 else "") + str(roundi((d - 1.0) * 100.0)) + "%")]
			if st.has("observ"):
				s += "%s: %s\n" % [OriginalLines.pip("observ"), y.call(("+" if float(st.observ) > 0.0 else "") + str(st.observ))]
			if st.has("skill"):
				s += "%s: %s\n" % [OriginalLines.pip("weapskill"), y.call(str(roundi(float(st.skill) * 100.0)) + "%")]
	if n >= 3 and u.has("vulner"):
		s += OriginalLines.pip("resists") + ": "
		for v: Array in u.vulner:
			s += "%s: %s   " % [b.call(_dam_name(v[0])), y.call(str(roundi((1.0 - float(v[1])) * 100.0)) + "%")]
	return s


## Resistances.parseDamageType: a legacy index or a DAM_ name, shown as pip tipdam<i>.
func _dam_name(tip: Variant) -> String:
	const DAMS := ["DAM_PIERCE", "DAM_CUT", "DAM_BLUNT", "DAM_BURN", "DAM_EXPLOSION", "DAM_LASER", "DAM_PLASMA",
		"DAM_VENOM", "DAM_EMP", "DAM_ELECTRIC", "DAM_ACID", "DAM_COLD", "DAM_POISON", "DAM_BLEED", "DAM_BITE"]
	var s := str(tip)
	var i := DAMS.find(s) if s.begins_with("DAM_") else (int(s) if s.is_valid_int() else 0)
	return OriginalLines.pip("tipdam%d" % maxi(i, 0))


## PipPageInfo PAGE_QUEST: open and closed quests (state > 0), main ones
## marked; closed ones dim with (done). The right column is PipPage.infoQuest.
func _fill_quests() -> void:
	for q in Story.quest_list():
		var done: bool = q.state == 2
		var color := DARK if done else GREEN
		var title: String = q.nazv()
		var cols: Array = [[title + (" (%s)" % OriginalLines.pip("done") if done else ""), 32, 520, color]]
		var row := _row(cols, {"title": title, "rich": Story.quest_text(q.id, YELLOW.to_html(false), DARK.to_html(false))})
		if q.main:
			# visPipQuestItem mq: mainQuest frame 1 at 0.6261 scale, alpha 0.4 once done.
			var star := TextureRect.new()
			star.texture = QUEST_STAR
			star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			star.stretch_mode = TextureRect.STRETCH_SCALE
			star.size = Vector2(19.4, 21.3)
			star.position = Vector2(7.6, (row.custom_minimum_size.y - star.size.y) * 0.5)
			star.mouse_filter = Control.MOUSE_FILTER_IGNORE
			star.modulate.a = 0.4 if done else 1.0
			row.add_child(star)
	if _rows.is_empty():
		_empty.text = OriginalLines.pip("emptytasks")
	if Vendors.in_base() and not Vendors.open_tasks().is_empty():
		_ok.text = OriginalLines.pip("alltask")
		_ok.visible = true


## PipPageInfo PAGE_NOTES: dialogues and notes with imp, the text on the right.
func _fill_notes() -> void:
	for note: Dictionary in Story.note_list():
		var title := str(note.title)
		if title.begins_with(" - "):
			title = title.substr(3)
		var text := Story.note_text(str(note.id))
		_row([[title.substr(0, 60), 32, 520, GREEN], ["•", 8, 20, YELLOW if int(note.ico) == 3 else LIGHT]], {
			"title": title,
			"rich": _yellow(text),
		})
	if _rows.is_empty():
		_empty.text = OriginalLines.pip("emptyinv")


func _yellow(s: String) -> String:
	return s.replace("[", "\u0001").replace("]", "\u0002").replace("\u0001", "[color=#%s]" % YELLOW.to_html(false)).replace("\u0002", "[/color]")


func _fill_world() -> void:
	_map = WorldMapPage.new()
	_map.font = _font
	_map.target = _map_target
	_map.position = PAGE
	_map.target_changed.connect(_on_map_target)
	_stage.add_child(_map)
	_stage.move_child(_map, _scroll.get_index())
	# The empty list stays above the map and would swallow clicks on the land marks.
	_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ok.text = OriginalLines.pip("trans")
	_ok.visible = _map.target != ""
	if Travel.map_travel():
		_top.text = _help("infotravel")


func _on_map_target(id: String) -> void:
	_map_target = id
	_ok.visible = id != ""
	_wire_focus()


func _map_focus() -> Control:
	if _lmap != null and is_instance_valid(_lmap):
		return _lmap
	if _map == null or not is_instance_valid(_map):
		return null
	return _map.first_focus()


# --- Меню ---

func _fill_menu(sub: int) -> void:
	match sub:
		0:
			_fill_slots(true)
		1:
			_fill_slots(false)
		2:
			_fill_options()
		3:
			_fill_controls()
		4:
			_fill_log()


func _fill_slots(loading: bool) -> void:
	for slot in range(0 if loading else 1, SaveSlots.SLOTS + 1):
		var row := SaveSlots.info(slot)
		var label := OriginalLines.pip("autoslot") if slot == 0 else "%s %d" % [OriginalLines.pip("saveslot"), slot]
		var data := {}
		if row.is_empty():
			_row([[label, 7, 150], [OriginalLines.pip("freeslot"), 160, 390, DARK]], data)
		else:
			# PipPageOpt.showSaveInfo: nazv is the hero, pers the slot's look, then the lines.
			data["title"] = str(row.get("name", ""))
			data["ico"] = [4, str(row.get("armor", "")), row.get("look", {})]
			var s := "%s: [%d]\n%s\n\n" % [OriginalLines.pip("level"), int(row.get("level", 1)), SaveSlots.land_name(row)]
			s += "%s: [%s]\n" % [OriginalLines.pip("diff"), OriginalLines.gui("dif%d" % int(row.get("difficulty", 2)))]
			if bool(row.get("dead", false)):
				s += "\u0005%s\u0006\n" % OriginalLines.pip("dead")
			elif bool(row.get("hardcore", false)):
				s += OriginalLines.gui("opt2") + "\n"
			if bool(row.get("hardinv", false)):
				s += OriginalLines.gui("opt6") + "\n"
			if bool(row.get("rndpump", false)):
				s += OriginalLines.gui("opt4") + "\n"
			if str(row.get("version", "")) != "":
				s += "%s: [%s]\n" % [OriginalLines.gui("version"), str(row.version)]
			if row.has("play_ms"):
				s += "%s: [%s]\n" % [OriginalLines.pip("tgame"), SaveSlots.game_time(int(row.play_ms))]
			s += "%s: [%s]" % [OriginalLines.pip("saved"), str(row.get("date", ""))]
			# PipPage .red for a dead hardcore run.
			data["rich"] = _yellow(s).replace("\u0005", "[color=#ff3333]").replace("\u0006", "[/color]")
			_row([[label, 7, 150], [str(row.get("date", "")), 160, 230], ["%s %d" % [OriginalLines.pip("level"), int(row.get("level", 1))], 400, 150, GREEN, HORIZONTAL_ALIGNMENT_RIGHT]], data)
		if loading and not row.is_empty():
			data["primary"] = _load_slot.bind(slot)
		elif not loading and (not Travel.hardcore() or slot == SaveSlots.auto_slot()):
			# A hardcore run saves only into its autosave slot.
			data["primary"] = _save_slot.bind(slot)
		_rows[-1].set_meta("data", data)
	_top.text = _help("infoload" if loading else "infosave")


func _save_slot(slot: int) -> void:
	if SaveSlots.save(slot):
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_notice"):
			hud.show_notice(OriginalLines.pip("saved"))
		_info.text = OriginalLines.pip("saved")
	_fill()


func _load_slot(slot: int) -> void:
	SaveSlots.request_load(slot)
	if GameState.has_method("set_paused"):
		GameState.set_paused(false)
	get_tree().paused = false
	Travel.enter_game()


## PipPageOpt PAGE_OPTIONS, in the original order; language and camera
## distance are the port's, at the end.
func _fill_options() -> void:
	if _opt_auto:
		_fill_autopick()
		return
	_opt_row("fullscreen", {"primary": func() -> void:
		var full := DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)})
	_flag_row("zoom100")
	_check_row("quake", UiSettings.quake_cam, UiSettings.set_quake_cam)
	_volume_row("opt1_1", UiSettings.sound_volume, UiSettings.set_sound_volume)
	_volume_row("opt1_2", UiSettings.music_volume, UiSettings.set_music_volume)
	_volume_row("opt1_3", UiSettings.step_volume, UiSettings.set_step_volume)
	for opt: Array in [["help_mess", "help"], ["dial_on", "dialon"]]:
		var key := str(opt[1])
		_check_row(str(opt[0]), func() -> bool: return bool(UiSettings.value("game", key, true)),
			func(on: bool) -> void: UiSettings.set_value("game", key, on))
	_check_row("show_hit1", func() -> bool: return UiSettings.show_hit() > 0,
		func(on: bool) -> void: UiSettings.set_show_hit((2 if UiSettings.show_hit() == 2 else 1) if on else 0))
	_check_row("show_hit2", func() -> bool: return UiSettings.show_hit() == 2,
		func(on: bool) -> void: UiSettings.set_show_hit(2 if on else mini(UiSettings.show_hit(), 1)))
	for key: String in ["hint_tele", "sys_cur", "show_favs"]:
		_flag_row(key)
	_check_row("mat_filter", func() -> bool: return bool(UiSettings.value("game", "mat", true)),
		func(on: bool) -> void: UiSettings.set_value("game", "mat", on))
	_flag_row("err_show")
	_opt_row("autotake", {"primary": func() -> void:
		_opt_auto = true
		_fill()
		if not _rows.is_empty():
			_rows[0].call_deferred("grab_focus")})
	var langs := UiSettings.languages()
	if langs.size() > 1:
		_row([[Locale.t("opt_language"), 7, 360], [Locale.language_name(Locale.language), 380, 170, GREEN, HORIZONTAL_ALIGNMENT_RIGHT]], {
			"adjust": func(step: int) -> void: Locale.cycle_language(step),
		})
	_camera_row()
	_fill_room_mods()


## visPipOptItem: nazv at 7; statInfo shows the pip line's info on the right.
func _opt_row(id: String, data: Dictionary = {}, width := 364.0) -> Button:
	var text := OriginalLines.pip(id)
	data["title"] = text
	data["info"] = OriginalLines.desc("pip", id)
	return _row([[text, 7, width]], data)


func _flag_row(key: String) -> void:
	_check_row(key, func() -> bool: return UiSettings.flag(key), func(on: bool) -> void: UiSettings.set_flag(key, on))


## The check CheckBox at 374. Left / right set it off / on.
func _check_row(id: String, getter: Callable, setter: Callable) -> void:
	var b := _opt_row(id)
	var box := TextureRect.new()
	box.texture = CheckMark.icon(bool(getter.call()), GREEN)
	box.position = Vector2(380, 5.5)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	var put := func(on: bool) -> void:
		setter.call(on)
		box.texture = CheckMark.icon(bool(getter.call()), GREEN)
	var data: Dictionary = b.get_meta("data")
	data["primary"] = func() -> void: put.call(not bool(getter.call()))
	data["adjust"] = func(step: int) -> void: put.call(step > 0)


## numb right-aligned to 557 and the scr ScrollBar from 259.6, 0..100.
func _volume_row(id: String, getter: Callable, setter: Callable) -> void:
	_bar_row(_opt_row(id, {}, 250.0), func() -> int: return int(round(float(getter.call()) * 100.0)),
		func(v: int) -> void: setter.call(v / 100.0), func(v: int) -> String: return str(v), 5)


## Port extra: camera distance on the same bar, MIN_DISTANCE..MAX_DISTANCE.
func _camera_row() -> void:
	var nazv := Locale.t("cam_title")
	var span := CameraDistance.MAX_DISTANCE - CameraDistance.MIN_DISTANCE
	_bar_row(_row([[nazv, 7, 250]], {"title": nazv, "info": Locale.t("cam_hint")}),
		func() -> int: return int(round((CameraDistance.distance - CameraDistance.MIN_DISTANCE) / span * 100.0)),
		func(v: int) -> void: CameraDistance.set_distance(snappedf(CameraDistance.MIN_DISTANCE + span * v / 100.0, 0.05)),
		func(_v: int) -> String: return CameraDistance.caption(), roundi(CameraDistance.STEP / span * 100.0))


## mods/rooms overlays. On/off is RoomFile.set_mod_enabled (mods/rooms/_disabled.json).
func _fill_room_mods() -> void:
	var files := preload("res://scripts/map/room_file.gd")
	var names: Array = []
	for name_v in files.file_names():
		var name := str(name_v)
		if files.has_mod(name):
			names.append(name)
	_row([[Locale.t("ed_mods_title"), 7, 540]], {"title": Locale.t("ed_mods_title"), "info": Locale.t("ed_mods_hint")})
	if names.is_empty():
		_row([[Locale.t("ed_mods_none"), 7, 540]], {"title": Locale.t("ed_mods_none"), "info": Locale.t("ed_mods_hint")})
		return
	for name_v in names:
		var name := str(name_v)
		var b := _row([[name, 7, 360]], {"title": name, "info": Locale.t("ed_mods_hint")})
		var box := TextureRect.new()
		box.texture = CheckMark.icon(files.mod_enabled(name), GREEN)
		box.position = Vector2(380, 5.5)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(box)
		var put := func(on: bool) -> void:
			files.set_mod_enabled(name, on)
			box.texture = CheckMark.icon(files.mod_enabled(name), GREEN)
		var data: Dictionary = b.get_meta("data")
		data["primary"] = func() -> void: put.call(not files.mod_enabled(name))
		data["adjust"] = func(step: int) -> void: put.call(step > 0)


func _bar_row(b: Button, getter: Callable, setter: Callable, shown: Callable, step: int) -> void:
	var pct: int = getter.call()
	var numb := Label.new()
	_style(numb, 16, GREEN)
	numb.position = Vector2(500, 1)
	numb.size = Vector2(55, 22)
	numb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	numb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(numb)
	numb.text = shown.call(pct)
	var bar := PipScroll.new()
	bar.position = Vector2(259.6, 3)
	bar.size = Vector2(238, 18)
	bar.set_value(pct)
	b.add_child(bar)
	var put := func(v: int) -> void:
		setter.call(clampi(v, 0, 100))
		numb.text = shown.call(clampi(v, 0, 100))
		bar.set_value(v)
	bar.moved.connect(put)
	var data: Dictionary = b.get_meta("data")
	data["adjust"] = func(dir: int) -> void: put.call(int(getter.call()) + maxi(step, 1) * dir)


## PAGE_AUTOPICKUP_OPT: AutoPickupManager's switches; the last five are
## the parts of vsStuffAll.
func _fill_autopick() -> void:
	for id in Autopick.IDS:
		_check_row(id, Autopick.flag.bind(id), func(on: bool) -> void: Autopick.set_flag(id, on))


func _relabel() -> void:
	var page := _page
	var subs := _sub.duplicate()
	var keep := _focused_row_index()
	_build()
	_page = page
	_sub = subs
	_show_page()
	if keep >= 0 and keep < _rows.size():
		_rows[keep].call_deferred("grab_focus")


func _fill_log() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	var lines: PackedStringArray = []
	if hud != null and hud.get("history") is PackedStringArray:
		lines = hud.get("history")
	# PipPageOpt PAGE_LOG: logText at 20, 85 (text 2, 2, 846 x 546, size 12, #00FF99),
	# htmlText = World.w.log in the GUI stylesheet, scrolled to the newest line.
	_scroll.visible = false
	_log_text = RichTextLabel.new()
	_log_text.bbcode_enabled = true
	_log_text.scroll_following = true
	_log_text.position = PAGE + Vector2(22, 87)
	_log_text.size = Vector2(846, 546)
	_log_text.add_theme_color_override("default_color", GREEN)
	_log_text.add_theme_font_override("normal_font", _font)
	_log_text.add_theme_font_size_override("normal_font_size", roundi(12 * TEXT_K))
	_log_text.text = "\n".join(lines)
	_stage.add_child(_log_text)


## After layout: the width of the page shown now, not of the one that queued it.
func _fit_scroll() -> void:
	if _list != null and is_instance_valid(_list):
		_list.custom_minimum_size.x = _list_w
		_list.size.x = _list_w
	if _scroll != null and is_instance_valid(_scroll):
		_scroll.size.x = _list_w + 18.0
		# After World (no rows) the bar keeps max 0 until the container sorts again.
		_scroll.queue_sort()


func _restore_scroll(v: int) -> void:
	await get_tree().process_frame
	if _scroll != null and is_instance_valid(_scroll):
		_scroll.scroll_vertical = v



## PipPageOpt PAGE_CONTROLS: one row per Ctr keyObj, key1 / key2 edited
## until Accept, plus the port's pad cell (saved at once) and pad options.
const KEY_X: Array[float] = [206.0, 324.0, 442.0]
const KEY_W := 114.0


func _fill_controls() -> void:
	if _kb_edit.is_empty():
		for action in InputBindings.ACTIONS:
			var kb := InputBindings.kb_events(action)
			_kb_edit[action] = [kb[0] if kb.size() > 0 else null, kb[1] if kb.size() > 1 else null]
	_head([[OriginalLines.pip("opt4"), 7, 190], ["1", KEY_X[0], KEY_W, HORIZONTAL_ALIGNMENT_CENTER],
		["2", KEY_X[1], KEY_W, HORIZONTAL_ALIGNMENT_CENTER], [Locale.t("ctl_col_pad"), KEY_X[2], KEY_W, HORIZONTAL_ALIGNMENT_CENTER]])
	for action in InputBindings.ACTIONS:
		_key_row(action)
	_pad_option_rows()
	_top.text = _help("infokeys")
	_ok.text = OriginalLines.pip("accept")
	_ok.visible = _keys_dirty()
	_def.text = OriginalLines.pip("default")
	_def.visible = true
	if _key_action != "":
		_info.text = "%s\n\n%s" % [OriginalLines.gui("setkeyinfo"), InputBindings.label_for(_key_action)]


func _key_row(action: String) -> void:
	var nazv := InputBindings.label_for(action)
	var b := _row([[nazv, 7, 196]], {"title": nazv, "info": OriginalLines.pip("infokeys")})
	var edit: Array = _kb_edit[action]
	for cell in 3:
		var text := ""
		if cell < 2:
			text = InputBindings.event_text(edit[cell]) if edit[cell] is InputEvent else ""
		else:
			text = InputBindings.binding_text(action, true)
			if text == Locale.t("unbound"):
				text = ""
		if action == _key_action and cell == _key_cell:
			text = "…"
		var box := Label.new()
		_style(box, 14, GREEN)
		box.position = Vector2(KEY_X[cell], 2)
		box.size = Vector2(KEY_W, 20)
		box.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.clip_text = true
		box.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		box.text = text
		box.mouse_filter = Control.MOUSE_FILTER_STOP
		box.gui_input.connect(_on_key_cell_input.bind(b, action, cell))
		b.add_child(box)
		b.move_child(box, 0)
		box.set_meta("cell", cell)
	_paint_key_cells(b)
	b.focus_entered.connect(_paint_key_cells.bind(b))
	b.focus_exited.connect(_paint_key_cells.bind(b))
	var data: Dictionary = b.get_meta("data")
	data["action"] = action
	data["primary"] = func() -> void: _listen_key(action, _key_cell)
	data["secondary"] = func() -> void: _clear_key(action, _key_cell)
	data["adjust"] = func(step: int) -> void:
		_key_cell = clampi(_key_cell + step, 0, 2)
		for row in _rows:
			if row.get_meta("data", {}).has("action"):
				_paint_key_cells(row)


## key1 / key2: shape 936, a dark green cell; the chosen cell of the focused row is lit.
func _paint_key_cells(b: Button) -> void:
	for child in b.get_children():
		if not child.has_meta("cell"):
			continue
		var box := StyleBoxFlat.new()
		box.bg_color = Color("0b4a2a")
		var lit := b.has_focus() and int(child.get_meta("cell")) == _key_cell
		box.border_color = GREEN
		box.set_border_width_all(1 if lit else 0)
		(child as Label).add_theme_stylebox_override("normal", box)


func _on_key_cell_input(event: InputEvent, b: Button, action: String, cell: int) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var mb := event as InputEventMouseButton
	if _key_action != "":
		return
	_key_cell = cell
	b.grab_focus()
	if mb.button_index == MOUSE_BUTTON_LEFT:
		SfxBank.play("pip1")
		_listen_key(action, cell)
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		_clear_key(action, cell)
	b.accept_event()


## PipPageOpt.showSetKey: the next key, mouse or pad press fills the cell.
func _listen_key(action: String, cell: int) -> void:
	_key_action = action
	_key_cell = cell
	_key_frame = Engine.get_process_frames()
	_fill()


func _clear_key(action: String, cell: int) -> void:
	if cell == 2:
		InputBindings.clear_binding(action, true)
	else:
		(_kb_edit[action] as Array)[cell] = null
	SfxBank.play("pip1")
	_fill()


## Ctr.requestKey. Esc cancels; the new key leaves every other cell (unshowSetKey).
func _key_listen_input(event: InputEvent) -> void:
	if Engine.get_process_frames() <= _key_frame or not event.is_pressed() or event.is_echo():
		return
	var action := _key_action
	if event is InputEventKey and (event as InputEventKey).keycode in [KEY_ESCAPE, KEY_TAB]:
		_key_action = ""
		_fill()
		return
	if event is InputEventKey and (event as InputEventKey).keycode == KEY_DELETE:
		_key_action = ""
		_clear_key(action, _key_cell)
		return
	var pad := event is InputEventJoypadButton or (event is InputEventJoypadMotion
		and (event as InputEventJoypadMotion).axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]
		and (event as InputEventJoypadMotion).axis_value >= 0.5)
	if event is InputEventJoypadMotion and not pad:
		return
	if _key_cell == 2:
		if not pad:
			if event is InputEventKey:
				_key_action = ""
				_fill()
			return
		InputBindings.set_binding(action, event)
	else:
		if pad:
			if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B:
				_key_action = ""
				_fill()
			return
		if not (event is InputEventKey or event is InputEventMouseButton):
			return
		for other: String in _kb_edit:
			var cells: Array = _kb_edit[other]
			for i in 2:
				if cells[i] is InputEvent and (cells[i] as InputEvent).is_match(event, true):
					cells[i] = null
		(_kb_edit[action] as Array)[_key_cell] = event
	_key_action = ""
	_key_frame = Engine.get_process_frames()
	SfxBank.play("pip1")
	_fill()


func _keys_dirty() -> bool:
	for action: String in _kb_edit:
		var now := InputBindings.kb_events(action)
		var cells: Array = _kb_edit[action]
		var want: Array = cells.filter(func(e: Variant) -> bool: return e is InputEvent)
		if want.size() != now.size():
			return true
		for i in want.size():
			if not (want[i] as InputEvent).is_match(now[i], true):
				return true
	return false


## transOk.
func _keys_accept() -> void:
	InputBindings.set_kb(_kb_edit)
	_kb_edit.clear()
	_fill()


## gotoDef: Ctr.gotoDef, saved at once.
func _keys_default() -> void:
	SfxBank.play("pip3")
	InputBindings.reset_defaults()
	_kb_edit.clear()
	_key_action = ""
	_fill()


## Port extras after the key list: the gamepad stick, cursor and aim assist.
## A pad option on the options bar: lo..hi mapped onto the bar's 0..100, steps of 0.05.
func _range_row(key: String, lo: float, hi: float, getter: Callable, setter: Callable) -> void:
	var nazv := Locale.t(key)
	var span := hi - lo
	_bar_row(_row([[nazv, 7, 250]], {"title": nazv}),
		func() -> int: return roundi((float(getter.call()) - lo) / span * 100.0),
		func(v: int) -> void: setter.call(snappedf(lo + span * v / 100.0, 0.05)),
		func(v: int) -> String: return "%d%%" % roundi(snappedf(lo + span * v / 100.0, 0.05) * 100.0),
		maxi(1, roundi(0.05 / span * 100.0)))


func _pad_option_rows() -> void:
	_range_row("ctl_deadzone", 0.05, 0.9, UiSettings.stick_deadzone, func(v: float) -> void:
		UiSettings.set_stick_deadzone(v)
		InputBindings.apply_deadzone())
	_range_row("ctl_aim_speed", 0.25, 3.0, UiSettings.aim_sensitivity, UiSettings.set_aim_sensitivity)
	var b := _row([[Locale.t("ctl_aim_assist"), 7, 364]], {"title": Locale.t("ctl_aim_assist")})
	var box := TextureRect.new()
	box.texture = CheckMark.icon(UiSettings.aim_assist(), GREEN)
	box.position = Vector2(380, 5.5)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	var put := func(on: bool) -> void:
		UiSettings.set_aim_assist(on)
		box.texture = CheckMark.icon(on, GREEN)
	var data: Dictionary = b.get_meta("data")
	data["primary"] = func() -> void: put.call(not UiSettings.aim_assist())
	data["adjust"] = func(step: int) -> void: put.call(step > 0)
	_range_row("ctl_assist_pull", 0.0, 2.0, UiSettings.assist_pull, UiSettings.set_assist_pull)
	_range_row("ctl_assist_slow", 0.0, 0.6, UiSettings.assist_slow, UiSettings.set_assist_slow)


# --- Right panel (pr / ritems) ---

func _refresh_rpanel() -> void:
	if _rp_labels.is_empty() or not _rpanel.visible:
		return
	var maxh := float(Progression.max_health()) if Progression.has_method("max_health") else 100.0
	var cap := maxf(1.0, GameState.organ_max())
	var rows: Array = [
		[OriginalLines.pip("hp"), _pair_text(GameState.health, maxh)],
		[OriginalLines.pip("head"), _pair_text(GameState.head_hp, cap)],
		[OriginalLines.pip("tors"), _pair_text(GameState.torso_hp, cap)],
		[OriginalLines.pip("legs"), _pair_text(GameState.legs_hp, cap)],
		[OriginalLines.pip("blood"), _pair_text(GameState.blood_hp, cap)],
	]
	if GameState.has_method("mana_max"):
		rows.append([OriginalLines.gui("magia"), _pair_text(GameState.mana_hp, float(GameState.mana_max()))])
	else:
		rows.append(["", []])
	if _no_med():
		# PipBuck.setRPanel: ritem1 1-5 hidden while nomed.
		for k in range(1, 6):
			rows[k] = ["", []]
	# ritem1 6: gg.pet hp / maxhp.
	if Pets.current != "":
		rows.append([Pets.pet_name(Pets.current), _pair_text(maxf(0.0, Pets.hp_of(Pets.current)), float(Pets.stats(Pets.current).maxhp))])
	else:
		rows.append(["", []])
	var wid := str(Inventory.weapon_id)
	var wpct := _durability(wid, true) if wid != "" else ""
	rows.append([OriginalLines.pip("inv1"), [wpct, _pct_color(wpct)] if wpct != "" else []])
	var apct := _durability(str(Inventory.worn), false) if str(Inventory.worn) != "" else ""
	rows.append([OriginalLines.pip("inv2"), [apct, _pct_color(apct)] if apct != "" else []])
	rows.append([OriginalLines.pip("caps"), [str(Inventory.count("money")), YELLOW]])
	if Inventory.hard_inv():
		# PipBuck.setRPanel ritem10-14: massW, massM, mass1-3.
		for spec: Array in [["allweap", float(Inventory.mass_w()), "maxmW", 4], ["allmagic", float(Inventory.mass_m()), "maxmM", 5],
				["allmass1", Inventory.mass(1), "maxm1", 1], ["allmass2", Inventory.mass(2), "maxm2", 2], ["allmass3", Inventory.mass(3), "maxm3", 3]]:
			var text := "%s / %d" % [Stash._numb(float(spec[1])), int(round(Inventory.max_mass(str(spec[2]))))]
			rows.append([OriginalLines.pip(str(spec[0])), [text, RED if Stash.over_mass(int(spec[3])) else GREEN]])
	for j in _rp_labels.size():
		var label := _rp_labels[j]
		var row: Control = label.get_meta("row")
		var spec: Array = rows[j] if j < rows.size() else ["", []]
		var value: Array = spec[1]
		row.visible = not value.is_empty()
		if value.is_empty():
			continue
		(label.get_meta("tag") as Label).text = str(spec[0])
		label.text = str(value[0])
		label.add_theme_color_override("font_color", value[1])


func _pair_text(cur: float, cap: float) -> Array:
	return ["%d / %d" % [int(round(cur)), int(round(cap))], _med(cur, cap)]


func _pct_color(text: String) -> Color:
	var n := int(text.trim_suffix("%"))
	return _med(float(n), 100.0)


# --- Input ---

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _key_action != "":
		_key_listen_input(event)
		get_viewport().set_input_as_handled()
		return
	if _opt_auto and event.is_action_pressed("ui_cancel"):
		_opt_auto = false
		_fill()
		for row in _rows:
			if str(row.get_meta("data", {}).get("title", "")) == OriginalLines.pip("autotake"):
				row.call_deferred("grab_focus")
		get_viewport().set_input_as_handled()
		return
	if _listen_id != "":
		if Engine.get_process_frames() <= _listen_frame:
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_cancel"):
			_listen_id = ""
			_refresh()
		elif MagicBinds != null:
			_bind_event(event)
		get_viewport().set_input_as_handled()
		return
	var action := action_of(event)
	if action == "pip_toggle":
		_close()
		get_viewport().set_input_as_handled()
		return
	if action != "" and not menu_only:
		var jump: Array = JUMPS[action]
		if int(jump[0]) == _page and (int(jump[1]) < 0 or int(jump[1]) == int(_sub[_page])):
			_close()
		else:
			_go(int(jump[0]), int(jump[1]))
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if _choosing:
			_choosing = false
			_fill()
		else:
			_close()
		get_viewport().set_input_as_handled()
		return
	if _fav_key(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_Y:
		var focus := get_viewport().gui_get_focus_owner()
		if focus is Button and _rows.has(focus as Button):
			var data: Dictionary = (focus as Button).get_meta("data", {})
			if data.has("third"):
				SfxBank.play("ui_click")
				(data["third"] as Callable).call()
				get_viewport().set_input_as_handled()
				return
	if event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_X:
		var owner := get_viewport().gui_get_focus_owner()
		if owner is Button and _rows.has(owner as Button):
			_secondary(owner as Button)
		get_viewport().set_input_as_handled()
		return
	if _adjust_focused(event):
		get_viewport().set_input_as_handled()


## Ctr.reqKey: a weapon, spell or magic key over an item row puts it in that
## cell; pad Y opens the cell picker on the row.
func _fav_key(event: InputEvent) -> bool:
	if event.is_echo() or not event.is_pressed():
		return false
	var owner := get_viewport().gui_get_focus_owner()
	if not (owner is Button and _rows.has(owner as Button)):
		return false
	var data: Dictionary = (owner as Button).get_meta("data", {})
	var id := str(data.get("fav_id", ""))
	if id == "":
		return false
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_Y:
		_arm_listen(id)
		return true
	var cell := int(Favorites.cell_of_event(event))
	if cell <= 0:
		return false
	Favorites.fav_item(id, cell)
	_refresh()
	return true


## Left / right on an option row changes it (UiNav turns the stick into
## ui_left / ui_right actions).
func _adjust_focused(event: InputEvent) -> bool:
	if event is InputEventJoypadMotion:
		return false
	var step := 0
	if event.is_action_pressed("ui_left", true):
		step = -1
	elif event.is_action_pressed("ui_right", true):
		step = 1
	if step == 0:
		return false
	var owner := get_viewport().gui_get_focus_owner()
	if not owner is Button or not _rows.has(owner as Button):
		return false
	var data: Dictionary = (owner as Button).get_meta("data", {})
	if not data.has("adjust"):
		return false
	SfxBank.play("ui_click")
	(data["adjust"] as Callable).call(step)
	return true


func _cycle_sub(step: int) -> void:
	var i := int(_sub[_page])
	for _n in 5:
		i = posmod(i + step, 5)
		if _sub_visible(_page, i):
			break
	_go_sub(i)


func _player_name() -> String:
	var saved := str(UiSettings.value("game", "name", ""))
	if saved != "":
		return saved
	return OriginalLines.unit("littlepip")


func _fill_app() -> void:
	if _app == null or not is_instance_valid(_app):
		_app = preload("res://scripts/appearance_screen.gd").new()
		add_child(_app)
		# PipPageApp.funVidOk / funVidCancel: pip.onoff(-1) either way.
		_app.closed.connect(_close)
	if _app.is_open():
		return
	var over := 0
	var n: Node = get_parent()
	while n != null:
		if n is CanvasLayer:
			over = (n as CanvasLayer).layer
			break
		n = n.get_parent()
	_app.call_deferred("open_in", _stage, PAGE + APP_AT, over)


func _close() -> void:
	if _app != null and is_instance_valid(_app):
		_app.cancel_quiet()
	_remember()
	Travel.travel_mode = false
	Vendors.clear_context()
	if get_parent() == get_tree().root:
		preload("res://scripts/exit_trace.gd").arm(get_tree(), "pipbuck at root")
		get_tree().change_scene_to_file(load("res://scripts/editor/editor_play.gd").menu_dest())
		return
	closed.emit()
	queue_free()
