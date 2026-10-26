extends Node2D

## Sandbox for enemy sheets already imported under assets/sprites/sheets.
## Clip rows, lengths, and speeds come from the Remains spritesheets manifest.
## Frames are cut with SheetFrames, the same cutter the game uses.
## AI stays off. Enter replays the clip and, when this enemy script actually
## has a matching act, runs that act once at the dummy.

const _EnemyScript := preload("res://scripts/enemy.gd")
const _EnemyScene := preload("res://scenes/enemy.tscn")

const SHEET_DIR := "res://assets/sprites/sheets"
const SPAWN := Vector2(480, 520)
const DUMMY_GAP := 340.0
const TPS := 30.0

var _sheets: Dictionary = {}
var _catalog: Dictionary = {}
var _sizes: Dictionary = {}
var _enemies: Array[String] = []
var _cell := Vector2i(120, 120)
var _sheet_rows := 0

var _enemy_list: ItemList
var _action_list: ItemList
var _status: Label
var _active := 1
var _enemy_i := 0
var _action_i := 0

var _actor: CharacterBody2D
var _dummy: Target
var _clip := ""
var _meta: Dictionary = {}
var _f := 0.0
var _acc := 0.0
var _hold := false
var _hopping := false
var _left_floor := false
var _hop_time := 0.0
var _stick_lock := 0.0
var _hit := ""


func _ready() -> void:
	_build_stage()
	_load_manifest()
	_load_catalog()
	_collect_enemies()
	_fill_enemy_list()
	if _enemies.is_empty():
		_status.text = "No enemy sheet under assets/sprites/sheets."
		return
	_select_enemy(0)


func _process(delta: float) -> void:
	_stick_lock = maxf(0.0, _stick_lock - delta)
	if _clip == "":
		return
	_acc += delta
	var step := 1.0 / TPS
	while _acc >= step:
		_acc -= step
		_advance()
	_show_frame()


func _physics_process(delta: float) -> void:
	if _actor == null or not is_instance_valid(_actor):
		return
	var wind := float(_actor.get("_windup_left"))
	if wind > 0.0:
		_actor.set("_windup_left", maxf(0.0, wind - delta))
		if float(_actor.get("_windup_left")) <= 0.0:
			_actor.call("_deliver_strike")
	if not _hopping:
		return
	_hop_time += delta
	_actor.velocity.y += float(_EnemyScript.GRAVITY) * delta
	_actor.move_and_slide()
	if not _actor.is_on_floor():
		_left_floor = true
	elif _left_floor or _hop_time > 1.5:
		_hopping = false
		_actor.velocity = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion and _stick_lock > 0.0:
		return
	if event.is_echo() and not (event.is_action("ui_up") or event.is_action("ui_down") or event.is_action("ui_left") or event.is_action("ui_right")):
		return
	if event.is_action_pressed("ui_cancel"):
		_leave()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept"):
		_confirm()
		get_viewport().set_input_as_handled()
		return
	var moved := false
	if event.is_action_pressed("ui_up"):
		_move_selection(-1)
		moved = true
	elif event.is_action_pressed("ui_down"):
		_move_selection(1)
		moved = true
	elif event.is_action_pressed("ui_left"):
		_active = 0
		_mark_lists()
		moved = true
	elif event.is_action_pressed("ui_right"):
		_active = 1
		_mark_lists()
		moved = true
	if not moved:
		return
	if event is InputEventJoypadMotion:
		_stick_lock = 0.18
	get_viewport().set_input_as_handled()


