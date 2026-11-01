extends RefCounted

## File and room dialogs for the room editor. Reads RoomFile; does not save.

const RoomFile := preload("res://scripts/map/room_file.gd")
const Check := preload("res://scripts/editor/editor_check.gd")
const ViewScr := preload("res://scripts/editor/editor_view.gd")
const Codec := preload("res://scripts/editor/room_codec.gd")
const Forms := preload("res://scripts/editor/editor_forms.gd")
const Groups := preload("res://scripts/editor/editor_groups.gd")


## check(text) returns "" when the text is usable, else the reason shown under the field.
static func ask_text(host: Node, title: String, placeholder: String, ok_text: String, then: Callable, initial := "", check := Callable()) -> void:
	var w := _window(host, title)
	var box := _column(w)
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.text = initial
	box.add_child(edit)
	var why := Label.new()
	why.modulate = Color(1.0, 0.55, 0.45)
	box.add_child(why)
	var row := HBoxContainer.new()
	box.add_child(row)
	var ok := _button(row, ok_text)
	var cancel := _button(row, Locale.t("ed_cancel"))
	var validate := func(text: String) -> void:
		var blank := text.strip_edges() == ""
		why.text = str(check.call(text)) if check.is_valid() and not blank else ""
		ok.disabled = why.text != "" or (blank and check.is_valid())
	validate.call(edit.text)
	edit.text_changed.connect(validate)
	var done := func() -> void:
		if ok.disabled:
			return
		var text := edit.text
		w.hide()
		w.queue_free()
		then.call(text)
	ok.pressed.connect(done)
	edit.text_submitted.connect(func(_t): done.call())
	cancel.pressed.connect(w.queue_free)
	w.popup_centered(Vector2i(440, 140))
	edit.grab_focus()


## on_done(action, data). action is empty, open, or import.
## name_problem(text) is "" when a new file name is usable.
static func new_map(host: Node, on_done: Callable, name_problem: Callable, open_existing := false) -> void:
	var w := _window(host, Locale.t("ed_new_map"))
	var built := _chooser(w, true)
	var files: ItemList = built.list
	_fill_map_choices(files)
	var refresh := func() -> void:
		_show_choice(w, _selected_meta(files), built, true)
		_sync_name(files, built.edit, built.why, built.ok, name_problem, true)
	files.item_selected.connect(func(_i): refresh.call())
	built.edit.text_changed.connect(func(_t): _sync_name(files, built.edit, built.why, built.ok, name_problem, true))
	built.map_c.gui_input.connect(func(event: InputEvent) -> void:
		if not _left_click(event):
			return
		var meta := _selected_meta(files)
		if str(meta.get("kind", "")) == "empty":
			return
		var cell: Vector2i = built.map_c.get_meta("view").minimap_cell_at(w.get_meta("doc", {}), Rect2(Vector2.ZERO, built.map_c.size), (event as InputEventMouseButton).position)
		var room := _room_at(w.get_meta("doc", {}), cell)
		if room.is_empty():
			return
		_show_room(w, room, built.name_l, built.map_c, built.room_c, "room", "sel")
	)
	built.browse.pressed.connect(func() -> void:
		_pick_path(w, func(path: String) -> void:
			var doc := _as_map(_doc_from_path(path))
			if (doc.get("rooms", []) as Array).is_empty():
				built.why.text = Locale.t("ed_import_bad")
				return
			var key := _store_import(w, doc)
			var n := files.add_item(path.get_file())
			files.set_item_metadata(n, {"kind": "import", "key": key})
			files.select(n)
			refresh.call()
		)
	)
	built.cancel.pressed.connect(w.queue_free)
	built.ok.pressed.connect(func() -> void:
		if built.ok.disabled:
			return
		var meta := _selected_meta(files)
		var kind := str(meta.get("kind", ""))
		if kind == "map":
			var room: Dictionary = w.get_meta("room", {})
			var file := str(meta.get("file", ""))
			var room_name := str(room.get("name", ""))
			_close(w)
			on_done.call("open", {"file": file, "room": room_name})
			return
		if kind == "import":
			var bag: Dictionary = w.get_meta("imports", {})
			var doc: Dictionary = bag.get(str(meta.get("key", "")), {})
			var imported_name := built.edit.text
			_close(w)
			on_done.call("import", {"name": imported_name, "doc": doc})
			return
		var empty_name := built.edit.text
		_close(w)
		on_done.call("empty", {"name": empty_name})
	)
	var pick := 1 if open_existing and files.item_count > 1 else 0
	if files.item_count > 0:
		files.select(pick)
	refresh.call()
	w.popup_centered(Vector2i(980, 600))


