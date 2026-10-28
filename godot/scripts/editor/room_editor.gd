extends Control

## Port of Editor.swf. Rooms plug in through RoomFile mods/ overlay.

const RoomFile := preload("res://scripts/map/room_file.gd")
const RoomDoc := preload("res://scripts/editor/room_doc.gd")
const Codec := preload("res://scripts/editor/room_codec.gd")
const Palette := preload("res://scripts/editor/editor_palette.gd")
const Check := preload("res://scripts/editor/editor_check.gd")
const View := preload("res://scripts/editor/editor_view.gd")
const Dialogs := preload("res://scripts/editor/editor_dialogs.gd")
const EditorPreview := preload("res://scripts/editor/editor_preview.gd")
const Forms := preload("res://scripts/editor/editor_forms.gd")
const Groups := preload("res://scripts/editor/editor_groups.gd")
const Settings := preload("res://scripts/editor/editor_settings.gd")
const SIDE_PANE := 280
const TIPS: Array = [
	["", "ed_tip_any"], ["uniq", "ed_tip_uniq"], ["beg0", "ed_tip_beg0"], ["back", "ed_tip_back"],
	["roof", "ed_tip_roof"], ["pass", "ed_tip_pass"], ["passroof", "ed_tip_passroof"],
	["roofpass", "ed_tip_roofpass"], ["vert", "ed_tip_vert"], ["surf", "ed_tip_surf"],
]
const ENTIP: Array = [
	["", "ed_entip_biome"], ["0", "ed_entip_0"], ["1", "ed_entip_1"], ["2", "ed_entip_2"],
	["3", "ed_entip_3"], ["4", "ed_entip_4"], ["5", "ed_entip_5"], ["6", "ed_entip_6"],
	["7", "ed_entip_7"], ["8", "ed_entip_8"], ["9", "ed_entip_9"], ["10", "ed_entip_10"],
	["11", "ed_entip_11"],
]
const WTIP: Array = [["", "ed_wtip_land"], ["0", "ed_wtip_0"], ["1", "ed_wtip_1"], ["2", "ed_wtip_2"]]
const LON: Array = [["", "ed_lon_own"], ["1", "ed_lon_on"], ["-1", "ed_lon_off"], ["0", "ed_lon_0"]]

const CELL := 16.0
const FRONT_COL := {
	"A": Color("8a8a8a"), "B": Color("d0d0d0"), "C": Color("9a9a90"), "D": Color("8a8070"),
	"E": Color("7a7060"), "F": Color("6b4a2a"), "G": Color("6a5a4a"), "H": Color("4a3a20"),
	"I": Color("8a4030"), "J": Color("505860"), "K": Color("404850"), "L": Color("4a6a40"),
	"M": Color("8a5030"), "N": Color("7a7068"), "O": Color("505050"), "P": Color("9a6050"),
	"Q": Color("8a8078"), "R": Color("5a4030"), "S": Color("304050"), "T": Color("283848"),
}
const ID_NEW_MAP := 1
const ID_NEW_ROOM := 2
const ID_SAVE := 5
const ID_SAVE_AS := 6
const ID_EXPORT := 7
const ID_REVERT := 9
const ID_FOLDER := 10
const ID_EXIT := 11
const ID_UNDO := 20
const ID_REDO := 21
const ID_COPY := 22
const ID_DELETE := 23
const ID_SELECT := 24
const ID_CHECK := 25
const ID_XML := 26
const ID_ADD_STOREY := 27
const ID_REM_STOREY := 28
const ID_OPT_ROOM := 30
const ID_OPT_MAP := 31
const ID_XML_ROOM := 32
const ID_XML_LAND := 33
const ID_V_IDS := 34
const ID_V_TEX := 35
const ID_ZOOM_IN := 36
const ID_ZOOM_OUT := 37
const ID_ZOOM_RESET := 38
const ID_GEN := 40
const ID_PLAY_MAP := 41
const ID_PLAY_ROOM := 42

var _doc: RefCounted = RoomDoc.new()
var _file := ""
var _kind := "map"
var _brush: Dictionary = Palette.brush_for("front", "C", 0)
var _slot := "front"
var _zform := 0
var _mode := "paint"
var _layer := "front"
var _vis := {
	"front": true, "back": true, "stairs": true, "doors": true,
	"actors": true, "props": true, "area": true, "backdrop": true,
}
var _eraser := false
var _brushes: Dictionary = {}
var _drag := false
var _outline := false
var _drag0 := Vector2i.ZERO
var _drag1 := Vector2i.ZERO
var _sel_obj := -1
var _moving := false
var _move_i := -1
var _move_from := Vector2i.ZERO
var _move_grab := Vector2i.ZERO
var _move_to := Vector2i.ZERO
var _resize := false
var _resize_handle := ""
var _resize_base := Rect2i()
var _resize_rect := Rect2i()
var _status: Label
var _ask: ConfirmationDialog
var _after := Callable()
var _grid: Control
var _obj_id := ""
var _obj_ids: Dictionary = {}
var _minimap: Control
var _show_ids := false
var _textured := false
var _autosave := 0.0
var _view: RefCounted = View.new()
var _zoom := 1.0
var _pan := Vector2.ZERO
var _pan_user := false
var _pan_drag := false
var _pan_from := Vector2.ZERO
var _pan_at := Vector2.ZERO
var _rdown := false
var _rpos := Vector2.ZERO
var _rdrag := false
var _ctx: PopupMenu
var _mm_zoom := 1.0
var _mm_pan := Vector2.ZERO
var _mm_pan_at := Vector2.ZERO
var _mm_pan_on := false
var _mm_press := false
var _mm_from := Vector2.ZERO
var _mm_moved := false
var _mm_drag_name := ""
var _mm_drag_from := Vector2i.ZERO
var _mm_drag_to := Vector2i(-99999, -99999)
var _view_lock := true
var _space := false
var _art_stale := true
var _tex_wait := -1.0
var _zlay := 0
var _pal: VBoxContainer
var _layer_rows: Dictionary = {}
var _layer_btn: Button
var _layer_pop: PopupPanel
var _z_row: HBoxContainer
var _z_btns: Array = []
var _z_group: ButtonGroup
var _hover := Vector2i(-99999, -99999)
var _placed_ms := 0
var _bake: SubViewport
var _bake_item: Control
var _bake_key := ""
var _bake_arm := false
var _art_rev := 0
var _eraser_btn: Button
var _outer: HSplitContainer
var _inner: HSplitContainer
var _splits_set := false
var _mode_btn: Button
var _z_btn: Button
var _bar: MenuBar
var _file_menu: PopupMenu
var _edit_menu: PopupMenu
var _view_menu: PopupMenu
var _opt_menu: PopupMenu
var _test_menu: PopupMenu
var _placing := false
var _place_blank := true
var _place_src: Dictionary = {}
var _place_at := Vector2i(-99999, -99999)
var _place_cancel: Button
var _plus: Button
var _pending_blank := true
var _pending_src: Dictionary = {}
var _pending_doc: Dictionary = {}
var _place_comein := false


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	theme = Forms.editor_theme()
	_build_ui()
	var back: Dictionary = load("res://scripts/editor/editor_play.gd").take_back()
	var back_file := str(back.get("file", ""))
	var back_kind := str(back.get("kind", ""))
	if back_kind == "room" or back_kind == "map":
		_kind = back_kind
	if back_file != "":
		var mem: Dictionary = back.get("doc", {})
		_load_file(back_file, mem)
		var back_room := str(back.get("room", ""))
		if back_room != "":
			_reload_rooms(back_room)
		_doc.dirty = bool(back.get("dirty", false))
	_sync_kind_ui()
	var view: Variant = back.get("view", {})
	if not (view is Dictionary) or (view as Dictionary).is_empty():
		view = Settings.view_get()
	_apply_view(view)
	_view_lock = false
	if back_file == "":
		_note("")


func _process(delta: float) -> void:
	if _bar:
		_bar.set_disable_shortcuts(_modal_open())
	if _tex_wait >= 0.0:
		_tex_wait -= delta
		if _tex_wait <= 0.0:
			_tex_wait = -1.0
			_rebuild_art()
	if not _doc.dirty or _file == "":
		return
	_autosave += delta
	if _autosave >= 180.0:
		_autosave = 0.0
		_write_autosave()


func _unhandled_input(event: InputEvent) -> void:
	if _modal_open():
		return
	if event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
		var up := event as InputEventMouseButton
		if up.button_index == MOUSE_BUTTON_LEFT and (_drag or _resize):
			_finish_left()
			get_viewport().set_input_as_handled()
			return
		if up.button_index == MOUSE_BUTTON_RIGHT and _moving:
			_end_move()
			get_viewport().set_input_as_handled()
			return
		if up.button_index == MOUSE_BUTTON_RIGHT or up.button_index == MOUSE_BUTTON_MIDDLE:
			if _pan_drag:
				_save_view()
			_pan_drag = false
	if not _typing() and event is InputEventKey:
		var key := event as InputEventKey
		if key.keycode == KEY_SPACE:
			_space = key.pressed and not key.echo
			if not key.pressed:
				_pan_drag = false
			get_viewport().set_input_as_handled()
			return
		if key.pressed and not key.echo and key.ctrl_pressed and _menu_key(key):
			return
		if key.pressed and not key.echo and not key.ctrl_pressed:
			if key.keycode == KEY_EQUAL or key.keycode == KEY_KP_ADD or key.unicode == 43:
				_zoom_by(1.1)
				get_viewport().set_input_as_handled()
				return
			if key.keycode == KEY_MINUS or key.keycode == KEY_KP_SUBTRACT:
				_zoom_by(1.0 / 1.1)
				get_viewport().set_input_as_handled()
				return
			if key.keycode == KEY_E and not key.shift_pressed:
				_eraser = not _eraser
				_sync_eraser()
				get_viewport().set_input_as_handled()
				return
			if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
				if _layer == "area":
					_edit_area()
				elif (_is_object_layer() or _layer == "backdrop") and _sel_obj >= 0:
					_edit_object()
				else:
					return
				get_viewport().set_input_as_handled()
				return
	if event.is_action_pressed("ui_undo") or (event is InputEventKey and event.pressed and event.ctrl_pressed and event.keycode == KEY_Z and not event.shift_pressed):
		_do_undo()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_redo") or (event is InputEventKey and event.pressed and event.ctrl_pressed and (event.keycode == KEY_Y or (event.keycode == KEY_Z and event.shift_pressed))):
		_do_redo()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if _placing:
			_cancel_place()
		else:
			_leave()
		get_viewport().set_input_as_handled()


func _menu_key(key: InputEventKey) -> bool:
	if _typing():
		return false
	var code := key.keycode
	if code == KEY_S and key.shift_pressed:
		_save_as()
	elif code == KEY_S:
		_save()
	elif code == KEY_O and not key.shift_pressed:
		_ask_new_map(true)
	elif code == KEY_N and key.shift_pressed:
		_ask_new_room()
	elif code == KEY_N:
		_ask_new_map()
	elif code == KEY_0 or code == KEY_KP_0:
		_zoom_reset()
	else:
		return false
	get_viewport().set_input_as_handled()
	return true


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(root)
	_build_menus(root)
	_status = Label.new()
	_status.clip_text = true
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.custom_minimum_size.y = 20
	root.add_child(_status)
	_outer = HSplitContainer.new()
	_outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_outer)
	_outer.add_child(_build_left())
	_inner = HSplitContainer.new()
	_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_outer.add_child(_inner)
	_grid = Control.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.clip_contents = true
	_grid.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_grid.draw.connect(_draw_grid)
	_grid.gui_input.connect(_grid_input)
	_grid.resized.connect(_fit_pan)
	_inner.add_child(_grid)
	_inner.add_child(_build_right())
	if not resized.is_connected(_layout_splits):
		resized.connect(_layout_splits)
	call_deferred("_layout_splits")


