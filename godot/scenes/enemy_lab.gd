extends Node2D

## Sandbox for every unit the game can draw: the list is `enemies.json` order (units with a
## sheet or a rig), and each one is the game's own `enemy.tscn` set up from its id, so its
## clips, frame counts, speeds and loops are the game's (sheet frames, or a rig following
## the ghost frames). New units, rigs and clips show up with no change here.
## AI stays off. Enter replays the clip and, when this enemy script actually
## has a matching act, runs that act once at the dummy.

const _EnemyScript := preload("res://scripts/enemy.gd")
const _EnemyScene := preload("res://scenes/enemy.tscn")

const SPAWN := Vector2(480, 520)
const DUMMY_GAP := 340.0

var _catalog: Dictionary = {}
var _enemies: Array[String] = []

var _enemy_list: ItemList
var _action_list: ItemList
var _status: Label
var _active := 1
var _enemy_i := 0
var _action_i := 0

var _actor: CharacterBody2D
var _dummy: Target
var _clip := ""
var _hopping := false
var _left_floor := false
var _hop_time := 0.0
var _stick_lock := 0.0
var _hit := ""


func _ready() -> void:
	_build_stage()
	_load_catalog()
	_collect_enemies()
	_fill_enemy_list()
	if _enemies.is_empty():
		_status.text = "No unit in enemies.json has a sheet or a rig."
		return
	_select_enemy(0)


func _process(delta: float) -> void:
	_stick_lock = maxf(0.0, _stick_lock - delta)
	if _clip != "":
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
	cam.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
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


func _load_catalog() -> void:
	var path := "res://assets/data/enemies.json"
	if not FileAccess.file_exists(path):
		push_error("Enemy lab: missing %s" % path)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		_catalog = parsed


## `order` first, then any unit added to `units` but not yet ordered.
func _collect_enemies() -> void:
	_enemies.clear()
	var units: Dictionary = _catalog.get("units", {})
	var ids: Array = (_catalog.get("order", []) as Array).duplicate()
	var rest: Array = units.keys().filter(func(k: Variant) -> bool: return not ids.has(k))
	rest.sort()
	ids.append_array(rest)
	for key in ids:
		var id := str(key)
		if not units.get(id, null) is Dictionary:
			continue
		var sheet := str(_EnemyScript._sheet_path(id))
		if str(_EnemyScript.rig_path(id)) != "" or (sheet != "" and ResourceLoader.exists(sheet)):
			_enemies.append(id)


func _fill_enemy_list() -> void:
	_enemy_list.clear()
	for name in _enemies:
		_enemy_list.add_item(name + ("  [rig]" if str(_EnemyScript.rig_path(name)) != "" else ""))


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


func _anim() -> AnimatedSprite2D:
	return _actor.get("anim") as AnimatedSprite2D if _actor != null else null


func _fill_actions() -> void:
	_action_list.clear()
	var anim := _anim()
	if anim == null or anim.sprite_frames == null:
		return
	for clip in anim.sprite_frames.get_animation_names():
		if anim.sprite_frames.get_frame_count(clip) > 0:
			_action_list.add_item(clip)
	if _action_list.item_count > 0:
		_action_i = 0


func _spawn_actor(id: String) -> void:
	_hopping = false
	_hit = ""
	if _actor != null and is_instance_valid(_actor):
		_actor.hide()
		_actor.set_physics_process(false)
		_actor.queue_free()
		_actor = null
	var before := int(GameState.enemies_remaining)
	var actor := _EnemyScene.instantiate() as CharacterBody2D
	actor.set_meta("unit_id", id)
	actor.name = id
	actor.position = SPAWN
	actor.add_to_group(id)
	add_child(actor)
	GameState.enemies_remaining = before
	# The body and its AI stay put; the sprite (and a rig following it) animates.
	actor.set_physics_process(false)
	actor.set_process(false)
	_actor = actor
	_actor.set("_player", _dummy)
	_place_dummy(false)
	_face_dummy()


func _restart_clip() -> void:
	if _action_list.item_count == 0:
		_clip = ""
		return
	_action_i = clampi(_action_i, 0, _action_list.item_count - 1)
	_clip = _action_list.get_item_text(_action_i)
	_actor.position = SPAWN
	_actor.velocity = Vector2.ZERO
	_hopping = false
	_place_dummy(false)
	_face_dummy()
	var anim := _anim()
	if anim:
		anim.play(_clip)
		anim.frame = 0
	_show_frame()
	_mark_lists()


func _show_frame() -> void:
	var anim := _anim()
	if anim == null or _clip == "" or anim.sprite_frames == null:
		return
	var frames := anim.sprite_frames
	var count := frames.get_frame_count(_clip)
	var kind := _behaviour(_clip)
	var act := "visual" if kind == "" else "Enter: %s" % kind
	var span := "loop" if frames.get_animation_loop(_clip) else "once"
	var src := "rig" if _actor.get("rig") != null else "sheet"
	var hit := ""
	if _hit != "":
		hit = " · dummy %s" % _hit
	_status.text = "%s · %s · %s · frame %d / %d · %s fps · %s · %s%s" % [
		_enemies[_enemy_i], src, _clip, anim.frame, count - 1,
		_num(frames.get_animation_speed(_clip)), span, act, hit
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

	# In group "player", so Condition's per-tick gun-wear check reads these.
	var _reload_left := 0.0
	var _fire_cd := 0.0
	var _semi_lock := false

	func take_hit(amount: int = 15, _type: String = "") -> void:
		struck.emit(amount)