## on_done(blank, room, file_name). blank is an empty room.
static func new_room(host: Node, on_done: Callable, name_problem: Callable) -> void:
	var w := _window(host, Locale.t("ed_new_room"))
	var built := _chooser(w, true)
	var files: ItemList = built.list
	_fill_room_choices(files)
	var picker := OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	files.get_parent().add_child(picker)
	var take_index := func(i: int) -> void:
		var src: Dictionary = w.get_meta("src", {})
		var rooms: Array = src.get("rooms", [])
		var shown: Array = (w.get_meta("doc", {}) as Dictionary).get("rooms", [])
		if i < 0 or i >= rooms.size() or i >= shown.size():
			return
		var taken: Dictionary = (rooms[i] as Dictionary).duplicate(true)
		var origin := str(w.get_meta("origin", ""))
		if origin != "":
			taken["_origin_file"] = origin
		w.set_meta("take", taken)
		_show_room(w, shown[i], built.name_l, built.map_c, built.room_c, "room", "sel")
		for k in picker.item_count:
			if picker.get_item_id(k) == i:
				picker.select(k)
	var refresh := func() -> void:
		_show_file(w, _selected_meta(files), picker)
		built.map_c.queue_redraw()
		if picker.item_count > 0:
			take_index.call(picker.get_item_id(0))
		else:
			_show_room(w, {}, built.name_l, built.map_c, built.room_c, "room", "sel")
		_sync_name(files, built.edit, built.why, built.ok, name_problem, false)
		if picker.visible and picker.item_count == 0:
			built.ok.disabled = true
	files.item_selected.connect(func(_i): refresh.call())
	picker.item_selected.connect(func(k: int): take_index.call(picker.get_item_id(k)))
	built.edit.text_changed.connect(func(_t): _sync_name(files, built.edit, built.why, built.ok, name_problem, false))
	built.map_c.gui_input.connect(func(event: InputEvent) -> void:
		if not _left_click(event):
			return
		var shown: Dictionary = w.get_meta("doc", {})
		var cell: Vector2i = built.map_c.get_meta("view").minimap_cell_at(shown, Rect2(Vector2.ZERO, built.map_c.size), (event as InputEventMouseButton).position)
		var room := _room_at(shown, cell)
		if room.is_empty():
			return
		take_index.call((shown.get("rooms", []) as Array).find(room))
	)
	built.browse.pressed.connect(func() -> void:
		_pick_path(w, func(path: String) -> void:
			var doc := _doc_from_path(path)
			if (doc.get("rooms", []) as Array).is_empty():
				built.why.text = Locale.t("ed_import_bad")
				return
			var key := _store_import(w, doc)
			var n := files.add_item(path.get_file())
			files.set_item_metadata(n, {"kind": "import", "key": key})
			files.select(n)
			refresh.call()
		)
	)
	built.cancel.pressed.connect(w.queue_free)
	built.ok.pressed.connect(func() -> void:
		if built.ok.disabled:
			return
		var meta := _selected_meta(files)
		var kind := str(meta.get("kind", ""))
		var file_name := built.edit.text
		if kind == "empty":
			_close(w)
			on_done.call(true, {}, file_name)
			return
		var take: Dictionary = (w.get_meta("take", {}) as Dictionary).duplicate(true)
		if take.is_empty():
			return
		var src: Dictionary = w.get_meta("src", {})
		var pair := Check.partner(take, src.get("rooms", []))
		if not pair.is_empty():
			var copy: Dictionary = pair.duplicate(true)
			copy.erase("_origin_file")
			copy.erase("_pair")
			take["_pair"] = copy
		_close(w)
		on_done.call(false, take, file_name)
	)
	if files.item_count > 0:
		files.select(0)
	refresh.call()
	w.popup_centered(Vector2i(980, 600))


class Chooser extends RefCounted:
	var list: ItemList
	var edit: LineEdit
	var why: Label
	var ok: Button
	var cancel: Button
	var browse: Button
	var map_c: Control
	var room_c: Control
	var name_l: Label