func _build_menus(root: VBoxContainer) -> void:
	_bar = MenuBar.new()
	_bar.prefer_global_menu = false
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_bar)
	_file_menu = PopupMenu.new()
	_edit_menu = PopupMenu.new()
	_opt_menu = PopupMenu.new()
	_view_menu = PopupMenu.new()
	_test_menu = PopupMenu.new()
	_bar.add_child(_file_menu)
	_bar.add_child(_edit_menu)
	_bar.add_child(_opt_menu)
	_bar.add_child(_view_menu)
	_bar.add_child(_test_menu)
	_bar.set_menu_title(0, Locale.t("ed_menu_file"))
	_bar.set_menu_title(1, Locale.t("ed_menu_edit"))
	_bar.set_menu_title(2, Locale.t("ed_menu_options"))
	_bar.set_menu_title(3, Locale.t("ed_menu_view"))
	_bar.set_menu_title(4, Locale.t("ed_menu_test"))
	_item(_file_menu, "ed_new_map", ID_NEW_MAP, KEY_MASK_CTRL | KEY_N)
	_item(_file_menu, "ed_new_room", ID_NEW_ROOM, KEY_MASK_CTRL | KEY_MASK_SHIFT | KEY_N)
	_file_menu.add_separator()
	_item(_file_menu, "ed_save", ID_SAVE, KEY_MASK_CTRL | KEY_S)
	_item(_file_menu, "ed_save_as", ID_SAVE_AS, KEY_MASK_CTRL | KEY_MASK_SHIFT | KEY_S)
	_file_menu.add_separator()
	_item(_file_menu, "ed_export_as", ID_EXPORT, KEY_MASK_CTRL | KEY_MASK_SHIFT | KEY_E)
	_file_menu.add_separator()
	_item(_file_menu, "ed_revert", ID_REVERT, KEY_NONE)
	_item(_file_menu, "ed_folder", ID_FOLDER, KEY_NONE)
	_file_menu.add_separator()
	_item(_file_menu, "ed_exit", ID_EXIT, KEY_NONE)
	_file_menu.id_pressed.connect(_on_file_menu)
	_item(_edit_menu, "ed_undo", ID_UNDO, KEY_MASK_CTRL | KEY_Z)
	_item(_edit_menu, "ed_redo", ID_REDO, KEY_MASK_CTRL | KEY_Y)
	_edit_menu.add_separator()
	_item(_edit_menu, "ed_copy_room", ID_COPY, KEY_NONE)
	_item(_edit_menu, "ed_delete", ID_DELETE, KEY_NONE)
	_edit_menu.add_separator()
	_item(_edit_menu, "ed_add_storey", ID_ADD_STOREY, KEY_NONE)
	_item(_edit_menu, "ed_remove_storey", ID_REM_STOREY, KEY_NONE)
	_edit_menu.add_separator()
	_item(_edit_menu, "ed_check", ID_CHECK, KEY_NONE)
	_edit_menu.about_to_popup.connect(_sync_storey_menu)
	_edit_menu.id_pressed.connect(_on_edit_menu)
	_item(_opt_menu, "ed_opt_room", ID_OPT_ROOM, KEY_NONE)
	_item(_opt_menu, "ed_opt_map", ID_OPT_MAP, KEY_NONE)
	_opt_menu.add_separator()
	_item(_opt_menu, "ed_xml_room", ID_XML_ROOM, KEY_NONE)
	_item(_opt_menu, "ed_xml_land", ID_XML_LAND, KEY_NONE)
	_opt_menu.about_to_popup.connect(_sync_kind_ui)
	_opt_menu.id_pressed.connect(_on_opt_menu)
	_check(_view_menu, "ed_view_ids", ID_V_IDS, false)
	_check(_view_menu, "ed_view_tex", ID_V_TEX, false)
	_view_menu.add_separator()
	_item(_view_menu, "ed_zoom_in", ID_ZOOM_IN, KEY_EQUAL)
	_item(_view_menu, "ed_zoom_out", ID_ZOOM_OUT, KEY_MINUS)
	_item(_view_menu, "ed_zoom_reset", ID_ZOOM_RESET, KEY_MASK_CTRL | KEY_0)
	_view_menu.about_to_popup.connect(_sync_view_checks)
	_view_menu.id_pressed.connect(_on_view_menu)
	_item(_test_menu, "ed_generate", ID_GEN, KEY_NONE)
	_item(_test_menu, "ed_play_land", ID_PLAY_MAP, KEY_NONE)
	_item(_test_menu, "ed_play_room", ID_PLAY_ROOM, KEY_NONE)
	_test_menu.about_to_popup.connect(_sync_kind_ui)
	_test_menu.id_pressed.connect(_on_test_menu)


func _item(menu: PopupMenu, key: String, id: int, accel: Key) -> void:
	menu.add_item(Locale.t(key), id, accel)


func _check(menu: PopupMenu, key: String, id: int, on: bool) -> void:
	menu.add_check_item(Locale.t(key), id)
	menu.set_item_checked(menu.get_item_index(id), on)


func _on_file_menu(id: int) -> void:
	match id:
		ID_NEW_MAP:
			_ask_new_map()
		ID_NEW_ROOM:
			_ask_new_room()
		ID_SAVE:
			_save()
		ID_SAVE_AS:
			_save_as()
		ID_EXPORT:
			_export_as()
		ID_REVERT:
			_revert()
		ID_FOLDER:
			_open_mods()
		ID_EXIT:
			_leave()


func _on_edit_menu(id: int) -> void:
	match id:
		ID_UNDO:
			_do_undo()
		ID_REDO:
			_do_redo()
		ID_COPY:
			_copy_room()
		ID_DELETE:
			_delete_room()
		ID_ADD_STOREY:
			_add_storey()
		ID_REM_STOREY:
			_ask_remove_storey()
		ID_CHECK:
			_run_checks()


func _on_opt_menu(id: int) -> void:
	if id == ID_OPT_ROOM:
		Forms.open_room(self, _doc, _after_doc, _kind == "room")
	elif id == ID_OPT_MAP and _kind != "room":
		Forms.open_map(self, _doc, _after_doc)
	elif id == ID_XML_ROOM:
		Forms.open_xml(self, _doc, -1, _after_doc, "room")
	elif id == ID_XML_LAND:
		Forms.open_xml(self, _doc, -1, _after_doc, "land")


func _after_doc() -> void:
	_touch_art()
	_sync_mode_btns()
	_sync_kind_ui()
	_redraw()


func _on_view_menu(id: int) -> void:
	if id == ID_ZOOM_IN:
		_zoom_by(1.1)
		return
	if id == ID_ZOOM_OUT:
		_zoom_by(1.0 / 1.1)
		return
	if id == ID_ZOOM_RESET:
		_zoom_reset()
		return
	var idx := _view_menu.get_item_index(id)
	var on := not _view_menu.is_item_checked(idx)
	_view_menu.set_item_checked(idx, on)
	match id:
		ID_V_IDS:
			_show_ids = on
			_save_view()
		ID_V_TEX:
			_set_textured(on)
			_save_view()
			return
	_redraw()


func _sync_view_checks() -> void:
	_view_menu.set_item_checked(_view_menu.get_item_index(ID_V_IDS), _show_ids)
	_view_menu.set_item_checked(_view_menu.get_item_index(ID_V_TEX), _textured)


func _layout_splits() -> void:
	if _splits_set or _outer == null or _inner == null:
		return
	var w := size.x
	if w < 64.0 and get_window():
		w = float(get_window().size.x)
	if w < 64.0:
		return
	var sep_o := _outer.get_theme_constant("separation")
	var sep_i := _inner.get_theme_constant("separation")
	var side := SIDE_PANE
	var grid := int(w) - side * 2 - sep_o - sep_i
	if grid < int(w) / 2:
		side = maxi(200, (int(w) - sep_o - sep_i) / 4)
		grid = int(w) - side * 2 - sep_o - sep_i
	var left := _outer.get_child(0) as Control
	var grid_c := _inner.get_child(0) as Control
	_outer.split_offset = side - int(left.get_combined_minimum_size().x)
	_inner.split_offset = grid - int(grid_c.get_combined_minimum_size().x)
	_splits_set = true
	if resized.is_connected(_layout_splits):
		resized.disconnect(_layout_splits)


func _on_test_menu(id: int) -> void:
	match id:
		ID_GEN:
			_generate()
		ID_PLAY_MAP:
			_play_land()
		ID_PLAY_ROOM:
			_play_room()


func _do_undo() -> void:
	_doc.undo()
	_reload_rooms(str(_doc.room().get("name", "")))
	_sync_kind_ui()


func _do_redo() -> void:
	_doc.redo()
	_reload_rooms(str(_doc.room().get("name", "")))
	_sync_kind_ui()


func _build_left() -> VBoxContainer:
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 280
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.clip_contents = true
	var cap := HBoxContainer.new()
	left.add_child(cap)
	cap.add_child(_label(Locale.t("ed_minimap")))
	var mm_out := Button.new()
	mm_out.text = "−"
	mm_out.tooltip_text = Locale.t("ed_zoom_out")
	mm_out.focus_mode = Control.FOCUS_NONE
	mm_out.pressed.connect(func(): _mm_zoom_at(_minimap.size * 0.5, 1.0 / 1.25))
	cap.add_child(mm_out)
	var mm_in := Button.new()
	mm_in.text = "+"
	mm_in.tooltip_text = Locale.t("ed_zoom_in")
	mm_in.focus_mode = Control.FOCUS_NONE
	mm_in.pressed.connect(func(): _mm_zoom_at(_minimap.size * 0.5, 1.25))
	cap.add_child(mm_in)
	var mm_fit := Button.new()
	mm_fit.text = Locale.t("ed_mm_fit")
	mm_fit.focus_mode = Control.FOCUS_NONE
	mm_fit.pressed.connect(_mm_reset)
	cap.add_child(mm_fit)
	_plus = Button.new()
	_plus.text = "+"
	_plus.tooltip_text = Locale.t("ed_add_room")
	_plus.pressed.connect(func(): _start_add())
	cap.add_child(_plus)
	_place_cancel = Button.new()
	_place_cancel.text = Locale.t("ed_cancel")
	_place_cancel.visible = false
	_place_cancel.pressed.connect(_cancel_place)
	cap.add_child(_place_cancel)
	_minimap = Control.new()
	_minimap.custom_minimum_size = Vector2(260, 220)
	_minimap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_minimap.size_flags_stretch_ratio = 1.3
	_minimap.clip_contents = true
	_minimap.draw.connect(_draw_minimap)
	_minimap.gui_input.connect(_minimap_input)
	left.add_child(_minimap)
	var mrow := HBoxContainer.new()
	left.add_child(mrow)
	_mode_btn = Button.new()
	_mode_btn.pressed.connect(_toggle_mode)
	mrow.add_child(_mode_btn)
	_z_btn = Button.new()
	_z_btn.pressed.connect(_toggle_storey)
	mrow.add_child(_z_btn)
	_sync_mode_btns()
	return left


func _build_right() -> VBoxContainer:
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = SIDE_PANE
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.clip_contents = true
	_layer_btn = Button.new()
	_layer_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_layer_btn.clip_text = true
	_layer_btn.pressed.connect(_open_layers)
	right.add_child(_layer_btn)
	_layer_pop = PopupPanel.new()
	_layer_pop.theme = Forms.editor_theme()
	var box := VBoxContainer.new()
	_layer_pop.add_child(box)
	for id_v in Groups.LAYERS:
		var id := str(id_v)
		var row := HBoxContainer.new()
		var eye := CheckBox.new()
		eye.button_pressed = true
		eye.focus_mode = Control.FOCUS_NONE
		eye.tooltip_text = Locale.t("ed_eye")
		eye.toggled.connect(_on_eye.bind(id))
		var name_b := Button.new()
		name_b.text = Locale.t("ed_layer_%s" % id)
		name_b.clip_text = true
		name_b.flat = true
		name_b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_b.pressed.connect(_choose_layer.bind(id))
		row.add_child(eye)
		row.add_child(name_b)
		box.add_child(row)
		_layer_rows[id] = {"eye": eye, "name": name_b}
	add_child(_layer_pop)
	var tools := HBoxContainer.new()
	right.add_child(tools)
	_eraser_btn = Button.new()
	_eraser_btn.toggle_mode = true
	_eraser_btn.text = Locale.t("ed_eraser")
	_eraser_btn.tooltip_text = Locale.t("ed_eraser_tip")
	_eraser_btn.toggled.connect(_on_eraser)
	tools.add_child(_eraser_btn)
	_z_group = ButtonGroup.new()
	_z_row = HBoxContainer.new()
	right.add_child(_z_row)
	for i in 4:
		var zb := Button.new()
		zb.toggle_mode = true
		zb.button_group = _z_group
		zb.text = Locale.t("ed_z%d" % i)
		zb.tooltip_text = Locale.tf("ed_z_tip", [i])
		zb.pressed.connect(_set_zform.bind(i))
		_z_row.add_child(zb)
		_z_btns.append(zb)
	(_z_btns[0] as Button).set_pressed_no_signal(true)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(sc)
	_pal = VBoxContainer.new()
	_pal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_pal)
	_brushes["front"] = _brush
	_activate_layer("front")
	return right


func _open_layers() -> void:
	if _layer_pop == null or _layer_btn == null:
		return
	var at := _layer_btn.global_position
	_layer_pop.popup(Rect2i(int(at.x), int(at.y + _layer_btn.size.y), 320, Groups.LAYERS.size() * 34 + 8))


func _choose_layer(id: String) -> void:
	_activate_layer(id)
	if _layer_pop:
		_layer_pop.hide()


func _label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	return l


func _btn(parent: Node, t: String, fn: Callable) -> void:
	var b := Button.new()
	b.text = t
	b.pressed.connect(fn)
	parent.add_child(b)


func _swatches(parent: Node, items: Array, storey := false) -> void:
	var wrap := HFlowContainer.new()
	parent.add_child(wrap)
	for id_v in items:
		var id := str(id_v)
		var slot := _item_slot(id)
		var b := Button.new()
		b.custom_minimum_size = Vector2(44, 44)
		b.tooltip_text = _swatch_tip(slot, id)
		var tex: Texture2D = _view.swatch(slot, id)
		if tex != null:
			if slot == "backdrop":
				var bg := TextureRect.new()
				bg.texture = _view.checker()
				bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				bg.stretch_mode = TextureRect.STRETCH_TILE
				bg.set_anchors_preset(Control.PRESET_FULL_RECT)
				bg.offset_left = 2
				bg.offset_top = 2
				bg.offset_right = -2
				bg.offset_bottom = -2
				bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
				b.add_child(bg)
			var rect := TextureRect.new()
			rect.texture = tex
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			rect.offset_left = 2
			rect.offset_top = 2
			rect.offset_right = -2
			rect.offset_bottom = -2
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(rect)
		else:
			b.text = id.substr(0, 2)
		if slot == "obj" or slot == "backdrop":
			b.pressed.connect(_pick_obj_id.bind(slot, id, storey))
		else:
			b.pressed.connect(_pick.bind(slot, id))
		wrap.add_child(b)


func _swatch_tip(slot: String, id: String) -> String:
	var name := id
	var size := "1×1"
	if slot == "obj":
		for row in Palette.objs():
			if str(row.id) == id:
				name = str(row.n)
				break
		var meta: Dictionary = Palette.object_meta(id)
		size = "%d×%d" % [int(meta.get("size", 1)), int(meta.get("wid", 1))]
	elif slot == "backdrop":
		var spec: Dictionary = _view._back_kinds().get(id, {})
		size = "%d×%d" % [maxi(int(ceil(float(spec.get("x2", 1)))), 1), maxi(int(ceil(float(spec.get("y2", 1)))), 1)]
	else:
		name = Palette.tile_name(slot, id)
	return "%s\n%s\n%s" % [name, id, size]


func _pick_obj_id(slot: String, id: String, storey := false) -> void:
	_eraser = false
	_sync_eraser()
	_obj_id = id
	_obj_ids[_layer] = id
	_place_comein = storey and id == "doorboss"
	_mode = "back" if slot == "backdrop" else "obj"
	if not _view_lock:
		_note(Locale.tf("ed_brush", [Locale.t("ed_layer_%s" % _layer), id]))