func _build_stage() -> void:
	var cam := Camera2D.new()
	cam.position = Vector2(640, 380)
	cam.enabled = true
	add_child(cam)
	cam.make_current()

	var backdrop := Polygon2D.new()
	backdrop.color = Color(0.04, 0.045, 0.04)
	backdrop.polygon = PackedVector2Array([
		Vector2(-400, -200), Vector2(1600, -200), Vector2(1600, 900), Vector2(-400, 900)
	])
	add_child(backdrop)

	var floor_body := StaticBody2D.new()
	floor_body.position = SPAWN
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var floor_shape := CollisionShape2D.new()
	var floor_box := RectangleShape2D.new()
	floor_box.size = Vector2(1800, 48)
	floor_shape.shape = floor_box
	floor_shape.position = Vector2(200, 24)
	floor_body.add_child(floor_shape)
	add_child(floor_body)

	var floor_draw := Polygon2D.new()
	floor_draw.color = Color(0.18, 0.16, 0.12)
	floor_draw.polygon = PackedVector2Array([
		Vector2(-200, SPAWN.y), Vector2(1500, SPAWN.y), Vector2(1500, SPAWN.y + 48), Vector2(-200, SPAWN.y + 48)
	])
	add_child(floor_draw)

	_dummy = Target.new()
	_dummy.position = SPAWN + Vector2(DUMMY_GAP, 0)
	_dummy.collision_layer = 2
	_dummy.collision_mask = 0
	_dummy.add_to_group("player")
	var dummy_shape := CollisionShape2D.new()
	var dummy_box := RectangleShape2D.new()
	dummy_box.size = Vector2(32, 56)
	dummy_shape.shape = dummy_box
	dummy_shape.position = Vector2(0, -28)
	_dummy.add_child(dummy_shape)
	var dummy_draw := Polygon2D.new()
	dummy_draw.color = Color(0.75, 0.45, 0.22)
	dummy_draw.polygon = PackedVector2Array([
		Vector2(-16, -56), Vector2(16, -56), Vector2(16, 0), Vector2(-16, 0)
	])
	_dummy.add_child(dummy_draw)
	_dummy.struck.connect(_on_dummy_hit)
	add_child(_dummy)

	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := load("res://theme/wasteland.tres") as Theme
	if theme:
		root.theme = theme
	layer.add_child(root)

	var title := Label.new()
	title.text = "Enemy Lab"
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.offset_top = 12
	title.offset_bottom = 40
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var enemy_title := _side_label(root, "Enemies", 16)
	var action_title := _side_label(root, "Actions", -280)

	_enemy_list = _make_list(root, 16, 280)
	_action_list = _make_list(root, -280, -16)
	_enemy_list.item_clicked.connect(_on_enemy_clicked)
	_action_list.item_clicked.connect(_on_action_clicked)

	_status = Label.new()
	_status.anchor_left = 0.0
	_status.anchor_right = 1.0
	_status.anchor_top = 1.0
	_status.anchor_bottom = 1.0
	_status.offset_left = 16
	_status.offset_right = -16
	_status.offset_top = -78
	_status.offset_bottom = -40
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status)

	var hint := Label.new()
	hint.text = "Up/Down and left stick change the row. Left/Right switches list. Enter plays. Esc returns to the menu."
	hint.anchor_left = 0.0
	hint.anchor_right = 1.0
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = 16
	hint.offset_right = -16
	hint.offset_top = -36
	hint.offset_bottom = -8
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(hint)
	enemy_title.offset_left = 16
	action_title.offset_left = -280


func _side_label(root: Control, text: String, left: float) -> Label:
	var label := Label.new()
	label.text = text
	label.anchor_top = 0.0
	label.offset_top = 44
	label.offset_bottom = 68
	label.offset_left = left
	label.offset_right = left + 240
	if left < 0.0:
		label.anchor_left = 1.0
		label.anchor_right = 1.0
	root.add_child(label)
	return label


func _make_list(root: Control, left: float, right: float) -> ItemList:
	var list := ItemList.new()
	list.anchor_top = 0.0
	list.anchor_bottom = 1.0
	list.offset_top = 72
	list.offset_bottom = -88
	list.offset_left = left
	list.offset_right = right
	if left < 0.0:
		list.anchor_left = 1.0
		list.anchor_right = 1.0
	list.focus_mode = Control.FOCUS_NONE
	list.select_mode = ItemList.SELECT_SINGLE
	root.add_child(list)
	return list


func _repo_file(rel: String) -> String:
	var godot_dir := ProjectSettings.globalize_path("res://").trim_suffix("/").trim_suffix("\\")
	return godot_dir.get_base_dir().path_join(rel)


func _load_manifest() -> void:
	var path := _repo_file("reference/Remains-Source2/Modules/core/spritesheets/spritesheets.json")
	if not FileAccess.file_exists(path):
		push_error("Enemy lab: missing spritesheets.json at %s" % path)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		_sheets = parsed