static func _chooser(w: Window, with_map: bool) -> Chooser:
	var root := _column(w)
	var row := _split_row(root)
	var left := _side(row)
	var built := Chooser.new()
	built.browse = _button(left, Locale.t("ed_browse"))
	built.list = ItemList.new()
	built.list.custom_minimum_size = Vector2(220, 180)
	built.list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	built.list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(built.list)
	var side := _side(row)
	var tex := _tex_box(side)
	built.map_c = _canvas()
	built.room_c = _canvas()
	if with_map:
		side.add_child(built.map_c)
	side.add_child(built.room_c)
	built.name_l = _name_label(side)
	built.edit = LineEdit.new()
	built.edit.placeholder_text = Locale.t("ed_file_name")
	root.add_child(built.edit)
	built.why = _note_label(root)
	var buttons := _button_row(root)
	built.ok = _button(buttons, Locale.t("ed_new_map"))
	built.cancel = _button(buttons, Locale.t("ed_cancel"))
	w.set_meta("imports", {})
	w.set_meta("doc", {})
	w.set_meta("room", {})
	w.set_meta("take", {})
	w.set_meta("sel", Vector2i(-1, -1))
	_bind_map_draw(built.map_c, func() -> Dictionary: return w.get_meta("doc", {}), func() -> Vector2i: return w.get_meta("sel", Vector2i(-1, -1)))
	_bind_room_draw(built.room_c, tex, func() -> Dictionary: return w.get_meta("room", {}))
	tex.toggled.connect(func(_on): built.room_c.queue_redraw())
	return built


static func _store_import(w: Window, doc: Dictionary) -> String:
	var n := int(w.get_meta("import_n", 0))
	w.set_meta("import_n", n + 1)
	var key := "i%d" % n
	var bag: Dictionary = w.get_meta("imports", {})
	bag[key] = doc
	w.set_meta("imports", bag)
	return key


static func _selected_meta(list: ItemList) -> Dictionary:
	var sel := list.get_selected_items()
	if sel.is_empty():
		return {}
	var meta: Variant = list.get_item_metadata(sel[0])
	return meta if meta is Dictionary else {}


static func _fill_map_choices(list: ItemList) -> void:
	list.clear()
	var top := list.add_item(Locale.t("ed_empty_map"))
	list.set_item_metadata(top, {"kind": "empty"})
	var names: Array = []
	for name_v in RoomFile.file_names():
		var name := str(name_v)
		if name == "" or name.begins_with("_"):
			continue
		var doc := RoomFile.load_doc(name)
		if doc.is_empty() or not bool(doc.get("placed", false)):
			continue
		names.append(name)
	names.sort_custom(func(a, b): return Groups.natural_less(str(a), str(b)))
	for name in names:
		var n := list.add_item(str(name))
		list.set_item_metadata(n, {"kind": "map", "file": str(name)})


static func _fill_room_choices(list: ItemList) -> void:
	list.clear()
	var top := list.add_item(Locale.t("ed_empty_room"))
	list.set_item_metadata(top, {"kind": "empty"})
	var names: Array = []
	for name_v in RoomFile.file_names():
		var name := str(name_v)
		if name == "" or name.begins_with("_"):
			continue
		names.append(name)
	names.sort_custom(func(a, b): return Groups.natural_less(str(a), str(b)))
	for name in names:
		var n := list.add_item(str(name))
		list.set_item_metadata(n, {"kind": "file", "file": str(name)})


## Room chooser: src is the file as loaded, doc is the same rooms laid out for the
## minimap (unplaced rooms in a square grid), picker lists rooms by name.
static func _show_file(w: Window, meta: Dictionary, picker: OptionButton) -> void:
	picker.clear()
	w.set_meta("take", {})
	var kind := str(meta.get("kind", "empty"))
	var src: Dictionary = {}
	var origin := ""
	if kind == "file":
		origin = str(meta.get("file", ""))
		src = RoomFile.load_doc(origin)
	elif kind == "import":
		src = (w.get_meta("imports", {}) as Dictionary).get(str(meta.get("key", "")), {})
	w.set_meta("src", src)
	w.set_meta("origin", origin)
	w.set_meta("doc", _grid_preview(src))
	picker.visible = kind != "empty"
	var rooms: Array = src.get("rooms", [])
	var order: Array = []
	for i in rooms.size():
		if typeof(rooms[i]) == TYPE_DICTIONARY:
			order.append(i)
	order.sort_custom(func(a, b):
		return Groups.natural_less(str(rooms[a].get("name", "")), str(rooms[b].get("name", "")))
	)
	for i in order:
		picker.add_item(str(rooms[i].get("name", "")), int(i))


