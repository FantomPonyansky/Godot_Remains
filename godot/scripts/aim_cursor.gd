extends CanvasLayer

## In-game pointer for the play scene, including pause.
## GameContainer.sysCur shows the system cursor and hides this marker.
## Otherwise the OS cursor stays hidden. Fullscreen is left alone.
## A bump adds event.relative to this marker. It does not copy the OS position
## and nothing here warps the OS pointer.
## The right stick moves this marker every playing frame. Axes are read from
## the event and from devices 0-7, because get_connected_joypads() can stay
## empty while device 0 is live, and the right stick has no InputMap action.
## Port extra, gamepad only: aim assist slows the marker near a target and,
## only while the stick moves, nudges it toward the nearest one. A released
## stick leaves the marker where it is.
## A menu draws the arrow at the mouse. A pad keeps this marker. Sats still aims.

const STICK_SPEED := 720.0
const _WARP := 200.0
const ASSIST_GROUPS := ["enemies", "tk_use", "levitatable", "pickups", "ground_loot"]
const ASSIST_RADIUS := 56.0
## A body whose origin is farther than this from the cursor cannot be under it
## (wide areas and doors keep their origin at a corner).
const PICK_REACH := 600.0
## fog_sight.META_HIDDEN: out of the player's sight right now.
const _FOG_HIDDEN := "fog_layer"
## Share of the gap to the target closed per second at full stick and 100% pull,
## fading to 0 at ASSIST_RADIUS. Pull and slowdown are Controls sliders.
const ASSIST_NUDGE := 3.0
## GameContainer.actionDist is 40000, a squared 200px.
const ACTION_REACH := 200.0
const _ARROW := preload("res://assets/ui/cursor/arrow.png")
const _RoomActivity := preload("res://scripts/map/room_activity.gd")
const _TARGET := preload("res://assets/ui/cursor/target.png")
const _COMBAT := preload("res://assets/ui/cursor/target1.png")
const _ACTION := preload("res://assets/ui/cursor/target2.png")

var screen_pos: Vector2 = Vector2(640, 360)
var _marker: Node2D
var _pads: Dictionary = {}
var _drop_warp := false
var _deadzone := 0.25
var _frame := "target"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_to_group("aim_cursor")
	# Above pause (10), the stand (90) and the intro (120).
	layer = 128
	var view := get_viewport().get_visible_rect().size
	var mouse := get_viewport().get_mouse_position()
	if mouse.x >= 0.0 and mouse.y >= 0.0 and mouse.x <= view.x and mouse.y <= view.y:
		screen_pos = mouse
	else:
		screen_pos = view * 0.5
	_marker = Node2D.new()
	_marker.z_index = 20
	_marker.scale = Vector2.ONE / 1.5
	_marker.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_marker)
	_marker.draw.connect(_draw_cross)
	_marker.position = screen_pos
	_marker.queue_redraw()
	_hide_os_cursor()


func _exit_tree() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if Input.mouse_mode == Input.MOUSE_MODE_CONFINED_HIDDEN or Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion:
		_remember_axis(event as InputEventJoypadMotion)
		return
	if not event is InputEventMouseMotion:
		return
	# Re-hide before the motion is drawn, so the bump cannot flash the OS cursor.
	if not UiSettings.flag("sys_cur"):
		_hide_os_cursor()
	var motion := event as InputEventMouseMotion
	if _drop_warp:
		_drop_warp = false
		if motion.relative.length() > _WARP:
			return
	# event.position is the OS cursor. Assigning it would teleport this marker.
	if motion.relative.length_squared() < 0.01:
		return
	# While the pad is in use a slight mouse touch must not move the marker.
	if not Prompts.accept_mouse_motion(motion):
		return
	# The weapon wheel reads the mouse for its slices.
	if has_meta("wheel"):
		return
	# The marker sits on the confined OS cursor. A marker that drifted away
	# from it could not reach the screen edge the cursor already touches.
	_move(get_viewport().get_mouse_position() - screen_pos, true)


