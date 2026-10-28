extends RefCounted

## Room options, map options, and area property windows.
## Map options are the land-row keys the game reads. Room options stay on the room.

const Palette := preload("res://scripts/editor/editor_palette.gd")
const Codec := preload("res://scripts/editor/room_codec.gd")
const RoomFile := preload("res://scripts/map/room_file.gd")
const Catalog := preload("res://scripts/map/tile_catalog.gd")
const Settings := preload("res://scripts/editor/editor_settings.gd")
const Check := preload("res://scripts/editor/editor_check.gd")
const Reg := preload("res://scripts/map/land_registry.gd")
const Rules := preload("res://scripts/editor/editor_rules.gd")
const ART := "res://assets/sprites/areas/"
const COLS := 48
const ROWS := 25

const TIPS: Array = Rules.TIPS
const ENTIP: Array = Rules.ENTIP
const WTIP: Array = Rules.WTIP
const LON: Array = Rules.LON
const AREA_TIP: Array = Rules.AREA_TIP
const VIS_IDS: PackedStringArray = Rules.VIS_IDS
const KIND_COLOR := {
	"scr": Color(0.62, 0.42, 0.95),
	"port": Color(0.25, 0.78, 1.0),
	"grav": Color(0.35, 0.9, 0.45),
	"emit": Color(1.0, 0.55, 0.2),
	"tile": Color(0.95, 0.35, 0.32),
	"mess": Color(0.95, 0.85, 0.25),
	"area": Color(0.75, 0.75, 0.8),
}

static var _vis_tex: Dictionary = {}
static var _script_ids: PackedStringArray = PackedStringArray()
static var _thumbs: Dictionary = {}
static var _theme: Theme
static var _area_ui := false
static var _obj_ui := false


static func editor_theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = Theme.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.1, 0.1, 0.12, 1)
	box.border_color = Color(0.62, 0.62, 0.68)
	box.set_border_width_all(1)
	box.set_content_margin_all(8)
	box.set_corner_radius_all(3)
	_theme.set_stylebox("panel", "TooltipPanel", box)
	_theme.set_color("font_color", "TooltipLabel", Color(0.94, 0.94, 0.92))
	_theme.set_font_size("font_size", "TooltipLabel", 14)
	var menu := box.duplicate() as StyleBoxFlat
	menu.set_content_margin_all(4)
	_theme.set_stylebox("panel", "PopupMenu", menu)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.24, 0.3, 0.4, 1)
	hover.set_corner_radius_all(2)
	_theme.set_stylebox("hover", "PopupMenu", hover)
	_theme.set_color("font_color", "PopupMenu", Color(0.94, 0.94, 0.92))
	_theme.set_color("font_hover_color", "PopupMenu", Color(1, 1, 1))
	_theme.set_stylebox("panel", "PopupPanel", box.duplicate())
	return _theme


static func open_room(host: Node, doc: RefCounted, on_changed: Callable, for_room_doc := false) -> void:
	_area_ui = false
	_obj_ui = false
	if doc.has_method("commit"):
		doc.commit()
	var w := _window(host, _tr("ed_opt_room"))
	var nodes: Array = []
	var box := _body(w)
	var room: Dictionary = doc.room()
	if room.is_empty():
		box.add_child(_plain(_tr("ed_no_file")))
		_buttons(w, func(): w.queue_free(), true)
		return
	var opt: Dictionary = room.get("options", {})
	_add_text(box, nodes, "name", {"name": str(room.get("name", ""))}, "roomname")
	_mark_need(nodes, "name")
	var name_edit := nodes[nodes.size() - 1] as Control
	name_edit.set_meta("current", str(room.get("name", "")))
	name_edit.set_meta("doc", doc)
	_add_check(box, nodes, "test", opt)
	_add_enum(box, nodes, "tip", TIPS, str(opt.get("tip", "")))
	_add_check(box, nodes, "uniq", opt)
	var entip := show_text(opt.get("entip", ""))
	if entip == "-1":
		entip = ""
	_add_enum(box, nodes, "entip", ENTIP, entip)
	_add_num(box, nodes, "level", opt, "int", 0, 999, PackedStringArray(["uniq"]))
	_add_check(box, nodes, "base", opt)
	_add_text(box, nodes, "back", opt, "")
	for key in ["levitoff", "portoff", "desoff", "petoff", "nomap"]:
		_add_check(box, nodes, key, opt)
	var colors := _color_ids()
	_add_pick(box, nodes, "color", colors, str(opt.get("color", "")), func(id):
		return _tr("ed_color_none") if str(id) == "" else str(id))
	_add_num(box, nodes, "dark", opt, "float", -400, 400, PackedStringArray())
	_add_num(box, nodes, "vis", opt, "float", 0, 100, PackedStringArray())
	_add_check(box, nodes, "noblack", opt)
	_add_check(box, nodes, "retdark", opt)
	_add_pick(box, nodes, "backwall", Palette.wall_ids(), str(opt.get("backwall", "")), func(id):
		return Palette.wall_label(str(id)))
	_paint_icons(nodes[nodes.size() - 1] as OptionButton, "wall")
	var forms := PackedStringArray(["", "0", "1", "2", "3"])
	_add_pick(box, nodes, "backform", forms, str(opt.get("backform", "")), func(id):
		return _tr("ed_color_none") if str(id) == "" else _tr("ed_form_%s" % str(id)))
	_add_enum(box, nodes, "lon", LON, str(opt.get("lon", "")))
	_add_check(box, nodes, "transpfon", opt)
	_add_pick(box, nodes, "colorfon", colors, str(opt.get("colorfon", "")), func(id):
		return _tr("ed_color_none") if str(id) == "" else str(id))
	_add_num(box, nodes, "rad", opt, "float", 0, 1000, PackedStringArray())
	_add_check(box, nodes, "bezdna", opt)
	_add_num(box, nodes, "wlevel", opt, "int", 0, 100, PackedStringArray())
	_add_enum(box, nodes, "wtip", WTIP, str(opt.get("wtip", "")))
	_add_num(box, nodes, "wopac", opt, "float", 0, 1, PackedStringArray())
	_add_num(box, nodes, "wrad", opt, "float", 0, 1000, PackedStringArray())
	var music := PackedStringArray([""])
	music.append_array(Palette.music_ids())
	_add_pick(box, nodes, "music", music, str(opt.get("music", "")), func(id):
		return _tr("ed_music_default") if str(id) == "" else str(id))
	_add_text(box, nodes, "items", opt, "token")
	_add_text(box, nodes, "spawn", opt, "token")
	_add_num(box, nodes, "kolspawn", opt, "int", 0, 100, PackedStringArray())
	_add_check(box, nodes, "nornd", opt)
	_add_num(box, nodes, "stage", opt, "int", 0, 99, PackedStringArray())
	_add_num(box, nodes, "wdam", opt, "float", 0, 10000, PackedStringArray())
	_add_text(box, nodes, "wtipdam", opt, "token")
	_add_pick(box, nodes, "fon", _fon_ids(), str(opt.get("fon", "")), func(id):
		return _tr("ed_color_none") if str(id) == "" else str(id))
	_paint_icons(nodes[nodes.size() - 1] as OptionButton, "fon")
	_add_num(box, nodes, "maxdy", opt, "float", 0, 500, PackedStringArray())
	_add_num(box, nodes, "tilespawn", opt, "float", 0, 1, PackedStringArray())
	_add_check(box, nodes, "train", opt)
	_add_num(box, nodes, "trus", opt, "float", 0, 100, PackedStringArray())
	_add_check(box, nodes, "sky", opt)
	_add_num(box, nodes, "zoom", opt, "float", 0, 20, PackedStringArray())
	var pools := _add_pools(box, room)
	if for_room_doc:
		var head := _plain(_tr("ed_test_only"))
		box.add_child(head)
		_add_pick(box, nodes, "testfon", _fon_ids(), Settings.test_fon(), func(id):
			return _tr("ed_color_none") if str(id) == "" else str(id))
		_paint_icons(nodes[nodes.size() - 1] as OptionButton, "fon")
	_help_label(box, _tr("ed_help_room"), nodes, "")
	var buttons := _buttons(w, func(): w.queue_free(), false)
	var watch := func(_a = null) -> void:
		_paint(nodes, buttons, func(node: Control) -> String: return _field_reason(node))
		_pool_notes(pools, _room_preview(doc, nodes, pools))
	_arm(nodes, watch)
	for cb in pools:
		(cb as CheckBox).toggled.connect(func(_on): watch.call())
	watch.call()
	var save_test := func() -> void:
		if not for_room_doc:
			return
		for node_v in nodes:
			var node := node_v as Control
			if str(node.get_meta("key", "")) == "testfon":
				Settings.set_test_fon(_value(node))
	buttons.get_node("ok").pressed.connect(func():
		if (buttons.get_node("ok") as Button).disabled:
			return
		save_test.call()
		_write_room(doc, nodes, pools)
		if on_changed.is_valid():
			on_changed.call()
		w.queue_free())
	buttons.get_node("apply").pressed.connect(func():
		if (buttons.get_node("apply") as Button).disabled:
			return
		save_test.call()
		_write_room(doc, nodes, pools)
		if on_changed.is_valid():
			on_changed.call())


static func open_map(host: Node, doc: RefCounted, on_changed: Callable) -> void:
	_area_ui = false
	_obj_ui = false
	var w := _window(host, _tr("ed_opt_map"))
	var nodes: Array = []
	var box := _body(w)
	var opt: Dictionary = {}
	var cur: Variant = doc.get("options")
	if cur is Dictionary:
		opt = cur
	var inherited: Dictionary = {}
	var land_v: Variant = doc.get("land_defaults")
	if land_v is Dictionary:
		inherited = land_v
	var shown := opt.duplicate()
	for key in inherited:
		if not shown.has(key):
			shown[key] = inherited[key]
	_add_text(box, nodes, "title", {"title": doc.get("title")}, "title")
	var mode := "1" if bool(doc.get("placed")) else "0"
	_add_enum(box, nodes, "mode", [["1", "ed_mode_map"], ["0", "ed_mode_rnd"]], mode)
	var colors := _color_ids()
	_add_pick(box, nodes, "color", colors, str(shown.get("color", "")), func(id):
		return _tr("ed_color_none") if str(id) == "" else str(id))
	_add_num(box, nodes, "darkness", shown, "float", -400, 400, PackedStringArray())
	_add_num(box, nodes, "vis", shown, "float", 0, 100, PackedStringArray())
	_add_num(box, nodes, "rad", shown, "float", 0, 1000, PackedStringArray())
	_add_num(box, nodes, "wrad", shown, "float", 0, 1000, PackedStringArray())
	_add_num(box, nodes, "wdam", shown, "float", 0, 1000, PackedStringArray())
	_add_text(box, nodes, "wtipdam", shown, "token")
	_add_enum(box, nodes, "wtip", WTIP, str(shown.get("wtip", "")))
	_add_num(box, nodes, "wopac", shown, "float", 0, 1, PackedStringArray())
	_add_pick(box, nodes, "backwall", Palette.wall_ids(), str(shown.get("backwall", "")), func(id):
		return Palette.wall_label(str(id)))
	_paint_icons(nodes[nodes.size() - 1] as OptionButton, "wall")
	var music := PackedStringArray([""])
	music.append_array(Palette.music_ids())
	_add_pick(box, nodes, "music", music, str(shown.get("music", "")), func(id):
		return _tr("ed_music_default") if str(id) == "" else str(id))
	_add_check(box, nodes, "postmusic", shown)
	_add_pick(box, nodes, "fon", _fon_ids(), str(shown.get("fon", "")), func(id):
		return _tr("ed_color_none") if str(id) == "" else str(id))
	_paint_icons(nodes[nodes.size() - 1] as OptionButton, "fon")
	_add_text(box, nodes, "art", shown, "token")
	_add_num(box, nodes, "xp", shown, "int", 0, 100000, PackedStringArray())
	for node_v in nodes:
		var node := node_v as Control
		var key := str(node.get_meta("key", ""))
		if key == "" or opt.has(key) or not inherited.has(key) or str(inherited[key]) == "":
			continue
		_note_from_land(node)
	_help_label(box, _tr("ed_help_map"), nodes, "")
	var buttons := _buttons(w, func(): w.queue_free(), false)
	var watch := func(_a = null) -> void:
		_paint(nodes, buttons, func(node: Control) -> String: return _field_reason(node))
	_arm(nodes, watch)
	watch.call()
	var write := func() -> void:
		_write_map(doc, nodes)
		if on_changed.is_valid():
			on_changed.call()
	buttons.get_node("ok").pressed.connect(func():
		if (buttons.get_node("ok") as Button).disabled:
			return
		write.call()
		w.queue_free())
	buttons.get_node("apply").pressed.connect(func():
		if (buttons.get_node("apply") as Button).disabled:
			return
		write.call())