static func _grid_preview(doc: Dictionary) -> Dictionary:
	if doc.is_empty() or not (doc.get("rooms") is Array):
		return {}
	if bool(doc.get("placed", false)):
		return _as_map(doc)
	var copy: Dictionary = doc.duplicate(true)
	copy.erase("remove")
	copy.erase("base")
	copy["placed"] = true
	var rooms: Array = copy.get("rooms", [])
	var wide := maxi(1, ceili(sqrt(float(rooms.size()))))
	for i in rooms.size():
		if typeof(rooms[i]) != TYPE_DICTIONARY:
			continue
		rooms[i]["x"] = i % wide
		rooms[i]["y"] = int(i / wide)
		rooms[i]["z"] = 0
	return copy


static func _sync_name(list: ItemList, edit: LineEdit, why: Label, ok: Button, problem: Callable, map_mode: bool) -> void:
	var kind := str(_selected_meta(list).get("kind", ""))
	if map_mode and kind == "map":
		edit.editable = false
		var file := str(_selected_meta(list).get("file", ""))
		if edit.text != file:
			edit.text = file
		ok.text = Locale.t("ed_open_btn")
		ok.disabled = file == ""
		why.text = ""
		return
	if not edit.editable:
		edit.editable = true
		edit.text = ""
	edit.editable = true
	ok.text = Locale.t("ed_new_map") if map_mode else Locale.t("ed_new_room")
	var reason := str(problem.call(edit.text)) if problem.is_valid() else ""
	why.text = reason
	ok.disabled = reason != "" or edit.text.strip_edges() == ""


static func _show_choice(w: Window, meta: Dictionary, built: Chooser, map_mode: bool) -> void:
	var kind := str(meta.get("kind", "empty"))
	if kind == "empty":
		w.set_meta("doc", {})
		w.set_meta("room", {})
		w.set_meta("take", {})
		w.set_meta("sel", Vector2i(-1, -1))
		built.name_l.text = ""
		built.map_c.queue_redraw()
		built.room_c.queue_redraw()
		return
	var doc: Dictionary = {}
	var room: Dictionary = {}
	if kind == "map":
		doc = RoomFile.load_doc(str(meta.get("file", "")))
		room = _first_room(doc)
	elif kind == "room":
		doc = RoomFile.load_doc(str(meta.get("file", "")))
		var rooms: Array = doc.get("rooms", [])
		var idx := int(meta.get("index", -1))
		if idx >= 0 and idx < rooms.size():
			room = (rooms[idx] as Dictionary).duplicate(true)
			room["_origin_file"] = str(meta.get("file", ""))
		w.set_meta("take", room)
		w.set_meta("doc", doc)
	elif kind == "import":
		var bag: Dictionary = w.get_meta("imports", {})
		doc = bag.get(str(meta.get("key", "")), {})
		if not map_mode:
			var rooms: Array = doc.get("rooms", [])
			var idx := int(meta.get("index", 0))
			if idx >= 0 and idx < rooms.size():
				room = (rooms[idx] as Dictionary).duplicate(true)
			w.set_meta("take", room)
			w.set_meta("doc", _as_map(doc))
			doc = w.get_meta("doc", {})
		else:
			room = _first_room(doc)
	if kind == "map":
		w.set_meta("doc", doc)
		if room.is_empty():
			room = _first_room(doc)
	elif kind == "import" and map_mode:
		w.set_meta("doc", doc)
	_show_room(w, room, built.name_l, built.map_c, built.room_c, "room", "sel")


