extends Control

## Standalone land viewer and room editor.
## Room files: res://assets/data/maps/rooms/<file>.json
## Esc leaves the room (saving it) and then returns to the main menu.

const RoomFile := preload("res://scripts/map/room_file.gd")
const LandGen := preload("res://scripts/map/land_gen.gd")
const Preview := preload("res://scripts/map/land_preview.gd")

const TILE := 40.0
const COLS := 48
const ROWS := 25
const PREFERRED := [
	"rooms_plant", "rooms_sewer", "rooms_stable", "rooms_mane", "rooms_canter",
	"rooms_mbase", "rooms_encl", "rooms_pi", "rooms_begin",
]

var _file := ""
var _build: Dictionary = {}
var _mode := "land"
var _edit: Dictionary = {}
var _mask: Array = []
var _explicit := false
var _doors_touched := false
var _dirty := false
var _esc_leave := false
var _cursor := Vector2i.ZERO
var _slot := 0
var _from_cell := false
var _at := Vector2i.ZERO
var _cell_mirror := false
var _lock := false
var _stick_wait := 0.0
var _hit_origin := Vector2.ZERO
var _hit_scale := 0.0
var _hit_min := Vector2i.ZERO
var _hit_ok := false
var _room_origin := Vector2.ZERO
var _room_scale := 0.0

var _land_root: Control
var _edit_root: Control
var _status: Label
var _edit_status: Label
var _files: ItemList
var _lands: OptionButton
var _templates: ItemList
var _rebuild: Button
var _land: Control
var _room: Control
var _preview: Control
var _code: LineEdit
var _loot_btn: Button
var _up_btn: Button
var _slot_buttons: Array = []


func _ready() -> void:
	GameState.set_paused(false)
	_build_ui()
	_fill_files()


func _process(delta: float) -> void:
	if _mode != "edit" or _typing():
		_stick_wait = 0.0
		return
	var axis_x := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var axis_y := Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	var dx := 0
	var dy := 0
	if absf(axis_x) > 0.5:
		dx = 1 if axis_x > 0.0 else -1
	if absf(axis_y) > 0.5:
		dy = 1 if axis_y > 0.0 else -1
	if dx == 0 and dy == 0:
		_stick_wait = 0.0
		return
	_stick_wait -= delta
	if _stick_wait > 0.0:
		return
	_stick_wait = 0.14
	_move_cursor(dx, dy)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if _preview != null and _preview.visible:
		if _cancel(event):
			_close_preview()
			get_viewport().set_input_as_handled()
		return
	if _cancel(event):
		_back()
		get_viewport().set_input_as_handled()
		return
	if _mode != "edit" or _typing() or not (event is InputEventKey) or not event.pressed:
		return
	var key := event as InputEventKey
	var dx := 0
	var dy := 0
	match key.keycode:
		KEY_LEFT:
			dx = -1
		KEY_RIGHT:
			dx = 1
		KEY_UP:
			dy = -1
		KEY_DOWN:
			dy = 1
		KEY_BRACKETLEFT:
			_select_slot(wrapi(_slot - 1, 0, 22))
		KEY_BRACKETRIGHT:
			_select_slot(wrapi(_slot + 1, 0, 22))
		KEY_MINUS, KEY_KP_SUBTRACT:
			_nudge_door(-1)
		KEY_EQUAL, KEY_KP_ADD:
			_nudge_door(1)
		_:
			return
	if dx != 0 or dy != 0:
		_move_cursor(dx, dy)
	get_viewport().set_input_as_handled()