func _pick(slot: String, id: String) -> void:
	_eraser = false
	_sync_eraser()
	_slot = slot
	_mode = "paint"
	_brush = Palette.brush_for(slot, id, _zform if slot == "front" else -1)
	var layer := _layer_for_slot(slot, id)
	if layer != "":
		_brushes[layer] = _brush
		if layer != _layer:
			_layer = layer
			_fill_palette()
			_sync_layers()
	_sync_z_buttons()
	if not _view_lock:
		_note(Locale.tf("ed_brush", [Locale.t("ed_layer_%s" % _layer), id]))


func _set_zform(z: int) -> void:
	_zform = z
	_mode = "paint"
	_eraser = false
	_sync_eraser()
	_sync_z_buttons()
	if _layer != "front" or _water_brush():
		return
	var id := str(_brush.get("front", "C"))
	if id == "" or id == "_":
		id = "C"
	_brush = Palette.brush_for("front", id, _zform)
	_brushes["front"] = _brush


func _water_brush() -> bool:
	return str(_brush.get("water", "")) == "*" and str(_brush.get("front", "")) == ""


func _sync_z_buttons() -> void:
	if _z_row:
		_z_row.visible = _layer == "front" and not _water_brush()
	for i in _z_btns.size():
		(_z_btns[i] as Button).set_pressed_no_signal(i == _zform)


func _on_eraser(on: bool) -> void:
	_eraser = on


func _sync_eraser() -> void:
	if _eraser_btn:
		_eraser_btn.set_pressed_no_signal(_eraser)


func _on_eye(on: bool, id: String) -> void:
	_vis[id] = on
	_sync_layers()
	_save_view()
	_redraw()


func _sync_layers() -> void:
	for id in _layer_rows:
		var row: Dictionary = _layer_rows[id]
		var eye := row.eye as CheckBox
		var on := bool(_vis.get(id, true))
		eye.set_pressed_no_signal(on)
		var name_b := row.name as Button
		name_b.text = ("● " if str(id) == _layer else "   ") + Locale.t("ed_layer_%s" % id)
	if _layer_btn:
		_layer_btn.text = Locale.t("ed_layer_%s" % _layer) + "  ▾"
	_sync_z_buttons()


func _activate_layer(id: String) -> void:
	_layer = id
	if id == "area":
		_mode = "area"
	elif id == "backdrop" or _is_object_layer():
		_mode = "back" if id == "backdrop" else "obj"
		_obj_id = str(_obj_ids.get(id, ""))
	else:
		_mode = "paint"
		if not _brushes.has(id):
			_brushes[id] = _default_brush(id)
		_brush = _brushes[id]
		if id == "front" and not _water_brush():
			var front_id := str(_brush.get("front", "C"))
			if front_id == "" or front_id == "_":
				front_id = "C"
			_brush = Palette.brush_for("front", front_id, _zform)
			_brushes["front"] = _brush
		_slot = _layer_slot()
	_fill_palette()
	_sync_layers()
	_save_view()


func _is_object_layer() -> bool:
	return _layer == "doors" or _layer == "actors" or _layer == "props"


func _is_piece() -> bool:
	return _is_object_layer() or _layer == "backdrop" or _layer == "area"


func _default_brush(id: String) -> Dictionary:
	match id:
		"front":
			return Palette.brush_for("front", "C", _zform)
		"back":
			return Palette.brush_for("back", "A")
		"stairs":
			return Palette.brush_for("diag", "В")
	return {}


func _erase_brush() -> Dictionary:
	match _layer:
		"front":
			return {"front": "_", "water": "_"}
		"back":
			return {"back": "_"}
		"stairs":
			return {"diag": "_", "stair": "_"}
	return {}


func _layer_slot() -> String:
	if _layer == "front":
		return "water" if _water_brush() else "front"
	if _layer == "back":
		return "back"
	if _layer == "stairs":
		if str(_brush.get("stair", "")) != "":
			return "stair"
		return "diag"
	return ""


func _layer_for_slot(slot: String, _id: String) -> String:
	match slot:
		"front", "water":
			return "front"
		"back":
			return "back"
		"stair", "diag":
			return "stairs"
	return ""


func _item_slot(id: String) -> String:
	if _layer == "front":
		return "water" if id == "*" else "front"
	if _layer == "back":
		return "back"
	if _layer == "stairs":
		return "stair" if Palette.STAIR.has(id) else "diag"
	if _layer == "backdrop":
		return "backdrop"
	return "obj"


func _obj_layer(obj: Dictionary) -> String:
	return Groups.obj_layer(obj)


func _drawn(id: String) -> bool:
	return bool(_vis.get(id, true))


func _clear_pal() -> void:
	while _pal.get_child_count() > 0:
		var child := _pal.get_child(0)
		_pal.remove_child(child)
		child.free()


func _fill_palette() -> void:
	_clear_pal()
	if _layer == "area":
		var hint := _label(Locale.t("ed_area_hint"))
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_pal.add_child(hint)
		return
	var groups: Array = Groups.for_layer(_layer)
	for group_v in groups:
		var group: Dictionary = group_v
		var gname := str(group.get("name", ""))
		var items: Array = group.get("items", [])
		if items.is_empty():
			continue
		if bool(group.get("flat", false)) or gname == "":
			_swatches(_pal, items)
			continue
		var head := Button.new()
		head.toggle_mode = true
		head.alignment = HORIZONTAL_ALIGNMENT_LEFT
		head.button_pressed = Settings.fold_open(_layer, gname)
		var body := VBoxContainer.new()
		var title := _group_title(gname)
		head.text = ("%s  %s  (%d)" % ["▼" if head.button_pressed else "▶", title, items.size()])
		body.visible = head.button_pressed
		head.toggled.connect(func(on: bool) -> void:
			body.visible = on
			head.text = "%s  %s  (%d)" % ["▼" if on else "▶", title, items.size()]
			Settings.set_fold(_layer, gname, on)
		)
		_swatches(body, items, gname == "storey")
		_pal.add_child(head)
		_pal.add_child(body)


func _group_title(name: String) -> String:
	return Locale.t("ed_sub_%s" % name, name)


func _sync_mode_btns() -> void:
	if _mode_btn:
		var mode := Locale.t("ed_mode_map") if _doc.placed else Locale.t("ed_mode_rnd")
		_mode_btn.text = Locale.tf("ed_mode_btn", [mode])
	if _z_btn:
		_z_btn.text = Locale.tf("ed_storey", [_zlay])


func _toggle_mode() -> void:
	if _kind == "room":
		return
	_doc.placed = not _doc.placed
	_doc.dirty = true
	_sync_mode_btns()
	_cancel_place()


func _toggle_storey() -> void:
	var other := Check.partner(_doc.room(), _doc.rooms)
	if not other.is_empty():
		_reload_rooms(str(other.get("name", "")))
		return
	_zlay = 1 - _zlay
	_sync_mode_btns()
	if _minimap:
		_minimap.queue_redraw()


func _px() -> float:
	return CELL * _zoom


func _fit_pan() -> void:
	if _pan_user or _grid == null:
		return
	var need := Vector2(Codec.COLS, Codec.ROWS) * _px()
	_pan = ((_grid.size - need) * 0.5).max(Vector2.ZERO)


func _zoom_by(factor: float) -> void:
	_zoom_at(_grid.size * 0.5, factor)


func _zoom_at(at: Vector2, factor: float) -> void:
	var old := _px()
	if old <= 0.0:
		return
	var world := (at - _pan) / old
	_zoom = clampf(_zoom * factor, 0.5, 3.0)
	_pan = at - world * _px()
	_pan_user = true
	_save_view()
	_redraw()


func _zoom_reset() -> void:
	_zoom = 1.0
	_pan_user = false
	_fit_pan()
	_save_view()
	_redraw()


func _redraw() -> void:
	if _grid:
		_grid.queue_redraw()


func _touch_art() -> void:
	_art_stale = true
	if _textured:
		_tex_wait = 0.2


func _set_textured(on: bool) -> void:
	_textured = on
	if on and _art_stale:
		_tex_wait = 0.0
	_redraw()


func _view_state() -> Dictionary:
	return {
		"tex": _textured, "ids": _show_ids, "layer": _layer,
		"zoom": _zoom, "pan_x": _pan.x, "pan_y": _pan.y, "pan_user": _pan_user,
		"eyes": _vis.duplicate(),
	}


func _save_view() -> void:
	if _view_lock:
		return
	Settings.view_set(_view_state())


func _apply_view(state: Dictionary) -> void:
	if state.is_empty():
		return
	_show_ids = bool(state.get("ids", _show_ids))
	_textured = bool(state.get("tex", _textured))
	var eyes: Variant = state.get("eyes", {})
	if eyes is Dictionary:
		var migrated := Settings.migrate_eyes(eyes)
		for id in _vis.keys():
			_vis[id] = bool(migrated.get(id, _vis[id]))
	var raw := str(state.get("layer", ""))
	var layer := Settings.layer_id(raw if raw != "" else _layer)
	_activate_layer(layer)
	if raw == "water":
		_pick("water", "*")
	elif raw == "ladder":
		_pick("stair", "А")
	elif raw == "beam":
		_pick("diag", "-")
	elif raw == "stair":
		_pick("diag", "В")
	_zoom = clampf(float(state.get("zoom", _zoom)), 0.5, 3.0)
	_pan = Vector2(float(state.get("pan_x", _pan.x)), float(state.get("pan_y", _pan.y)))
	_pan_user = bool(state.get("pan_user", _pan_user))
	if _textured:
		_tex_wait = 0.0
	_sync_view_checks()
	_redraw()


func _rebuild_art() -> void:
	_art_stale = false
	_art_rev += 1
	var opt: Dictionary = _doc.room().get("options", {})
	var land: Dictionary = {}
	var land_v: Variant = _doc.get("land_defaults")
	if land_v is Dictionary:
		land = land_v
	var wall := str(opt.get("backwall", ""))
	var fon := ""
	if _kind == "room":
		if wall == "":
			wall = "tBackWall"
	else:
		if wall == "":
			wall = str(_doc.options.get("backwall", ""))
		if wall == "":
			wall = str(land.get("backwall", ""))
		fon = str(_doc.options.get("fon", ""))
		if fon == "":
			fon = str(land.get("fon", ""))
		if fon == "":
			fon = "fonDefault"
	_view.rebuild(_doc.grid, wall, int(str(opt.get("backform", "0"))), {}, fon)
	_redraw()


func _typing() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	return focused is LineEdit or focused is TextEdit


func _load_file(name: String, mem: Dictionary = {}) -> void:
	_file = name
	_doc.load_dict(mem if not mem.is_empty() else RoomFile.load_doc(name))
	_placing = false
	_sync_place()
	var mode := Locale.t("ed_mode_map") if _doc.placed else Locale.t("ed_mode_rnd")
	_note(Locale.tf("ed_open", [_doc.rooms.size(), mode]))
	_sync_kind_ui()
	_reload_rooms("" if _doc.rooms.is_empty() else str(_doc.rooms[0].get("name", "")))
	if mem.is_empty():
		call_deferred("_offer_autosave")


func _reload_rooms(select: String) -> void:
	if _doc.rooms.is_empty():
		_sel_obj = -1
		_touch_art()
		_redraw()
		if _minimap:
			_minimap.queue_redraw()
		return
	var name := select
	var found := false
	for room_v in _doc.rooms:
		if str(room_v.get("name", "")) == select:
			found = true
			break
	if not found:
		name = str(_doc.rooms[0].get("name", ""))
	_doc.open_room(name)
	_sel_obj = -1
	_zlay = int(_doc.room().get("z", 0))
	if str(_doc.room().get("options", {}).get("tip", "")) == "back" and _zlay == 0:
		_zlay = 1
	_sync_mode_btns()
	_touch_art()
	_redraw()
	if _minimap:
		_minimap.queue_redraw()


func _tile_at(pos: Vector2) -> Vector2i:
	var p := (pos - _pan) / _px()
	var x := int(floor(p.x))
	var y := int(floor(p.y))
	if x < 0 or y < 0 or x >= Codec.COLS or y >= Codec.ROWS:
		return Vector2i(-1, -1)
	return Vector2i(x, y)


func _grid_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(mb.position, 1.1)
			_grid.accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(mb.position, 1.0 / 1.1)
			_grid.accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_MIDDLE or (_space and mb.button_index == MOUSE_BUTTON_LEFT):
			_pan_drag = mb.pressed
			_pan_from = mb.position
			_pan_at = _pan
			_grid.accept_event()
			return
		if _doc.room_i < 0:
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_grid_right(mb)
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_grid_left(mb)
	elif event is InputEventMouseMotion and _rdown and not _rdrag and not _pan_drag:
		var rmotion := event as InputEventMouseMotion
		if rmotion.position.distance_to(_rpos) >= 4.0:
			_rdrag = true
			if _is_piece():
				var rat := _tile_at(_rpos)
				var rhits := _object_hits(rat, _layer)
				if rat.x >= 0 and not rhits.is_empty():
					_begin_move(int(rhits[0]), rat)
					_redraw()
	elif event is InputEventMouseMotion and _pan_drag:
		var motion := event as InputEventMouseMotion
		_pan = _pan_at + motion.position - _pan_from
		_pan_user = true
		if motion.position.distance_to(_pan_from) >= 4.0:
			_rdrag = true
		_redraw()
	elif _doc.room_i < 0:
		return
	elif event is InputEventMouseMotion and _resize:
		var resize_at := _tile_at((event as InputEventMouseMotion).position)
		if resize_at.x >= 0:
			_resize_rect = Forms.resize_rect(_resize_base, _resize_handle, resize_at)
			_redraw()
	elif event is InputEventMouseMotion and _moving:
		var move_at := _tile_at((event as InputEventMouseMotion).position)
		if move_at.x >= 0:
			var objs: Array = _doc.room().get("objs", [])
			var obj: Dictionary = objs[_move_i] if _move_i >= 0 and _move_i < objs.size() else {}
			_move_to = _clamp_anchor(move_at - _move_grab, obj)
			_redraw()
	elif event is InputEventMouseMotion and _drag:
		var at := _tile_at((event as InputEventMouseMotion).position)
		if at.x >= 0:
			_drag1 = at
			_redraw()
	elif event is InputEventMouseMotion:
		var hover_at := _tile_at((event as InputEventMouseMotion).position)
		if hover_at != _hover:
			_hover = hover_at
			_redraw()