## on_done(blank, room). blank is an empty room; otherwise room is a deep copy.
static func pick_room(host: Node, title: String, on_done: Callable) -> void:
	var w := _window(host, title)
	var root := _column(w)
	var tabs := _tabs(root)
	var empty := _page(tabs, Locale.t("ed_empty_room"))
	var empty_note := _plain_label(Locale.t("ed_empty_room_note"))
	empty_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty.add_child(empty_note)
	var copy := _page(tabs, Locale.t("ed_copy_of"))
	_build_copy(copy, w)
	var from := _page(tabs, Locale.t("ed_from_file"))
	_build_room_file(from, w)
	var note := _note_label(root)
	var buttons := _button_row(root)
	var ok := _button(buttons, title)
	var cancel := _button(buttons, Locale.t("ed_cancel"))
	cancel.pressed.connect(w.queue_free)
	ok.pressed.connect(func() -> void:
		if tabs.current_tab == 0:
			_close(w)
			on_done.call(true, {})
			return
		var key := "file_room" if tabs.current_tab == 2 else "copy_room"
		var room: Dictionary = w.get_meta(key, {})
		if room.is_empty():
			note.text = Locale.t("ed_need_pick")
			return
		var taken: Dictionary = room.duplicate(true)
		if tabs.current_tab == 1:
			taken["_origin_file"] = str(w.get_meta("copy_file", ""))
		_close(w)
		on_done.call(false, taken)
	)
	w.popup_centered(Vector2i(980, 560))


static func _build_copy(page: VBoxContainer, w: Window) -> void:
	var row := _split_row(page)
	var files := _file_list(row)
	var rooms := _file_list(row)
	var side := _side(row)
	var tex := _tex_box(side)
	var room_c := _canvas()
	side.add_child(room_c)
	var name_l := _name_label(side)
	_sort_toggle(side, rooms, func() -> Dictionary: return w.get_meta("copy_doc", {}))
	w.set_meta("copy_doc", {})
	w.set_meta("copy_room", {})
	_bind_room_draw(room_c, tex, func() -> Dictionary: return w.get_meta("copy_room", {}))
	tex.toggled.connect(func(_on): room_c.queue_redraw())
	_fill_files(files, false)
	files.item_selected.connect(func(i: int) -> void:
		var stem := str(files.get_item_metadata(i))
		w.set_meta("copy_file", stem)
		var doc := RoomFile.load_doc(stem)
		w.set_meta("copy_doc", doc)
		_fill_rooms(rooms, doc)
		_select_first(rooms, doc, w, "copy_room", name_l, room_c)
	)
	rooms.item_selected.connect(func(i: int) -> void:
		_pick_listed(w.get_meta("copy_doc", {}), i, w, "copy_room", name_l, room_c, rooms)
	)


static func _build_room_file(page: VBoxContainer, w: Window) -> void:
	var bar := _button_row(page)
	var browse := _button(bar, Locale.t("ed_browse"))
	var path_l := _plain_label(Locale.t("ed_from_file_note"))
	path_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_l.clip_text = true
	path_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bar.add_child(path_l)
	var row := _split_row(page)
	var rooms := _file_list(row)
	var side := _side(row)
	var tex := _tex_box(side)
	var room_c := _canvas()
	side.add_child(room_c)
	var name_l := _name_label(side)
	_sort_toggle(side, rooms, func() -> Dictionary: return w.get_meta("file_doc", {}))
	w.set_meta("file_doc", {})
	w.set_meta("file_room", {})
	_bind_room_draw(room_c, tex, func() -> Dictionary: return w.get_meta("file_room", {}))
	tex.toggled.connect(func(_on): room_c.queue_redraw())
	rooms.item_selected.connect(func(i: int) -> void:
		_pick_listed(w.get_meta("file_doc", {}), i, w, "file_room", name_l, room_c, rooms)
	)
	browse.pressed.connect(func() -> void:
		_pick_path(w, func(path: String) -> void:
			var doc := _doc_from_path(path)
			var list: Array = doc.get("rooms", [])
			if list.is_empty():
				path_l.text = Locale.t("ed_import_bad")
				w.set_meta("file_doc", {})
				w.set_meta("file_room", {})
				_fill_rooms(rooms, {})
				room_c.queue_redraw()
				return
			w.set_meta("file_doc", doc)
			path_l.text = path.get_file()
			_fill_rooms(rooms, doc)
			_select_first(rooms, doc, w, "file_room", name_l, room_c)
		)
	)