func _process(_delta: float) -> void:
	var sys := UiSettings.flag("sys_cur")
	if _marker != null:
		_marker.visible = not sys
	if sys:
		_show_os_cursor()
	else:
		_hide_os_cursor()
	# PipBuck, pause, the stand and the other overlays pause the tree.
	# The arrow follows the mouse. A pad keeps the marker where the stick left it.
	if _menu_arrow():
		if not sys:
			_paint("arrow", get_viewport().get_mouse_position())
		return
	var playing := not get_tree().paused or has_meta("sats")
	if playing:
		if not sys:
			_paint(_aim_frame(), screen_pos)
	elif _frame == "arrow" and not sys:
		_paint("target", screen_pos)
	# Sats pauses the world but still aims.
	if not playing:
		return
	# The menu dead zone covers the left stick; the right stick is a bit finer.
	_deadzone = maxf(0.05, UiSettings.stick_deadzone() - 0.1)
	var stick := _stick()
	# After the weapon wheel the stick that picked a slice must come back first.
	if has_meta("stick_lock"):
		if stick.length() >= _deadzone:
			return
		remove_meta("stick_lock")
	if stick.length() < _deadzone:
		return
	var assist := Prompts.pad and UiSettings.aim_assist()
	var target := _assist_target() if assist else Vector2.INF
	var speed := STICK_SPEED * UiSettings.aim_sensitivity()
	var step := stick * speed * _delta
	if target != Vector2.INF:
		step *= 1.0 - UiSettings.assist_slow()
		var to := target - screen_pos
		var falloff := 1.0 - clampf(to.length() / ASSIST_RADIUS, 0.0, 1.0)
		step += to * minf(1.0, ASSIST_NUDGE * UiSettings.assist_pull() * falloff * minf(stick.length(), 1.0) * _delta)
	_move(step)


func _menu_arrow() -> bool:
	if Prompts.pad or has_meta("sats"):
		return false
	return get_tree().paused or GameState.paused


func _paint(frame: String, at: Vector2) -> void:
	if _marker == null:
		return
	var moved := _marker.position.distance_squared_to(at) > 0.25
	if frame == _frame and not moved:
		return
	_frame = frame
	_marker.position = at
	_marker.queue_redraw()


## GUI.setCelObj, then GameContainer.cur swaps in combat for the whole battle.
func _aim_frame() -> String:
	if _foe_tracking():
		return "combat"
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return "target"
	var carried: Variant = player.get("_tele_obj")
	if is_instance_valid(carried) and carried is Node:
		return "action"
	var using: Variant = player.get("_use_node")
	if is_instance_valid(using) and using is Node:
		return "action"
	var hit := _under_cursor(player)
	if hit == null:
		return "target"
	if _action_target(player, hit):
		return "action"
	if hit.is_in_group("enemies"):
		return "combat"
	return "target"


## GameContainer.t_battle stays up while some foe is on the player.
func _foe_tracking() -> bool:
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node) and node.get("_track_player") == true:
			return true
	return false


func _under_cursor(player: Node2D) -> Node2D:
	if not player.has_method("_aim_rect"):
		return null
	var at := world_position()
	var best: Node2D = null
	var best_prior := -1.0
	var seen := {}
	# Loot prior is 3. Units and boxes are 1. The higher one is the object under the cursor.
	for group_name in ASSIST_GROUPS:
		for node in _RoomActivity.near(get_tree(), group_name):
			if not node is Node2D or seen.has(node) or not is_instance_valid(node):
				continue
			seen[node] = true
			var body := node as Node2D
			if body.global_position.distance_squared_to(at) > PICK_REACH * PICK_REACH:
				continue
			if not body.is_visible_in_tree() or body.has_meta(_FOG_HIDDEN):
				continue
			if bool(body.get_meta("dead", false)) or bool(body.get_meta("spent", false)) or body.get("_dead") == true:
				continue
			var got: Variant = player.call("_aim_rect", body)
			if not got is Rect2 or not (got as Rect2).has_point(at):
				continue
			var prior := 3.0 if (body.is_in_group("pickups") or body.is_in_group("ground_loot")) else 1.0
			if prior < best_prior:
				continue
			best_prior = prior
			best = body
	return best