static func open_area(host: Node, doc: RefCounted, index: int, on_changed: Callable) -> void:
	if doc.has_method("commit"):
		doc.commit()
	var room: Dictionary = doc.room()
	var objs: Array = room.get("objs", [])
	if index < 0 or index >= objs.size() or not is_area(objs[index]):
		return
	_area_ui = true
	_obj_ui = false
	var obj: Dictionary = objs[index]
	var attrs: Dictionary = _attrs(obj)
	var shown := attrs.duplicate()
	if not attrs.has("w"):
		shown["w"] = "2"
	if not attrs.has("h"):
		shown["h"] = "2"
	var w := _window(host, _tr("ed_area_title"))
	var nodes: Array = []
	var box := _body(w)
	_add_num(box, nodes, "x", {"x": obj.get("x", 0)}, "int", 0, COLS - 1, PackedStringArray())
	_add_num(box, nodes, "y", {"y": obj.get("y", 0)}, "int", 0, ROWS - 1, PackedStringArray())
	_add_num(box, nodes, "w", shown, "int", 1, COLS, PackedStringArray())
	_add_num(box, nodes, "h", shown, "int", 1, ROWS, PackedStringArray())
	for axis in ["x", "y", "w", "h"]:
		_mark_need(nodes, axis)
	_add_vis(box, nodes, str(attrs.get("vis", "")))
	var tip := str(attrs.get("tip", ""))
	if tip == "gg":
		tip = ""
	_add_enum(box, nodes, "tip", AREA_TIP, tip)
	_add_text(box, nodes, "mess", attrs, "")
	_add_check(box, nodes, "down", attrs)
	_add_check(box, nodes, "off", attrs)
	_add_text(box, nodes, "allact", attrs, "")
	_add_uid(box, nodes, room, str(attrs.get("allid", "")))
	_add_check(box, nodes, "trig", attrs)
	_add_script(box, nodes, room, "scr", str(attrs.get("scr", "")))
	_add_script(box, nodes, room, "scrout", str(attrs.get("scrout", "")))
	var kids := _add_kid_board(box, nodes, obj)
	_add_num(box, nodes, "tilehp", attrs, "int", 0, 1000000, PackedStringArray())
	_add_num(box, nodes, "tileop", attrs, "float", 0, 1, PackedStringArray())
	_add_num(box, nodes, "tilethre", attrs, "int", 0, 1000000, PackedStringArray())
	_add_num(box, nodes, "grav", attrs, "float", -100, 100, PackedStringArray())
	_add_check(box, nodes, "norad", attrs)
	_add_emit(box, nodes, str(attrs.get("emit", "")))
	_add_num(box, nodes, "dens", attrs, "float", 0, 100, PackedStringArray())
	_add_port(box, nodes, str(attrs.get("port", "")))
	_add_text(box, nodes, "code", attrs, "code")
	_add_text(box, nodes, "uid", attrs, "")
	_help_label(box, _tr("ed_help_area"), nodes, _tr("ed_area_recipes"))
	var buttons := _buttons(w, func(): w.queue_free(), false)
	var watch := func(_a = null) -> void:
		var live: Dictionary = doc.room()
		_paint(nodes, buttons, func(node: Control) -> String:
			var why := _field_reason(node)
			if why == "" and str(node.get_meta("rule", "")) == "port":
				why = _port_reason(_value(node), live)
			if why == "" and str(node.get_meta("rule", "")) == "script":
				why = _script_reason(_value(node), live)
			if why == "" and str(node.get_meta("rule", "")) == "uid":
				why = _uid_reason(_value(node), live)
			if why == "" and str(node.get_meta("key", "")) in ["x", "y", "w", "h"]:
				why = _zone_reason(nodes)
			return why)
	_arm(nodes, watch)
	_area_ui = false
	watch.call()
	var write := func() -> void:
		_write_area(doc, index, nodes, kids)
		if on_changed.is_valid():
			on_changed.call()
	buttons.get_node("ok").pressed.connect(func():
		if (buttons.get_node("ok") as Button).disabled:
			return
		write.call()
		w.queue_free())
	buttons.get_node("apply").pressed.connect(func():
		if (buttons.get_node("apply") as Button).disabled:
			return
		write.call())


static func is_area(obj: Dictionary) -> bool:
	_bind_rules()
	return Rules.is_area(obj)

static func area_rect(obj: Dictionary) -> Rect2i:
	var attrs := _attrs(obj)
	var w := _span(attrs, "w")
	var h := _span(attrs, "h")
	var x := int(obj.get("x", 0))
	var y := int(obj.get("y", 0))
	return Rect2i(x, y - (h - 1), w, h)


static func set_area_rect(obj: Dictionary, rect: Rect2i) -> void:
	obj["x"] = rect.position.x
	obj["y"] = rect.position.y + rect.size.y - 1
	var attrs := _attrs(obj)
	_assign(attrs, "w", str(rect.size.x))
	_assign(attrs, "h", str(rect.size.y))
	obj["attrs"] = attrs


static func area_kind(obj: Dictionary) -> String:
	var attrs := _attrs(obj)
	if _filled(attrs, "scr") or _filled(attrs, "scrout") or _filled(attrs, "trig") or _scr_kid(obj):
		return "scr"
	if _filled(attrs, "port"):
		return "port"
	if _grav_on(attrs):
		return "grav"
	if _filled(attrs, "emit"):
		return "emit"
	if _filled(attrs, "tilehp") or _filled(attrs, "tileop") or _filled(attrs, "tilethre"):
		return "tile"
	if _filled(attrs, "mess"):
		return "mess"
	return "area"


static func area_color(obj: Dictionary) -> Color:
	return KIND_COLOR.get(area_kind(obj), KIND_COLOR.area)


static func area_label(obj: Dictionary) -> String:
	var kind := area_kind(obj)
	var attrs := _attrs(obj)
	var bit := kind
	if kind == "emit":
		bit = str(attrs.get("emit", "emit"))
	elif kind == "mess":
		bit = "mess"
	elif kind == "port":
		bit = "port"
	var vis := str(attrs.get("vis", "")).strip_edges()
	if vis == "":
		return bit
	if bit == "area":
		return vis
	return "%s %s" % [bit, vis]


static func area_inert(obj: Dictionary) -> bool:
	if not is_area(obj):
		return false
	var attrs := _attrs(obj)
	for key in ["mess", "scr", "scrout", "port", "emit", "tilehp", "tileop", "tilethre", "allact", "norad"]:
		if _filled(attrs, key):
			return false
	if _grav_on(attrs) or _scr_kid(obj):
		return false
	return true


static func vis_texture(id: String) -> Texture2D:
	var key := id.strip_edges().to_lower()
	if key == "":
		return null
	if _vis_tex.has(key):
		var cached: Variant = _vis_tex[key]
		return cached if cached is Texture2D else null
	var path := ART + key + ".png"
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_vis_tex[key] = tex if tex != null else false
	return tex


static func area_handle(rect: Rect2i, pan: Vector2, px: float, mouse: Vector2) -> String:
	var box := Rect2(pan + Vector2(rect.position) * px, Vector2(rect.size) * px)
	if box.size.x < 1.0 or box.size.y < 1.0 or not box.grow(8.0).has_point(mouse):
		return ""
	var near := 7.0
	var left := absf(mouse.x - box.position.x) <= near
	var right := absf(mouse.x - box.end.x) <= near
	var top := absf(mouse.y - box.position.y) <= near
	var bot := absf(mouse.y - box.end.y) <= near
	var in_x := mouse.x >= box.position.x - near and mouse.x <= box.end.x + near
	var in_y := mouse.y >= box.position.y - near and mouse.y <= box.end.y + near
	if top and left:
		return "nw"
	if top and right:
		return "ne"
	if bot and left:
		return "sw"
	if bot and right:
		return "se"
	if top and in_x:
		return "n"
	if bot and in_x:
		return "s"
	if left and in_y:
		return "w"
	if right and in_y:
		return "e"
	return ""


static func resize_rect(start: Rect2i, handle: String, cell: Vector2i) -> Rect2i:
	var x0 := start.position.x
	var y0 := start.position.y
	var x1 := start.end.x - 1
	var y1 := start.end.y - 1
	if handle.find("w") >= 0:
		x0 = cell.x
	if handle.find("e") >= 0:
		x1 = cell.x
	if handle.find("n") >= 0:
		y0 = cell.y
	if handle.find("s") >= 0:
		y1 = cell.y
	if x1 < x0:
		var swap_x := x0
		x0 = x1
		x1 = swap_x
	if y1 < y0:
		var swap_y := y0
		y0 = y1
		y1 = swap_y
	x0 = clampi(x0, 0, COLS - 1)
	x1 = clampi(x1, 0, COLS - 1)
	y0 = clampi(y0, 0, ROWS - 1)
	y1 = clampi(y1, 0, ROWS - 1)
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)


static func _span(attrs: Dictionary, key: String) -> int:
	if not attrs.has(key):
		return 2
	var raw := str(attrs[key]).strip_edges()
	if not raw.is_valid_float():
		return 2
	return maxi(int(float(raw)), 1)


static func _attrs(obj: Dictionary) -> Dictionary:
	var attrs: Variant = obj.get("attrs", {})
	return (attrs as Dictionary).duplicate(true) if attrs is Dictionary else {}


