extends Node

## One PlayerCommand per sim tick. The device is read on every rendered frame
## (_input and _process). Phase INPUT freezes that into the command the tick
## reads, then clears the edges. A press and a release between two ticks is
## one press and one release; held is the latest state.
## Menus pause the tree. This node stays active so those edges are spent here
## and do not fire on the first live tick. SATS is the pause that still reads
## the command. Sim skips INPUT while paused, so a paused tick freezes here.

class PlayerCommand:
	var tick := 0
	var held: Dictionary = {}
	var pressed: Dictionary = {}
	var released: Dictionary = {}
	var strength: Dictionary = {}
	var aim := Vector2.ZERO


var command := PlayerCommand.new()

var _actions: Array[StringName] = []
var _live_held: Dictionary = {}
var _live_pressed: Dictionary = {}
var _live_released: Dictionary = {}
var _live_strength: Dictionary = {}
var _live_aim := Vector2.ZERO
var _idle_pressed: Dictionary = {}
var _idle_released: Dictionary = {}
## action -> process frame an inject wrote the edge. The idle clear keeps those.
var _idle_frame: Dictionary = {}
var _idle_rel_frame: Dictionary = {}
var _edge_gen := 0
var _idle_seen_gen := -1
var _idle_seen_frame := -1
var _applied_tick := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_reload_actions()
	var bindings := InputBindings
	if bindings != null and not bindings.changed.is_connected(_reload_actions):
		bindings.changed.connect(_reload_actions)
	Sim.register(Sim.Phase.INPUT, _freeze)


func _input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_action_type():
		return
	_ensure_actions()
	for action in _actions:
		if not event.is_action(action):
			continue
		if event.is_pressed():
			_live_pressed[action] = true
			_live_held[action] = true
		elif event.is_released():
			_live_released[action] = true
			_live_held.erase(action)


func _process(_delta: float) -> void:
	# The batch was shown last frame and no tick has replaced it.
	# Edges injected this frame (PadGestures runs first) stay.
	var frame := Engine.get_process_frames()
	if _idle_seen_gen == _edge_gen and _idle_seen_frame != frame:
		_drop_seen_idle(frame)
		_edge_gen += 1
		_idle_seen_gen = -1
	_poll()


## A synthetic press between polls. _process readers see it this frame; the
## next freeze still has the live edge.
func inject_down(action: StringName) -> void:
	var frame := Engine.get_process_frames()
	_live_held[action] = true
	_live_pressed[action] = true
	_idle_pressed[action] = true
	_idle_frame[action] = frame


func inject_up(action: StringName) -> void:
	var frame := Engine.get_process_frames()
	if bool(_live_held.get(action, false)):
		_live_released[action] = true
		_idle_released[action] = true
		_idle_rel_frame[action] = frame
	_live_held.erase(action)


func _drop_seen_idle(frame: int) -> void:
	var pressed := {}
	for action in _idle_pressed:
		if int(_idle_frame.get(action, -1)) == frame:
			pressed[action] = true
		else:
			_idle_frame.erase(action)
	_idle_pressed = pressed
	var released := {}
	for action in _idle_released:
		if int(_idle_rel_frame.get(action, -1)) == frame:
			released[action] = true
		else:
			_idle_rel_frame.erase(action)
	_idle_released = released


func _physics_process(_delta: float) -> void:
	if Sim.paused():
		_freeze()


func held(action: StringName) -> bool:
	# Physics reads the frozen command. UI and _process (the weapon wheel,
	# a PipBuck favourite assign) read the device, which already includes
	# a PadGestures inject from this frame.
	if Engine.is_in_physics_frame():
		return bool(command.held.get(action, false))
	return bool(_live_held.get(action, false))


func just_pressed(action: StringName) -> bool:
	if Engine.is_in_physics_frame():
		return bool(command.pressed.get(action, false))
	_idle_seen_gen = _edge_gen
	_idle_seen_frame = Engine.get_process_frames()
	return bool(_idle_pressed.get(action, false))


func just_released(action: StringName) -> bool:
	if Engine.is_in_physics_frame():
		return bool(command.released.get(action, false))
	_idle_seen_gen = _edge_gen
	_idle_seen_frame = Engine.get_process_frames()
	return bool(_idle_released.get(action, false))


func axis(neg: StringName, pos: StringName) -> float:
	return float(command.strength.get(pos, 0.0)) - float(command.strength.get(neg, 0.0))


func aim() -> Vector2:
	return command.aim


func _freeze() -> void:
	if _applied_tick == Sim.tick:
		return
	_applied_tick = Sim.tick
	_poll()
	var cmd := PlayerCommand.new()
	cmd.tick = Sim.tick
	cmd.held = _live_held.duplicate()
	cmd.strength = _live_strength.duplicate()
	cmd.aim = _live_aim
	if not _keep_edges():
		_drop_edges()
		command = cmd
		return
	cmd.pressed = _live_pressed.duplicate()
	cmd.released = _live_released.duplicate()
	if _idle_seen_gen == _edge_gen:
		_idle_pressed.clear()
		_idle_released.clear()
		_idle_frame.clear()
		_idle_rel_frame.clear()
		_edge_gen += 1
		_idle_seen_gen = -1
	for action in _live_pressed:
		_idle_pressed[action] = true
	for action in _live_released:
		_idle_released[action] = true
	_live_pressed.clear()
	_live_released.clear()
	command = cmd


func _keep_edges() -> bool:
	if not Sim.paused():
		return true
	var player := Run.local_player()
	if player == null:
		return false
	var sats := player.get_node_or_null("Sats")
	return sats != null and bool(sats.get("active"))


func _drop_edges() -> void:
	_live_pressed.clear()
	_live_released.clear()
	_idle_pressed.clear()
	_idle_released.clear()
	_idle_frame.clear()
	_idle_rel_frame.clear()
	_edge_gen += 1
	_idle_seen_gen = -1


func _poll() -> void:
	_ensure_actions()
	for action in _actions:
		var down := Input.is_action_pressed(action)
		var was := bool(_live_held.get(action, false))
		if down and not was:
			_live_pressed[action] = true
		elif not down and was:
			_live_released[action] = true
		if down:
			_live_held[action] = true
		else:
			_live_held.erase(action)
		_live_strength[action] = Input.get_action_strength(action)
	_live_aim = _sample_aim()


func _sample_aim() -> Vector2:
	var tree := get_tree()
	if tree == null:
		return _live_aim
	var cursor := tree.get_first_node_in_group("aim_cursor")
	if cursor != null and cursor.has_method("world_position"):
		return cursor.world_position()
	var vp := get_viewport()
	if vp == null:
		return _live_aim
	return vp.get_canvas_transform().affine_inverse() * vp.get_mouse_position()


func _reload_actions() -> void:
	_actions.clear()
	for action in InputMap.get_actions():
		_actions.append(StringName(action))


func _ensure_actions() -> void:
	if _actions.size() != InputMap.get_actions().size():
		_reload_actions()