func _grid_right(mb: InputEventMouseButton) -> void:
	if mb.pressed and mb.alt_pressed:
		var at := _tile_at(mb.position)
		if at.x >= 0:
			_eyedrop(at)
		return
	if mb.pressed:
		_rdown = true
		_rpos = mb.position
		_rdrag = false
		if not _is_piece():
			_pan_drag = true
			_pan_from = mb.position
			_pan_at = _pan
		return
	var opened := not _rdrag and not _moving
	if _moving:
		_end_move()
	var panned := _pan_drag and _rdrag
	_pan_drag = false
	_rdown = false
	if opened:
		_open_context(_tile_at(_rpos))
	elif panned:
		_save_view()
	_rdrag = false


func _finish_left() -> void:
	if _resize:
		_end_resize()
		return
	if _drag:
		_drag = false
		_apply_drag()


func _grid_left(mb: InputEventMouseButton) -> void:
	if not mb.pressed:
		_finish_left()
		return
	var at := _tile_at(mb.position)
	if at.x < 0:
		return
	if _layer == "area" and mb.double_click:
		var hits := _object_hits(at, "area")
		_drag = false
		_resize = false
		if not hits.is_empty():
			_sel_obj = int(hits[0])
			_edit_area()
		return
	_outline = mb.shift_pressed
	if mb.alt_pressed:
		if _is_object_layer() and not _eraser and _brush_is_storey() and _object_hits(at, _layer).is_empty():
			_place_obj(at, false)
			return
		_eyedrop(at)
		return
	if _layer == "area":
		_area_press(at, mb.position)
		return
	if _is_object_layer() or _layer == "backdrop":
		if mb.double_click and not _eraser:
			if Time.get_ticks_msec() - _placed_ms < 400:
				_doc.undo()
				_placed_ms = 0
			var hits := _object_hits(at, _layer)
			_drag = false
			if not hits.is_empty():
				_sel_obj = int(hits[0])
				_edit_object()
			_redraw()
			return
		if _eraser:
			_drag = true
			_drag0 = at
			_drag1 = at
			_redraw()
		elif not _object_hits(at, _layer).is_empty():
			_pick_obj(at)
			_redraw()
		else:
			_place_obj(at, true)
		return
	_drag = true
	_drag0 = at
	_drag1 = at
	_redraw()


func _eyedrop(at: Vector2i) -> void:
	var objs: Array = _doc.room().get("objs", [])
	for i in _object_hits(at, ""):
		var obj: Dictionary = objs[i]
		var oid := str(obj.get("id", ""))
		var lay := _obj_layer(obj)
		_obj_ids[lay] = oid
		_activate_layer(lay)
		_obj_id = oid
		if _layer == "backdrop":
			_mode = "back"
		elif _layer == "area":
			_mode = "area"
		elif _is_object_layer():
			_mode = "obj"
		_eraser = false
		_sync_eraser()
		_note(Locale.tf("ed_brush", [Locale.t("ed_layer_%s" % _layer), _obj_id]))
		return
	var c: Dictionary = _doc.cell(at.x, at.y)
	if str(c.get("water", "")) != "":
		_pick("water", str(c.water))
		return
	if str(c.get("stair", "")) != "":
		_pick("stair", str(c.stair))
		return
	if str(c.get("front", "")) != "":
		_zform = clampi(int(c.get("zform", 0)), 0, 3)
		_sync_z_buttons()
		_pick("front", str(c.front))
		return
	var diag := str(c.get("diag", ""))
	if diag != "":
		_pick("diag", diag)
		return
	if str(c.get("back", "")) != "":
		_pick("back", str(c.back))


func _area_press(at: Vector2i, screen: Vector2) -> void:
	if _eraser:
		_drag = true
		_drag0 = at
		_drag1 = at
		_redraw()
		return
	if _sel_obj >= 0:
		var objs: Array = _doc.room().get("objs", [])
		if _sel_obj < objs.size() and Forms.is_area(objs[_sel_obj]):
			var handle := Forms.area_handle(Forms.area_rect(objs[_sel_obj]), _pan, _px(), screen)
			if handle != "":
				_resize = true
				_resize_handle = handle
				_resize_base = Forms.area_rect(objs[_sel_obj])
				_resize_rect = _resize_base
				_redraw()
				return
	_drag = true
	_drag0 = at
	_drag1 = at
	_redraw()


func _apply_area() -> void:
	if _eraser:
		_erase_layer_objs()
		_redraw()
		_note(Locale.t("ed_painted"))
		return
	if _drag0 == _drag1:
		var hits := _object_hits(_drag0, "area")
		_sel_obj = int(hits[0]) if not hits.is_empty() else -1
		_redraw()
		return
	var x0 := mini(_drag0.x, _drag1.x)
	var y0 := mini(_drag0.y, _drag1.y)
	var x1 := maxi(_drag0.x, _drag1.x)
	var y1 := maxi(_drag0.y, _drag1.y)
	var w := x1 - x0 + 1
	var h := y1 - y0 + 1
	_doc.snapshot()
	var room: Dictionary = _doc.room()
	var objs: Array = room.get("objs", [])
	objs.append({
		"tag": "obj", "id": "area", "x": x0, "y": y1, "size": 1,
		"attrs": {"w": str(w), "h": str(h), "code": Codec.object_code()},
	})
	room["objs"] = objs
	_sel_obj = objs.size() - 1
	_doc.dirty = true
	_touch_art()
	_redraw()
	_note(Locale.t("ed_painted"))


func _end_resize() -> void:
	_resize = false
	if _sel_obj < 0:
		_redraw()
		return
	var objs: Array = _doc.room().get("objs", [])
	if _sel_obj >= objs.size():
		_redraw()
		return
	var obj: Dictionary = objs[_sel_obj]
	var before := Forms.area_rect(obj)
	if before == _resize_rect:
		_redraw()
		return
	_doc.snapshot()
	Forms.set_area_rect(obj, _resize_rect)
	_doc.dirty = true
	_touch_art()
	_redraw()


func _edit_object() -> void:
	if _sel_obj < 0:
		return
	var objs: Array = _doc.room().get("objs", [])
	if _sel_obj >= objs.size() or Forms.is_area(objs[_sel_obj]):
		return
	var snap := {"obj": (objs[_sel_obj] as Dictionary).duplicate(true)}
	Forms.open_object(self, _doc, _sel_obj, func() -> void:
		_mirror_door(snap)
		_after_doc()
	)


func _edit_xml() -> void:
	var objs: Array = _doc.room().get("objs", [])
	var snap := {"obj": {}}
	if _sel_obj >= 0 and _sel_obj < objs.size():
		snap["obj"] = (objs[_sel_obj] as Dictionary).duplicate(true)
	Forms.open_xml(self, _doc, _sel_obj, func() -> void:
		_mirror_door(snap)
		_after_doc()
	)


func _ensure_ctx() -> void:
	if _ctx != null:
		return
	_ctx = PopupMenu.new()
	_ctx.theme = Forms.editor_theme()
	_ctx.transparent = false
	_ctx.add_item(Locale.t("ed_xml_edit"), 1)
	_ctx.add_item(Locale.t("ed_obj_title"), 2)
	_ctx.id_pressed.connect(_on_ctx)
	add_child(_ctx)


func _open_context(at: Vector2i) -> void:
	if at.x < 0:
		return
	if not _is_piece():
		return
	var hits := _object_hits(at, _layer)
	if hits.is_empty():
		return
	_sel_obj = int(hits[0])
	_redraw()
	_ensure_ctx()
	var label := Locale.t("ed_area_title") if _layer == "area" else Locale.t("ed_obj_title")
	_ctx.set_item_text(1, label)
	var pos := DisplayServer.mouse_get_position()
	_ctx.popup(Rect2i(int(pos.x), int(pos.y), 1, 1))


func _on_ctx(id: int) -> void:
	if id == 1:
		_edit_xml()
	elif id == 2:
		if _layer == "area":
			_edit_area()
		else:
			_edit_object()


func _edit_area() -> void:
	if _layer != "area" or _sel_obj < 0:
		return
	var objs: Array = _doc.room().get("objs", [])
	if _sel_obj >= objs.size() or not Forms.is_area(objs[_sel_obj]):
		return
	Forms.open_area(self, _doc, _sel_obj, _after_doc)


func _apply_drag() -> void:
	if _layer == "area":
		_apply_area()
		return
	if _is_object_layer() or _layer == "backdrop":
		if _eraser:
			_erase_layer_objs()
			_redraw()
			_note(Locale.t("ed_painted"))
		return
	if _eraser:
		var clear := _erase_brush()
		if clear.is_empty():
			_redraw()
			return
		_doc.paint_drag(_drag0, _drag1, clear, _outline, true, "")
	elif not _brush.is_empty():
		_doc.paint_drag(_drag0, _drag1, _brush, _outline, false)
	else:
		_redraw()
		return
	_touch_art()
	_redraw()
	_note(Locale.t("ed_painted"))


func _place_obj(at: Vector2i, link := true) -> void:
	if _obj_id == "" or at.x < 0:
		return
	var tag := "back" if _layer == "backdrop" else "obj"
	if tag != "back" and at.x >= Codec.COLS - 1:
		return
	var storey := tag == "obj" and link and _brush_is_storey()
	if storey and Check.partner(_doc.room(), _doc.rooms).is_empty():
		if not _can_add_storey():
			_stamp_obj(at, false)
			return
		_confirm(Locale.t("ed_storey_need"), Locale.t("ed_add_storey"), func() -> void:
			if not _add_storey():
				return
			_stamp_obj(at, true)
		)
		return
	_stamp_obj(at, storey)


func _stamp_obj(at: Vector2i, link: bool) -> void:
	var tag := "back" if _layer == "backdrop" else "obj"
	_doc.snapshot()
	var obj := _make_obj(tag, at)
	var room: Dictionary = _doc.room()
	var objs: Array = room.get("objs", [])
	objs.append(obj)
	room["objs"] = objs
	if link:
		_stamp_twin(obj)
	_doc.dirty = true
	_placed_ms = Time.get_ticks_msec()
	_touch_art()
	_redraw()


func _make_obj(tag: String, at: Vector2i) -> Dictionary:
	var obj := {"tag": tag, "id": _obj_id, "x": at.x, "y": at.y, "size": 1, "attrs": {"code": Codec.object_code()}}
	if tag != "obj":
		return obj
	var meta: Dictionary = Palette.object_meta(_obj_id)
	obj["size"] = int(meta.get("size", 1))
	var obj_kind := str(meta.get("kind", ""))
	if obj_kind != "":
		obj["kind"] = obj_kind
	if _place_comein and _obj_id == "doorboss":
		(obj["attrs"] as Dictionary)["allact"] = "comein"
	return obj


func _stamp_twin(obj: Dictionary) -> void:
	var other := Check.partner(_doc.room(), _doc.rooms)
	if other.is_empty():
		return
	var twin: Dictionary = obj.duplicate(true)
	(twin["attrs"] as Dictionary)["code"] = Codec.object_code()
	var objs: Array = other.get("objs", [])
	objs.append(twin)
	other["objs"] = objs


func _object_hits(at: Vector2i, only_layer: String) -> Array:
	var objs: Array = _doc.room().get("objs", [])
	var hits: Array = []
	for i in range(objs.size() - 1, -1, -1):
		var obj: Dictionary = objs[i]
		if only_layer != "" and _obj_layer(obj) != only_layer:
			continue
		if _view.obj_rect(obj).has_point(at):
			hits.append(i)
	return hits


func _pick_obj(at: Vector2i) -> void:
	var objs: Array = _doc.room().get("objs", [])
	var hits := _object_hits(at, _layer)
	if hits.is_empty():
		return
	var idx := 0
	if _sel_obj in hits:
		idx = (hits.find(_sel_obj) + 1) % hits.size()
	_sel_obj = int(hits[idx])
	_redraw()


func _begin_move(i: int, at: Vector2i) -> void:
	var objs: Array = _doc.room().get("objs", [])
	if i < 0 or i >= objs.size():
		return
	var obj: Dictionary = objs[i]
	_moving = true
	_move_i = i
	_move_from = Vector2i(int(obj.get("x", 0)), int(obj.get("y", 0)))
	_move_grab = at - _move_from
	_move_to = _move_from
	_sel_obj = i


func _end_move() -> void:
	if not _moving:
		return
	_moving = false
	var objs: Array = _doc.room().get("objs", [])
	if _move_to == _move_from or _move_i < 0 or _move_i >= objs.size():
		_redraw()
		return
	_doc.snapshot()
	var moved: Dictionary = objs[_move_i]
	var from := _move_from
	moved["x"] = _move_to.x
	moved["y"] = _move_to.y
	if Check.is_storey_door(moved):
		_move_twin(moved, from)
	_doc.dirty = true
	_touch_art()
	_redraw()


func _clamp_anchor(at: Vector2i, obj: Dictionary) -> Vector2i:
	if Forms.is_area(obj):
		var rect := Forms.area_rect(obj)
		var x := clampi(at.x, 0, Codec.COLS - rect.size.x)
		var y := clampi(at.y, rect.size.y - 1, Codec.ROWS - 1)
		return Vector2i(x, y)
	var x2 := clampi(at.x, 0, Codec.COLS - 1)
	var y2 := clampi(at.y, 0, Codec.ROWS - 1)
	if str(obj.get("tag", "obj")) != "back":
		x2 = mini(x2, Codec.COLS - 2)
	return Vector2i(x2, y2)