func paint_land(canvas: Control) -> void:
	var vp := canvas.size
	canvas.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.03, 0.035, 0.04, 1.0))
	var cells: Dictionary = _build.get("cells", {})
	if bool(_build.get("templates_only", false)) or cells.is_empty():
		_hit_ok = false
		_draw_text(canvas, Vector2(24.0, 40.0), "Pick a room from the list.", 16, Color(0.9, 0.86, 0.7))
		return
	var min_x := int(_build.get("min_x", 0))
	var min_y := int(_build.get("min_y", 0))
	var span_x := maxi(int(_build.get("max_x", 1)) - min_x, 1)
	var span_y := maxi(int(_build.get("max_y", 1)) - min_y, 1)
	var room_px := Vector2(COLS * TILE, ROWS * TILE)
	var map := Vector2(float(span_x) * room_px.x, float(span_y) * room_px.y)
	var pad := Vector2(16.0, 16.0)
	var scale := minf((vp.x - pad.x * 2.0) / map.x, (vp.y - pad.y * 2.0) / map.y)
	if scale <= 0.0:
		return
	var origin := (Vector2(vp.x, vp.y) - map * scale) * 0.5
	_hit_origin = origin
	_hit_scale = scale
	_hit_min = Vector2i(min_x, min_y)
	_hit_ok = true
	var font := ThemeDB.fallback_font
	for key in cells.keys():
		var cell: Dictionary = cells[key]
		var rect := Rect2(
			origin + Vector2(float(int(cell.x) - min_x) * room_px.x, float(int(cell.y) - min_y) * room_px.y) * scale,
			room_px * scale
		)
		canvas.draw_rect(rect, Color(0.12, 0.24, 0.22, 1.0))
		var water := int(cell.get("water", 100))
		if water < ROWS:
			var band_y := maxi(water, 0)
			var top := band_y * TILE * scale
			canvas.draw_rect(Rect2(rect.position + Vector2(0.0, top), Vector2(rect.size.x, maxf(0.0, rect.size.y - top))), Color(0.1, 0.35, 0.7, 0.35))
		canvas.draw_rect(rect, Color(0.55, 0.82, 0.68, 0.95), false, 2.0)
		if font == null or rect.size.y < 18.0:
			continue
		var text := "(%d,%d)" % [int(cell.x), int(cell.y)]
		var font_size := clampi(int(rect.size.y * 0.18), 10, 22)
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var top_left := rect.position + (rect.size - text_size) * 0.5
		canvas.draw_string(font, top_left + Vector2(0.0, font.get_ascent(font_size)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.92, 0.96, 0.9))
	for link_v in _build.get("passes", []):
		_draw_pass(canvas, origin, scale, link_v, min_x, min_y)


func paint_room(canvas: Control) -> void:
	var vp := canvas.size
	canvas.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.05, 0.05, 0.06, 1.0))
	var map := Vector2(COLS * TILE, ROWS * TILE)
	var scale := minf((vp.x - 12.0) / map.x, (vp.y - 12.0) / map.y)
	if scale <= 0.0:
		return
	var origin := (Vector2(vp.x, vp.y) - map * scale) * 0.5
	_room_origin = origin
	_room_scale = scale
	var tile := TILE * scale
	var rows: Array = _edit.get("rows", [])
	for y in ROWS:
		for x in COLS:
			var open := RoomFile.is_open_code(RoomFile.code_at(rows, x, y))
			var rect := Rect2(origin + Vector2(x, y) * tile, Vector2(tile, tile))
			canvas.draw_rect(rect, Color(0.16, 0.18, 0.2) if open else Color(0.45, 0.42, 0.36))
	for obj_v in _edit.get("objs", []):
		var obj: Dictionary = obj_v
		var kind := str(obj.get("kind", ""))
		if kind != "loot" and kind != "up":
			continue
		var sz := maxi(int(obj.get("size", 1)), 1)
		var rect := Rect2(origin + Vector2(int(obj.get("x", 0)), int(obj.get("y", 0))) * tile, Vector2(tile, tile) * float(sz))
		var color := Color(0.95, 0.78, 0.2, 0.9) if kind == "loot" else Color(0.9, 0.28, 0.22, 0.9)
		canvas.draw_rect(rect, color, false, 2.0)
	var cursor := Rect2(origin + Vector2(_cursor) * tile, Vector2(tile, tile))
	canvas.draw_rect(cursor, Color(1.0, 0.9, 0.3), false, 2.0)