func _load_cell_sizes() -> void:
	var path := _repo_file("reference/Remains-Source2/Modules/core/AllData/units.xml")
	var parser := XMLParser.new()
	if parser.open(path) != OK:
		return
	var id := ""
	var parent := ""
	while parser.read() == OK:
		if parser.get_node_type() != XMLParser.NODE_ELEMENT:
			continue
		var node := parser.get_node_name()
		if node == "unit":
			id = _attr(parser, "id")
			parent = _attr(parser, "parent")
		elif node == "vis" and id != "":
			var sx := _attr(parser, "sprX")
			if sx == "":
				continue
			var sy := _attr(parser, "sprY")
			var size := Vector2i(int(sx), int(sy) if sy != "" else int(sx))
			var sheet := parent if parent != "" else id
			if not _sizes.has(sheet):
				_sizes[sheet] = []
			(_sizes[sheet] as Array).append(size)


func _attr(parser: XMLParser, key: String) -> String:
	if not parser.has_attribute(key):
		return ""
	return parser.get_named_attribute_value(key)


func _load_catalog() -> void:
	var path := "res://assets/data/enemies.json"
	if not FileAccess.file_exists(path):
		push_error("Enemy lab: missing %s" % path)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		_catalog = parsed


func _collect_enemies() -> void:
	_enemies.clear()
	var units: Dictionary = _catalog.get("units", {})
	var order: Array = _catalog.get("order", [])
	for key in order:
		var id := str(key)
		var row: Variant = units.get(id, {})
		if row is not Dictionary:
			continue
		var tex := str(row.get("texture", ""))
		if tex == "":
			continue
		if ResourceLoader.exists("%s/%s" % [SHEET_DIR, tex]):
			_enemies.append(id)


func _is_enemy_sheet(sheet: String) -> bool:
	if _sizes.has(sheet):
		return true
	# A parent with no sprX of its own still owns the sheet (raider).
	return _sheets.has(sheet) and sheet != "pony"


func _fill_enemy_list() -> void:
	_enemy_list.clear()
	for name in _enemies:
		_enemy_list.add_item(name)


func _select_enemy(index: int) -> void:
	if _enemies.is_empty():
		return
	_enemy_i = clampi(index, 0, _enemies.size() - 1)
	_active = 0
	_spawn_actor(_enemies[_enemy_i])
	_fill_actions()
	_mark_lists()
	_action_i = 0
	_restart_clip()


func _fill_actions() -> void:
	_action_list.clear()
	_meta.clear()
	var spec := _clip_spec(_enemies[_enemy_i])
	for key in spec.keys():
		var clip := str(key)
		var data: Dictionary = spec[key] if spec[key] is Dictionary else {}
		_meta[clip] = data
		_action_list.add_item(clip)
	if _action_list.item_count > 0:
		_action_i = 0


func _spawn_actor(sheet: String) -> void:
	_hopping = false
	_hit = ""
	if _actor != null and is_instance_valid(_actor):
		_actor.hide()
		_actor.set_physics_process(false)
		_actor.queue_free()
		_actor = null
	var before := int(GameState.enemies_remaining)
	var actor := _EnemyScene.instantiate() as CharacterBody2D
	var row := _unit_row(sheet)
	var tex_name := str(row.get("texture", ""))
	var tex := load("%s/%s" % [SHEET_DIR, tex_name]) as Texture2D
	actor.set("sheet_texture", tex)
	actor.set_meta("unit_id", sheet)
	actor.name = sheet
	actor.position = SPAWN
	actor.add_to_group(sheet)
	add_child(actor)
	GameState.enemies_remaining = before
	actor.set_physics_process(false)
	_actor = actor
	_actor.set("_player", _dummy)
	var cell: Array = row.get("cell", [120, 120])
	_cell = Vector2i(int(cell[0]), int(cell[1])) if cell.size() >= 2 else Vector2i(120, 120)
	_sheet_rows = int(tex.get_height() / _cell.y) if tex != null and _cell.y > 0 else 0
	_apply_sheet(_clip_spec(sheet), tex)
	_place_dummy(false)
	_face_dummy()