func _obj_in_drag(obj: Dictionary) -> bool:
	var foot: Rect2i = _view.obj_rect(obj)
	var x0 := mini(_drag0.x, _drag1.x)
	var y0 := mini(_drag0.y, _drag1.y)
	var x1 := maxi(_drag0.x, _drag1.x)
	var y1 := maxi(_drag0.y, _drag1.y)
	for y in range(foot.position.y, foot.position.y + foot.size.y):
		for x in range(foot.position.x, foot.position.x + foot.size.x):
			if x < x0 or x > x1 or y < y0 or y > y1:
				continue
			if _outline and x != x0 and x != x1 and y != y0 and y != y1:
				continue
			return true
	return false


func _erase_layer_objs() -> void:
	var room: Dictionary = _doc.room()
	var objs: Array = room.get("objs", [])
	var keep: Array = []
	var dropped: Array = []
	for obj_v in objs:
		var obj: Dictionary = obj_v
		if _obj_layer(obj) == _layer and _obj_in_drag(obj):
			dropped.append(obj)
			continue
		keep.append(obj)
	if dropped.is_empty():
		return
	_doc.snapshot()
	room["objs"] = keep
	for gone_v in dropped:
		if Check.is_storey_door(gone_v):
			_drop_twin(gone_v)
	_sel_obj = -1
	_doc.dirty = true
	_touch_art()