func land_click(pos: Vector2) -> void:
	if not _hit_ok or _hit_scale <= 0.0:
		return
	var tile := (pos - _hit_origin) / (_hit_scale * TILE)
	var key := Vector2i(int(floor(tile.x / float(COLS))) + _hit_min.x, int(floor(tile.y / float(ROWS))) + _hit_min.y)
	var cells: Dictionary = _build.get("cells", {})
	if not cells.has(key):
		return
	_open_room(str(cells[key].get("name", "")), key, true)


func room_click(pos: Vector2, button: int) -> void:
	if _code != null and _code.has_focus():
		_code.release_focus()
	var tile := _tile_at(pos)
	if tile.x < 0:
		return
	_cursor = tile
	if button == MOUSE_BUTTON_RIGHT:
		_write_code(tile.x, tile.y, "")
	else:
		_write_code(tile.x, tile.y, "C")
	_refresh_markers()
	_refresh_edit_status()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.045, 0.05)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_land_root = VBoxContainer.new()
	_land_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_land_root)
	var bar := HBoxContainer.new()
	_land_root.add_child(bar)
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bar.add_child(_status)
	_rebuild = Button.new()
	_rebuild.text = "Rebuild"
	_rebuild.focus_mode = Control.FOCUS_NONE
	_rebuild.pressed.connect(_on_rebuild)
	bar.add_child(_rebuild)
	var final_result := Button.new()
	final_result.text = "Final result"
	final_result.focus_mode = Control.FOCUS_NONE
	final_result.pressed.connect(_on_final)
	bar.add_child(final_result)
	var menu := Button.new()
	menu.text = "Menu"
	menu.focus_mode = Control.FOCUS_NONE
	menu.pressed.connect(_back)
	bar.add_child(menu)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_land_root.add_child(body)
	_files = ItemList.new()
	_files.custom_minimum_size = Vector2(220, 0)
	_files.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_files.item_selected.connect(_on_file)
	body.add_child(_files)
	var land_view := _LandView.new()
	land_view.host = self
	_land = land_view
	body.add_child(land_view)
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(280, 0)
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(side)
	_lands = OptionButton.new()
	_lands.item_selected.connect(_on_land)
	side.add_child(_lands)
	_templates = ItemList.new()
	_templates.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_templates.item_clicked.connect(_on_template)
	side.add_child(_templates)

	_edit_root = HBoxContainer.new()
	_edit_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_edit_root.hide()
	add_child(_edit_root)
	var tools := VBoxContainer.new()
	tools.custom_minimum_size = Vector2(280, 0)
	_edit_root.add_child(tools)
	var back := Button.new()
	back.text = "Land"
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(_back)
	tools.add_child(back)
	var save := Button.new()
	save.text = "Save"
	save.focus_mode = Control.FOCUS_NONE
	save.pressed.connect(_save_room)
	tools.add_child(save)
	_edit_status = Label.new()
	_edit_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools.add_child(_edit_status)
	var paint_row := HBoxContainer.new()
	tools.add_child(paint_row)
	var solid := Button.new()
	solid.text = "Solid"
	solid.focus_mode = Control.FOCUS_NONE
	solid.pressed.connect(func() -> void: _write_code(_cursor.x, _cursor.y, "C"))
	paint_row.add_child(solid)
	var empty := Button.new()
	empty.text = "Empty"
	empty.focus_mode = Control.FOCUS_NONE
	empty.pressed.connect(func() -> void: _write_code(_cursor.x, _cursor.y, ""))
	paint_row.add_child(empty)
	_code = LineEdit.new()
	_code.placeholder_text = "Tile code, then Enter"
	_code.text_submitted.connect(_on_code_submitted)
	tools.add_child(_code)
	var mark_row := HBoxContainer.new()
	tools.add_child(mark_row)
	_loot_btn = Button.new()
	_loot_btn.text = "Place loot"
	_loot_btn.focus_mode = Control.FOCUS_NONE
	_loot_btn.pressed.connect(func() -> void: _toggle_marker("loot"))
	mark_row.add_child(_loot_btn)
	_up_btn = Button.new()
	_up_btn.text = "Place up"
	_up_btn.focus_mode = Control.FOCUS_NONE
	_up_btn.pressed.connect(func() -> void: _toggle_marker("up"))
	mark_row.add_child(_up_btn)
	var help := Label.new()
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.text = "Arrows or the left stick move the cursor. Click paints solid, right click clears. [ ] chooses a door slot, - and = change its number. Gold means the paired neighbor slot also agrees. Esc saves and returns."
	tools.add_child(help)
	var width_row := HBoxContainer.new()
	tools.add_child(width_row)
	var narrower := Button.new()
	narrower.text = "Width -"
	narrower.focus_mode = Control.FOCUS_NONE
	narrower.pressed.connect(func() -> void: _nudge_door(-1))
	width_row.add_child(narrower)
	var wider := Button.new()
	wider.text = "Width +"
	wider.focus_mode = Control.FOCUS_NONE
	wider.pressed.connect(func() -> void: _nudge_door(1))
	width_row.add_child(wider)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tools.add_child(scroll)
	var slots := VBoxContainer.new()
	slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(slots)
	for i in 22:
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_select_slot.bind(i))
		slots.add_child(btn)
		_slot_buttons.append(btn)
	var room_view := _RoomView.new()
	room_view.host = self
	room_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_room = room_view
	_edit_root.add_child(room_view)

	_preview = Preview.new()
	add_child(_preview)