static func _filled(attrs: Dictionary, key: String) -> bool:
	return attrs.has(key) and str(attrs[key]).strip_edges() != ""


static func _grav_on(attrs: Dictionary) -> bool:
	if not _filled(attrs, "grav"):
		return false
	var g := str(attrs.grav).strip_edges()
	return g != "1" and g != "1.0"


static func _scr_kid(obj: Dictionary) -> bool:
	for kid_v in obj.get("kids", []):
		if typeof(kid_v) == TYPE_DICTIONARY and str((kid_v as Dictionary).get("tag", "")) == "scr":
			return true
	return false


static func _window(host: Node, title: String) -> Window:
	var w := Window.new()
	w.title = title
	w.theme = editor_theme()
	w.unresizable = false
	w.exclusive = true
	w.close_requested.connect(w.queue_free)
	host.add_child(w)
	w.popup_centered(Vector2i(760, 640))
	return w


static func _body(w: Window) -> VBoxContainer:
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 10)
	root.add_theme_constant_override("margin_right", 10)
	root.add_theme_constant_override("margin_top", 8)
	root.add_theme_constant_override("margin_bottom", 8)
	w.add_child(root)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(col)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	w.set_meta("col", col)
	return box


static func _buttons(w: Window, on_cancel: Callable, locked: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "buttons"
	row.alignment = BoxContainer.ALIGNMENT_END
	var col: VBoxContainer = w.get_meta("col")
	col.add_child(row)
	var ok := Button.new()
	ok.name = "ok"
	ok.text = _tr("ed_win_ok")
	ok.disabled = locked
	row.add_child(ok)
	var apply := Button.new()
	apply.name = "apply"
	apply.text = _tr("ed_win_apply")
	apply.disabled = locked
	row.add_child(apply)
	var cancel := Button.new()
	cancel.text = _tr("ed_cancel")
	cancel.pressed.connect(on_cancel)
	row.add_child(cancel)
	return row


static func _help_label(box: VBoxContainer, intro: String, nodes: Array, recipes: String) -> Label:
	var fold := Button.new()
	fold.toggle_mode = true
	fold.text = _tr("ed_help")
	fold.alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(fold)
	var lab := Label.new()
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.visible = false
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lines := PackedStringArray()
	if intro != "":
		lines.append(intro)
	for node_v in nodes:
		var node := node_v as Control
		var name := str(node.get_meta("label", ""))
		var tip := str(node.get_meta("tip", ""))
		if name != "" and tip != "":
			lines.append("%s — %s" % [name, tip])
	if recipes != "":
		lines.append(recipes)
	lab.text = "\n\n".join(lines)
	box.add_child(lab)
	fold.toggled.connect(func(on): lab.visible = on)
	return lab


static func _plain(text: String) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lab


static func _tip(key: String) -> String:
	if _obj_ui:
		var obj_tip := _tr("ed_obj_tip_%s" % key, "")
		if obj_tip != "":
			return obj_tip
	if _area_ui:
		var area_tip := _tr("ed_area_tip_%s" % key, "")
		if area_tip != "":
			return area_tip
	var base := _tr("ed_opt_tip_%s" % key, "")
	var extra := _tr("ed_opt_ex_%s" % key, "")
	if base == "":
		return extra
	if extra == "":
		return base
	return "%s %s" % [base, extra]


static func _label_for(key: String) -> String:
	if _obj_ui:
		var obj_lab := _tr("ed_obj_%s" % key, "")
		if obj_lab != "":
			return obj_lab
	if _area_ui:
		var area := _tr("ed_area_%s" % key, "")
		if area != "":
			return area
	var named := _tr("ed_key_%s" % key, "")
	return named if named != "" else key


static func _add_line(box: VBoxContainer, key: String) -> Dictionary:
	var tip := _tip(key)
	var row := HBoxContainer.new()
	box.add_child(row)
	var lab := Label.new()
	lab.text = _label_for(key)
	lab.tooltip_text = tip
	lab.custom_minimum_size.x = 148
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab.clip_text = true
	lab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(lab)
	var why := Label.new()
	why.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	why.custom_minimum_size.x = 180
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	why.add_theme_color_override("font_color", Color(0.95, 0.3, 0.28))
	why.visible = false
	return {"row": row, "why": why, "tip": tip, "label": lab.text}


static func _track(nodes: Array, node: Control, key: String, rule: String, why: Label, tip: String, label: String) -> void:
	node.set_meta("key", key)
	node.set_meta("rule", rule)
	node.set_meta("why", why)
	node.set_meta("tip", tip)
	node.set_meta("label", label)
	node.tooltip_text = tip
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nodes.append(node)


static func _add_text(box: VBoxContainer, nodes: Array, key: String, src: Dictionary, rule: String) -> void:
	var line := _add_line(box, key)
	var edit := LineEdit.new()
	edit.text = show_text(src[key]) if src.has(key) else ""
	(line.row as HBoxContainer).add_child(edit)
	(line.row as HBoxContainer).add_child(line.why)
	_track(nodes, edit, key, rule, line.why, line.tip, line.label)


static func _add_num(box: VBoxContainer, nodes: Array, key: String, src: Dictionary, kind: String, lo: float, hi: float, extra: PackedStringArray) -> void:
	var line := _add_line(box, key)
	var edit := LineEdit.new()
	edit.text = show_text(src[key]) if src.has(key) else ""
	edit.set_meta("lo", lo)
	edit.set_meta("hi", hi)
	edit.set_meta("extra", extra)
	(line.row as HBoxContainer).add_child(edit)
	(line.row as HBoxContainer).add_child(line.why)
	_track(nodes, edit, key, kind, line.why, line.tip, line.label)


static func _add_check(box: VBoxContainer, nodes: Array, key: String, src: Dictionary) -> void:
	var line := _add_line(box, key)
	var cb := CheckBox.new()
	cb.button_pressed = _switch_on(key, src)
	(line.row as HBoxContainer).add_child(cb)
	(line.row as HBoxContainer).add_child(line.why)
	_track(nodes, cb, key, "check", line.why, line.tip, line.label)


static func _add_enum(box: VBoxContainer, nodes: Array, key: String, pairs: Array, current: String) -> void:
	current = show_text(current)
	var ids := PackedStringArray()
	var labels := {}
	for pair_v in pairs:
		var pair: Array = pair_v
		var id := str(pair[0])
		ids.append(id)
		labels[id] = _tr(str(pair[1]))
	_add_pick(box, nodes, key, ids, current, func(id): return str(labels.get(str(id), id)))


static func _add_pick(box: VBoxContainer, nodes: Array, key: String, ids: PackedStringArray, current: String, label_of: Callable) -> void:
	var line := _add_line(box, key)
	var pick := _make_pick(ids, current, label_of)
	(line.row as HBoxContainer).add_child(pick)
	(line.row as HBoxContainer).add_child(line.why)
	_track(nodes, pick, key, "pick", line.why, line.tip, line.label)


static func _make_pick(ids: PackedStringArray, current: String, label_of: Callable) -> OptionButton:
	var pick := OptionButton.new()
	pick.clip_text = true
	var have := ids.duplicate()
	var known := {}
	for id in ids:
		known[str(id)] = true
	if current != "" and not known.has(current):
		have.append(current)
	pick.set_meta("ids", ids)
	var sel := 0
	for i in have.size():
		var id := str(have[i])
		pick.add_item(str(label_of.call(id)))
		pick.set_item_metadata(i, id)
		if id == current:
			sel = i
	pick.select(sel)
	return pick


static func _add_vis(box: VBoxContainer, nodes: Array, current: String) -> void:
	var ids := PackedStringArray([""])
	ids.append_array(VIS_IDS)
	_add_pick(box, nodes, "vis", ids, _canon_current(current, VIS_IDS), func(id):
		return _tr("ed_color_none") if str(id) == "" else str(id))
	var pick := nodes[nodes.size() - 1] as OptionButton
	_keep_case(pick, current)


static func _add_emit(box: VBoxContainer, nodes: Array, current: String) -> void:
	var ids := _emit_ids()
	_add_pick(box, nodes, "emit", ids, _canon_current(current, ids), func(id):
		return _tr("ed_color_none") if str(id) == "" else str(id))
	_keep_case(nodes[nodes.size() - 1] as OptionButton, current)


static func _add_script(box: VBoxContainer, nodes: Array, room: Dictionary, key: String, current: String) -> void:
	var ids := PackedStringArray([""])
	var seen := {"": true}
	for id in _game_scripts():
		if not seen.has(id):
			seen[id] = true
			ids.append(id)
	for id_v in _room_script_ids(room):
		var id := str(id_v)
		if not seen.has(id):
			seen[id] = true
			ids.append(id)
	_add_pick(box, nodes, key, ids, current, func(id):
		return _tr("ed_color_none") if str(id) == "" else str(id))
	var pick := nodes[nodes.size() - 1] as OptionButton
	pick.set_meta("rule", "script")


static func _add_uid(box: VBoxContainer, nodes: Array, room: Dictionary, current: String) -> void:
	var ids := PackedStringArray([""])
	var seen := {"": true}
	for id_v in _room_uids(room):
		var id := str(id_v)
		if not seen.has(id):
			seen[id] = true
			ids.append(id)
	_add_pick(box, nodes, "allid", ids, current, func(id):
		return _tr("ed_color_none") if str(id) == "" else str(id))
	var pick := nodes[nodes.size() - 1] as OptionButton
	pick.set_meta("rule", "uid")


static func _add_port(box: VBoxContainer, nodes: Array, current: String) -> void:
	var line := _add_line(box, "port")
	var edit := LineEdit.new()
	edit.text = show_port(current)
	(line.row as HBoxContainer).add_child(edit)
	(line.row as HBoxContainer).add_child(line.why)
	_track(nodes, edit, "port", "port", line.why, line.tip, line.label)


static func _add_obj_spec(box: VBoxContainer, nodes: Array, id: String, attrs: Dictionary) -> void:
	for spec_v in Rules.OBJ_SPEC:
		var spec: Dictionary = spec_v
		if not Rules.spec_on(id, attrs, spec):
			continue
		var key := str(spec.get("k", ""))
		var rule := str(spec.get("r", ""))
		if rule == "check":
			_add_check(box, nodes, key, attrs)
		elif rule == "int":
			_add_num(box, nodes, key, attrs, "int", int(spec.get("lo", 0)), int(spec.get("hi", 0)), PackedStringArray())
		elif rule == "float":
			_add_num(box, nodes, key, attrs, "float", float(spec.get("lo", 0.0)), float(spec.get("hi", 0.0)), PackedStringArray())
		elif rule == "token":
			_add_text(box, nodes, key, attrs, "token")
		else:
			_add_text(box, nodes, key, attrs, "")


static func _add_kid_board(box: VBoxContainer, nodes: Array, obj: Dictionary) -> Control:
	var id := str(obj.get("id", ""))
	var kinds := Rules.kid_kinds(id, obj)
	var kids: Array = []
	for kid_v in obj.get("kids", []):
		if typeof(kid_v) == TYPE_DICTIONARY:
			kids.append((kid_v as Dictionary).duplicate(true))
	var board := VBoxContainer.new()
	board.set_meta("kids", kids)
	board.set_meta("kinds", kinds)
	board.set_meta("raw_user", false)
	board.set_meta("raw_lock", false)
	if kinds.is_empty() and kids.is_empty():
		board.set_meta("absent", true)
		return board
	box.add_child(board)
	for kind_v in kinds:
		var kind := str(kind_v)
		var head := HBoxContainer.new()
		board.add_child(head)
		var lab := Label.new()
		lab.text = _tr("ed_kid_%s" % kind)
		lab.tooltip_text = _tr("ed_kid_tip_%s" % kind)
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(lab)
		var add := Button.new()
		add.text = _tr("ed_kid_add")
		add.tooltip_text = _tr("ed_kid_tip_%s" % kind)
		add.pressed.connect(_kid_add.bind(board, kind))
		head.add_child(add)
		var rows := VBoxContainer.new()
		rows.set_meta("kind", kind)
		board.add_child(rows)
		board.set_meta("rows_" + kind, rows)
	var raw_lab := Label.new()
	raw_lab.text = _tr("ed_kid_raw")
	raw_lab.tooltip_text = _tr("ed_kid_raw_tip")
	board.add_child(raw_lab)
	var edit := TextEdit.new()
	edit.custom_minimum_size.y = 72
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.text = _kids_text({"kids": kids})
	edit.tooltip_text = _tr("ed_kid_raw_tip")
	edit.placeholder_text = _tr("ed_kid_raw_tip")
	board.add_child(edit)
	var why := Label.new()
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	why.add_theme_color_override("font_color", Color(0.95, 0.3, 0.28))
	why.visible = false
	board.add_child(why)
	edit.set_meta("initial", edit.text)
	edit.set_meta("board", board)
	_track(nodes, edit, "kids", "kids", why, edit.tooltip_text, raw_lab.text)
	board.set_meta("raw", edit)
	edit.text_changed.connect(func():
		if bool(board.get_meta("raw_lock")):
			return
		board.set_meta("raw_user", true))
	_kid_rebuild(board)
	return board


static func _kid_add(board: Control, kind: String) -> void:
	var kids: Array = board.get_meta("kids")
	var row := {"tag": kind, "attrs": {}}
	if kind == "scr":
		row["kids"] = []
	kids.append(row)
	board.set_meta("raw_user", false)
	_kid_rebuild(board)
	_kid_refresh_raw(board)


static func _kid_field(text: String, board: Control, index: int, key: String) -> void:
	var kids: Array = board.get_meta("kids")
	if index < 0 or index >= kids.size():
		return
	_kid_put((kids[index] as Dictionary).get("attrs", {}), key, text)
	board.set_meta("raw_user", false)
	_kid_refresh_raw(board)


static func _kid_flag(on: bool, board: Control, index: int, key: String) -> void:
	_kid_field("1" if on else "", board, index, key)


static func _kid_move(board: Control, index: int, dir: int) -> void:
	var kids: Array = board.get_meta("kids")
	if index < 0 or index >= kids.size():
		return
	var tag := str((kids[index] as Dictionary).get("tag", ""))
	var idxs := _kid_indexes(kids, tag)
	var at := idxs.find(index)
	var nxt := at + dir
	if at < 0 or nxt < 0 or nxt >= idxs.size():
		return
	var j := int(idxs[nxt])
	var tmp: Variant = kids[index]
	kids[index] = kids[j]
	kids[j] = tmp
	board.set_meta("raw_user", false)
	_kid_rebuild(board)
	_kid_refresh_raw(board)


static func _kid_remove(board: Control, index: int) -> void:
	var kids: Array = board.get_meta("kids")
	if index < 0 or index >= kids.size():
		return
	kids.remove_at(index)
	board.set_meta("raw_user", false)
	_kid_rebuild(board)
	_kid_refresh_raw(board)


static func _kid_s_add(board: Control, index: int) -> void:
	var kids: Array = board.get_meta("kids")
	if index < 0 or index >= kids.size():
		return
	var scr: Dictionary = kids[index]
	var nested: Array = scr.get("kids", [])
	nested.append({"tag": "s", "attrs": {}})
	scr["kids"] = nested
	board.set_meta("raw_user", false)
	_kid_rebuild(board)
	_kid_refresh_raw(board)


static func _kid_s_field(text: String, board: Control, index: int, sindex: int, key: String) -> void:
	var kids: Array = board.get_meta("kids")
	if index < 0 or index >= kids.size():
		return
	var nested: Array = (kids[index] as Dictionary).get("kids", [])
	if sindex < 0 or sindex >= nested.size():
		return
	_kid_put((nested[sindex] as Dictionary).get("attrs", {}), key, text)
	board.set_meta("raw_user", false)
	_kid_refresh_raw(board)


static func _kid_s_move(board: Control, index: int, sindex: int, dir: int) -> void:
	var kids: Array = board.get_meta("kids")
	if index < 0 or index >= kids.size():
		return
	var nested: Array = (kids[index] as Dictionary).get("kids", [])
	var j := sindex + dir
	if sindex < 0 or j < 0 or j >= nested.size():
		return
	var tmp: Variant = nested[sindex]
	nested[sindex] = nested[j]
	nested[j] = tmp
	board.set_meta("raw_user", false)
	_kid_rebuild(board)
	_kid_refresh_raw(board)


static func _kid_s_remove(board: Control, index: int, sindex: int) -> void:
	var kids: Array = board.get_meta("kids")
	if index < 0 or index >= kids.size():
		return
	var nested: Array = (kids[index] as Dictionary).get("kids", [])
	if sindex < 0 or sindex >= nested.size():
		return
	nested.remove_at(sindex)
	if nested.is_empty():
		(kids[index] as Dictionary).erase("kids")
	board.set_meta("raw_user", false)
	_kid_rebuild(board)
	_kid_refresh_raw(board)


static func _kid_put(attrs: Dictionary, key: String, value: String) -> void:
	if value == "":
		if attrs.has(key) and str(attrs[key]) == "":
			return
		attrs.erase(key)
		return
	attrs[key] = value


static func _kid_indexes(kids: Array, tag: String) -> Array:
	var out: Array = []
	for i in kids.size():
		if typeof(kids[i]) == TYPE_DICTIONARY and str((kids[i] as Dictionary).get("tag", "")) == tag:
			out.append(i)
	return out


static func _kid_rebuild(board: Control) -> void:
	if bool(board.get_meta("absent", false)):
		return
	var kids: Array = board.get_meta("kids")
	var kinds: PackedStringArray = board.get_meta("kinds")
	for kind_v in kinds:
		var kind := str(kind_v)
		var rows: VBoxContainer = board.get_meta("rows_" + kind)
		while rows.get_child_count() > 0:
			var child := rows.get_child(0)
			rows.remove_child(child)
			child.queue_free()
		for index_v in _kid_indexes(kids, kind):
			var index := int(index_v)
			rows.add_child(_kid_row(board, index, kind))


static func _kid_row(board: Control, index: int, kind: String) -> Control:
	var kids: Array = board.get_meta("kids")
	var attrs: Dictionary = (kids[index] as Dictionary).get("attrs", {})
	var wrap := VBoxContainer.new()
	var line := HBoxContainer.new()
	wrap.add_child(line)
	var fields: Array = _kid_fields(kind)
	for field_v in fields:
		var field: Dictionary = field_v
		var key := str(field.get("k", ""))
		if str(field.get("r", "")) == "check":
			var cb := CheckBox.new()
			cb.text = _tr("ed_kid_%s" % key)
			cb.button_pressed = attrs.has(key) and str(attrs[key]) != ""
			cb.toggled.connect(_kid_flag.bind(board, index, key))
			line.add_child(cb)
		else:
			var edit := LineEdit.new()
			edit.placeholder_text = _tr("ed_kid_%s" % key)
			edit.tooltip_text = _tr("ed_kid_tip_%s" % key)
			edit.text = show_text(attrs[key]) if attrs.has(key) else ""
			edit.custom_minimum_size.x = 72
			edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			edit.text_changed.connect(_kid_field.bind(board, index, key))
			line.add_child(edit)
	_kid_order_buttons(line, board, index, -1)
	if kind == "scr":
		var steps := HBoxContainer.new()
		wrap.add_child(steps)
		var slab := Label.new()
		slab.text = _tr("ed_kid_s")
		slab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		steps.add_child(slab)
		var sadd := Button.new()
		sadd.text = _tr("ed_kid_add")
		sadd.pressed.connect(_kid_s_add.bind(board, index))
		steps.add_child(sadd)
		var nested: Array = (kids[index] as Dictionary).get("kids", [])
		for sindex in nested.size():
			wrap.add_child(_kid_s_row(board, index, sindex))
	return wrap


static func _kid_s_row(board: Control, index: int, sindex: int) -> Control:
	var kids: Array = board.get_meta("kids")
	var nested: Array = (kids[index] as Dictionary).get("kids", [])
	var attrs: Dictionary = {}
	if sindex < nested.size() and typeof(nested[sindex]) == TYPE_DICTIONARY:
		attrs = (nested[sindex] as Dictionary).get("attrs", {})
	var line := HBoxContainer.new()
	for key in ["act", "targ", "val", "n", "t", "opt1", "opt2"]:
		var edit := LineEdit.new()
		edit.placeholder_text = _tr("ed_kid_%s" % key)
		edit.tooltip_text = _tr("ed_kid_tip_%s" % key)
		edit.text = show_text(attrs[key]) if attrs.has(key) else ""
		edit.custom_minimum_size.x = 56
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.text_changed.connect(_kid_s_field.bind(board, index, sindex, key))
		line.add_child(edit)
	var up := Button.new()
	up.text = "↑"
	up.pressed.connect(_kid_s_move.bind(board, index, sindex, -1))
	line.add_child(up)
	var down := Button.new()
	down.text = "↓"
	down.pressed.connect(_kid_s_move.bind(board, index, sindex, 1))
	line.add_child(down)
	var remove := Button.new()
	remove.text = "×"
	remove.pressed.connect(_kid_s_remove.bind(board, index, sindex))
	line.add_child(remove)
	return line


static func _kid_order_buttons(line: HBoxContainer, board: Control, index: int, _sindex: int) -> void:
	var up := Button.new()
	up.text = "↑"
	up.pressed.connect(_kid_move.bind(board, index, -1))
	line.add_child(up)
	var down := Button.new()
	down.text = "↓"
	down.pressed.connect(_kid_move.bind(board, index, 1))
	line.add_child(down)
	var remove := Button.new()
	remove.text = "×"
	remove.pressed.connect(_kid_remove.bind(board, index))
	line.add_child(remove)


static func _kid_fields(kind: String) -> Array:
	if kind == "item":
		return [{"k": "id", "r": "text"}, {"k": "kol", "r": "int"}, {"k": "imp", "r": "check"}]
	if kind == "move":
		return [
			{"k": "dx", "r": "int"}, {"k": "dy", "r": "int"},
			{"k": "tstay", "r": "int"}, {"k": "tmove", "r": "int"}, {"k": "on", "r": "check"},
		]
	return [{"k": "eve", "r": "text"}, {"k": "act", "r": "text"}, {"k": "targ", "r": "text"}, {"k": "val", "r": "text"}, {"k": "n", "r": "text"}]


static func _kid_refresh_raw(board: Control) -> void:
	if bool(board.get_meta("absent", false)):
		return
	var edit: TextEdit = board.get_meta("raw")
	var text := _kids_text({"kids": board.get_meta("kids")})
	board.set_meta("raw_lock", true)
	if edit.text != text:
		edit.text = text
	board.set_meta("raw_lock", false)


static func _kids_commit(board: Control) -> Array:
	if board == null or bool(board.get_meta("absent", false)):
		return []
	if bool(board.get_meta("raw_user")):
		var edit: TextEdit = board.get_meta("raw")
		var parsed: Variant = _parse_kids(edit.text)
		if parsed is Array:
			return parsed
	var kids: Variant = board.get_meta("kids")
	return kids if kids is Array else []


static func _kids_same(a: Variant, b: Array) -> bool:
	var left: Array = a if a is Array else []
	return left == b


static func _kid_check(kids: Array) -> String:
	for kid_v in kids:
		if typeof(kid_v) != TYPE_DICTIONARY:
			continue
		var kid: Dictionary = kid_v
		var tag := str(kid.get("tag", ""))
		var attrs: Dictionary = kid.get("attrs", {})
		if tag == "item":
			var iid := show_text(attrs.get("id", ""))
			if not _item_id_ok(iid):
				return _loc("ed_bad_name")
			var kol := show_text(attrs.get("kol", ""))
			var kol_why := _int_text(kol, 0, 1000000, PackedStringArray())
			if kol_why != "":
				return kol_why
		elif tag == "move":
			for key in ["dx", "dy"]:
				var why := _int_text(show_text(attrs.get(key, "")), -500, 500, PackedStringArray())
				if why != "":
					return why
			for key in ["tstay", "tmove"]:
				var stay := _int_text(show_text(attrs.get(key, "")), 0, 100000, PackedStringArray())
				if stay != "":
					return stay
		var nested: Variant = kid.get("kids", [])
		if nested is Array and not (nested as Array).is_empty():
			var deep := _kid_check(nested)
			if deep != "":
				return deep
	return ""


static func _add_kids(box: VBoxContainer, nodes: Array, obj: Dictionary) -> TextEdit:
	var tip := _tip("kids")
	var lab := Label.new()
	lab.text = _label_for("kids")
	lab.tooltip_text = tip
	box.add_child(lab)
	var edit := TextEdit.new()
	edit.custom_minimum_size.y = 72
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.text = _kids_text(obj)
	edit.tooltip_text = tip
	box.add_child(edit)
	var why := Label.new()
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	why.add_theme_color_override("font_color", Color(0.95, 0.3, 0.28))
	why.visible = false
	box.add_child(why)
	edit.set_meta("initial", edit.text)
	_track(nodes, edit, "kids", "kids", why, tip, lab.text)
	return edit


static func _add_pools(box: VBoxContainer, room: Dictionary) -> Array:
	var head := Label.new()
	head.text = _tr("ed_pools")
	head.tooltip_text = _tr("ed_pools_note")
	box.add_child(head)
	var note := _plain(_tr("ed_pools_note"))
	box.add_child(note)
	var have := {}
	var pools: Variant = room.get("pools", [])
	if pools is Array:
		for id_v in pools:
			have[str(id_v)] = true
	var boxes: Array = []
	for land_v in RoomFile.random_lands():
		var land: Dictionary = land_v
		var cb := CheckBox.new()
		cb.text = str(land.get("name", land.get("id", "")))
		cb.tooltip_text = _tr("ed_pools_note")
		cb.set_meta("land_id", str(land.get("id", "")))
		cb.button_pressed = have.has(str(land.get("id", "")))
		box.add_child(cb)
		boxes.append(cb)
	var warn := VBoxContainer.new()
	box.add_child(warn)
	box.set_meta("pool_warn", warn)
	return boxes


static func _arm(nodes: Array, watch: Callable) -> void:
	for node_v in nodes:
		var node := node_v as Control
		if node is LineEdit:
			(node as LineEdit).text_changed.connect(func(_t): watch.call())
		elif node is TextEdit:
			(node as TextEdit).text_changed.connect(func(): watch.call())
		elif node is OptionButton:
			(node as OptionButton).item_selected.connect(func(_i): watch.call())
		elif node is CheckBox:
			(node as CheckBox).toggled.connect(func(_on): watch.call())


static func _paint(nodes: Array, buttons: HBoxContainer, reason_of: Callable) -> void:
	var bad := false
	for node_v in nodes:
		var node := node_v as Control
		var raw := str(reason_of.call(node))
		var warn := raw.begins_with("~")
		var why := raw.substr(1) if warn else raw
		var lab: Label = node.get_meta("why")
		lab.text = why
		lab.visible = why != ""
		lab.add_theme_color_override("font_color", Color(0.93, 0.75, 0.28) if warn else Color(0.95, 0.3, 0.28))
		_tint(node, "warn" if warn else ("bad" if why != "" else "ok"))
		bad = bad or (why != "" and not warn)
	(buttons.get_node("ok") as Button).disabled = bad
	(buttons.get_node("apply") as Button).disabled = bad


static func _tint(node: Control, level: String) -> void:
	var col := Color(1, 1, 1)
	if level == "bad":
		col = Color(0.95, 0.28, 0.25)
	elif level == "warn":
		col = Color(0.93, 0.75, 0.28)
	if node is LineEdit or node is TextEdit or node is OptionButton:
		node.add_theme_color_override("font_color", col)


static func _mark_need(nodes: Array, key: String) -> void:
	for node_v in nodes:
		var node := node_v as Control
		if str(node.get_meta("key", "")) == key:
			node.set_meta("need", true)


static func _field_reason(node: Control) -> String:
	var rule := str(node.get_meta("rule", ""))
	var text := _value(node)
	if text == "" and bool(node.get_meta("need", false)) and (rule == "int" or rule == "float"):
		return _loc("ed_bad_int") if rule == "int" else _loc("ed_bad_num")
	match rule:
		"int":
			var why := _int_text(text, int(node.get_meta("lo")), int(node.get_meta("hi")), node.get_meta("extra"))
			if why != "" and str(node.get_meta("key", "")) == "tr" and _token(text):
				return "~" + why
			return why
		"float":
			return _float_text(text, float(node.get_meta("lo")), float(node.get_meta("hi")))
		"pick":
			return _pick_reason(node)
		"token":
			return "" if text == "" or text == "*" or _token(text) else _loc("ed_bad_name")
		"code":
			return _code_reason(text)
		"kids":
			var kids_why := _kids_reason(text)
			if kids_why != "":
				return kids_why
			if node.has_meta("board"):
				return _kid_check(_kids_commit(node.get_meta("board")))
			return ""
		"roomname":
			return _room_name_reason(text, node)
		"ownuid":
			return _own_uid_reason(text, node)
		_:
			return ""


static func _value(node: Control) -> String:
	if node is LineEdit:
		return (node as LineEdit).text.strip_edges()
	if node is TextEdit:
		return (node as TextEdit).text
	if node is OptionButton:
		var pick := node as OptionButton
		if pick.selected < 0:
			return ""
		return str(pick.get_item_metadata(pick.selected))
	if node is CheckBox:
		return "1" if (node as CheckBox).button_pressed else ""
	return ""


static func show_text(v) -> String:
	_bind_rules()
	return Rules.show_text(v)

static func show_port(v) -> String:
	_bind_rules()
	return Rules.show_port(v)

static func _parse_whole(text: String) -> Dictionary:
	_bind_rules()
	return Rules._parse_whole(text)

static func _bind_rules() -> void:
	if Rules.locale_on:
		return
	Rules.bind(func(k): return Locale.t(k), func(k, a): return Locale.tf(k, a))


static func _tr(key: String, fallback := "") -> String:
	return Locale.t(key, fallback)


static func _loc(key: String) -> String:
	return Locale.t(key)


static func _locf(key: String, args: Array) -> String:
	return Locale.tf(key, args)


static func _int_text(text: String, lo: int, hi: int, extra: PackedStringArray) -> String:
	_bind_rules()
	return Rules._int_text(text, lo, hi, extra)

static func _float_text(text: String, lo: float, hi: float) -> String:
	_bind_rules()
	return Rules._float_text(text, lo, hi)

static func _in_ids(id: String, ids: PackedStringArray) -> bool:
	_bind_rules()
	return Rules._in_ids(id, ids)

static func _ids_reason(id: String, ids: PackedStringArray, key := "") -> String:
	_bind_rules()
	return Rules._ids_reason(id, ids, key)

static func _pick_reason(node: Control) -> String:
	var ids: PackedStringArray = node.get_meta("ids")
	return _ids_reason(_value(node), ids, str(node.get_meta("key", "")))


static func _code_reason(text: String) -> String:
	_bind_rules()
	return Rules._code_reason(text)

static func _letter(ch: String) -> bool:
	_bind_rules()
	return Rules._letter(ch)

static func _token(text: String) -> bool:
	_bind_rules()
	return Rules._token(text)


static func _item_id_ok(text: String) -> bool:
	if text == "":
		return false
	for part in text.split("^"):
		if not _token(part):
			return false
	return true

static func _zone_reason(nodes: Array) -> String:
	var got := {}
	for node_v in nodes:
		var node := node_v as Control
		var key := str(node.get_meta("key", ""))
		if key in ["x", "y", "w", "h"]:
			var text := _value(node)
			var whole := _parse_whole(text)
			if text == "" or not bool(whole.get("ok", false)):
				return ""
			got[key] = int(whole.n)
	if got.size() < 4:
		return ""
	var x := int(got.x)
	var y := int(got.y)
	var w := int(got.w)
	var h := int(got.h)
	if Rules.bad_rect(x, y, w, h):
		return _loc("ed_bad_rect")
	return ""


static func _port_reason(text: String, room: Dictionary) -> String:
	_bind_rules()
	return Rules._port_reason(text, room)

static func _wall(room: Dictionary, x: int, y: int) -> bool:
	_bind_rules()
	return Rules._wall(room, x, y)

static func _script_reason(text: String, room: Dictionary) -> String:
	_bind_rules()
	return Rules._script_reason(text, room)

static func _uid_reason(text: String, room: Dictionary) -> String:
	_bind_rules()
	return Rules._uid_reason(text, room)

static func _kids_reason(text: String) -> String:
	_bind_rules()
	return Rules._kids_reason(text)

static func _parse_kids(text: String) -> Variant:
	_bind_rules()
	return Rules._parse_kids(text)

static func _kids_text(obj: Dictionary) -> String:
	_bind_rules()
	return Rules._kids_text(obj)

static func _switch_on(key: String, opt: Dictionary) -> bool:
	if not opt.has(key):
		return false
	var v := str(opt[key]).strip_edges().to_lower()
	if key == "retdark" and (v == "0" or v == "false" or v == ""):
		return false
	if key == "off":
		return v.is_valid_float() and float(v) > 0.0
	return v != ""


static func _write_room(doc: RefCounted, nodes: Array, pools: Array) -> void:
	var room: Dictionary = doc.room()
	if room.is_empty():
		return
	var opt: Dictionary = room.get("options", {}).duplicate()
	var new_name := ""
	for node_v in nodes:
		var node := node_v as Control
		var key := str(node.get_meta("key", ""))
		if key == "name":
			new_name = _value(node)
			continue
		if key == "" or key == "title" or key == "mode" or key == "testfon":
			continue
		var value := _value(node)
		if key == "entip" and value == "" and str(opt.get("entip", "")) == "-1":
			continue
		_assign(opt, key, value)
	var ids: Array = []
	for cb_v in pools:
		var cb := cb_v as CheckBox
		if cb.button_pressed:
			ids.append(str(cb.get_meta("land_id")))
	var same_opt: bool = opt == (room.get("options", {}) as Dictionary)
	var old_pools: Variant = room.get("pools", [])
	var same_pools: bool = (ids.is_empty() and not (old_pools is Array)) or (old_pools is Array and (old_pools as Array) == ids)
	var same_name := new_name == "" or new_name == str(room.get("name", ""))
	if same_opt and same_pools and same_name:
		return
	doc.snapshot()
	if not same_name:
		room["name"] = new_name
	room["options"] = opt
	if ids.is_empty():
		room.erase("pools")
	else:
		room["pools"] = ids
	doc.dirty = true


static func _room_preview(doc: RefCounted, nodes: Array, pools: Array) -> Dictionary:
	var room: Dictionary = doc.room().duplicate(true)
	var opt: Dictionary = room.get("options", {}).duplicate()
	for node_v in nodes:
		var node := node_v as Control
		var key := str(node.get_meta("key", ""))
		if key == "" or key == "name" or key == "testfon":
			continue
		_assign(opt, key, _value(node))
	room["options"] = opt
	var ids: Array = []
	for cb_v in pools:
		var cb := cb_v as CheckBox
		if cb.button_pressed:
			ids.append(str(cb.get_meta("land_id")))
	if ids.is_empty():
		room.erase("pools")
	else:
		room["pools"] = ids
	return room


static func _pool_notes(pools: Array, room: Dictionary) -> void:
	if pools.is_empty():
		return
	var host := (pools[0] as Node).get_parent()
	var warn: Node = host.get_meta("pool_warn") if host.has_meta("pool_warn") else null
	if warn == null:
		return
	while warn.get_child_count() > 0:
		var child := warn.get_child(0)
		warn.remove_child(child)
		child.free()
	for cb_v in pools:
		var cb := cb_v as CheckBox
		if not cb.button_pressed:
			continue
		var id := str(cb.get_meta("land_id"))
		var problems: Array = RoomFile.check_pool_room(room, id)
		var lab := Label.new()
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if problems.is_empty():
			lab.text = _locf("ed_pool_ok", [cb.text])
		else:
			var bits := PackedStringArray()
			for problem_v in problems:
				bits.append(str(problem_v))
			lab.text = "%s: %s" % [cb.text, "; ".join(bits)]
			lab.add_theme_color_override("font_color", Color(0.95, 0.55, 0.35))
		warn.add_child(lab)


static func _note_from_land(node: Control) -> void:
	var mark := " (%s)" % _tr("ed_from_land")
	if node is OptionButton:
		var pick := node as OptionButton
		var i := pick.selected
		if i >= 0 and not pick.get_item_text(i).ends_with(mark):
			pick.set_item_text(i, pick.get_item_text(i) + mark)
		return
	var row := node.get_parent()
	if row == null or row.get_child_count() == 0:
		return
	var lab := row.get_child(0) as Label
	if lab != null and not lab.text.ends_with(mark):
		lab.text = lab.text + mark


static func _same_text(a, b) -> bool:
	var sa := str(a).strip_edges()
	var sb := str(b).strip_edges()
	if sa == sb:
		return true
	if sa.is_valid_float() and sb.is_valid_float():
		return is_equal_approx(float(sa), float(sb))
	return false


## A value equal to the land default is not stored unless the file already had it.
static func _assign_land(opt: Dictionary, key: String, value: String, cur: Dictionary, inherited: Dictionary) -> void:
	if inherited.has(key) and _same_text(value, inherited[key]):
		if cur.has(key) and _same_text(cur[key], value):
			opt[key] = cur[key]
		return
	_assign(opt, key, value)


static func _write_map(doc: RefCounted, nodes: Array) -> void:
	var opt: Dictionary = {}
	var cur: Variant = doc.get("options")
	if cur is Dictionary:
		opt = (cur as Dictionary).duplicate(true)
	var inherited: Dictionary = {}
	var land_v: Variant = doc.get("land_defaults")
	if land_v is Dictionary:
		inherited = land_v
	var cur_opt: Dictionary = cur if cur is Dictionary else {}
	var title := str(doc.get("title"))
	var placed := bool(doc.get("placed"))
	for node_v in nodes:
		var node := node_v as Control
		var key := str(node.get_meta("key", ""))
		var value := _value(node)
		if key == "title":
			title = value
		elif key == "mode":
			placed = value == "1"
		elif key != "":
			_assign_land(opt, key, value, cur_opt, inherited)
	var same: bool = opt == cur_opt and title == str(doc.get("title")) and placed == bool(doc.get("placed"))
	if same:
		return
	doc.snapshot()
	doc.set("options", opt)
	doc.set("title", title)
	doc.set("placed", placed)
	doc.dirty = true


static func _write_area(doc: RefCounted, index: int, nodes: Array, kids_board: Control) -> void:
	var room: Dictionary = doc.room()
	var objs: Array = room.get("objs", [])
	if index < 0 or index >= objs.size():
		return
	var obj: Dictionary = objs[index]
	var attrs := _attrs(obj)
	var x := int(obj.get("x", 0))
	var y := int(obj.get("y", 0))
	var next_x := x
	var next_y := y
	for node_v in nodes:
		var node := node_v as Control
		var key := str(node.get_meta("key", ""))
		if key == "kids":
			continue
		var value := _value(node)
		if key == "x" and value.is_valid_int():
			next_x = int(value)
		elif key == "y" and value.is_valid_int():
			next_y = int(value)
		elif key == "tip" and value == "" and str(attrs.get("tip", "")) == "gg":
			continue
		elif key in ["w", "h"] and value == "2" and not _attrs(obj).has(key):
			continue
		elif key != "":
			_assign(attrs, key, value)
	var next_kids: Array = _kids_commit(kids_board)
	var kids_same := _kids_same(obj.get("kids", []), next_kids)
	var same := next_x == x and next_y == y and attrs == _attrs(obj) and kids_same
	if same:
		return
	doc.snapshot()
	obj["x"] = next_x
	obj["y"] = next_y
	obj["attrs"] = attrs
	if kids_same:
		pass
	elif next_kids.is_empty():
		obj.erase("kids")
	else:
		obj["kids"] = next_kids
	doc.dirty = true


static func _assign(opt: Dictionary, key: String, value: String) -> void:
	if value == "":
		# An explicit empty string (music="") means the default. Leave it in place.
		if opt.has(key) and str(opt[key]) == "":
			return
		opt.erase(key)
		return
	if opt.has(key):
		var old: Variant = opt[key]
		if str(old) == value:
			return
		if (typeof(old) == TYPE_INT or typeof(old) == TYPE_FLOAT) and value.is_valid_float() and is_equal_approx(float(old), float(value)):
			return
	opt[key] = value


static func _color_ids() -> PackedStringArray:
	_bind_rules()
	return Rules._color_ids()

static func _fon_ids() -> PackedStringArray:
	_bind_rules()
	return Rules._fon_ids()

static func _emit_ids() -> PackedStringArray:
	_bind_rules()
	return Rules._emit_ids()

static func _canon_current(current: String, ids: PackedStringArray) -> String:
	var fold := current.strip_edges().to_lower()
	for id in ids:
		if str(id).to_lower() == fold:
			return str(id)
	return current


static func _keep_case(pick: OptionButton, current: String) -> void:
	if current == "" or pick.selected < 0:
		return
	var shown := str(pick.get_item_metadata(pick.selected))
	if shown.to_lower() == current.to_lower() and shown != current:
		pick.set_item_metadata(pick.selected, current)


static func _game_scripts() -> PackedStringArray:
	_bind_rules()
	return Rules._game_scripts()

static func _room_script_ids(room: Dictionary) -> Array:
	_bind_rules()
	return Rules._room_script_ids(room)

static func _room_uids(room: Dictionary) -> Array:
	_bind_rules()
	return Rules._room_uids(room)

static func _paint_icons(pick: OptionButton, kind: String) -> void:
	if pick == null:
		return
	for i in pick.item_count:
		var tex := _choice_icon(kind, str(pick.get_item_metadata(i)))
		if tex:
			pick.set_item_icon(i, tex)


static func _choice_icon(kind: String, id: String) -> Texture2D:
	if id == "" or id == "sky":
		return null
	var path := "res://assets/sprites/fon/%s.png" % id if kind == "fon" else Catalog.file_for(id)
	if path == "" or not ResourceLoader.exists(path):
		return null
	if _thumbs.has(path):
		return _thumbs[path]
	var src: Texture2D = load(path)
	var tex: Texture2D = null
	if src != null:
		var img := src.get_image()
		if img != null and not img.is_empty():
			var side := 32
			var scale := minf(float(side) / float(img.get_width()), float(side) / float(img.get_height()))
			var nw := maxi(1, int(float(img.get_width()) * scale))
			var nh := maxi(1, int(float(img.get_height()) * scale))
			img.resize(nw, nh, Image.INTERPOLATE_BILINEAR)
			var canvas := Image.create(side, side, false, Image.FORMAT_RGBA8)
			canvas.fill(Color(0, 0, 0, 0))
			canvas.blit_rect(img, Rect2i(0, 0, nw, nh), Vector2i(int((side - nw) / 2), int((side - nh) / 2)))
			tex = ImageTexture.create_from_image(canvas)
			_thumbs[path + "#src"] = src
	_thumbs[path] = tex
	return tex


static func _room_chars(s: String) -> bool:
	_bind_rules()
	return Rules._room_chars(s)

static func _room_name_reason(text: String, node: Control) -> String:
	var name := text.strip_edges()
	if name == "":
		return _loc("ed_need_name")
	if not _room_chars(name):
		return _loc("ed_name_chars")
	var current := str(node.get_meta("current", ""))
	var doc: Object = node.get_meta("doc")
	if doc == null:
		return ""
	for room_v in doc.rooms:
		var n := str(room_v.get("name", ""))
		if n == name and n != current:
			return _loc("ed_name_used")
	return ""


static func _own_uid_reason(text: String, node: Control) -> String:
	if text == "":
		return ""
	if not _token(text):
		return _loc("ed_bad_name")
	var room: Dictionary = node.get_meta("room")
	var mine := str(node.get_meta("self_uid", ""))
	var n := 0
	for obj_v in room.get("objs", []):
		if str((obj_v as Dictionary).get("attrs", {}).get("uid", "")) == text:
			n += 1
	if n > 1 or (n == 1 and mine != text):
		return "~" + _loc("ed_name_used")
	return ""


static func open_object(host: Node, doc: RefCounted, index: int, on_changed: Callable) -> void:
	if doc.has_method("commit"):
		doc.commit()
	var room: Dictionary = doc.room()
	var objs: Array = room.get("objs", [])
	if index < 0 or index >= objs.size() or is_area(objs[index]):
		return
	_area_ui = false
	_obj_ui = true
	var obj: Dictionary = objs[index]
	var attrs: Dictionary = _attrs(obj)
	var id := str(obj.get("id", ""))
	var w := _window(host, _tr("ed_obj_title"))
	var nodes: Array = []
	var box := _body(w)
	box.add_child(_plain("%s  %s" % [id, str(Reg.obj(id).get("n", id))]))
	_add_num(box, nodes, "x", {"x": obj.get("x", 0)}, "int", 0, COLS - 1, PackedStringArray())
	_add_num(box, nodes, "y", {"y": obj.get("y", 0)}, "int", 0, ROWS - 1, PackedStringArray())
	_mark_need(nodes, "x")
	_mark_need(nodes, "y")
	if Rules.attr_on(id, "lock"):
		_add_num(box, nodes, "lock", attrs, "float", 0, 100, PackedStringArray())
	if Rules.attr_on(id, "locktip"):
		_add_enum(box, nodes, "locktip", LOCKTIP, str(attrs.get("locktip", "")))
	if Rules.attr_on(id, "lockhp"):
		_add_num(box, nodes, "lockhp", attrs, "int", 0, 100000, PackedStringArray())
	if Rules.attr_on(id, "lockatt"):
		_add_num(box, nodes, "lockatt", attrs, "int", -1000, 1000, PackedStringArray())
	if Rules.attr_on(id, "key"):
		_add_text(box, nodes, "key", attrs, "token")
	if Rules.attr_on(id, "keyloss"):
		_add_enum(box, nodes, "keyloss", KEYLOSS, str(attrs.get("keyloss", "")))
	if Rules.attr_on(id, "hack"):
		_add_check(box, nodes, "hack", attrs)
	if Rules.attr_on(id, "mine"):
		_add_num(box, nodes, "mine", attrs, "int", 0, 20, PackedStringArray())
	if Rules.attr_on(id, "minetip"):
		_add_enum(box, nodes, "minetip", MINETIP, str(attrs.get("minetip", "")))
	if Rules.attr_on(id, "cont"):
		_add_text(box, nodes, "cont", attrs, "token")
	if Rules.attr_on(id, "open"):
		_add_check(box, nodes, "open", attrs)
	if Rules.attr_on(id, "autoclose"):
		_add_num(box, nodes, "autoclose", attrs, "int", 0, 100000, PackedStringArray())
	if Rules.attr_on(id, "inter"):
		_add_enum(box, nodes, "inter", INTER, str(attrs.get("inter", "")))
	if Rules.attr_on(id, "time"):
		_add_num(box, nodes, "time", attrs, "int", 0, 100000, PackedStringArray())
	if Rules.attr_on(id, "turn"):
		_add_enum(box, nodes, "turn", TURN, str(attrs.get("turn", "")))
	if Rules.attr_on(id, "hpmult"):
		_add_num(box, nodes, "hpmult", attrs, "float", 0.01, 100, PackedStringArray())
	if Rules.attr_on(id, "ai"):
		_add_text(box, nodes, "ai", attrs, "token")
	if Rules.attr_on(id, "fraction"):
		_add_enum(box, nodes, "fraction", FRACTION, str(attrs.get("fraction", "")))
	if Rules.attr_on(id, "weap"):
		_add_pick(box, nodes, "weap", _weap_ids(), str(attrs.get("weap", "")), func(wid):
			return _tr("ed_obj_default") if str(wid) == "" else str(wid))
	if Rules.attr_on(id, "qid"):
		_add_text(box, nodes, "qid", attrs, "token")
	if Rules.attr_on(id, "unres"):
		_add_check(box, nodes, "unres", attrs)
	if Rules.attr_on(id, "tr"):
		_add_num(box, nodes, "tr", attrs, "int", 0, 100, PackedStringArray())
	if Rules.attr_on(id, "emit"):
		_add_emit(box, nodes, str(attrs.get("emit", "")))
	if Rules.attr_on(id, "allact"):
		_add_text(box, nodes, "allact", attrs, "token")
	if Rules.attr_on(id, "allid"):
		_add_uid(box, nodes, room, str(attrs.get("allid", "")))
	if Rules.attr_on(id, "fun"):
		_add_enum(box, nodes, "fun", FUN, str(attrs.get("fun", "")))
	_add_text(box, nodes, "uid", attrs, "ownuid")
	var uid_node := nodes[nodes.size() - 1] as Control
	uid_node.set_meta("room", room)
	uid_node.set_meta("self_uid", str(attrs.get("uid", "")))
	_add_text(box, nodes, "code", attrs, "code")
	_add_obj_spec(box, nodes, id, attrs)
	var kids_board := _add_kid_board(box, nodes, obj)
	var other := _other_box(box, id, attrs, nodes)
	_help_label(box, _tr("ed_obj_help"), nodes, "")
	var buttons := _buttons(w, func(): w.queue_free(), false)
	var watch := func(_a = null) -> void:
		var extra := _other_note(other, nodes)
		_paint(nodes, buttons, func(node: Control) -> String:
			var why := _field_reason(node)
			return why if why != "" else extra)
	_arm(nodes, watch)
	other.text_changed.connect(func(): watch.call())
	watch.call()
	var write := func() -> void:
		_write_object(doc, index, nodes, other, kids_board)
		if on_changed.is_valid():
			on_changed.call()
	buttons.get_node("ok").pressed.connect(func():
		if (buttons.get_node("ok") as Button).disabled:
			return
		write.call()
		w.queue_free())
	buttons.get_node("apply").pressed.connect(func():
		if (buttons.get_node("apply") as Button).disabled:
			return
		write.call())


static func xml_heading(obj: Dictionary) -> String:
	var id := str(obj.get("id", ""))
	var n := str(Reg.obj(id).get("n", id))
	if n == "":
		n = id
	return "%s (%s) at %d,%d" % [n, id, int(obj.get("x", 0)), int(obj.get("y", 0))]


static func open_xml(host: Node, doc: RefCounted, index: int, on_changed: Callable, kind := "node") -> void:
	if doc.has_method("commit"):
		doc.commit()
	var room: Dictionary = doc.room()
	var objs: Array = room.get("objs", [])
	var expect := "options"
	var text := _options_xml(room.get("options", {}))
	var title := _loc("ed_xml_title")
	var help := _loc("ed_xml_help")
	var header := ""
	if kind == "room":
		text = Codec.room_xml(room)
		title = _loc("ed_xml_room")
		help = _loc("ed_xml_room_help")
		expect = "room"
	elif kind == "land":
		var body: Dictionary = doc.to_dict() if doc.has_method("to_dict") else {}
		text = Codec.land_xml(body)
		title = _loc("ed_xml_land")
		help = _loc("ed_xml_land_help")
		expect = "land"
	elif index >= 0 and index < objs.size():
		expect = str(objs[index].get("tag", "obj"))
		text = Codec.node_xml(objs[index], true)
		header = xml_heading(objs[index])
		title = header
		help = _loc("ed_xml_obj_help")
	var w := _window(host, title)
	var box := _body(w)
	if header != "":
		box.add_child(_plain(header))
	box.add_child(_plain(help))
	var edit := TextEdit.new()
	edit.text = text
	edit.custom_minimum_size.y = 220
	edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.add_child(edit)
	var why := Label.new()
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	why.add_theme_color_override("font_color", Color(0.95, 0.3, 0.28))
	box.add_child(why)
	var warn := Label.new()
	warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warn.add_theme_color_override("font_color", Color(0.95, 0.55, 0.35))
	box.add_child(warn)
	var buttons := _buttons(w, func(): w.queue_free(), false)
	var watch := func() -> void:
		var bad := ""
		var note := ""
		if expect == "room":
			bad = _room_xml_reason(edit.text)
		elif expect == "land":
			bad = _land_xml_reason(edit.text)
		else:
			bad = _xml_reason(edit.text, expect)
			note = _xml_warn(edit.text, expect)
		why.text = bad
		why.visible = bad != ""
		warn.text = note
		warn.visible = note != ""
		(buttons.get_node("ok") as Button).disabled = bad != ""
		(buttons.get_node("apply") as Button).disabled = bad != ""
	edit.text_changed.connect(func(): watch.call())
	watch.call()
	var write := func() -> void:
		var wrote := false
		if expect == "room":
			wrote = _apply_room_xml(doc, edit.text)
		elif expect == "land":
			wrote = _apply_land_xml(doc, edit.text)
		else:
			wrote = _apply_xml_text(doc, index, edit.text, expect)
		if not wrote:
			return
		if on_changed.is_valid():
			on_changed.call()
	buttons.get_node("ok").pressed.connect(func():
		if (buttons.get_node("ok") as Button).disabled:
			return
		write.call()
		w.queue_free())
	buttons.get_node("apply").pressed.connect(func():
		if (buttons.get_node("apply") as Button).disabled:
			return
		write.call())


const LOCKTIP: Array = Rules.LOCKTIP
const KEYLOSS: Array = Rules.KEYLOSS
const MINETIP: Array = Rules.MINETIP
const INTER: Array = Rules.INTER
const TURN: Array = Rules.TURN
const FRACTION: Array = Rules.FRACTION
const FUN: Array = Rules.FUN


static func _other_box(box: VBoxContainer, id: String, attrs: Dictionary, nodes: Array) -> TextEdit:
	var lines: PackedStringArray = PackedStringArray()
	var kept: PackedStringArray = PackedStringArray()
	for key_v in attrs.keys():
		var key := str(key_v)
		if key in ["x", "y", "uid", "code"]:
			continue
		if Rules.attr_on(id, key):
			continue
		lines.append("%s=%s" % [key, str(attrs[key])])
		if Rules.is_field(key):
			kept.append(key)
	var lab := Label.new()
	lab.text = _tr("ed_obj_other")
	lab.tooltip_text = _tr("ed_obj_other_tip")
	box.add_child(lab)
	if not kept.is_empty():
		var note := Label.new()
		note.text = _locf("ed_obj_other_kept", [", ".join(kept)])
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_color_override("font_color", Color(0.95, 0.75, 0.35))
		box.add_child(note)
	var edit := TextEdit.new()
	edit.text = "\n".join(lines)
	edit.custom_minimum_size.y = 72
	edit.placeholder_text = "key=value"
	edit.tooltip_text = _tr("ed_obj_other_tip")
	box.add_child(edit)
	var why := Label.new()
	why.add_theme_color_override("font_color", Color(0.95, 0.55, 0.35))
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(why)
	edit.set_meta("why", why)
	edit.set_meta("nodes", nodes)
	return edit


static func _other_note(edit: TextEdit, nodes: Array) -> String:
	var shown := {}
	for node_v in nodes:
		shown[str((node_v as Control).get_meta("key", ""))] = true
	var hard := ""
	var warn := ""
	for line_v in edit.text.split("\n"):
		var line := str(line_v).strip_edges()
		if line == "":
			continue
		var at := line.find("=")
		if at <= 0:
			hard = _tr("ed_obj_other_bad")
			break
		var key := line.substr(0, at).strip_edges()
		if shown.has(key):
			hard = _tr("ed_obj_other_dup")
			break
		if not Check.OBJ_KEYS.has(key) and warn == "":
			warn = _locf("ed_xml_warn", [key])
	var why: Label = edit.get_meta("why")
	why.text = "" if hard != "" else warn
	why.visible = why.text != ""
	return hard


static func _write_object(doc: RefCounted, index: int, nodes: Array, other: TextEdit, kids_board: Control) -> void:
	var room: Dictionary = doc.room()
	var objs: Array = room.get("objs", [])
	if index < 0 or index >= objs.size():
		return
	var obj: Dictionary = (objs[index] as Dictionary).duplicate(true)
	var old_attrs: Dictionary = _attrs(obj)
	var attrs: Dictionary = {}
	var x := int(obj.get("x", 0))
	var y := int(obj.get("y", 0))
	for node_v in nodes:
		var node := node_v as Control
		var key := str(node.get_meta("key", ""))
		if key == "kids":
			continue
		var value := _value(node)
		if key == "x" and bool(_parse_whole(value).get("ok", false)):
			x = int(_parse_whole(value).n)
		elif key == "y" and bool(_parse_whole(value).get("ok", false)):
			y = int(_parse_whole(value).n)
		elif key != "" and value != "":
			attrs[key] = value
		elif key != "" and value == "" and old_attrs.has(key) and str(old_attrs[key]) == "":
			attrs[key] = ""
	for line_v in other.text.split("\n"):
		var line := str(line_v).strip_edges()
		if line == "":
			continue
		var at := line.find("=")
		if at <= 0:
			continue
		var key := line.substr(0, at).strip_edges()
		if attrs.has(key) or key == "x" or key == "y":
			continue
		attrs[key] = line.substr(at + 1).strip_edges()
	var next_kids: Array = _kids_commit(kids_board)
	var kids_same := _kids_same(obj.get("kids", []), next_kids)
	if int(obj.get("x", 0)) == x and int(obj.get("y", 0)) == y and attrs == (obj.get("attrs", {}) as Dictionary) and kids_same:
		return
	doc.snapshot()
	obj["x"] = x
	obj["y"] = y
	obj["attrs"] = attrs
	if not kids_same:
		if next_kids.is_empty():
			obj.erase("kids")
		else:
			obj["kids"] = next_kids
	objs[index] = obj
	room["objs"] = objs
	doc.dirty = true


static func _options_xml(opt: Dictionary) -> String:
	var s := "<options"
	for k in opt.keys():
		s += " %s=\"%s\"" % [str(k), Codec._esc(str(opt[k]))]
	return s + "/>"


static func _xml_reason(text: String, expect: String) -> String:
	var body := text.strip_edges()
	if body == "":
		return _tr("ed_xml_bad")
	var p := XMLParser.new()
	if p.open_buffer(body.to_utf8_buffer()) != OK:
		return _tr("ed_xml_bad")
	var tag := ""
	while true:
		var err := p.read()
		if err == ERR_FILE_EOF:
			break
		if err != OK:
			return _tr("ed_xml_bad")
		if tag == "" and p.get_node_type() == XMLParser.NODE_ELEMENT:
			tag = p.get_node_name()
	if tag != expect:
		return _locf("ed_xml_tag", [expect])
	var wrapped := "<all><room name=\"x\">%s</room></all>" % body
	var parsed := Codec.doc_from_xml(wrapped, "xml")
	var rooms: Array = parsed.get("rooms", [])
	if rooms.is_empty():
		return _tr("ed_xml_bad")
	if expect == "options":
		return ""
	var got: Array = rooms[0].get("objs", [])
	if got.is_empty() or str(got[0].get("tag", "")) != expect:
		return _locf("ed_xml_tag", [expect])
	return ""


static func _xml_warn(text: String, expect: String) -> String:
	var body := text.strip_edges()
	var p := XMLParser.new()
	if p.open_buffer(body.to_utf8_buffer()) != OK:
		return ""
	if p.read() != OK or p.get_node_type() != XMLParser.NODE_ELEMENT:
		return ""
	var known: Dictionary = Check.ROOM_KEYS if expect == "options" else Check.OBJ_KEYS
	var bad: PackedStringArray = PackedStringArray()
	for i in p.get_attribute_count():
		var key := p.get_attribute_name(i)
		if key in ["name", "id", "x", "y", "z"]:
			continue
		if not known.has(key):
			bad.append(key)
	if bad.is_empty():
		return ""
	return _locf("ed_xml_warn", [", ".join(bad)])


static func _apply_xml_text(doc: RefCounted, index: int, text: String, expect: String) -> bool:
	if _xml_reason(text, expect) != "":
		return false
	var wrapped := "<all><room name=\"x\">%s</room></all>" % text.strip_edges()
	var parsed := Codec.doc_from_xml(wrapped, "xml")
	var rooms: Array = parsed.get("rooms", [])
	if rooms.is_empty():
		return false
	if expect != "options":
		var objs0: Array = doc.room().get("objs", [])
		var got0: Array = rooms[0].get("objs", [])
		if index < 0 or index >= objs0.size() or got0.is_empty():
			return false
	doc.snapshot()
	if expect == "options":
		doc.room()["options"] = rooms[0].get("options", {})
	else:
		var objs: Array = doc.room().get("objs", [])
		var got: Array = rooms[0].get("objs", [])
		var old: Dictionary = objs[index]
		var neu: Dictionary = got[0]
		if old.has("size"):
			neu["size"] = old["size"]
		if old.has("kind"):
			neu["kind"] = old["kind"]
		if old.has("wid"):
			neu["wid"] = old["wid"]
		objs[index] = neu
	doc.dirty = true
	return true


static func _strip_decl(text: String) -> String:
	var s := text.strip_edges()
	if s.begins_with("<?"):
		var at := s.find("?>")
		if at >= 0:
			s = s.substr(at + 2).strip_edges()
	return s


static func _rows_reason(room: Dictionary) -> String:
	var rows: Array = room.get("rows", [])
	if rows.size() != Codec.ROWS:
		return _loc("ed_xml_rows")
	for row_v in rows:
		var parts := str(row_v).split(".")
		if parts.size() != Codec.COLS:
			return _loc("ed_xml_rows")
		for part in parts:
			if not Codec.token_ok(str(part)):
				return _locf("ed_xml_token", [str(part)])
	return ""


static func _room_xml_reason(text: String) -> String:
	var body := _strip_decl(text)
	if body == "":
		return _loc("ed_xml_bad")
	var p := XMLParser.new()
	if p.open_buffer(body.to_utf8_buffer()) != OK:
		return _loc("ed_xml_bad")
	var rooms_n := 0
	while true:
		var err := p.read()
		if err == ERR_FILE_EOF:
			break
		if err != OK:
			return _loc("ed_xml_bad")
		if p.get_node_type() == XMLParser.NODE_ELEMENT and p.get_node_name() == "room":
			rooms_n += 1
	if rooms_n != 1:
		return _loc("ed_xml_one_room")
	var parsed := Codec.doc_from_xml("<all>%s</all>" % body, "xml")
	var list: Array = parsed.get("rooms", [])
	if list.size() != 1:
		return _loc("ed_xml_one_room")
	return _rows_reason(list[0])


static func _land_xml_reason(text: String) -> String:
	var body := text.strip_edges()
	if body == "":
		return _loc("ed_xml_bad")
	var p := XMLParser.new()
	if p.open_buffer(body.to_utf8_buffer()) != OK:
		return _loc("ed_xml_bad")
	var saw := false
	while true:
		var err := p.read()
		if err == ERR_FILE_EOF:
			break
		if err != OK:
			return _loc("ed_xml_bad")
		if p.get_node_type() == XMLParser.NODE_ELEMENT and p.get_node_name() == "land":
			saw = true
	if not saw:
		return _loc("ed_xml_land_need")
	var parsed := Codec.doc_from_xml(body, "xml")
	var list: Array = parsed.get("rooms", [])
	if list.is_empty():
		return _loc("ed_xml_land_need")
	for room_v in list:
		var why := _rows_reason(room_v)
		if why != "":
			return why
	return ""


static func _apply_room_xml(doc: RefCounted, text: String) -> bool:
	if _room_xml_reason(text) != "" or not doc.has_method("apply_room"):
		return false
	var parsed := Codec.doc_from_xml("<all>%s</all>" % _strip_decl(text), "xml")
	var list: Array = parsed.get("rooms", [])
	if list.size() != 1:
		return false
	doc.apply_room(list[0])
	return true


static func _apply_land_xml(doc: RefCounted, text: String) -> bool:
	if _land_xml_reason(text) != "" or not doc.has_method("apply_land"):
		return false
	doc.apply_land(Codec.doc_from_xml(text.strip_edges(), str(doc.get("file"))))
	return true


static var _weaps: PackedStringArray = PackedStringArray()


static func _weap_ids() -> PackedStringArray:
	_bind_rules()
	return Rules._weap_ids()

static func _push(out: Array, field: String, value, msg: String) -> void:
	_bind_rules()
	return Rules._push(out, field, value, msg)

static func _enum_ids(pairs: Array) -> PackedStringArray:
	_bind_rules()
	return Rules._enum_ids(pairs)

static func _music_ids() -> PackedStringArray:
	_bind_rules()
	return Rules._music_ids()

static func _token_reason(text: String) -> String:
	_bind_rules()
	return Rules._token_reason(text)

static func _need_int(text: String, lo: int, hi: int, extra: PackedStringArray) -> String:
	_bind_rules()
	return Rules._need_int(text, lo, hi, extra)

static func _audit_room_name(name: String, rooms: Array) -> String:
	_bind_rules()
	return Rules._audit_room_name(name, rooms)

static func _own_uid_text(text: String, room: Dictionary, mine: String) -> String:
	_bind_rules()
	return Rules._own_uid_text(text, room, mine)

static func audit_room(room: Dictionary, rooms: Array) -> Array:
	_bind_rules()
	return Rules.audit_room(room, rooms)

static func audit_map(opt: Dictionary) -> Array:
	_bind_rules()
	return Rules.audit_map(opt)

static func audit_object(obj: Dictionary, room: Dictionary) -> Array:
	_bind_rules()
	return Rules.audit_object(obj, room)

static func audit_area(obj: Dictionary, room: Dictionary) -> Array:
	_bind_rules()
	return Rules.audit_area(obj, room)