func _draw_grid() -> void:
	var px := _px()
	var origin := _pan
	if _textured and _doc.room_i >= 0:
		origin = Vector2(round(_pan.x), round(_pan.y))
		_refresh_bake()
		var baked := _bake.get_texture() if _bake else null
		if baked:
			_grid.draw_texture(baked, origin)
		var grid_col := Color(1, 1, 1, 0.12)
		var gw := float(int(floor(Codec.COLS * px)))
		var gh := float(int(floor(Codec.ROWS * px)))
		for x in Codec.COLS + 1:
			var gx := origin.x + float(int(floor(x * px)))
			_grid.draw_line(Vector2(gx, origin.y), Vector2(gx, origin.y + gh), grid_col)
		for y in Codec.ROWS + 1:
			var gy := origin.y + float(int(floor(y * px)))
			_grid.draw_line(Vector2(origin.x, gy), Vector2(origin.x + gw, gy), grid_col)
	else:
		_grid.draw_rect(Rect2(origin, Vector2(Codec.COLS, Codec.ROWS) * px), Color(0.08, 0.08, 0.08))
	if _doc.room_i < 0:
		return
	if not _textured:
		for y in Codec.ROWS:
			for x in Codec.COLS:
				var c: Dictionary = _doc.cell(x, y)
				var r := Rect2(origin + Vector2(x, y) * px, Vector2(px, px))
				var front := str(c.get("front", ""))
				if _drawn("back") and str(c.get("back", "")) != "":
					_grid.draw_rect(r, Color(0.25, 0.25, 0.3, 0.7))
				if _drawn("front") and front != "":
					var col: Color = FRONT_COL.get(front, Color("666666"))
					var h := 1.0 - int(c.get("zform", 0)) * 0.25
					var block := r
					block.position.y += block.size.y * (1.0 - h)
					block.size.y *= h
					_grid.draw_rect(block, col)
				if _drawn("front") and str(c.get("water", "")) == "*":
					_grid.draw_rect(r, Color(0.2, 0.45, 0.8, 0.35))
				if _drawn("stairs") and str(c.get("stair", "")) != "":
					_grid.draw_line(origin + Vector2(x, y + 1) * px, origin + Vector2(x + 1, y) * px, Color.YELLOW, 1.0)
				var diag := str(c.get("diag", ""))
				if diag != "" and _drawn("stairs"):
					var kind := Palette.diag_kind(diag)
					var show_diag := kind == "beam" or kind == "slope"
					if show_diag:
						_grid.draw_line(origin + Vector2(x, y) * px, origin + Vector2(x + 1, y + 1) * px, Color(0.8, 0.6, 0.2), 1.0)
				if _show_ids and _drawn("front") and front != "":
					_grid.draw_string(ThemeDB.fallback_font, origin + Vector2(x, y) * px + Vector2(2, 12), front, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
	elif _show_ids and _drawn("front"):
		for y in Codec.ROWS:
			for x in Codec.COLS:
				var front := str(_doc.cell(x, y).get("front", ""))
				if front != "":
					_grid.draw_string(ThemeDB.fallback_font, origin + Vector2(x, y) * px + Vector2(2, 12), front, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
	if not _textured:
		var objs: Array = _doc.room().get("objs", [])
		for i in objs.size():
			var obj_v: Dictionary = objs[i]
			if Forms.is_area(obj_v):
				continue
			var tag := str(obj_v.get("tag", "obj"))
			if not _drawn(_obj_layer(obj_v)):
				continue
			var footprint: Rect2i = _view.obj_rect(obj_v)
			var p := origin + Vector2(footprint.position) * px
			var col := Color(0.3, 0.75, 0.95, 0.55) if tag == "back" else Color(0.2, 0.9, 0.4, 0.5)
			_grid.draw_rect(Rect2(p, Vector2(footprint.size) * px), col)
		if _drawn("area"):
			View.paint_areas(_grid, origin, px, _doc.room(), false)
	if _sel_obj >= 0:
		var selected: Array = _doc.room().get("objs", [])
		if _sel_obj < selected.size():
			var mark: Rect2i = _view.obj_rect(selected[_sel_obj])
			_grid.draw_rect(Rect2(origin + Vector2(mark.position) * px, Vector2(mark.size) * px), Color.WHITE, false, 1.0)
	_draw_place(origin, px)
	if _resize:
		var ghost := Rect2(origin + Vector2(_resize_rect.position) * px, Vector2(_resize_rect.size) * px)
		_grid.draw_rect(ghost, Color(1, 1, 1, 0.25))
		_grid.draw_rect(ghost, Color.WHITE, false, 1.0)
	if _layer == "area" and _sel_obj >= 0:
		var handles: Array = _doc.room().get("objs", [])
		if _sel_obj < handles.size() and Forms.is_area(handles[_sel_obj]):
			var hr := Forms.area_rect(handles[_sel_obj])
			var box := Rect2(origin + Vector2(hr.position) * px, Vector2(hr.size) * px)
			for pt in [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]:
				_grid.draw_rect(Rect2(pt - Vector2(3, 3), Vector2(6, 6)), Color.WHITE)
	if _moving and _move_i >= 0:
		var moved: Array = _doc.room().get("objs", [])
		if _move_i < moved.size():
			var ghost: Rect2i = _view.obj_rect(moved[_move_i])
			var delta := _move_to - _move_from
			var gp := origin + Vector2(ghost.position + delta) * px
			var gr := Rect2(gp, Vector2(ghost.size) * px)
			var bad := _move_bad(moved[_move_i])
			var edge := Color(0.95, 0.25, 0.22) if bad else Color.WHITE
			_grid.draw_rect(gr, Color(edge.r, edge.g, edge.b, 0.28))
			_grid.draw_rect(gr, edge, false, 1.0)


func _ensure_bake() -> void:
	if _bake != null:
		return
	_bake = SubViewport.new()
	_bake.disable_3d = true
	_bake.transparent_bg = false
	_bake.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_bake.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_bake_item = Control.new()
	_bake_item.draw.connect(_draw_bake)
	_bake.add_child(_bake_item)
	add_child(_bake)


func _refresh_bake() -> void:
	_ensure_bake()
	var px := _px()
	var w := maxi(1, int(floor(Codec.COLS * px)))
	var h := maxi(1, int(floor(Codec.ROWS * px)))
	var key := "%d|%d|%d|%s" % [w, h, _art_rev, _vis_key()]
	if key == _bake_key and _bake.size == Vector2i(w, h):
		return
	_bake.size = Vector2i(w, h)
	_bake_item.size = Vector2(w, h)
	_bake_item.queue_redraw()
	_bake.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_bake_key = key
	if not _bake_arm:
		_bake_arm = true
		call_deferred("_redraw_bake")


func _redraw_bake() -> void:
	_bake_arm = false
	_redraw()


func _draw_bake() -> void:
	_view.paint(_bake_item, Vector2.ZERO, _zoom, true, true, _doc.room(), true, true, _vis)


func _vis_key() -> String:
	var s := ""
	for id in Groups.LAYERS:
		s += "1" if _drawn(str(id)) else "0"
	return s


func _draw_place(origin: Vector2, px: float) -> void:
	var cells: Array = []
	var ghost: Dictionary = {}
	if _drag:
		cells = _drag_cells()
	elif not _moving and not _resize:
		ghost = _hover_piece()
		if not ghost.is_empty():
			var foot: Rect2i = _view.obj_rect(ghost)
			if foot.size.x > 1 or foot.size.y > 1:
				for y in range(foot.position.y, foot.position.y + foot.size.y):
					for x in range(foot.position.x, foot.position.x + foot.size.x):
						cells.append(Vector2i(x, y))
	if cells.is_empty():
		return
	var bad := _place_bad(cells)
	var col := Color(0.95, 0.25, 0.22, 0.9) if bad else Color(0.35, 0.95, 0.55, 0.9)
	if _textured and not ghost.is_empty() and not bad:
		_view.draw_faded(_grid, ghost, origin, _zoom, 0.35)
	elif _textured and _drag and _layer_slot() != "":
		var slot := _layer_slot()
		var id := str(_brush.get(slot, ""))
		var tex: Texture2D = _view.swatch(slot, id)
		if tex:
			for cell in cells:
				var at: Vector2i = cell
				_grid.draw_texture_rect(tex, Rect2(origin + Vector2(at) * px, Vector2(px, px)), false, Color(1, 1, 1, 0.35))
	for cell in cells:
		var at: Vector2i = cell
		_grid.draw_rect(Rect2(origin + Vector2(at) * px, Vector2(px, px)), col, false, 1.0)


func _hover_piece() -> Dictionary:
	if _hover.x < 0 or _obj_id == "" or _eraser:
		return {}
	if not _is_object_layer() and _layer != "backdrop":
		return {}
	var tag := "back" if _layer == "backdrop" else "obj"
	var obj := {"tag": tag, "id": _obj_id, "x": _hover.x, "y": _hover.y, "size": 1}
	if tag == "obj":
		var meta: Dictionary = Palette.object_meta(_obj_id)
		obj["size"] = int(meta.get("size", 1))
		obj["wid"] = int(meta.get("wid", 1))
	return obj


func _place_bad(cells: Array) -> bool:
	for cell in cells:
		var at: Vector2i = cell
		if at.x < 0 or at.y < 0 or at.x >= Codec.COLS or at.y >= Codec.ROWS:
			return true
		if _is_object_layer() and at.x >= Codec.COLS - 1:
			return true
		var solid := _solid_front(_doc.room(), at.x, at.y)
		if solid and _blocked_by_solid():
			return true
	if _is_object_layer() and not _drag and _hover.x >= Codec.COLS - 1:
		return true
	if not _drag and _brush_is_storey() and _hover.x >= 0:
		return _storey_place_bad(_hover, -1)
	return false


func _blocked_by_solid() -> bool:
	if _is_object_layer():
		return true
	if _eraser or _layer != "stairs":
		return false
	var diag := str(_brush.get("diag", ""))
	if diag != "" and diag != "_" and Palette.diag_kind(diag) == "beam":
		return false
	return str(_brush.get("stair", "")) != "" or diag != ""


func _brush_is_storey() -> bool:
	if not _is_object_layer() or _obj_id == "":
		return false
	if Check.STOREY_IDS.has(_obj_id):
		return true
	return _obj_id == "doorboss" and _place_comein


func _back_room(room: Dictionary) -> bool:
	if int(room.get("z", 0)) == 1:
		return true
	return str(room.get("options", {}).get("tip", "")) == "back"


func _can_add_storey() -> bool:
	var room: Dictionary = _doc.room()
	if room.is_empty() or str(room.get("name", "")) == "":
		return false
	if not Check.partner(room, _doc.rooms).is_empty() or _back_room(room):
		return false
	if _doc.placed:
		return room.has("x") and room.has("y") and int(room.get("z", 0)) == 0
	return true


func _sync_storey_menu() -> void:
	if _edit_menu == null:
		return
	var add_i := _edit_menu.get_item_index(ID_ADD_STOREY)
	var rem_i := _edit_menu.get_item_index(ID_REM_STOREY)
	if add_i >= 0:
		_edit_menu.set_item_disabled(add_i, not _can_add_storey())
	if rem_i >= 0:
		_edit_menu.set_item_disabled(rem_i, Check.partner(_doc.room(), _doc.rooms).is_empty())


func _add_storey() -> bool:
	if not _can_add_storey():
		return false
	_doc.snapshot()
	var room: Dictionary = _doc.room()
	if _doc.placed:
		var x := int(room.get("x", 0))
		var y := int(room.get("y", 0))
		_doc.rooms.append({
			"name": _unique_room("room_%d_%d_1" % [x, y]),
			"rows": _blank_rows(), "objs": [], "x": x, "y": y, "z": 1,
		})
	else:
		var nm := _unique_room("%s_back" % str(room.get("name", "room")))
		var opt: Dictionary = room.get("options", {})
		if typeof(room.get("options", {})) != TYPE_DICTIONARY:
			opt = {}
		else:
			opt = opt.duplicate()
		opt["back"] = nm
		room["options"] = opt
		_doc.rooms.append({
			"name": nm, "rows": _blank_rows(), "objs": [], "options": {"tip": "back"},
		})
	_doc.dirty = true
	_sync_kind_ui()
	_note(Locale.t("ed_created"))
	return true


func _ask_remove_storey() -> void:
	var room: Dictionary = _doc.room()
	var other := Check.partner(room, _doc.rooms)
	if other.is_empty():
		return
	var victim := other
	var stay := room
	if _back_room(room) and not _back_room(other):
		victim = room
		stay = other
	elif _back_room(other):
		victim = other
		stay = room
	var victim_name := str(victim.get("name", ""))
	var stay_name := str(stay.get("name", ""))
	_confirm(Locale.tf("ed_remove_storey_ask", [victim_name]), Locale.t("ed_remove_storey"), func() -> void:
		_remove_storey(victim_name, stay_name)
	)


func _remove_storey(victim_name: String, stay_name: String) -> void:
	_doc.snapshot()
	if not _doc.placed:
		for room_v in _doc.rooms:
			if str(room_v.get("name", "")) != stay_name:
				continue
			var opt: Dictionary = room_v.get("options", {})
			if str(opt.get("back", "")) == victim_name:
				opt.erase("back")
				if opt.is_empty():
					room_v.erase("options")
			break
	for i in _doc.rooms.size():
		if str(_doc.rooms[i].get("name", "")) != victim_name:
			continue
		_doc.rooms.remove_at(i)
		if _doc.room_i == i:
			_doc.room_i = -1
			_doc.grid.clear()
		elif _doc.room_i > i:
			_doc.room_i -= 1
		break
	_doc.dirty = true
	_reload_rooms(stay_name)


func _cell_of(room: Dictionary, x: int, y: int) -> Dictionary:
	if x < 0 or y < 0 or x >= Codec.COLS or y >= Codec.ROWS:
		return Codec.empty_cell()
	if str(room.get("name", "")) == str(_doc.room().get("name", "")) and _doc.room_i >= 0:
		return _doc.cell(x, y)
	var rows: Array = room.get("rows", [])
	if y < 0 or y >= rows.size():
		return Codec.empty_cell()
	var parts: PackedStringArray = str(rows[y]).split(".")
	if x < 0 or x >= parts.size():
		return Codec.empty_cell()
	return Codec.parse_token(parts[x])


func _solid_front(room: Dictionary, x: int, y: int) -> bool:
	var cell := _cell_of(room, x, y)
	return str(cell.get("front", "")) != "" and int(cell.get("zform", 0)) == 0


func _storey_place_bad(at: Vector2i, _skip: int) -> bool:
	var ghost := _hover_piece()
	if ghost.is_empty():
		ghost = {"tag": "obj", "id": _obj_id, "x": at.x, "y": at.y, "size": int(Palette.object_meta(_obj_id).get("size", 1)), "wid": int(Palette.object_meta(_obj_id).get("wid", 1))}
	return _door_bad(ghost, at, -1)


func _move_bad(obj: Dictionary) -> bool:
	if not Check.is_storey_door(obj):
		return false
	return _door_bad(obj, _move_to, _move_i)


func _door_bad(src: Dictionary, at: Vector2i, skip_cur: int) -> bool:
	var probe: Dictionary = src.duplicate(true)
	probe["x"] = at.x
	probe["y"] = at.y
	var foot: Rect2i = _view.obj_rect(probe)
	var other := Check.partner(_doc.room(), _doc.rooms)
	if other.is_empty():
		return true
	var twin_i := _twin_index(other, src)
	for room_v in [_doc.room(), other]:
		var room: Dictionary = room_v
		var skip := skip_cur if str(room.get("name", "")) == str(_doc.room().get("name", "")) else twin_i
		for y in range(foot.position.y, foot.position.y + foot.size.y):
			for x in range(foot.position.x, foot.position.x + foot.size.x):
				if x < 0 or y < 0 or x >= Codec.COLS or y >= Codec.ROWS or x >= Codec.COLS - 1:
					return true
				if _solid_front(room, x, y):
					return true
		if _obj_hit(room, foot, skip):
			return true
	var size := int(probe.get("size", Palette.object_meta(str(probe.get("id", ""))).get("size", 1)))
	return _arrival_live(other, at.x, at.y, size)


func _arrival_live(room: Dictionary, ax: int, ay: int, size: int) -> bool:
	for cell_v in Check.arrival_cells(ax, ay, size):
		var at: Vector2i = cell_v
		if at.x < 0 or at.y < 0 or at.x >= Codec.COLS or at.y >= Codec.ROWS:
			continue
		if Check.tile_blocks(_cell_of(room, at.x, at.y)):
			return true
	return false


func _obj_hit(room: Dictionary, foot: Rect2i, skip: int) -> bool:
	var objs: Array = room.get("objs", [])
	for i in objs.size():
		if i == skip:
			continue
		var obj: Dictionary = objs[i]
		if str(obj.get("tag", "obj")) == "back" or Forms.is_area(obj):
			continue
		if foot.intersects(_view.obj_rect(obj)):
			return true
	return false


func _twin_index(room: Dictionary, obj: Dictionary) -> int:
	if room.is_empty():
		return -1
	var id := str(obj.get("id", ""))
	var x := int(obj.get("x", 0))
	var y := int(obj.get("y", 0))
	var objs: Array = room.get("objs", [])
	for i in objs.size():
		var twin: Dictionary = objs[i]
		if not Check.is_storey_door(twin):
			continue
		if str(twin.get("id", "")) == id and int(twin.get("x", 0)) == x and int(twin.get("y", 0)) == y:
			return i
	return -1


func _move_twin(obj: Dictionary, from: Vector2i) -> void:
	var other := Check.partner(_doc.room(), _doc.rooms)
	var probe: Dictionary = obj.duplicate(true)
	probe["x"] = from.x
	probe["y"] = from.y
	var i := _twin_index(other, probe)
	if i < 0:
		return
	var objs: Array = other.get("objs", [])
	objs[i]["x"] = obj.get("x", 0)
	objs[i]["y"] = obj.get("y", 0)


func _drop_twin(obj: Dictionary) -> void:
	var other := Check.partner(_doc.room(), _doc.rooms)
	var i := _twin_index(other, obj)
	if i < 0:
		return
	var objs: Array = other.get("objs", [])
	objs.remove_at(i)
	other["objs"] = objs


func _mirror_door(snap: Dictionary) -> void:
	var before: Dictionary = snap.get("obj", {})
	if before.is_empty() or not Check.is_storey_door(before):
		return
	var objs: Array = _doc.room().get("objs", [])
	if _sel_obj < 0 or _sel_obj >= objs.size():
		return
	var now: Dictionary = objs[_sel_obj]
	var other := Check.partner(_doc.room(), _doc.rooms)
	var i := _twin_index(other, before)
	if i < 0:
		return
	var twins: Array = other.get("objs", [])
	var twin: Dictionary = twins[i]
	twin["id"] = now.get("id", twin.get("id", ""))
	twin["x"] = now.get("x", 0)
	twin["y"] = now.get("y", 0)
	if now.has("size"):
		twin["size"] = now.get("size")
	if now.has("wid"):
		twin["wid"] = now.get("wid")
	if now.has("kind"):
		twin["kind"] = now.get("kind")
	var attrs: Dictionary = twin.get("attrs", {})
	if typeof(twin.get("attrs", {})) != TYPE_DICTIONARY:
		attrs = {}
	var now_attrs: Dictionary = now.get("attrs", {})
	if now_attrs.has("allact"):
		attrs["allact"] = now_attrs.get("allact", "")
	else:
		attrs.erase("allact")
	twin["attrs"] = attrs
	snap["obj"] = now.duplicate(true)


func _copy_room() -> void:
	var src := str(_doc.room().get("name", ""))
	if src == "":
		_note(Locale.t("ed_need_name"))
		return
	Dialogs.ask_text(self, Locale.t("ed_copy_room"), Locale.t("ed_name_ph"), Locale.t("ed_copy_room"), _finish_copy.bind(src), "", func(text: String) -> String:
		return _room_name_problem(text, src)
	)


func _finish_copy(src: String, raw: String) -> void:
	var dest := raw.strip_edges()
	if _doc.copy_room(src, dest):
		if _kind == "room":
			_doc.delete_room(src)
		_reload_rooms(dest)
		_note(Locale.t("ed_copied"))


func _room_name_problem(raw: String, current: String) -> String:
	var name := raw.strip_edges()
	if name == "":
		return Locale.t("ed_need_name")
	if not Forms._room_chars(name):
		return Locale.t("ed_name_chars")
	if name == current:
		return Locale.t("ed_name_used")
	for room_v in _doc.rooms:
		if str(room_v.get("name", "")) == name:
			return Locale.t("ed_name_used")
	return ""


func _delete_room() -> void:
	var n := str(_doc.room().get("name", ""))
	if n == "":
		return
	_confirm(Locale.tf("ed_delete_ask", [n]), Locale.t("ed_delete"), _do_delete.bind(n))


func _do_delete(n: String) -> void:
	if _doc.delete_room(n):
		_reload_rooms("" if _doc.rooms.is_empty() else str(_doc.rooms[0].get("name", "")))


func _ask_new_map(open_existing := false) -> void:
	_guard(func(): Dialogs.new_map(self, _on_map_choice, _map_name_problem, open_existing))


func _on_map_choice(action: String, data: Dictionary) -> void:
	if action == "open":
		_open_existing_map(str(data.get("file", "")), str(data.get("room", "")))
		return
	var raw := str(data.get("name", ""))
	if action == "import":
		_pending_doc = data.get("doc", {})
		var imported := _adopt_name(raw, _finish_map_file)
		if imported != "":
			_finish_map_file(imported)
		return
	var made := _adopt_name(raw, _finish_new_map)
	if made != "":
		_finish_new_map(made)


func _ask_empty_map_name() -> void:
	Dialogs.ask_text(self, Locale.t("ed_new_map"), Locale.t("ed_file_name"), Locale.t("ed_new_map"), _make_map, "", _map_name_problem)


func _map_name_problem(raw: String) -> String:
	var name := _clean_stem(raw)
	if name == "":
		return Locale.t("ed_name_bad")
	if FileAccess.file_exists("%s/%s.json" % [RoomFile.DIR, name]):
		return Locale.t("ed_name_builtin")
	return ""


func _make_map(raw: String) -> void:
	var name := _adopt_name(raw, _finish_new_map)
	if name != "":
		_finish_new_map(name)


func _finish_new_map(name: String) -> void:
	_kind = "map"
	_file = name
	_doc.load_dict({"file": name, "source": "mod", "placed": true, "rooms": []})
	_zlay = 0
	_placing = false
	_sync_place()
	_sync_kind_ui()
	_add_room(true, {}, Vector2i.ZERO)


func _open_existing_map(file: String, room: String) -> void:
	_kind = "map"
	_load_file(file)
	if room != "":
		_reload_rooms(room)


func _on_map_file(doc: Dictionary) -> void:
	if (doc.get("rooms", []) as Array).is_empty():
		_note(Locale.t("ed_import_bad"))
		return
	_pending_doc = doc
	Dialogs.ask_text(self, Locale.t("ed_new_map"), Locale.t("ed_file_name"), Locale.t("ed_new_map"), _make_map_file, "", _map_name_problem)


func _make_map_file(raw: String) -> void:
	var name := _adopt_name(raw, _finish_map_file)
	if name != "":
		_finish_map_file(name)


func _finish_map_file(name: String) -> void:
	var doc: Dictionary = _pending_doc.duplicate(true)
	_pending_doc = {}
	var source := str(doc.get("file", ""))
	if source == "" or source == name:
		source = str(doc.get("base", ""))
	doc["file"] = name
	doc["source"] = "mod"
	doc["placed"] = true
	doc.erase("remove")
	doc.erase("base")
	var org: Variant = doc.get("origin", {})
	if source != "" and source != name and not (org is Dictionary and str((org as Dictionary).get("file", "")) != ""):
		doc["origin"] = {"file": source}
	_kind = "map"
	_file = name
	_doc.load_dict(doc)
	_doc.dirty = true
	_zlay = 0
	_placing = false
	_sync_place()
	_sync_kind_ui()
	_reload_rooms("" if _doc.rooms.is_empty() else str(_doc.rooms[0].get("name", "")))
	_note(Locale.tf("ed_imported", [_doc.rooms.size()]))


func _ask_new_room() -> void:
	_guard(func(): Dialogs.new_room(self, _on_room_choice, _new_room_file_problem))


func _new_room_file_problem(raw: String) -> String:
	var why := _map_name_problem(raw)
	if why != "":
		return why
	var name := _clean_stem(raw)
	if not Forms._room_chars(name):
		return Locale.t("ed_name_chars")
	return ""


func _on_room_choice(blank: bool, src: Dictionary, raw: String) -> void:
	_pending_blank = blank
	_pending_src = src
	var name := _adopt_name(raw, _finish_room_doc)
	if name != "":
		_finish_room_doc(name)


func _on_room_source(blank: bool, src: Dictionary) -> void:
	_pending_blank = blank
	_pending_src = src
	Dialogs.ask_text(self, Locale.t("ed_new_room"), Locale.t("ed_file_name"), Locale.t("ed_new_room"), _make_room_doc, "", _map_name_problem)


func _make_room_doc(raw: String) -> void:
	var name := _adopt_name(raw, _finish_room_doc)
	if name != "":
		_finish_room_doc(name)


func _finish_room_doc(name: String) -> void:
	var room: Dictionary
	var origin_file := ""
	var origin_name := ""
	if _pending_blank:
		room = {"name": name, "rows": _blank_rows(), "objs": []}
	else:
		room = _pending_src.duplicate(true)
		origin_file = str(room.get("_origin_file", ""))
		room.erase("_origin_file")
		origin_name = str(room.get("name", ""))
		if origin_name == "":
			room["name"] = name
			origin_name = name
	var rooms: Array = [room]
	var pair: Variant = room.get("_pair", {})
	room.erase("_pair")
	if pair is Dictionary and not (pair as Dictionary).is_empty():
		var extra: Dictionary = (pair as Dictionary).duplicate(true)
		extra.erase("_origin_file")
		extra.erase("_pair")
		rooms.append(extra)
	_pending_src = {}
	_kind = "room"
	_file = name
	_doc.load_dict({"file": name, "source": "mod", "placed": false, "rooms": rooms})
	if origin_file != "":
		_doc.origin = {"file": origin_file, "name": origin_name}
		_doc.land_defaults = RoomDoc.inherited_options(_doc.file, _doc.land_probe())
	_doc.dirty = true
	_zlay = int(room.get("z", 0))
	_placing = false
	_sync_place()
	_sync_kind_ui()
	_reload_rooms(str(room.get("name", "")))
	_note(Locale.t("ed_created"))


func _adopt_name(raw: String, then: Callable, allow := "") -> String:
	var name := _clean_stem(raw)
	if name == "":
		_note(Locale.t("ed_name_bad"))
		return ""
	var why := _map_name_problem(name)
	if why != "":
		_note(why)
		return ""
	if name != allow and RoomFile.file_names().has(name):
		_confirm(Locale.t("ed_name_exists"), Locale.t("ed_replace"), then.bind(name))
		return ""
	return name


func _start_add(at: Vector2i = Vector2i(-99999, -99999)) -> void:
	if _kind == "room":
		return
	if _file == "" and _doc.rooms.is_empty():
		_note(Locale.t("ed_no_file"))
		return
	_place_at = at
	Dialogs.pick_room(self, Locale.t("ed_add_room"), _on_add_room)


func _on_add_room(blank: bool, src: Dictionary) -> void:
	src.erase("_origin_file")
	var at := _place_at
	_place_at = Vector2i(-99999, -99999)
	if at.x != -99999:
		_add_room(blank, src, at)
		return
	if not _doc.placed:
		_add_room(blank, src, Vector2i.ZERO)
		return
	_place_blank = blank
	_place_src = src
	_placing = true
	_note(Locale.t("ed_pick_cell"))
	_sync_place()


func _cancel_place() -> void:
	_placing = false
	_place_src = {}
	_sync_place()


func _sync_place() -> void:
	if _place_cancel:
		_place_cancel.visible = _placing
	if _minimap:
		_minimap.queue_redraw()


func _add_room(blank: bool, src: Dictionary, at: Vector2i) -> void:
	_doc.snapshot()
	var made: Dictionary
	if blank:
		var nm := "room_%d_%d" % [at.x, at.y]
		if _doc.placed and _zlay > 0:
			nm = "%s_%d" % [nm, _zlay]
		if not _doc.placed:
			nm = _unique_room("room")
		made = {"name": _unique_room(nm), "rows": _blank_rows(), "objs": []}
	else:
		made = src.duplicate(true)
		made["name"] = _unique_room(str(made.get("name", "room")))
	if _doc.placed:
		made["x"] = at.x
		made["y"] = at.y
		if _zlay > 0:
			made["z"] = _zlay
		else:
			made.erase("z")
	else:
		made.erase("x")
		made.erase("y")
		made.erase("z")
	_doc.rooms.append(made)
	_doc.dirty = true
	_placing = false
	_place_src = {}
	_sync_place()
	_reload_rooms(str(made["name"]))
	_note(Locale.t("ed_created"))


func _unique_room(base: String) -> String:
	var used := {}
	for room_v in _doc.rooms:
		used[str(room_v.get("name", ""))] = true
	var name := base if base != "" else "room"
	if not used.has(name):
		return name
	var n := 2
	while used.has("%s_%d" % [name, n]):
		n += 1
	return "%s_%d" % [name, n]


func _blank_rows() -> Array:
	var parts: PackedStringArray = PackedStringArray()
	parts.resize(Codec.COLS)
	parts.fill("_")
	var row := ".".join(parts)
	var rows: Array = []
	for _y in Codec.ROWS:
		rows.append(row)
	return rows


func _cell_taken(at: Vector2i) -> bool:
	for room_v in _doc.rooms:
		if int(room_v.get("z", 0)) != _zlay:
			continue
		if int(room_v.get("x", -99999)) == at.x and int(room_v.get("y", -99999)) == at.y:
			return true
	return false


func _minimap_doc() -> Dictionary:
	if _kind != "room":
		return {"file": _doc.file, "source": _doc.source, "placed": _doc.placed, "rooms": _doc.rooms}
	var rooms: Array = []
	for room_v in _doc.rooms:
		if typeof(room_v) != TYPE_DICTIONARY:
			continue
		var copy: Dictionary = (room_v as Dictionary).duplicate(true)
		if not copy.has("x"):
			copy["x"] = 0
		if not copy.has("y"):
			copy["y"] = 0
		rooms.append(copy)
	return {"file": _doc.file, "source": "mod", "placed": true, "rooms": rooms}


func _drag_cells() -> Array:
	var cells: Array = []
	if _eraser or _is_object_layer() or _layer == "backdrop":
		return _rect_cells()
	var diag := str(_brush.get("diag", ""))
	var stair := str(_brush.get("stair", ""))
	if diag != "" and diag != "_" and Palette.diag_kind(diag) == "beam":
		for x in range(mini(_drag0.x, _drag1.x), maxi(_drag0.x, _drag1.x) + 1):
			cells.append(Vector2i(x, _drag0.y))
		return cells
	if diag != "" and diag != "_":
		var dx := _drag1.x - _drag0.x
		var dy := _drag1.y - _drag0.y
		var sx := 0
		var sy := 0
		if dx != 0 and dy != 0:
			sx = 1 if dx > 0 else -1
			sy = 1 if dy > 0 else -1
		elif dx != 0:
			sx = 1 if dx > 0 else -1
			sy = sx
		elif dy != 0:
			sy = 1 if dy > 0 else -1
			sx = sy
		var n := maxi(absi(dx), absi(dy))
		for i in n + 1:
			cells.append(Vector2i(_drag0.x + sx * i, _drag0.y + sy * i))
		return cells
	if stair != "" and stair != "_":
		for y in range(mini(_drag0.y, _drag1.y), maxi(_drag0.y, _drag1.y) + 1):
			cells.append(Vector2i(_drag0.x, y))
		return cells
	return _rect_cells()


func _rect_cells() -> Array:
	var cells: Array = []
	var x0 := mini(_drag0.x, _drag1.x)
	var y0 := mini(_drag0.y, _drag1.y)
	var x1 := maxi(_drag0.x, _drag1.x)
	var y1 := maxi(_drag0.y, _drag1.y)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if _outline and x != x0 and x != x1 and y != y0 and y != y1:
				continue
			cells.append(Vector2i(x, y))
	return cells


func _mm_rect() -> Rect2:
	return Rect2(Vector2.ZERO, _minimap.size)


func _mm_cell(pos: Vector2) -> Vector2i:
	return _view.minimap_cell_at(_minimap_doc(), _mm_rect(), pos, _mm_zoom, _mm_pan)


func _room_on_storey(at: Vector2i) -> String:
	for room_v in _doc.rooms:
		if int(room_v.get("x", -99999)) != at.x or int(room_v.get("y", -99999)) != at.y:
			continue
		if int(room_v.get("z", 0)) == _zlay:
			return str(room_v.get("name", ""))
	return ""


func _storey_taken(at: Vector2i, except_name: String) -> bool:
	var name := _room_on_storey(at)
	return name != "" and name != except_name


func _mm_zoom_at(at: Vector2, factor: float) -> void:
	var rect := _mm_rect()
	var doc := _minimap_doc()
	var before: Dictionary = _view._mm_geom(doc, rect, _mm_zoom, _mm_pan)
	var old := _mm_zoom
	_mm_zoom = clampf(_mm_zoom * factor, 0.35, 8.0)
	if not bool(before.get("ok", false)) or old <= 0.0:
		_minimap.queue_redraw()
		return
	var origin: Vector2 = before.origin
	var cell: float = before.cell
	var frac := (at - origin) / cell
	var fit: float = before.fit
	var span := Vector2(before.max - before.min)
	var center := rect.position + span * fit * 0.5
	var ncell := fit * _mm_zoom
	var desired := at - frac * ncell
	_mm_pan = desired - center + span * ncell * 0.5
	_minimap.queue_redraw()


func _mm_reset() -> void:
	_mm_zoom = 1.0
	_mm_pan = Vector2.ZERO
	if _minimap:
		_minimap.queue_redraw()


func _draw_minimap() -> void:
	var doc := _minimap_doc()
	var sel := Vector2i(-1, -1)
	var room: Dictionary = _doc.room()
	if int(room.get("z", 0)) == _zlay and room.has("x") and room.has("y"):
		sel = Vector2i(int(room.x), int(room.y))
	var rect := _mm_rect()
	_view.paint_minimap(_minimap, doc, rect, sel, _placing, _mm_zoom, _mm_pan)
	if _mm_drag_name == "":
		return
	var ghost: Rect2 = _view.minimap_cell_rect(doc, rect, _mm_drag_to, _mm_zoom, _mm_pan)
	var blocked := _storey_taken(_mm_drag_to, _mm_drag_name)
	var col := Color(0.95, 0.35, 0.3, 0.85) if blocked else Color(0.4, 1.0, 0.7, 0.9)
	_minimap.draw_rect(ghost, Color(col.r, col.g, col.b, 0.35))
	_minimap.draw_rect(ghost, col, false, 2.0)


func _minimap_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _mm_pan_on:
			_mm_pan = _mm_pan_at + motion.position - _mm_from
			_minimap.queue_redraw()
			return
		if _mm_press and not _mm_moved and motion.position.distance_to(_mm_from) >= 4.0:
			_mm_moved = true
			var from := _mm_cell(_mm_from)
			var dragged := ""
			if _kind != "room" and _doc.placed and not _placing:
				dragged = _room_on_storey(from)
			if dragged != "":
				_mm_drag_name = dragged
				_mm_drag_from = from
				_mm_drag_to = from
			else:
				_mm_pan_on = true
				_mm_pan_at = _mm_pan
		if _mm_drag_name != "":
			var at := _mm_cell(motion.position)
			if at.x > -1000:
				_mm_drag_to = at
			_minimap.queue_redraw()
			return
		var hover := _mm_cell(motion.position)
		_minimap.tooltip_text = _room_tip(hover)
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
		_mm_zoom_at(mb.position, 1.25)
		_minimap.accept_event()
		return
	if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
		_mm_zoom_at(mb.position, 1.0 / 1.25)
		_minimap.accept_event()
		return
	if mb.button_index == MOUSE_BUTTON_MIDDLE:
		_mm_pan_on = mb.pressed
		_mm_from = mb.position
		_mm_pan_at = _mm_pan
		_minimap.accept_event()
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_mm_press = true
		_mm_from = mb.position
		_mm_moved = false
		_mm_pan_at = _mm_pan
		return
	var dragged_name := _mm_drag_name
	var dragged_to := _mm_drag_to
	var dragged_from := _mm_drag_from
	var moved := _mm_moved
	_mm_press = false
	_mm_pan_on = false
	_mm_drag_name = ""
	if dragged_name != "":
		_drop_mm_room(dragged_name, dragged_from, dragged_to)
		return
	if moved:
		_minimap.queue_redraw()
		return
	_minimap_click(_mm_cell(mb.position))


func _drop_mm_room(name: String, from: Vector2i, to: Vector2i) -> void:
	if to == from or to.x < -1000:
		_minimap.queue_redraw()
		return
	if _storey_taken(to, name):
		_note(Locale.t("ed_not_free"))
		_minimap.queue_redraw()
		return
	_doc.snapshot()
	for room_v in _doc.rooms:
		if str(room_v.get("name", "")) != name:
			continue
		room_v["x"] = to.x
		room_v["y"] = to.y
		break
	_doc.dirty = true
	_minimap.queue_redraw()
	_redraw()


func _minimap_click(at: Vector2i) -> void:
	if at.x < -1000:
		return
	if _kind == "room":
		_pick_minimap(at)
		return
	if not _doc.placed:
		_note(Locale.t("ed_not_map"))
		return
	if _placing:
		if _cell_taken(at):
			_note(Locale.t("ed_not_free"))
			return
		_add_room(_place_blank, _place_src, at)
		return
	var on_z := ""
	var other := ""
	for room_v in _doc.rooms:
		if int(room_v.get("x", -99999)) != at.x or int(room_v.get("y", -99999)) != at.y:
			continue
		if int(room_v.get("z", 0)) == _zlay:
			on_z = str(room_v.get("name", ""))
		elif other == "":
			other = str(room_v.get("name", ""))
	if on_z != "":
		_reload_rooms(on_z)
	elif other != "":
		_reload_rooms(other)
	else:
		_start_add(at)


func _room_tip(at: Vector2i) -> String:
	if at.x < -1000:
		return ""
	var names: PackedStringArray = PackedStringArray()
	for room_v in _doc.rooms:
		var x := int(room_v.get("x", 0)) if room_v.has("x") else 0
		var y := int(room_v.get("y", 0)) if room_v.has("y") else 0
		if _kind != "room" and (not room_v.has("x") or not room_v.has("y")):
			continue
		if x == at.x and y == at.y:
			names.append(str(room_v.get("name", "")))
	return "\n".join(names)


func _pick_minimap(at: Vector2i) -> void:
	for room_v in _doc.rooms:
		if typeof(room_v) != TYPE_DICTIONARY:
			continue
		var x := int(room_v.get("x", 0)) if room_v.has("x") else 0
		var y := int(room_v.get("y", 0)) if room_v.has("y") else 0
		if x == at.x and y == at.y:
			_reload_rooms(str(room_v.get("name", "")))
			return


func _run_checks() -> void:
	_doc.commit()
	var items: Array = Check.run(_doc.to_dict())
	if items.is_empty():
		_note("ok")
		print("ok")
		return
	var lines := Check.lines(items)
	_note(" | ".join(lines).substr(0, 240))
	print("\n".join(lines))


func _gate(run: bool, then: Callable) -> void:
	_doc.commit()
	var items: Array = Check.run(_doc.to_dict())
	if items.is_empty():
		then.call()
		return
	_show_issues(items, run, then)


func _show_issues(items: Array, run: bool, then: Callable) -> void:
	var w := Window.new()
	w.theme = Forms.editor_theme()
	w.title = Locale.t("ed_check")
	w.exclusive = true
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 8
	box.offset_top = 8
	box.offset_right = -8
	box.offset_bottom = -8
	w.add_child(box)
	var list := ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.custom_minimum_size = Vector2(520, 280)
	for item_v in items:
		list.add_item(str((item_v as Dictionary).get("text", "")))
	list.item_selected.connect(func(i: int) -> void:
		if i >= 0 and i < items.size() and items[i] is Dictionary:
			_focus_issue(items[i])
	)
	box.add_child(list)
	var row := HBoxContainer.new()
	box.add_child(row)
	var go := Button.new()
	go.text = Locale.t("ed_run_anyway" if run else "ed_save_anyway")
	var cancel := Button.new()
	cancel.text = Locale.t("ed_cancel")
	go.pressed.connect(func() -> void:
		w.queue_free()
		then.call()
	)
	cancel.pressed.connect(w.queue_free)
	row.add_child(go)
	row.add_child(cancel)
	add_child(w)
	w.close_requested.connect(w.queue_free)
	w.popup_centered(Vector2i(560, 400))


func _focus_issue(item: Dictionary) -> void:
	var room := str(item.get("room", ""))
	if room != "":
		_reload_rooms(room)
	if item.has("obj_index"):
		_sel_obj = int(item.get("obj_index", -1))
		var objs: Array = _doc.room().get("objs", [])
		if _sel_obj >= 0 and _sel_obj < objs.size():
			_activate_layer(_obj_layer(objs[_sel_obj]))
	_redraw()


func _test_fon() -> String:
	return Settings.test_fon() if _kind == "room" else ""


func _save(ask := true) -> bool:
	_gate(false, func() -> void: _commit_save(ask))
	return false


func _commit_save(ask := true) -> bool:
	if _file == "":
		_note(Locale.t("ed_no_file"))
		return false
	if _kind == "room":
		var origin: Dictionary = _doc.origin
		var same := str(origin.get("file", "")) != "" and str(origin.get("name", "")) == str(_doc.room().get("name", ""))
		if ask and same:
			_confirm(Locale.tf("ed_replace_src", [str(origin.get("file", ""))]), Locale.t("ed_replace"), _save_into_origin)
			return false
		var why := _map_name_problem(_file)
		if why != "":
			_note(why)
			return false
		_doc.placed = false
		_doc.source = "mod"
	var err := RoomFile.save_doc(_file, _doc_body(), true)
	if err == "":
		_doc.dirty = false
		_autosave = 0.0
		_drop_autosave(_file)
		_note(Locale.t("ed_saved"))
		return true
	_note(err)
	return false


func _doc_body() -> Dictionary:
	var body: Dictionary = _doc.to_dict()
	if _kind != "room":
		return body
	var rooms: Array = []
	for room_v in _doc.rooms:
		if typeof(room_v) != TYPE_DICTIONARY:
			continue
		var copy: Dictionary = (room_v as Dictionary).duplicate(true)
		copy.erase("_pair")
		copy.erase("_origin_file")
		rooms.append(copy)
	body["file"] = _file
	body["source"] = "mod"
	body["placed"] = false
	body["rooms"] = rooms
	return body


func _autosave_path(file_name := "") -> String:
	var stem := file_name if file_name != "" else _file
	return RoomFile.mods_dir().path_join("_autosave").path_join(stem + ".json")


func _write_autosave() -> void:
	if _file == "" or not _doc.dirty:
		return
	var path := _autosave_path()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_doc_body()))
	f.close()
	_note(Locale.t("ed_autosaved"))