func _fill_files() -> void:
	var names := _ordered_files()
	if names.is_empty():
		_status.text = "No room files in res://assets/data/maps/rooms"
		return
	var pick := 0
	for i in names.size():
		var name := str(names[i])
		var kind := "hand"
		if name == "rooms_prob":
			kind = "trials"
		elif not LandGen.lands_using(name).is_empty():
			kind = "gen"
		var idx := _files.add_item("%s  %s" % [kind, name])
		_files.set_item_metadata(idx, name)
		if name == "rooms_plant":
			pick = i
	_lock = true
	_files.select(pick)
	_lock = false
	_file = str(names[pick])
	_activate_file()


func _ordered_files() -> Array:
	var names: Array = RoomFile.file_names()
	var out: Array = []
	for preferred in PREFERRED:
		if preferred in names:
			out.append(preferred)
	var rest: Array = []
	for name in names:
		if name not in out and str(name) != "rooms_prob":
			rest.append(str(name))
	rest.sort()
	out.append_array(rest)
	if "rooms_prob" in names:
		out.append("rooms_prob")
	return out


func _activate_file() -> void:
	var ids: Array = LandGen.lands_using(_file)
	_lock = true
	_lands.clear()
	for land_id in ids:
		_lands.add_item(str(land_id))
	if not ids.is_empty():
		_lands.select(0)
	_lands.visible = ids.size() > 1
	_rebuild.visible = not ids.is_empty()
	_lock = false
	_fill_templates()
	if ids.is_empty():
		_run_present()
	else:
		_run_generated(str(ids[0]))


func _fill_templates() -> void:
	_templates.clear()
	var doc := RoomFile.load_doc(_file)
	for room_v in doc.get("rooms", []):
		var room: Dictionary = room_v
		var idx := _templates.add_item(_room_label(room))
		_templates.set_item_metadata(idx, str(room.get("name", "")))


func _on_file(index: int) -> void:
	if _lock:
		return
	_file = str(_files.get_item_metadata(index))
	_activate_file()


func _on_land(index: int) -> void:
	if _lock:
		return
	_run_generated(_lands.get_item_text(index))


func _on_template(index: int, _at: Vector2, button: int) -> void:
	if button != MOUSE_BUTTON_LEFT:
		return
	_open_room(str(_templates.get_item_metadata(index)), Vector2i.ZERO, false)


func _on_rebuild() -> void:
	if _lands.item_count <= 0:
		return
	var selected := _lands.selected
	if selected < 0:
		selected = 0
	_run_generated(_lands.get_item_text(selected))


func _run_generated(land_id: String) -> void:
	_build = LandGen.build(land_id)
	_show_build()