func _action_target(player: Node2D, body: Node2D) -> bool:
	if bool(player.get("rat")) or not body.is_in_group("tk_use"):
		return false
	if body.has_meta("usable") and not bool(body.get_meta("usable")):
		return false
	var point := body.global_position
	if player.has_method("_use_point"):
		var got: Variant = player.call("_use_point", body)
		if got is Vector2:
			point = got
	return player.global_position.distance_squared_to(point) <= ACTION_REACH * ACTION_REACH


func _assist_target() -> Vector2:
	var player := get_tree().get_first_node_in_group("player")
	var to_screen := get_viewport().get_canvas_transform()
	var best := Vector2.INF
	var best_d := ASSIST_RADIUS
	for group_name in ASSIST_GROUPS:
		for node in _RoomActivity.near(get_tree(), group_name):
			if not node is Node2D or not is_instance_valid(node) or node == player:
				continue
			var body := node as Node2D
			if (to_screen * body.global_position).distance_to(screen_pos) > best_d + PICK_REACH:
				continue
			if not body.is_visible_in_tree() or body.has_meta(_FOG_HIDDEN) or bool(body.get_meta("dead", false)) or bool(body.get_meta("spent", false)) or body.get_meta("no_vis", false):
				continue
			var at := body.global_position
			if player != null and player.has_method("_body_center"):
				at = player.call("_body_center", body)
			var spot := to_screen * at
			var gap := spot.distance_to(screen_pos)
			if gap < best_d:
				best_d = gap
				best = spot
	return best


func world_position() -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos


func warp_world(at: Vector2) -> void:
	_move(get_viewport().get_canvas_transform() * at - screen_pos)


func _remember_axis(motion: InputEventJoypadMotion) -> void:
	var id := motion.device
	if id < 0:
		id = 0
	var right: Vector2 = _pads.get(id, Vector2.ZERO)
	match motion.axis:
		JOY_AXIS_RIGHT_X:
			right.x = motion.axis_value
		JOY_AXIS_RIGHT_Y:
			right.y = motion.axis_value
		_:
			return
	_pads[id] = right


func _stick() -> Vector2:
	# Device 0 is polled even when it is missing from get_connected_joypads().
	# The left stick is movement. Only the right stick moves this marker.
	var ids: Dictionary = {0: true}
	for extra in range(1, 8):
		ids[extra] = true
	for pad in Input.get_connected_joypads():
		ids[int(pad)] = true
	for seen in _pads.keys():
		ids[int(seen)] = true
	var sum := Vector2.ZERO
	for id in ids.keys():
		var device := int(id)
		var right: Vector2 = _pads.get(device, Vector2.ZERO)
		var polled_right := Vector2(Input.get_joy_axis(device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y))
		if polled_right.length() > right.length():
			right = polled_right
		if right.length() >= _deadzone:
			sum += right
	return sum.limit_length(1.0)


func _move(delta: Vector2, from_mouse := false) -> void:
	if _marker == null:
		return
	var view := get_viewport().get_visible_rect().size
	screen_pos += delta
	screen_pos.x = clampf(screen_pos.x, 0.0, view.x)
	screen_pos.y = clampf(screen_pos.y, 0.0, view.y)
	# The menu arrow is placed at the OS mouse in _process. Leave it there.
	if _menu_arrow():
		return
	if not from_mouse and DisplayServer.get_name() != "headless" and get_window().has_focus():
		# Prompts must not read the warp's motion as the mouse taking over.
		UiNav.warped_frame = Engine.get_process_frames()
		get_viewport().warp_mouse(screen_pos)
	_marker.position = screen_pos
	_marker.queue_redraw()


func _show_os_cursor() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _hide_os_cursor() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if Input.mouse_mode == Input.MOUSE_MODE_CONFINED_HIDDEN:
		return
	_drop_warp = true
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN


func _draw_cross() -> void:
	var tex := _TARGET
	var hot := Vector2(13, 13)
	match _frame:
		"arrow":
			tex = _ARROW
			hot = Vector2.ZERO
		"combat":
			tex = _COMBAT
		"action":
			tex = _ACTION
	_marker.draw_texture(tex, -hot)