static func _doc_from_path(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.strip_edges() == "":
		return {}
	if path.get_extension().to_lower() == "json":
		var data: Variant = JSON.parse_string(text)
		if typeof(data) != TYPE_DICTIONARY:
			return {}
		var doc: Dictionary = data
		if doc.get("rooms") is Array:
			return doc
		if doc.has("rows"):
			return {"file": path.get_file().get_basename(), "source": "json", "placed": false, "rooms": [doc]}
		return {}
	return Codec.doc_from_xml(text, path.get_file().get_basename())


static func _as_map(doc: Dictionary) -> Dictionary:
	if doc.is_empty() or not (doc.get("rooms") is Array):
		return {}
	var copy: Dictionary = doc.duplicate(true)
	copy.erase("remove")
	copy.erase("base")
	copy["placed"] = true
	var rooms: Array = copy.get("rooms", [])
	var used := {}
	for room_v in rooms:
		if typeof(room_v) != TYPE_DICTIONARY:
			continue
		if room_v.has("x") and room_v.has("y"):
			used[Vector2i(int(room_v.x), int(room_v.y))] = true
	var n := 0
	for room_v in rooms:
		if typeof(room_v) != TYPE_DICTIONARY:
			continue
		if room_v.has("x") and room_v.has("y"):
			continue
		while used.has(Vector2i(n, 0)):
			n += 1
		room_v["x"] = n
		room_v["y"] = 0
		used[Vector2i(n, 0)] = true
		n += 1
	return copy


static func _pick_path(host: Node, then: Callable) -> void:
	var dlg := FileDialog.new()
	dlg.theme = Forms.editor_theme()
	dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.title = Locale.t("ed_from_file")
	dlg.filters = PackedStringArray(["*.xml ; XML", "*.json ; JSON"])
	dlg.exclusive = true
	var parent := host.get_parent() if host is Window and host.get_parent() != null else host
	if host is Window:
		(host as Window).exclusive = false
	parent.add_child(dlg)
	var restore := func() -> void:
		if host is Window and is_instance_valid(host):
			(host as Window).exclusive = true
	dlg.file_selected.connect(func(path: String) -> void:
		restore.call()
		dlg.queue_free()
		then.call(path)
	)
	dlg.canceled.connect(func() -> void:
		restore.call()
		dlg.queue_free()
	)
	dlg.popup_centered(Vector2i(800, 500))


static func _close(w: Window) -> void:
	w.hide()
	w.queue_free()


static func _tabs(parent: VBoxContainer) -> TabContainer:
	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(tabs)
	return tabs


static func _page(tabs: TabContainer, title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(box)
	tabs.set_tab_title(box.get_index(), title)
	return box


static func _window(host: Node, title: String) -> Window:
	var w := Window.new()
	w.title = title
	w.theme = Forms.editor_theme()
	w.exclusive = true
	w.min_size = Vector2i(640, 420)
	w.close_requested.connect(w.queue_free)
	host.add_child(w)
	return w


static func _column(w: Window) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 8)
	w.add_child(margin)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(box)
	return box


static func _split_row(parent: VBoxContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	return row


static func _side(row: HBoxContainer) -> VBoxContainer:
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(side)
	return side


static func _file_list(row: HBoxContainer) -> ItemList:
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(200, 160)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(list)
	return list


static func _canvas() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(240, 150)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.clip_contents = true
	c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	c.set_meta("view", ViewScr.new())
	return c


static func _tex_box(parent: Node) -> CheckBox:
	var tex := CheckBox.new()
	tex.text = Locale.t("ed_view_tex")
	parent.add_child(tex)
	return tex


static func _name_label(parent: Node) -> Label:
	var name_l := Label.new()
	name_l.clip_text = true
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(name_l)
	return name_l


static func _note_label(parent: Node) -> Label:
	var note := Label.new()
	note.clip_text = true
	parent.add_child(note)
	return note


static func _plain_label(text: String) -> Label:
	var lab := Label.new()
	lab.text = text
	return lab


static func _button_row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	parent.add_child(row)
	return row


static func _button(parent: Node, text: String) -> Button:
	var b := Button.new()
	b.text = text
	parent.add_child(b)
	return b


static func _bind_map_draw(c: Control, doc_of: Callable, sel_of: Callable) -> void:
	c.draw.connect(func() -> void:
		if c.size.x < 2.0 or c.size.y < 2.0:
			return
		c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.05, 0.05, 0.08))
		c.get_meta("view").paint_minimap(c, doc_of.call(), Rect2(Vector2.ZERO, c.size), sel_of.call(), false)
	)


static func _bind_room_draw(c: Control, tex: CheckBox, room_of: Callable) -> void:
	c.draw.connect(func() -> void:
		if c.size.x < 2.0 or c.size.y < 2.0:
			return
		c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.06, 0.06, 0.07))
		c.get_meta("view").paint_room_preview(c, room_of.call(), Rect2(Vector2.ZERO, c.size), tex.button_pressed)
	)