func _run_present() -> void:
	_build = LandGen.present(_file)
	_show_build()


func _show_build() -> void:
	var err := str(_build.get("error", ""))
	if err != "":
		_status.text = err
		push_error(err)
		_land.queue_redraw()
		return
	var cells: Dictionary = _build.get("cells", {})
	var line := "%s  %sx%s  rooms %d  passages %d" % [
		str(_build.get("land_id", _file)),
		str(_build.get("width", 0)),
		str(_build.get("height", 0)),
		cells.size(),
		(_build.get("passes", []) as Array).size(),
	]
	if int(_build.get("catalog_my", 0)) > 0 and int(_build.get("height", 0)) != int(_build.catalog_my):
		line += "  catalog %sx%s" % [str(_build.catalog_mx), str(_build.catalog_my)]
	var note := str(_build.get("note", ""))
	if note != "":
		line += "  " + note
	if bool(_build.get("rnd", false)):
		line += "  xp %s" % str(_build.get("xp_total", 0))
	_status.text = line
	print("MapBuilder %s" % line)
	_land.queue_redraw()


func _open_room(room_name: String, at: Vector2i, from_cell: bool) -> void:
	var doc := RoomFile.load_doc(_file)
	var src: Dictionary = {}
	for room_v in doc.get("rooms", []):
		var room: Dictionary = room_v
		if str(room.get("name", "")) == room_name:
			src = room
			break
	if src.is_empty():
		_status.text = "Missing room %s" % room_name
		return
	_edit = src.duplicate(true)
	_from_cell = from_cell
	_at = at
	_cursor = Vector2i.ZERO
	_slot = 0
	_dirty = false
	_esc_leave = false
	_doors_touched = false
	_explicit = _edit.has("doors")
	_mask = RoomFile.editor_mask(_edit)
	_cell_mirror = false
	if from_cell:
		var cell: Dictionary = _build.get("cells", {}).get(at, {})
		_cell_mirror = bool(cell.get("mirror", false))
	_mode = "edit"
	_land_root.hide()
	_edit_root.show()
	_sync_code()
	_refresh_markers()
	_refresh_edit_status()
	_refresh_slots()
	_room.queue_redraw()


func _on_final() -> void:
	if _preview == null:
		return
	_preview.show_land(_build)
	_land_root.hide()
	_edit_root.hide()
	_preview.show()
	_mode = "preview"


func _close_preview() -> void:
	if _preview:
		_preview.hide()
	_mode = "land"
	_land_root.show()
	if _land:
		_land.queue_redraw()


func _back() -> void:
	if _mode == "preview":
		_close_preview()
		return
	if _mode == "edit":
		if _dirty and not _esc_leave:
			var err := _save_room()
			if err != "":
				_edit_status.text = err + "  Esc again leaves without saving."
				_esc_leave = true
				return
		_esc_leave = false
		_mode = "land"
		_edit_root.hide()
		_land_root.show()
		_land.queue_redraw()
		return
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _save_room() -> String:
	if _edit.is_empty():
		return "No room open."
	if _explicit or _doors_touched:
		var doors: Array = []
		for value in _mask:
			doors.append(int(value))
		_edit["doors"] = doors
	else:
		_edit.erase("doors")
	var err := RoomFile.save_room(_file, _edit)
	if err != "":
		return err
	_dirty = false
	_explicit = _edit.has("doors")
	if bool(_build.get("rnd", false)):
		_status.text = "Saved %s. Rebuild to restamp this generated land." % str(_edit.get("name", ""))
	else:
		_run_present()
		_status.text = "Saved %s." % str(_edit.get("name", ""))
	return ""


