extends Node

## In-game look at an unsaved editor doc. No player, no fog, units frozen.
## Esc returns through editor_play (same cache drop and editor reopen).

const GAME := "res://scenes/game.tscn"
const Play := preload("res://scripts/editor/editor_play.gd")

static var _on := false


static func running() -> bool:
	return _on


static func start(doc: Dictionary, file: String, room: String, one_room: bool, dirty := false, kind := "", fon := "", view: Dictionary = {}) -> void:
	_on = true
	Play.start(file, room, one_room, doc, dirty, kind, fon, view)
	var tree := Engine.get_main_loop() as SceneTree
	var travel := tree.root.get_node_or_null("Travel") if tree else null
	if travel != null:
		travel.enter_game()
	elif tree:
		tree.change_scene_to_file(GAME)


static func attach(host: Node) -> void:
	if not _on or host.get_node_or_null("EditorPreview") != null:
		return
	var node = load("res://scripts/editor/editor_preview.gd").new()
	node.name = "EditorPreview"
	host.add_child(node)


var _drag := false
var _ldrag := false
var _left := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var travel := get_node_or_null("/root/Travel")
	if travel and travel.has_signal("land_entered"):
		travel.land_entered.connect(_on_land)


func _on_land(_id: String) -> void:
	_freeze()
	var cam := _cam()
	var player := _player()
	if cam != null and player != null:
		cam.global_position = player.global_position
		_keep_cam(cam)


## The player is disabled, and with physics interpolation the Camera2D scrolls in
## its internal physics step, so it must keep processing while its script stays off.
func _keep_cam(cam: Camera2D) -> void:
	cam.process_mode = Node.PROCESS_MODE_ALWAYS
	cam.set_physics_process(false)


func _process(delta: float) -> void:
	_freeze()
	var cam := _cam()
	if cam == null:
		return
	_keep_cam(cam)
	var dir := Vector2.ZERO
	if Input.is_action_pressed("move_left") or Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_action_pressed("move_right") or Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_action_pressed("aim_up") or Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_action_pressed("aim_down") or Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if dir != Vector2.ZERO:
		cam.global_position += dir.normalized() * (900.0 / maxf(cam.zoom.x, 0.2)) * delta
		_clamp(cam)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_leave()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_drag = mb.pressed
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_ldrag = mb.pressed
			get_viewport().set_input_as_handled()
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var factor := 1.1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1
			var cam := _cam()
			if cam:
				var z := clampf(cam.zoom.x * factor, 0.25, 3.0)
				cam.zoom = Vector2(z, z)
				_clamp(cam)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and (_drag or _ldrag):
		var cam := _cam()
		if cam:
			cam.global_position -= (event as InputEventMouseMotion).relative / cam.zoom
			_clamp(cam)


func _freeze() -> void:
	var player := _player()
	if player != null:
		player.visible = false
		player.process_mode = Node.PROCESS_MODE_DISABLED
		if player.has_method("set_control_off"):
			player.set_control_off(true)
		if player is CollisionObject2D:
			(player as CollisionObject2D).collision_layer = 0
			(player as CollisionObject2D).collision_mask = 0
	var fog: Node = null
	if get_parent() != null:
		fog = get_parent().get_node_or_null("Fog")
		var hud := get_parent().get_node_or_null("HUD")
		if hud != null and "visible" in hud:
			hud.visible = false
	if fog != null:
		fog.visible = false
		fog.process_mode = Node.PROCESS_MODE_DISABLED
	for group in ["enemies", "allies", "story_npc"]:
		for node in get_tree().get_nodes_in_group(group):
			node.process_mode = Node.PROCESS_MODE_DISABLED
			if node is CharacterBody2D:
				(node as CharacterBody2D).velocity = Vector2.ZERO


func _leave() -> void:
	if _left:
		return
	_left = true
	_on = false
	get_tree().change_scene_to_file(Play.menu_dest())


func _player() -> Node2D:
	var host := get_parent()
	if host == null:
		return null
	return host.get_node_or_null("Player") as Node2D


func _cam() -> Camera2D:
	var player := _player()
	if player == null:
		return null
	return player.get_node_or_null("Camera2D") as Camera2D


func _clamp(cam: Camera2D) -> void:
	var half := get_viewport().get_visible_rect().size * 0.5 / cam.zoom
	var x := clampf(cam.global_position.x, cam.limit_left + half.x, maxf(float(cam.limit_left) + half.x, float(cam.limit_right) - half.x))
	var y := clampf(cam.global_position.y, cam.limit_top + half.y, maxf(float(cam.limit_top) + half.y, float(cam.limit_bottom) - half.y))
	cam.global_position = Vector2(x, y)