func _drop_autosave(file_name: String) -> void:
	if file_name == "":
		return
	var path := _autosave_path(file_name)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _offer_autosave() -> void:
	if _file == "" or _modal_open():
		return
	var path := _autosave_path()
	if not FileAccess.file_exists(path):
		return
	var auto_t := int(FileAccess.get_modified_time(path))
	var mod := RoomFile.mods_dir().path_join(_file + ".json")
	if FileAccess.file_exists(mod) and auto_t <= int(FileAccess.get_modified_time(mod)):
		return
	var when := Time.get_datetime_string_from_unix_time(auto_t, true)
	var dlg := ConfirmationDialog.new()
	dlg.theme = Forms.editor_theme()
	dlg.dialog_text = Locale.tf("ed_restore_ask", [when])
	dlg.ok_button_text = Locale.t("ed_restore")
	dlg.cancel_button_text = Locale.t("ed_discard")
	add_child(dlg)
	dlg.confirmed.connect(func() -> void:
		_restore_autosave(path)
		dlg.queue_free()
	)
	dlg.canceled.connect(func() -> void:
		_drop_autosave(_file)
		dlg.queue_free()
	)
	dlg.popup_centered(Vector2i(520, 180))


func _restore_autosave(path: String) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		_note(Locale.t("ed_import_bad"))
		return
	var doc: Dictionary = parsed
	var org: Variant = doc.get("origin", {})
	_doc.load_dict(doc)
	if org is Dictionary:
		_doc.origin = (org as Dictionary).duplicate(true)
	_doc.dirty = true
	_sync_kind_ui()
	_reload_rooms("" if _doc.rooms.is_empty() else str(_doc.rooms[0].get("name", "")))
	_note(Locale.t("ed_restored"))