func _write_code(x: int, y: int, code: String) -> void:
	if _edit.is_empty():
		return
	if not _edit.has("rows") or not (_edit.rows is Array):
		_edit["rows"] = []
	var rows: Array = _edit.rows
	while rows.size() <= y:
		rows.append(".".repeat(COLS - 1))
	var parts := str(rows[y]).split(".")
	while parts.size() < COLS:
		parts.append("")
	if parts.size() > COLS:
		parts.resize(COLS)
	if str(parts[x]) == code:
		_sync_code()
		_room.queue_redraw()
		return
	parts[x] = code
	rows[y] = ".".join(parts)
	_dirty = true
	_esc_leave = false
	if not _explicit and not _doors_touched:
		_mask = RoomFile.doors_from_tiles(rows)
		_refresh_slots()
	_sync_code()
	_room.queue_redraw()


func _on_code_submitted(text: String) -> void:
	_write_code(_cursor.x, _cursor.y, text)


func _toggle_marker(kind: String) -> void:
	if not _edit.has("objs") or not (_edit.objs is Array):
		_edit["objs"] = []
	var objs: Array = _edit.objs
	var removed := false
	for i in range(objs.size() - 1, -1, -1):
		var obj: Dictionary = objs[i]
		if str(obj.get("kind", "")) == kind and int(obj.get("x", -1)) == _cursor.x and int(obj.get("y", -1)) == _cursor.y:
			objs.remove_at(i)
			removed = true
	if not removed:
		var id := "chest" if kind == "loot" else "enl2"
		objs.append({"tag": "obj", "id": id, "x": _cursor.x, "y": _cursor.y, "size": 2, "kind": kind})
	_dirty = true
	_esc_leave = false
	_refresh_markers()
	_refresh_edit_status()
	_room.queue_redraw()


func _move_cursor(dx: int, dy: int) -> void:
	_cursor.x = clampi(_cursor.x + dx, 0, COLS - 1)
	_cursor.y = clampi(_cursor.y + dy, 0, ROWS - 1)
	_sync_code()
	_refresh_markers()
	_room.queue_redraw()


func _select_slot(index: int) -> void:
	_slot = clampi(index, 0, 21)
	_refresh_slots()


func _nudge_door(delta: int) -> void:
	if _mask.is_empty():
		return
	_doors_touched = true
	_dirty = true
	_esc_leave = false
	_mask[_slot] = clampi(int(_mask[_slot]) + delta, 0, 9)
	_refresh_slots()


func _refresh_slots() -> void:
	var placed := RoomFile.mirror_mask(_mask) if _cell_mirror else _mask
	for i in _slot_buttons.size():
		var btn: Button = _slot_buttons[i]
		var opens := _agrees(placed, i)
		var state := "opens" if opens else "wall"
		btn.text = "%s  %d  %s" % [_slot_name(i), int(_mask[i]) if i < _mask.size() else 0, state]
		if i == _slot and opens:
			btn.modulate = Color(1.0, 0.92, 0.45)
		elif opens:
			btn.modulate = Color(0.95, 0.82, 0.35)
		elif i == _slot:
			btn.modulate = Color(1, 1, 1)
		else:
			btn.modulate = Color(0.72, 0.72, 0.72)


func _agrees(placed: Array, slot: int) -> bool:
	if not _from_cell or slot >= placed.size():
		return false
	var other := Vector2i.ZERO
	var their := 0
	if slot < 6:
		other = Vector2i(_at.x + 1, _at.y)
		their = slot + 11
	elif slot < 11:
		other = Vector2i(_at.x, _at.y + 1)
		their = slot + 11
	elif slot < 17:
		other = Vector2i(_at.x - 1, _at.y)
		their = slot - 11
	else:
		other = Vector2i(_at.x, _at.y - 1)
		their = slot - 11
	var cells: Dictionary = _build.get("cells", {})
	if not cells.has(other):
		return false
	var doors: Array = cells[other].get("doors", [])
	if their < 0 or their >= doors.size():
		return false
	return mini(int(placed[slot]), int(doors[their])) >= 2


func _refresh_markers() -> void:
	if _loot_btn == null:
		return
	_loot_btn.text = "Remove loot" if _marker_here("loot") else "Place loot"
	_up_btn.text = "Remove up" if _marker_here("up") else "Place up"


