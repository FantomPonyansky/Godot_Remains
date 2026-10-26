extends Node

## Tap / hold pairs on one gamepad button. When the tap action and the hold
## action of a pair are bound to the same pad button, InputBindings takes that
## button out of both actions in the InputMap and this node drives them:
## a release before the hold time presses the tap action for TAP_FRAMES physics
## frames (so it fires on release), and holding past it keeps the hold action
## pressed until the button comes up. Presses that start while the tree is
## paused (menus, Sats) are ignored. Child of InputBindings.

## [tap, hold, seconds]
const PAIRS := [
	["reload", "pet_command", 0.4],
	["weapon_next", "weapon_wheel", 0.25],
	["weapon_prev", "spell_wheel", 0.25],
	["quick_heal", "quick_mana", 0.4],
]
const TAP_FRAMES := 2
## Sprint (Shift / L3) pressed twice within this window presses dash toward facing.
const DASH_WINDOW_MS := 300

## button_index -> pair index, filled by InputBindings.
var buttons: Dictionary = {}
## button_index -> {"pair": int, "at": msec, "held": bool}
var _down: Dictionary = {}
## action -> physics frames left pressed
var _pulses: Dictionary = {}
var _last_sprint_at := -100000


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func set_buttons(map: Dictionary) -> void:
	for button in _down.keys():
		_end(int(button), false)
	buttons = map


func hold_action(button: int) -> String:
	return str(PAIRS[int(buttons[button])][1]) if buttons.has(button) else ""


func tap_action(button: int) -> String:
	return str(PAIRS[int(buttons[button])][0]) if buttons.has(button) else ""


func is_holding(action: String) -> bool:
	for button in _down:
		var row: Dictionary = _down[button]
		if bool(row["held"]) and str(PAIRS[int(row["pair"])][1]) == action:
			return true
	return false


func _input(event: InputEvent) -> void:
	if InputMap.has_action("sprint") and event.is_action_pressed("sprint") and not event.is_echo():
		_sprint_tap()
	if not event is InputEventJoypadButton:
		return
	var button := (event as InputEventJoypadButton).button_index as int
	if not buttons.has(button):
		return
	if event.is_pressed():
		if _down.has(button) or get_tree().paused:
			return
		_down[button] = {"pair": int(buttons[button]), "at": Time.get_ticks_msec(), "held": false}
	elif _down.has(button):
		_end(button, true)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	for button in _down.keys():
		var row: Dictionary = _down[button]
		if bool(row["held"]):
			continue
		var pair: Array = PAIRS[int(row["pair"])]
		if now - int(row["at"]) >= int(float(pair[2]) * 1000.0):
			row["held"] = true
			Input.action_press(str(pair[1]))


func _physics_process(_delta: float) -> void:
	for action in _pulses.keys():
		var left := int(_pulses[action]) - 1
		if left <= 0:
			_pulses.erase(action)
			Input.action_release(str(action))
		else:
			_pulses[action] = left


func _end(button: int, tap: bool) -> void:
	var row: Dictionary = _down[button]
	_down.erase(button)
	var pair: Array = PAIRS[int(row["pair"])]
	if bool(row["held"]):
		Input.action_release(str(pair[1]))
	elif tap and not get_tree().paused:
		var action := str(pair[0])
		if action == "reload":
			var keys := get_tree().get_first_node_in_group("quick_keys")
			if keys != null and keys.call("crack_ready"):
				action = "crack"
		_pulse(action)


func _pulse(action: String) -> void:
	Input.action_press(action)
	_pulses[action] = TAP_FRAMES


func _sprint_tap() -> void:
	if get_tree().paused:
		return
	var now := Time.get_ticks_msec()
	if now - _last_sprint_at <= DASH_WINDOW_MS:
		_pulse("dash")
		_last_sprint_at = -100000
	else:
		_last_sprint_at = now