func _save_into_origin() -> void:
	var origin: Dictionary = _doc.origin
	var file := str(origin.get("file", ""))
	var rname := str(origin.get("name", ""))
	if file == "" or rname == "":
		return
	_doc.commit()
	var doc := RoomFile.load_doc(file)
	var rooms: Array = doc.get("rooms", [])
	var by := {}
	for i in rooms.size():
		by[str(rooms[i].get("name", ""))] = i
	if not by.has(rname):
		_note(Locale.t("ed_no_file"))
		return
	var open_name := str(_doc.room().get("name", ""))
	for room_v in _doc.rooms:
		if typeof(room_v) != TYPE_DICTIONARY:
			continue
		var mine: Dictionary = (room_v as Dictionary).duplicate(true)
		mine.erase("_pair")
		mine.erase("_origin_file")
		var key := str(mine.get("name", ""))
		if key == open_name:
			key = rname
			mine["name"] = rname
		if by.has(key):
			var old: Dictionary = rooms[int(by[key])]
			if key == rname:
				mine["x"] = old.get("x", 0)
				mine["y"] = old.get("y", 0)
				mine["z"] = old.get("z", 0)
			else:
				for axis in ["x", "y", "z"]:
					if old.has(axis):
						mine[axis] = old[axis]
					else:
						mine.erase(axis)
			rooms[int(by[key])] = mine
		else:
			rooms.append(mine)
			by[str(mine.get("name", ""))] = rooms.size() - 1
	doc["rooms"] = rooms
	var err := RoomFile.save_doc(file, doc, true)
	if err == "":
		_doc.dirty = false
		_autosave = 0.0
		_drop_autosave(file)
		_drop_autosave(_file)
		_note(Locale.tf("ed_replaced", [file]))
		return
	_note(err)


func _save_as() -> void:
	if _doc.rooms.is_empty() and _file == "":
		_note(Locale.t("ed_no_file"))
		return
	_gate(false, func() -> void:
		Dialogs.ask_text(self, Locale.t("ed_save_as"), Locale.t("ed_file_name"), Locale.t("ed_save"), _save_as_named, _file, _map_name_problem)
	)


func _save_as_named(raw: String) -> void:
	var name := _adopt_name(raw, _write_as, _file)
	if name != "":
		_write_as(name)


func _write_as(name: String) -> void:
	_doc.file = name
	_doc.source = "mod"
	_file = name
	_commit_save(false)


func _clean_stem(raw: String) -> String:
	var s := raw.strip_edges()
	if s.get_extension().to_lower() == "json":
		s = s.get_basename()
	if s == "" or s.begins_with("_") or s.begins_with("."):
		return ""
	if s.contains("/") or s.contains("\\") or s.contains(":") or s.contains("."):
		return ""
	return s


func _export_as() -> void:
	if _doc.rooms.is_empty():
		_note(Locale.t("ed_no_file"))
		return
	var dlg := FileDialog.new()
	dlg.theme = Forms.editor_theme()
	dlg.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.title = Locale.t("ed_export_as")
	dlg.filters = PackedStringArray(["*.xml ; XML", "*.json ; JSON"])
	dlg.current_file = (_file if _file != "" else "rooms") + ".xml"
	add_child(dlg)
	dlg.file_selected.connect(func(path: String) -> void:
		_on_export(path)
		dlg.queue_free()
	)
	dlg.canceled.connect(dlg.queue_free)
	dlg.popup_centered(Vector2i(800, 500))


func _on_export(path: String) -> void:
	_doc.commit()
	var text := ""
	var as_json := path.get_extension().to_lower() == "json"
	if _kind == "room":
		var rooms: Array = (_doc_body().get("rooms", []) as Array).duplicate(true)
		if as_json:
			text = JSON.stringify({"file": _file, "source": "mod", "placed": false, "rooms": rooms}, "\t")
		else:
			text = Codec.xml_rooms(rooms)
	elif as_json:
		text = JSON.stringify(_doc.to_dict(), "\t")
	else:
		text = Codec.xml_from_doc(_doc.to_dict())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_note(Locale.t("ed_import_bad"))
		return
	f.store_string(text)
	f.close()
	_note(Locale.t("ed_exported"))


func _generate() -> void:
	if _file == "" and _doc.rooms.is_empty():
		_note(Locale.t("ed_no_file"))
		return
	_gate(true, _generate_now)


func _generate_now() -> void:
	_doc.commit()
	var room := str(_doc.room().get("name", ""))
	_save_view()
	EditorPreview.start(_doc.land_probe(), _file, room, _kind == "room", _doc.dirty, _kind, _test_fon(), _view_state())


func _play_land() -> void:
	if _kind == "room":
		return
	_gate(true, func() -> void: _boot_play(false))


func _play_room() -> void:
	_gate(true, func() -> void: _boot_play(true))


func _boot_play(one_room: bool) -> void:
	if _file == "" and _doc.rooms.is_empty():
		_note(Locale.t("ed_no_file"))
		return
	_doc.commit()
	var Play := load("res://scripts/editor/editor_play.gd")
	var one := one_room or _kind == "room"
	_save_view()
	Play.start(_file, str(_doc.room().get("name", "")), one, _doc.land_probe(), _doc.dirty, _kind, _test_fon() if one else "", _view_state())
	Travel.enter_game()


func _open_mods() -> void:
	var dir := ProjectSettings.globalize_path(RoomFile.mods_dir())
	DirAccess.make_dir_recursive_absolute(dir)
	OS.shell_open(dir)


func _leave() -> void:
	if _modal_open():
		return
	_guard(func(): get_tree().change_scene_to_file(load("res://scripts/editor/editor_play.gd").menu_dest()))


func _revert() -> void:
	if _file == "":
		_note(Locale.t("ed_no_file"))
		return
	if not RoomFile.has_mod(_file):
		_note(Locale.t("ed_no_mod"))
		return
	_confirm(Locale.tf("ed_revert_ask", [_file]), Locale.t("ed_revert"), _do_revert)


func _do_revert() -> void:
	var err := RoomFile.delete_mod(_file)
	if err != "":
		_note(err)
		return
	_doc.dirty = false
	_drop_autosave(_file)
	_load_file(_file)
	_note(Locale.t("ed_reverted"))


func _guard(then: Callable) -> void:
	if not _doc.dirty:
		then.call()
		return
	_ensure_ask()
	_after = then
	_ask.dialog_text = Locale.t("ed_unsaved")
	_ask.popup_centered(Vector2i(480, 160))


func _ensure_ask() -> void:
	if _ask != null:
		return
	_ask = ConfirmationDialog.new()
	_ask.theme = Forms.editor_theme()
	_ask.title = Locale.t("ed_unsaved_title")
	_ask.ok_button_text = Locale.t("ed_save")
	_ask.cancel_button_text = Locale.t("ed_cancel")
	_ask.add_button(Locale.t("ed_discard"), false, "discard")
	_ask.confirmed.connect(_on_ask_save)
	_ask.custom_action.connect(_on_ask_action)
	_ask.canceled.connect(func(): _after = Callable())
	add_child(_ask)


func _on_ask_save() -> void:
	var fn := _after
	_after = Callable()
	_gate(false, func() -> void:
		if _commit_save(true) and fn.is_valid():
			fn.call()
	)


func _on_ask_action(action: StringName) -> void:
	if str(action) != "discard":
		return
	var fn := _after
	_after = Callable()
	_drop_autosave(_file)
	_doc.dirty = false
	_ask.hide()
	if fn.is_valid():
		fn.call()


func _confirm(text: String, ok_text: String, then: Callable) -> void:
	var dlg := ConfirmationDialog.new()
	dlg.theme = Forms.editor_theme()
	dlg.dialog_text = text
	dlg.ok_button_text = ok_text
	dlg.cancel_button_text = Locale.t("ed_cancel")
	add_child(dlg)
	dlg.confirmed.connect(func():
		dlg.queue_free()
		then.call()
	)
	dlg.canceled.connect(dlg.queue_free)
	dlg.popup_centered(Vector2i(520, 180))


func _modal_open() -> bool:
	for c in get_children():
		if c is Window and (c as Window).visible:
			return true
	return false


func _sync_kind_ui() -> void:
	var room_doc := _kind == "room"
	if _plus:
		_plus.disabled = room_doc
	if _mode_btn:
		_mode_btn.disabled = room_doc
	if _test_menu:
		var i := _test_menu.get_item_index(ID_PLAY_MAP)
		if i >= 0:
			_test_menu.set_item_disabled(i, room_doc)
	if _opt_menu:
		var map_i := _opt_menu.get_item_index(ID_OPT_MAP)
		if map_i >= 0:
			_opt_menu.set_item_disabled(map_i, room_doc)
	_sync_mode_btns()
	_sync_storey_menu()
	_refresh_title()
	if _minimap:
		_minimap.queue_redraw()


func _doc_label() -> String:
	var kind := Locale.t("ed_kind_room" if _kind == "room" else "ed_kind_map")
	var name := _file if _file != "" else Locale.t("ed_untitled")
	if _kind != "room" and str(_doc.title) != "":
		name = "%s (%s)" % [_doc.title, name]
	return "%s — %s" % [kind, name]


func _refresh_title() -> void:
	var win := get_window()
	if win:
		win.title = _doc_label()


func _note(t: String) -> void:
	_refresh_title()
	if _status:
		_status.text = _doc_label() if t == "" else "%s  %s" % [_doc_label(), t]