func _refresh_edit_status() -> void:
	var bits: PackedStringArray = PackedStringArray()
	bits.append(str(_edit.get("name", "")))
	if _cell_mirror:
		bits.append("mirrored in this build; the numbers are the source room")
	if _from_cell:
		var cell: Dictionary = _build.get("cells", {}).get(_at, {})
		bits.append("enemy %s on %s up" % [str(cell.get("enemy_type", "-")), str(cell.get("ups", 0))])
		bits.append("xp %d" % (cell.get("xp", []) as Array).size())
		bits.append("water %s" % str(cell.get("water", 100)))
		var back := str(cell.get("back", ""))
		if back != "":
			bits.append("back %s" % back)
	_edit_status.text = "   ".join(bits)


func _sync_code() -> void:
	if _code == null or _edit.is_empty():
		return
	_code.text = RoomFile.code_at(_edit.get("rows", []), _cursor.x, _cursor.y)


func _marker_here(kind: String) -> bool:
	for obj_v in _edit.get("objs", []):
		var obj: Dictionary = obj_v
		if str(obj.get("kind", "")) == kind and int(obj.get("x", -1)) == _cursor.x and int(obj.get("y", -1)) == _cursor.y:
			return true
	return false


func _tile_at(pos: Vector2) -> Vector2i:
	if _room_scale <= 0.0:
		return Vector2i(-1, -1)
	var local := (pos - _room_origin) / (TILE * _room_scale)
	var x := int(floor(local.x))
	var y := int(floor(local.y))
	if x < 0 or y < 0 or x >= COLS or y >= ROWS:
		return Vector2i(-1, -1)
	return Vector2i(x, y)


func _room_label(room: Dictionary) -> String:
	var name := str(room.get("name", ""))
	var z := int(room.get("z", 0))
	if z != 0:
		return "%s  z%d" % [name, z]
	if room.has("x"):
		return "%s  (%s,%s)" % [name, str(room.get("x", 0)), str(room.get("y", 0))]
	var options: Dictionary = room.get("options", {})
	if options.has("tip") and str(options.tip) != "":
		return "%s  [%s]" % [name, str(options.tip)]
	return name


func _slot_name(index: int) -> String:
	if index < 6:
		return "R%d" % index
	if index < 11:
		return "D%d" % (index - 6)
	if index < 17:
		return "L%d" % (index - 11)
	return "U%d" % (index - 17)


func _typing() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	return focus is LineEdit


func _cancel(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel"):
		return true
	return event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE


func _draw_text(canvas: Control, at: Vector2, text: String, size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	canvas.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _draw_pass(canvas: Control, origin: Vector2, scale: float, link: Dictionary, min_x: int, min_y: int) -> void:
	var thick := 7.0
	var color := Color(1.0, 0.86, 0.15, 1.0)
	var ox := float(min_x * COLS)
	var oy := float(min_y * ROWS)
	if bool(link.get("vertical", false)):
		var top := origin + Vector2((float(link.edge) - ox) * TILE, (float(link.start) - oy) * TILE) * scale
		var height := float(int(link.end) - int(link.start)) * TILE * scale
		canvas.draw_rect(Rect2(top.x - thick * 0.5, top.y, thick, height), color)
	else:
		var left := origin + Vector2((float(link.start) - ox) * TILE, (float(link.edge) - oy) * TILE) * scale
		var width := float(int(link.end) - int(link.start)) * TILE * scale
		canvas.draw_rect(Rect2(left.x, left.y - thick * 0.5, width, thick), color)


class _LandView extends Control:
	var host

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		resized.connect(queue_redraw)

	func _draw() -> void:
		if host:
			host.paint_land(self)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var button := event as InputEventMouseButton
			if button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
				host.land_click(button.position)
				accept_event()


class _RoomView extends Control:
	var host

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		resized.connect(queue_redraw)

	func _draw() -> void:
		if host:
			host.paint_room(self)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var button := event as InputEventMouseButton
			if button.pressed and (button.button_index == MOUSE_BUTTON_LEFT or button.button_index == MOUSE_BUTTON_RIGHT):
				host.room_click(button.position, button.button_index)
				accept_event()