func _pick_cell(sheet: String, tex: Texture2D) -> Vector2i:
	var found: Array = _sizes.get(sheet, [])
	for entry in found:
		var size: Vector2i = entry
		if size.x > 0 and size.y > 0 and tex.get_width() % size.x == 0 and tex.get_height() % size.y == 0:
			return size
	if tex.get_width() % 120 == 0 and tex.get_height() % 120 == 0:
		return Vector2i(120, 120)
	if not found.is_empty():
		return found[0] as Vector2i
	return Vector2i(120, 120)


func _unit_row(id: String) -> Dictionary:
	var units: Dictionary = _catalog.get("units", {})
	var row: Variant = units.get(id, {})
	return row if row is Dictionary else {}


func _clip_spec(id: String) -> Dictionary:
	var spec := {}
	var keys: Array = _unit_row(id).get("clip_sheets", [])
	for key in keys:
		var part: Variant = _sheets.get(str(key), {})
		if part is Dictionary:
			for clip in part.keys():
				spec[str(clip)] = part[clip]
	if spec.is_empty():
		var baked: Variant = _unit_row(id).get("clips", {})
		if baked is Dictionary:
			return baked
	return spec


func _apply_sheet(spec: Dictionary, tex: Texture2D) -> void:
	var clips := {}
	var speeds := {}
	var loops := {}
	for key in spec.keys():
		var clip := str(key)
		var data: Dictionary = spec[key] if spec[key] is Dictionary else {}
		var row := int(data.get("y", 0))
		var length := maxi(int(data.get("len", 1)), 1)
		var start := int(data.get("ff", 0))
		var df := float(data.get("df", 1.0))
		clips[clip] = SheetFrames.row_clip(row, length, start)
		speeds[clip] = df * TPS
		loops[clip] = _loops(clip, data)
	var anim := _actor.get_node("AnimatedSprite2D") as AnimatedSprite2D
	anim.sprite_frames = SheetFrames.build(tex, _cell.x, _cell.y, clips, speeds, loops)
	anim.centered = true
	anim.scale = Vector2.ONE
	anim.position = Vector2.ZERO
	var off: Array = _unit_row(_enemies[_enemy_i]).get("offset", [])
	if off.size() >= 2:
		anim.offset = Vector2(float(off[0]), float(off[1]))


func _loops(clip: String, data: Dictionary) -> bool:
	if clip == "die" or clip == "fall":
		return false
	return int(data.get("rep", 0)) == 1


func _restart_clip() -> void:
	if _action_list.item_count == 0:
		_clip = ""
		return
	_action_i = clampi(_action_i, 0, _action_list.item_count - 1)
	_clip = _action_list.get_item_text(_action_i)
	var data: Dictionary = _meta.get(_clip, {})
	_f = float(int(data.get("ff", 0)))
	_acc = 0.0
	_hold = false
	_actor.position = SPAWN
	_actor.velocity = Vector2.ZERO
	_hopping = false
	_place_dummy(false)
	_face_dummy()
	_show_frame()
	_mark_lists()


func _advance() -> void:
	if _clip == "" or _hold:
		return
	var data: Dictionary = _meta.get(_clip, {})
	var start := int(data.get("ff", 0))
	var length := maxi(int(data.get("len", 1)), 1)
	var last := float(start + length - 1)
	var df := float(data.get("df", 1.0))
	if _f < last:
		_f += df
		return
	if _loops(_clip, data):
		_f = float(int(data.get("rf", 0)))
	else:
		_f = last
		_hold = true


func _show_frame() -> void:
	if _actor == null or _clip == "":
		return
	var data: Dictionary = _meta.get(_clip, {})
	var start := int(data.get("ff", 0))
	var length := maxi(int(data.get("len", 1)), 1)
	var row := int(data.get("y", 0))
	var col := clampi(int(_f), start, start + length - 1)
	var local := col - start
	var anim := _actor.get_node("AnimatedSprite2D") as AnimatedSprite2D
	if anim.sprite_frames and anim.sprite_frames.has_animation(_clip):
		anim.animation = _clip
		anim.frame = local
		anim.pause()
	var kind := _behaviour(_clip)
	var act := "visual" if kind == "" else "Enter: %s" % kind
	var outside := ""
	if row >= _sheet_rows:
		outside = " · row outside sheet"
	var fps := float(data.get("df", 1.0)) * TPS
	var span := "loop" if _loops(_clip, data) else "once"
	var hit := ""
	if _hit != "":
		hit = " · dummy %s" % _hit
	_status.text = "%s · %s · frame %d / %d · col %d row %d · %s fps · %s · %s%s%s" % [
		_enemies[_enemy_i], _clip, local, length - 1, col, row, _num(fps), span, act, outside, hit
	]