static func _show_room(w: Window, room: Dictionary, name_l: Label, map_c: Control, room_c: Control, room_key: String, sel_key: String) -> void:
	w.set_meta(room_key, room)
	var sel := Vector2i(-1, -1)
	if room.has("x") and room.has("y"):
		sel = Vector2i(int(room.x), int(room.y))
	w.set_meta(sel_key, sel)
	name_l.text = str(room.get("name", ""))
	if map_c:
		map_c.queue_redraw()
	if room_c:
		room_c.queue_redraw()


static func _select_first(list: ItemList, doc: Dictionary, w: Window, room_key: String, name_l: Label, room_c: Control) -> void:
	var rooms: Array = doc.get("rooms", [])
	if rooms.is_empty():
		w.set_meta(room_key, {})
		name_l.text = ""
		room_c.queue_redraw()
		return
	list.select(0)
	_pick_listed(doc, 0, w, room_key, name_l, room_c, list)


static func _pick_listed(doc: Dictionary, i: int, w: Window, room_key: String, name_l: Label, room_c: Control, list: ItemList = null) -> void:
	var rooms: Array = doc.get("rooms", [])
	var idx := i
	if list != null and i >= 0 and i < list.item_count:
		idx = int(list.get_item_metadata(i))
	var room: Dictionary = rooms[idx] if idx >= 0 and idx < rooms.size() else {}
	w.set_meta(room_key, room)
	name_l.text = str(room.get("name", ""))
	room_c.queue_redraw()


static func _fill_files(list: ItemList, placed_only: bool) -> void:
	list.clear()
	for name_v in RoomFile.file_names():
		var name := str(name_v)
		if name == "" or name.begins_with("_"):
			continue
		var doc := RoomFile.load_doc(name)
		if doc.is_empty():
			continue
		if placed_only and not bool(doc.get("placed", false)):
			continue
		var label := name
		if RoomFile.has_mod(name):
			label += "  [%s]" % Locale.t("ed_mod_mark")
		var i := list.add_item(label)
		list.set_item_metadata(i, name)


static func _sort_toggle(parent: Node, list: ItemList, doc_of: Callable) -> void:
	var toggle := CheckButton.new()
	toggle.text = Locale.t("ed_sort_pos")
	toggle.tooltip_text = Locale.t("ed_sort_pos_tip")
	toggle.button_pressed = false
	list.set_meta("by_pos", false)
	toggle.toggled.connect(func(on: bool) -> void:
		list.set_meta("by_pos", on)
		_fill_rooms(list, doc_of.call())
	)
	parent.add_child(toggle)


static func _fill_rooms(list: ItemList, doc: Dictionary) -> void:
	list.clear()
	var rooms: Array = []
	var src: Array = doc.get("rooms", [])
	for i in src.size():
		if typeof(src[i]) == TYPE_DICTIONARY:
			rooms.append({"i": i, "room": src[i]})
	var by_pos := bool(list.get_meta("by_pos", false))
	rooms.sort_custom(func(a, b):
		var ra: Dictionary = a.room
		var rb: Dictionary = b.room
		if by_pos:
			var ay := int(ra.get("y", 0))
			var by := int(rb.get("y", 0))
			if ay != by:
				return ay < by
			var ax := int(ra.get("x", 0))
			var bx := int(rb.get("x", 0))
			if ax != bx:
				return ax < bx
		return Groups.natural_less(str(ra.get("name", "")), str(rb.get("name", "")))
	)
	for row_v in rooms:
		var row: Dictionary = row_v
		var room: Dictionary = row.room
		var n := list.add_item(str(room.get("name", "")))
		list.set_item_metadata(n, int(row.i))


static func _first_room(doc: Dictionary) -> Dictionary:
	var rooms: Array = doc.get("rooms", [])
	for room_v in rooms:
		if room_v.has("x") and room_v.has("y"):
			return room_v
	if rooms.is_empty():
		return {}
	return rooms[0]


static func _room_at(doc: Dictionary, cell: Vector2i) -> Dictionary:
	var found := {}
	for room_v in doc.get("rooms", []):
		if int(room_v.get("x", -99999)) != cell.x or int(room_v.get("y", -99999)) != cell.y:
			continue
		if found.is_empty() or int(room_v.get("z", 0)) < int(found.get("z", 0)):
			found = room_v
	return found


static func _left_click(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