func _num(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	return str(snapped(value, 0.1))


func _behaviour(clip: String) -> String:
	if _actor == null:
		return ""
	var style := str(_actor.get("fight_style"))
	var fixed := bool(_actor.get("fixed_post"))
	# UnitMonstrik plays "attack" for the claw. The port swings with _melee_swing.
	if clip == "attack" and style == "melee" and _actor.has_method("_melee_swing"):
		return "melee"
	# UnitRaider plays "run" while dashing. The port's dash is _leap_back.
	if clip == "run" and style == "gunner" and not fixed and bool(_actor.get("_do_backoff")) and _actor.has_method("_leap_back"):
		return "hop"
	# Gunners and turrets shoot from hold. No sheet clip is that shot.
	return ""


func _confirm() -> void:
	if _clip == "":
		return
	var kind := _behaviour(_clip)
	_restart_clip()
	if kind == "hop":
		_begin_hop()
	elif kind == "melee":
		_begin_melee()


func _begin_hop() -> void:
	_actor.position = SPAWN
	_actor.velocity = Vector2.ZERO
	_place_dummy(false)
	_actor.set("_player", _dummy)
	_face_dummy()
	_left_floor = false
	_hop_time = 0.0
	_hopping = true
	_actor.call("_leap_back")


func _begin_melee() -> void:
	_actor.position = SPAWN
	_actor.velocity = Vector2.ZERO
	_hopping = false
	_place_dummy(true)
	_actor.set("_player", _dummy)
	_face_dummy()
	_actor.set("_attack_cd", 0.0)
	_actor.set("_windup_left", 0.0)
	_actor.call("_melee_swing")


func _place_dummy(close: bool) -> void:
	var gap := DUMMY_GAP
	if close and _actor != null:
		var body: Vector2 = _actor.get("body_size")
		if bool(_actor.get("_contact_bite")):
			gap = (body.x + 32.0) * 0.5 - 2.0
		else:
			gap = maxf(28.0, float(_actor.get("_swing_x")) - 6.0)
	_dummy.position = SPAWN + Vector2(gap, 0.0)


func _face_dummy() -> void:
	if _actor == null:
		return
	var dx := _dummy.global_position.x - _actor.global_position.x
	var facing := 1.0 if dx >= 0.0 else -1.0
	_actor.set("facing", facing)
	var anim := _actor.get_node("AnimatedSprite2D") as AnimatedSprite2D
	anim.flip_h = facing < 0.0
	var muzzle := _actor.get_node_or_null("Muzzle") as Marker2D
	var body: Vector2 = _actor.get("body_size")
	if muzzle:
		muzzle.position = Vector2(facing * maxf(body.x * 0.5, 16.0), -body.y * 0.6)


func _on_dummy_hit(amount: int) -> void:
	_hit = "hit %d" % amount
	_show_frame()


func _move_selection(step: int) -> void:
	if _active == 0:
		if _enemies.is_empty():
			return
		var next := posmod(_enemy_i + step, _enemies.size())
		if next != _enemy_i:
			_select_enemy(next)
		return
	if _action_list.item_count == 0:
		return
	_action_i = posmod(_action_i + step, _action_list.item_count)
	_restart_clip()


func _on_enemy_clicked(index: int, _at: Vector2, _button: int) -> void:
	_select_enemy(index)


func _on_action_clicked(index: int, _at: Vector2, _button: int) -> void:
	_active = 1
	_action_i = index
	_restart_clip()


func _mark_lists() -> void:
	_enemy_list.deselect_all()
	_action_list.deselect_all()
	if _enemy_i >= 0 and _enemy_i < _enemy_list.item_count:
		_enemy_list.select(_enemy_i)
	if _action_i >= 0 and _action_i < _action_list.item_count:
		_action_list.select(_action_i)


func _leave() -> void:
	GameState.set_paused(false)
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


class Target extends StaticBody2D:
	signal struck(amount: int)

	func take_hit(amount: int = 15, _type: String = "") -> void:
		struck.emit(amount)
